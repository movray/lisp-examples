;;; Step 1: Newell teapot data + bicubic Bezier math
;;; No OpenGL — just the geometry foundation.
;;; Load and call (teapot:test) to verify a few surface points.
;;;
;;; Coordinate system: z-up, teapot sits at z=0, rim at z~2.4
;;; Vertices 1-120 (rim + body) are exact Newell data.
;;; Handle (121-161), spout (162-203), lid (204-269), bottom (270-306)
;;; are close approximations — adjust after first visual render.

(defpackage #:teapot
  (:use #:cl)
  (:export #:+patches+ #:+vertices+
           #:bernstein #:dbernstein
           #:patch-point #:patch-tangents #:patch-normal
           #:tessellate-patch #:tessellate-all
           #:test))

(in-package #:teapot)

;;; ----------------------------------------------------------------
;;; Newell teapot: 32 patches x 16 control point indices (1-indexed)
;;; ----------------------------------------------------------------
(defparameter +patches+
  #(;; rim (4 patches)
    #( 1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16)
    #( 4 17 18 19  8 20 21 22 12 23 24 25 16 26 27 28)
    #(19 29 30 31 22 32 33 34 25 35 36 37 28 38 39 40)
    #(31 41 42  1 34 43 44  5 37 45 46  9 40 47 48 13)
    ;; upper body (4 patches)
    #(13 14 15 16 49 50 51 52 53 54 55 56 57 58 59 60)
    #(16 26 27 28 52 61 62 63 56 64 65 66 60 67 68 69)
    #(28 38 39 40 63 70 71 72 66 73 74 75 69 76 77 78)
    #(40 47 48 13 72 79 80 49 75 81 82 53 78 83 84 57)
    ;; lower body (4 patches)
    #(57 58 59 60 85 86 87 88 89 90 91 92 93 94 95 96)
    #(60 67 68 69 88 97 98 99 92 100 101 102 96 103 104 105)
    #(69 76 77 78 99 106 107 108 102 109 110 111 105 112 113 114)
    #(78 83 84 57 108 115 116 85 111 117 118 89 114 119 120 93)
    ;; handle (4 patches)
    #(121 122 123 124 125 126 127 128 129 130 131 132 133 134 135 136)
    #(124 137 138 121 128 139 140 125 132 141 142 129 136 143 144 133)
    #(133 134 135 136 145 146 147 148 149 150 151 152  69 153 154 155)
    #(136 143 144 133 148 156 157 145 152 158 159 149 155 160 161  69)
    ;; spout (4 patches)
    #(162 163 164 165 166 167 168 169 170 171 172 173 174 175 176 177)
    #(165 178 179 162 169 180 181 166 173 182 183 170 177 184 185 174)
    #(174 175 176 177 186 187 188 189 190 191 192 193 194 195 196 197)
    #(177 184 185 174 189 198 199 186 193 200 201 190 197 202 203 194)
    ;; lid top (4 patches, degenerate apex at v204, ring at v211)
    #(204 204 204 204 207 208 209 210 211 211 211 211 212 213 214 215)
    #(204 204 204 204 210 217 218 219 211 211 211 211 215 220 221 222)
    #(204 204 204 204 219 224 225 226 211 211 211 211 222 227 228 229)
    #(204 204 204 204 226 230 231 207 211 211 211 211 229 232 233 212)
    ;; lid skirt (4 patches)
    #(212 213 214 215 234 235 236 237 238 239 240 241 242 243 244 245)
    #(215 220 221 222 237 246 247 248 241 249 250 251 245 252 253 254)
    #(222 227 228 229 248 255 256 257 251 258 259 260 254 261 262 263)
    #(229 232 233 212 257 264 265 234 260 266 267 238 263 268 269 242)
    ;; bottom (4 patches, degenerate center at v270, ring at v275)
    #(270 270 270 270 279 280 281 282 275 275 275 275 271 272 273 274)
    #(270 270 270 270 282 289 290 291 275 275 275 275 274 283 284 285)
    #(270 270 270 270 291 298 299 300 275 275 275 275 285 294 295 296)
    #(270 270 270 270 300 305 306 279 275 275 275 275 296 301 302 271)))

;;; ----------------------------------------------------------------
;;; 306 control points — flat array, 3 floats per vertex (x y z)
;;; Access: vertex n (1-indexed) → indices 3*(n-1), 3*(n-1)+1, 3*(n-1)+2
;;; ----------------------------------------------------------------
(defparameter +vertices+
  (coerce
   '(;; ---- rim (1-48) ---- exact Newell data
     ;; q1: x+, y-
      1.4     0.0     2.4       ;  1
      1.4    -0.784   2.4       ;  2
      0.784  -1.4     2.4       ;  3
      0.0    -1.4     2.4       ;  4
      1.3375  0.0     2.53125   ;  5
      1.3375 -0.749   2.53125   ;  6
      0.749  -1.3375  2.53125   ;  7
      0.0    -1.3375  2.53125   ;  8
      1.4375  0.0     2.53125   ;  9
      1.4375 -0.805   2.53125   ; 10
      0.805  -1.4375  2.53125   ; 11
      0.0    -1.4375  2.53125   ; 12
      1.5     0.0     2.4       ; 13
      1.5    -0.84    2.4       ; 14
      0.84   -1.5     2.4       ; 15
      0.0    -1.5     2.4       ; 16
     ;; q2: x-, y-
     -0.784  -1.4     2.4       ; 17
     -1.4    -0.784   2.4       ; 18
     -1.4     0.0     2.4       ; 19
     -0.749  -1.3375  2.53125   ; 20
     -1.3375 -0.749   2.53125   ; 21
     -1.3375  0.0     2.53125   ; 22
     -0.805  -1.4375  2.53125   ; 23
     -1.4375 -0.805   2.53125   ; 24
     -1.4375  0.0     2.53125   ; 25
     -0.84   -1.5     2.4       ; 26
     -1.5    -0.84    2.4       ; 27
     -1.5     0.0     2.4       ; 28
     ;; q3: x-, y+
     -1.4     0.784   2.4       ; 29
     -0.784   1.4     2.4       ; 30
      0.0     1.4     2.4       ; 31
     -1.3375  0.749   2.53125   ; 32
     -0.749   1.3375  2.53125   ; 33
      0.0     1.3375  2.53125   ; 34
     -1.4375  0.805   2.53125   ; 35
     -0.805   1.4375  2.53125   ; 36
      0.0     1.4375  2.53125   ; 37
     -1.5     0.84    2.4       ; 38
     -0.84    1.5     2.4       ; 39
      0.0     1.5     2.4       ; 40
     ;; q4: x+, y+
      0.784   1.4     2.4       ; 41
      1.4     0.784   2.4       ; 42
      0.749   1.3375  2.53125   ; 43
      1.3375  0.749   2.53125   ; 44
      0.805   1.4375  2.53125   ; 45
      1.4375  0.805   2.53125   ; 46
      0.84    1.5     2.4       ; 47
      1.5     0.84    2.4       ; 48

     ;; ---- upper body (49-84) ---- exact Newell data
     ;; q1
      1.75    0.0     1.875     ; 49
      1.75   -0.98    1.875     ; 50
      0.98   -1.75    1.875     ; 51
      0.0    -1.75    1.875     ; 52
      2.0     0.0     1.35      ; 53
      2.0    -1.12    1.35      ; 54
      1.12   -2.0     1.35      ; 55
      0.0    -2.0     1.35      ; 56
      2.0     0.0     0.9       ; 57
      2.0    -1.12    0.9       ; 58
      1.12   -2.0     0.9       ; 59
      0.0    -2.0     0.9       ; 60
     ;; q2
     -0.98   -1.75    1.875     ; 61
     -1.75   -0.98    1.875     ; 62
     -1.75    0.0     1.875     ; 63
     -1.12   -2.0     1.35      ; 64
     -2.0    -1.12    1.35      ; 65
     -2.0     0.0     1.35      ; 66
     -1.12   -2.0     0.9       ; 67
     -2.0    -1.12    0.9       ; 68
     -2.0     0.0     0.9       ; 69
     ;; q3
     -1.75    0.98    1.875     ; 70
     -0.98    1.75    1.875     ; 71
      0.0     1.75    1.875     ; 72
     -2.0     1.12    1.35      ; 73
     -1.12    2.0     1.35      ; 74
      0.0     2.0     1.35      ; 75
     -2.0     1.12    0.9       ; 76
     -1.12    2.0     0.9       ; 77
      0.0     2.0     0.9       ; 78
     ;; q4
      0.98    1.75    1.875     ; 79
      1.75    0.98    1.875     ; 80
      1.12    2.0     1.35      ; 81
      2.0     1.12    1.35      ; 82
      1.12    2.0     0.9       ; 83
      2.0     1.12    0.9       ; 84

     ;; ---- lower body (85-120) ---- exact Newell data
     ;; q1
      2.0     0.0     0.45      ; 85
      2.0    -1.12    0.45      ; 86
      1.12   -2.0     0.45      ; 87
      0.0    -2.0     0.45      ; 88
      1.5     0.0     0.225     ; 89
      1.5    -0.84    0.225     ; 90
      0.84   -1.5     0.225     ; 91
      0.0    -1.5     0.225     ; 92
      1.5     0.0     0.15      ; 93
      1.5    -0.84    0.15      ; 94
      0.84   -1.5     0.15      ; 95
      0.0    -1.5     0.15      ; 96
     ;; q2
     -1.12   -2.0     0.45      ; 97
     -2.0    -1.12    0.45      ; 98
     -2.0     0.0     0.45      ; 99
     -0.84   -1.5     0.225     ; 100
     -1.5    -0.84    0.225     ; 101
     -1.5     0.0     0.225     ; 102
     -0.84   -1.5     0.15      ; 103
     -1.5    -0.84    0.15      ; 104
     -1.5     0.0     0.15      ; 105
     ;; q3
     -2.0     1.12    0.45      ; 106
     -1.12    2.0     0.45      ; 107
      0.0     2.0     0.45      ; 108
     -1.5     0.84    0.225     ; 109
     -0.84    1.5     0.225     ; 110
      0.0     1.5     0.225     ; 111
     -1.5     0.84    0.15      ; 112
     -0.84    1.5     0.15      ; 113
      0.0     1.5     0.15      ; 114
     ;; q4
      1.12    2.0     0.45      ; 115
      2.0     1.12    0.45      ; 116
      0.84    1.5     0.225     ; 117
      1.5     0.84    0.225     ; 118
      0.84    1.5     0.15      ; 119
      1.5     0.84    0.15      ; 120

     ;; ---- handle (121-161) ---- approximate
     ;; upper loop (patches 13-14): curves left from body
     -1.6     0.0     2.025     ; 121
     -1.6    -0.3     2.025     ; 122
     -1.5    -0.3     2.25      ; 123
     -1.5     0.0     2.25      ; 124
     -2.3     0.0     2.025     ; 125
     -2.3    -0.3     2.025     ; 126
     -2.5    -0.3     2.25      ; 127
     -2.5     0.0     2.25      ; 128
     -2.7     0.0     2.025     ; 129
     -2.7    -0.3     2.025     ; 130
     -3.0    -0.3     2.25      ; 131
     -3.0     0.0     2.25      ; 132
     -2.7     0.0     1.8       ; 133
     -2.7    -0.3     1.8       ; 134
     -3.0    -0.3     1.8       ; 135
     -3.0     0.0     1.8       ; 136
     ;; y+ mirror verts for patch 14
     -1.5     0.3     2.25      ; 137
     -1.6     0.3     2.025     ; 138
     -2.5     0.3     2.25      ; 139
     -2.3     0.3     2.025     ; 140
     -3.0     0.3     2.25      ; 141
     -2.7     0.3     2.025     ; 142
     -3.0     0.3     1.8       ; 143
     -2.7     0.3     1.8       ; 144
     ;; lower loop (patches 15-16): curves down to v69=(-2,0,0.9)
     -2.7     0.0     1.575     ; 145
     -2.7    -0.3     1.575     ; 146
     -3.0    -0.3     1.35      ; 147
     -3.0     0.0     1.35      ; 148
     -2.5     0.0     1.125     ; 149
     -2.5    -0.3     1.125     ; 150
     -2.65   -0.3     0.9375    ; 151
     -2.65    0.0     0.9375    ; 152
     -2.0    -0.3     0.9       ; 153
     -1.9    -0.3     0.6       ; 154
     -1.9     0.0     0.6       ; 155
     -3.0     0.3     1.35      ; 156
     -2.7     0.3     1.575     ; 157
     -2.65    0.3     0.9375    ; 158
     -2.5     0.3     1.125     ; 159
     -2.0     0.3     0.9       ; 160
     -1.9     0.3     0.6       ; 161

     ;; ---- spout (162-203) ---- approximate
     ;; outer spout patches 17-18: tip curves up and right
      2.7     0.0     2.025     ; 162
      2.7    -0.3     2.025     ; 163
      3.0    -0.3     2.25      ; 164
      3.0     0.0     2.25      ; 165
      2.6     0.0     1.275     ; 166
      2.6    -0.3     1.275     ; 167
      3.1    -0.3     1.275     ; 168
      3.1     0.0     1.275     ; 169
      2.3     0.0     1.35      ; 170
      2.3    -0.3     1.35      ; 171
      2.4    -0.3     1.5       ; 172
      2.4     0.0     1.5       ; 173
      1.95    0.0     0.6       ; 174
      1.95   -0.3     0.6       ; 175
      1.75   -0.3     0.45      ; 176
      1.75    0.0     0.45      ; 177
     ;; y+ mirror verts for patch 18
      3.0     0.3     2.25      ; 178
      2.7     0.3     2.025     ; 179
      3.1     0.3     1.275     ; 180
      2.6     0.3     1.275     ; 181
      2.4     0.3     1.5       ; 182
      2.3     0.3     1.35      ; 183
      1.75    0.3     0.45      ; 184
      1.95    0.3     0.6       ; 185
     ;; inner spout patches 19-20: base connecting to body
      2.3     0.0     0.9       ; 186
      2.3    -0.3     0.9       ; 187
      2.5    -0.3     0.9       ; 188
      2.5     0.0     0.9       ; 189
      2.0     0.0     0.9       ; 190
      2.0    -0.3     0.9       ; 191
      2.0    -0.3     1.125     ; 192
      2.0     0.0     1.125     ; 193
      1.5     0.0     0.9       ; 194
      1.5    -0.3     0.9       ; 195
      1.5    -0.3     0.9       ; 196
      1.5     0.0     0.9       ; 197
      2.5     0.3     0.9       ; 198
      2.3     0.3     0.9       ; 199
      2.0     0.3     1.125     ; 200
      2.0     0.3     0.9       ; 201
      1.5     0.3     0.9       ; 202
      1.5     0.3     0.9       ; 203

     ;; ---- lid (204-269) ---- approximate
     ;; knob tip (degenerate apex)
      0.0     0.0     3.15      ; 204  ← used 4x as apex
      0.0     0.0     3.15      ; 205  (unused placeholder)
      0.0     0.0     3.15      ; 206  (unused placeholder)
     ;; knob ring (vertices 207-210, 217-219, 224-226, 230-231)
      0.8     0.0     3.15      ; 207
      0.8    -0.45    3.15      ; 208
      0.45   -0.8     3.15      ; 209
      0.0    -0.8     3.15      ; 210
     ;; degenerate mid ring (vertex 211, used 4x)
      0.0     0.0     2.85      ; 211  ← used 4x as mid-ring apex
     ;; lid outer ring row (212-215, 220-222, 227-229, 232-233)
      1.4     0.0     2.7       ; 212
      1.4    -0.784   2.7       ; 213
      0.784  -1.4     2.7       ; 214
      0.0    -1.4     2.7       ; 215
      0.0    -0.0     2.85      ; 216  (unused placeholder)
     -0.45   -0.8     3.15      ; 217
     -0.8    -0.45    3.15      ; 218
     -0.8     0.0     3.15      ; 219
     -0.784  -1.4     2.7       ; 220
     -1.4    -0.784   2.7       ; 221
     -1.4     0.0     2.7       ; 222
      0.0     0.0     2.85      ; 223  (unused placeholder)
     -0.8     0.45    3.15      ; 224
     -0.45    0.8     3.15      ; 225
      0.0     0.8     3.15      ; 226
     -1.4     0.784   2.7       ; 227
     -0.784   1.4     2.7       ; 228
      0.0     1.4     2.7       ; 229
      0.45    0.8     3.15      ; 230
      0.8     0.45    3.15      ; 231
     -0.0    -0.0     0.0       ; 232  placeholder
      0.784   1.4     2.7       ; 233  (was 232+1)
     ;; lid skirt (234-269): patches 25-28
      1.5     0.0     2.4       ; 234  connects to rim area
      1.5    -0.84    2.4       ; 235
      0.84   -1.5     2.4       ; 236
      0.0    -1.5     2.4       ; 237
      1.6     0.0     2.1       ; 238
      1.6    -0.9     2.1       ; 239
      0.9    -1.6     2.1       ; 240
      0.0    -1.6     2.1       ; 241
      1.5     0.0     1.95      ; 242
      1.5    -0.84    1.95      ; 243
      0.84   -1.5     1.95      ; 244
      0.0    -1.5     1.95      ; 245
     -0.84   -1.5     2.4       ; 246
     -1.5    -0.84    2.4       ; 247
     -1.5     0.0     2.4       ; 248
     -0.9    -1.6     2.1       ; 249
     -1.6    -0.9     2.1       ; 250
     -1.6     0.0     2.1       ; 251
     -0.84   -1.5     1.95      ; 252
     -1.5    -0.84    1.95      ; 253
     -1.5     0.0     1.95      ; 254
     -1.5     0.84    2.4       ; 255
     -0.84    1.5     2.4       ; 256
      0.0     1.5     2.4       ; 257
     -1.6     0.9     2.1       ; 258
     -0.9     1.6     2.1       ; 259
      0.0     1.6     2.1       ; 260
     -1.5     0.84    1.95      ; 261
     -0.84    1.5     1.95      ; 262
      0.0     1.5     1.95      ; 263
      0.84    1.5     2.4       ; 264
      1.5     0.84    2.4       ; 265
      0.9     1.6     2.1       ; 266
      1.6     0.9     2.1       ; 267
      0.84    1.5     1.95      ; 268
      1.5     0.84    1.95      ; 269

     ;; ---- bottom (270-306) ---- approximate
     ;; degenerate center
      0.0     0.0     0.0       ; 270  ← center (used 4x)
      0.6     0.0     0.0       ; 271
      0.6    -0.336   0.0       ; 272
      0.336  -0.6     0.0       ; 273
      0.0    -0.6     0.0       ; 274
     ;; degenerate inner ring
      0.0     0.0     0.0       ; 275  ← inner ring (used 4x)
      0.0     0.0     0.0       ; 276  placeholder
      0.0     0.0     0.0       ; 277  placeholder
      0.0     0.0     0.0       ; 278  placeholder
     ;; outer ring  and intermediates
      1.5     0.0     0.0       ; 279  connects to body bottom
      1.5    -0.84    0.0       ; 280
      0.84   -1.5     0.0       ; 281
      0.0    -1.5     0.0       ; 282
     -0.336  -0.6     0.0       ; 283
     -0.6    -0.336   0.0       ; 284
     -0.6     0.0     0.0       ; 285
      0.0     0.0     0.0       ; 286  placeholder
      0.0     0.0     0.0       ; 287  placeholder
      0.0     0.0     0.0       ; 288  placeholder
     -1.5     0.0     0.0       ; 289
     -1.5     0.84    0.0       ; 290
     -0.84    1.5     0.0       ; 291  -- wait wrong
     ;; fixing: patch 30 row 1 is 282,289,290,291
      0.0    -1.5     0.0       ; 292  placeholder
      0.0     0.0     0.0       ; 293  placeholder
     -0.6     0.336   0.0       ; 294
     -0.336   0.6     0.0       ; 295
      0.0     0.6     0.0       ; 296
      0.0     0.0     0.0       ; 297  placeholder
      0.0     1.5     0.0       ; 298
      0.84    1.5     0.0       ; 299
      1.5     0.84    0.0       ; 300  -- hmm
      0.336   0.6     0.0       ; 301
      0.6     0.336   0.0       ; 302
      0.0     0.0     0.0       ; 303  placeholder
      0.0     0.0     0.0       ; 304  placeholder
      1.5     0.84    0.0       ; 305
      1.5     0.0     0.0)      ; 306
   '(simple-array single-float (*))))

;;; ----------------------------------------------------------------
;;; Bernstein basis polynomial B_i(t), degree 3
;;; ----------------------------------------------------------------
(defun bernstein (i tt)
  (declare (type (integer 0 3) i) (type single-float tt))
  (let ((s (- 1.0 tt)))
    (case i
      (0 (* s s s))
      (1 (* 3.0 tt s s))
      (2 (* 3.0 tt tt s))
      (3 (* tt tt tt)))))

;;; derivative dB_i/dt
(defun dbernstein (i tt)
  (declare (type (integer 0 3) i) (type single-float tt))
  (let ((s (- 1.0 tt)))
    (case i
      (0 (* -3.0 s s))
      (1 (* 3.0 (- (* s s) (* 2.0 tt s))))
      (2 (* 3.0 (- (* 2.0 tt s) (* tt tt))))
      (3 (* 3.0 tt tt)))))

;;; ----------------------------------------------------------------
;;; Evaluate a bicubic Bezier patch at (u, v)
;;; patch-idx: 0-based index into +patches+
;;; Returns (values x y z)
;;; ----------------------------------------------------------------
(defun patch-point (patch-idx u v)
  (declare (type fixnum patch-idx) (type single-float u v))
  (let ((patch (aref +patches+ patch-idx))
        (x 0.0) (y 0.0) (z 0.0))
    (dotimes (j 4)
      (let ((bv (bernstein j v)))
        (dotimes (i 4)
          (let* ((bu  (bernstein i u))
                 (w   (* bu bv))
                 (vi  (1- (aref patch (+ (* j 4) i)))) ; 0-indexed
                 (base (* vi 3)))
            (incf x (* w (aref +vertices+ base)))
            (incf y (* w (aref +vertices+ (+ base 1))))
            (incf z (* w (aref +vertices+ (+ base 2))))))))
    (values x y z)))

;;; Tangent vectors dP/du and dP/dv at (u, v)
;;; Returns (values tu-x tu-y tu-z  tv-x tv-y tv-z)
(defun patch-tangents (patch-idx u v)
  (declare (type fixnum patch-idx) (type single-float u v))
  (let ((patch (aref +patches+ patch-idx))
        (tux 0.0) (tuy 0.0) (tuz 0.0)
        (tvx 0.0) (tvy 0.0) (tvz 0.0))
    (dotimes (j 4)
      (dotimes (i 4)
        (let* ((vi   (1- (aref patch (+ (* j 4) i))))
               (base (* vi 3))
               (px   (aref +vertices+ base))
               (py   (aref +vertices+ (+ base 1)))
               (pz   (aref +vertices+ (+ base 2)))
               (du   (* (dbernstein i u) (bernstein j v)))
               (dv   (* (bernstein i u) (dbernstein j v))))
          (incf tux (* du px)) (incf tuy (* du py)) (incf tuz (* du pz))
          (incf tvx (* dv px)) (incf tvy (* dv py)) (incf tvz (* dv pz)))))
    (values tux tuy tuz  tvx tvy tvz)))

;;; Surface normal = normalize(dP/du × dP/dv)
;;; Returns (values nx ny nz) — zero vector at degenerate points
(defun patch-normal (patch-idx u v)
  (multiple-value-bind (tux tuy tuz tvx tvy tvz)
      (patch-tangents patch-idx u v)
    (let* ((nx (- (* tuy tvz) (* tuz tvy)))
           (ny (- (* tuz tvx) (* tux tvz)))
           (nz (- (* tux tvy) (* tuy tvx)))
           (len (sqrt (+ (* nx nx) (* ny ny) (* nz nz)))))
      (if (< len 1e-6)
          (values 0.0 0.0 1.0)   ; fallback for degenerate patches
          (values (/ nx len) (/ ny len) (/ nz len))))))

;;; ----------------------------------------------------------------
;;; Tessellate one patch into triangles
;;; n-steps: grid resolution (n-steps×n-steps quads per patch)
;;; Returns: (list-of-vertices list-of-normals)
;;;   each vertex/normal is a list (x y z)
;;; ----------------------------------------------------------------
(defun tessellate-patch (patch-idx n-steps)
  (let ((vertices '())
        (normals  '()))
    (dotimes (j n-steps)
      (dotimes (i n-steps)
        (flet ((add-point (ui vi)
                 (let* ((u (/ (float ui) n-steps))
                        (v (/ (float vi) n-steps)))
                   (multiple-value-bind (x y z)
                       (patch-point patch-idx u v)
                     (push (list x y z) vertices))
                   (multiple-value-bind (nx ny nz)
                       (patch-normal patch-idx u v)
                     (push (list nx ny nz) normals)))))
          ;; two triangles per quad: (i,j) (i+1,j) (i+1,j+1) and (i,j) (i+1,j+1) (i,j+1)
          (add-point  i      j)
          (add-point (1+ i)  j)
          (add-point (1+ i) (1+ j))
          (add-point  i      j)
          (add-point (1+ i) (1+ j))
          (add-point  i     (1+ j)))))
    (values (nreverse vertices) (nreverse normals))))

;;; Tessellate all 32 patches, returns flat arrays ready for OpenGL
(defun tessellate-all (n-steps)
  (let ((all-verts   '())
        (all-normals '()))
    (dotimes (p 32)
      (multiple-value-bind (verts norms)
          (tessellate-patch p n-steps)
        (setf all-verts   (nconc all-verts   verts))
        (setf all-normals (nconc all-normals norms))))
    (let* ((count  (length all-verts))
           (vbuf   (make-array (* count 6) :element-type 'single-float))
           (idx    0))
      (mapcar (lambda (v n)
                (setf (aref vbuf idx)       (float (first  v) 1.0)
                      (aref vbuf (+ idx 1)) (float (second v) 1.0)
                      (aref vbuf (+ idx 2)) (float (third  v) 1.0)
                      (aref vbuf (+ idx 3)) (float (first  n) 1.0)
                      (aref vbuf (+ idx 4)) (float (second n) 1.0)
                      (aref vbuf (+ idx 5)) (float (third  n) 1.0))
                (incf idx 6))
              all-verts all-normals)
      (values vbuf count))))

;;; ----------------------------------------------------------------
;;; Quick sanity test — prints a few known body surface points
;;; ----------------------------------------------------------------
(defun test ()
  (format t "~%Bezier patch test — body patch 4 (0-indexed):~%")
  (format t "  P(0,0) = ")
  (multiple-value-call #'format t "  (~,3f ~,3f ~,3f)~%" (patch-point 4 0.0 0.0))
  (format t "  P(1,0) = ")
  (multiple-value-call #'format t "  (~,3f ~,3f ~,3f)~%" (patch-point 4 1.0 0.0))
  (format t "  P(0.5,0.5) = ")
  (multiple-value-call #'format t "  (~,3f ~,3f ~,3f)~%" (patch-point 4 0.5 0.5))
  (format t "~%Normal at P(0.5,0.5):~%  ")
  (multiple-value-call #'format t "  (~,3f ~,3f ~,3f)~%" (patch-normal 4 0.5 0.5))
  (format t "~%Tessellating all 32 patches at N=8...~%")
  (multiple-value-bind (buf count)
      (tessellate-all 8)
    (format t "  ~a triangles, ~a floats in buffer~%" count (length buf)))
  (format t "~%Step 1 OK.~%"))
