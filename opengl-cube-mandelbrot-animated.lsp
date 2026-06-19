(ql:quickload '(:cl-opengl :cl-glfw3 :3d-vectors :3d-matrices))

(defpackage #:cube-mandelbrot
  (:use #:cl)
  (:export #:run #:start #:*running*
           #:*angle* #:*light-pos*
           #:*max-iter* #:*palette-offset* #:*palette-speed*
           #:*face-states* #:*boundary-points*))

(in-package #:cube-mandelbrot)

;;; shaders
(defparameter *vertex-shader*
  "#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
out vec3 vPos;
out vec3 vFragPos;
out vec3 vNormal;
out vec3 vLocalNormal;
uniform mat4 uMVP;
uniform mat4 uModel;
void main() {
    gl_Position  = uMVP * vec4(aPos, 1.0);
    vPos         = aPos;
    vFragPos     = vec3(uModel * vec4(aPos, 1.0));
    vNormal      = mat3(transpose(inverse(uModel))) * aNormal;
    vLocalNormal = aNormal;
}")

(defparameter *fragment-shader*
  "#version 330 core
in vec3 vPos;
in vec3 vFragPos;
in vec3 vNormal;
in vec3 vLocalNormal;
out vec4 FragColor;
uniform int   uMaxIter;
uniform float uPaletteOffset;
uniform vec3  uLightPos;
uniform vec3  uViewPos;
uniform vec2  uCenter[6];
uniform float uZoom[6];
void main() {
    // stable UV axes from local (pre-rotation) normal
    vec3 ln = abs(vLocalNormal);
    vec2 uv;
    if      (ln.z > 0.5) uv = vPos.xy;
    else if (ln.x > 0.5) uv = vPos.yz;
    else                  uv = vPos.xz;

    // face index from local normal
    int fi;
    if      (vLocalNormal.z >  0.5) fi = 0;
    else if (vLocalNormal.z < -0.5) fi = 1;
    else if (vLocalNormal.x < -0.5) fi = 2;
    else if (vLocalNormal.x >  0.5) fi = 3;
    else if (vLocalNormal.y < -0.5) fi = 4;
    else                             fi = 5;

    vec2 c = uv * 3.5 / uZoom[fi] + uCenter[fi];
    vec2 z = vec2(0.0);
    int i;
    for (i = 0; i < uMaxIter; i++) {
        z = vec2(z.x*z.x - z.y*z.y, 2.0*z.x*z.y) + c;
        if (dot(z, z) > 4.0) break;
    }
    vec3 color;
    if (i == uMaxIter) {
        color = vec3(0.02);
    } else {
        float t = float(i) - log2(log2(dot(z,z))) + 4.0;
        t = t / float(uMaxIter);
        color = 0.5 + 0.5 * cos(6.28318 * (t + uPaletteOffset + vec3(0.0, 0.33, 0.67)));
    }

    // phong lighting
    vec3 ambient    = 0.2 * color;
    vec3 norm       = normalize(vNormal);
    vec3 lightDir   = normalize(uLightPos - vFragPos);
    float diff      = max(dot(norm, lightDir), 0.0);
    vec3 diffuse    = diff * color;
    vec3 viewDir    = normalize(uViewPos - vFragPos);
    vec3 reflectDir = reflect(-lightDir, norm);
    float spec      = pow(max(dot(viewDir, reflectDir), 0.0), 32.0);
    vec3 specular   = 0.4 * spec * vec3(1.0);

    FragColor = vec4(ambient + diffuse + specular, 1.0);
}")

;;; geometry: xyz + normal(xyz) per vertex, 4 vertices per face
(defparameter *vertices*
  (coerce
   '(;; front  (0, 0, 1)
     -0.5 -0.5  0.5   0.0  0.0  1.0
      0.5 -0.5  0.5   0.0  0.0  1.0
      0.5  0.5  0.5   0.0  0.0  1.0
     -0.5  0.5  0.5   0.0  0.0  1.0
     ;; back   (0, 0, -1)
      0.5 -0.5 -0.5   0.0  0.0 -1.0
     -0.5 -0.5 -0.5   0.0  0.0 -1.0
     -0.5  0.5 -0.5   0.0  0.0 -1.0
      0.5  0.5 -0.5   0.0  0.0 -1.0
     ;; left   (-1, 0, 0)
     -0.5 -0.5 -0.5  -1.0  0.0  0.0
     -0.5 -0.5  0.5  -1.0  0.0  0.0
     -0.5  0.5  0.5  -1.0  0.0  0.0
     -0.5  0.5 -0.5  -1.0  0.0  0.0
     ;; right  (1, 0, 0)
      0.5 -0.5  0.5   1.0  0.0  0.0
      0.5 -0.5 -0.5   1.0  0.0  0.0
      0.5  0.5 -0.5   1.0  0.0  0.0
      0.5  0.5  0.5   1.0  0.0  0.0
     ;; bottom (0, -1, 0)
     -0.5 -0.5 -0.5   0.0 -1.0  0.0
      0.5 -0.5 -0.5   0.0 -1.0  0.0
      0.5 -0.5  0.5   0.0 -1.0  0.0
     -0.5 -0.5  0.5   0.0 -1.0  0.0
     ;; top    (0, 1, 0)
     -0.5  0.5  0.5   0.0  1.0  0.0
      0.5  0.5  0.5   0.0  1.0  0.0
      0.5  0.5 -0.5   0.0  1.0  0.0
     -0.5  0.5 -0.5   0.0  1.0  0.0)
   '(simple-array single-float (*))))

(defparameter *indices*
  (coerce
   '(;; front       back
      0  1  2   2  3  0    4  5  6   6  7  4
     ;; left        right
      8  9 10  10 11  8   12 13 14  14 15 12
     ;; bottom      top
     16 17 18  18 19 16   20 21 22  22 23 20)
   '(simple-array (unsigned-byte 32) (*))))

;;; known interesting boundary points
(defparameter *boundary-points*
  #((-0.7435 .  0.1314)
    (-0.7269 .  0.1889)
    (-0.7491 .  0.0820)
    (-0.1015 .  0.6327)
    (-0.5251 .  0.5253)
    (-1.2523 .  0.0000)
    ( 0.2800 .  0.0100)
    (-0.1592 .  1.0317)))

;;; per-face state: plist with :cx :cy :zoom :max-zoom :speed :dir :point-idx
(defun make-face-state (point-idx speed max-zoom)
  (let ((pt (aref *boundary-points* point-idx)))
    (list :cx       (float (car pt) 1.0)
          :cy       (float (cdr pt) 1.0)
          :zoom     1.5
          :max-zoom (float max-zoom 1.0)
          :speed    (float speed 1.0)
          :dir      1
          :point-idx point-idx)))

(defparameter *face-states*
  (vector (make-face-state 0 0.004  60.0)
          (make-face-state 1 0.003  80.0)
          (make-face-state 2 0.005  45.0)
          (make-face-state 3 0.0025 100.0)
          (make-face-state 4 0.006  55.0)
          (make-face-state 5 0.0035 70.0)))

(defun update-face! (face)
  (let* ((zoom      (getf face :zoom))
         (dir       (getf face :dir))
         (speed     (getf face :speed))
         (max-zoom  (getf face :max-zoom))
         (new-zoom  (if (= dir 1)
                        (* zoom (+ 1.0 speed))
                        (/ zoom (+ 1.0 speed)))))
    (cond
      ((and (= dir 1) (> new-zoom max-zoom))
       (setf (getf face :dir) -1))
      ((and (= dir -1) (< new-zoom 1.5))
       (let* ((next (mod (1+ (getf face :point-idx)) (length *boundary-points*)))
              (pt   (aref *boundary-points* next)))
         (setf (getf face :point-idx) next
               (getf face :cx)        (float (car pt) 1.0)
               (getf face :cy)        (float (cdr pt) 1.0)
               (getf face :dir)       1
               new-zoom               1.5))))
    (setf (getf face :zoom) (float new-zoom 1.0))))

(defparameter *angle*          0.0)
(defparameter *max-iter*       100)
(defparameter *palette-offset* 0.0)
(defparameter *palette-speed*  0.005)
(defparameter *light-pos*     '(2.0 2.0 2.0))
(defparameter *running*        t)

(defun make-shader (type source)
  (let ((shader (gl:create-shader type)))
    (gl:shader-source shader source)
    (gl:compile-shader shader)
    (unless (gl:get-shader shader :compile-status)
      (error "Shader error: ~a" (gl:get-shader-info-log shader)))
    shader))

(defun make-program ()
  (let* ((vs   (make-shader :vertex-shader *vertex-shader*))
         (fs   (make-shader :fragment-shader *fragment-shader*))
         (prog (gl:create-program)))
    (gl:attach-shader prog vs)
    (gl:attach-shader prog fs)
    (gl:link-program prog)
    (unless (gl:get-program prog :link-status)
      (error "Link error: ~a" (gl:get-program-info-log prog)))
    (gl:delete-shader vs)
    (gl:delete-shader fs)
    prog))

(defun start ()
  (setf *running* nil)
  (sleep 0.2)
  (setf *running* t)
  (sb-thread:make-thread #'run :name "opengl")
  nil)

(defun run ()
  (glfw:with-init-window (:title "Mandelbrot Cube" :width 800 :height 600
                          :opengl-profile :opengl-core-profile
                          :context-version-major 3
                          :context-version-minor 3
                          :opengl-forward-compat t)
    (gl:enable :depth-test)

    (let* ((program     (make-program))
           (vao         (first (gl:gen-vertex-arrays 1)))
           (vbo         (first (gl:gen-buffers 1)))
           (ebo         (first (gl:gen-buffers 1)))
           (mvp-loc     (gl:get-uniform-location program "uMVP"))
           (model-loc   (gl:get-uniform-location program "uModel"))
           (iter-loc    (gl:get-uniform-location program "uMaxIter"))
           (palette-loc (gl:get-uniform-location program "uPaletteOffset"))
           (light-loc   (gl:get-uniform-location program "uLightPos"))
           (view-loc    (gl:get-uniform-location program "uViewPos"))
           ;; per-face uniform locations
           (center-locs (map 'vector
                             (lambda (i) (gl:get-uniform-location
                                          program (format nil "uCenter[~a]" i)))
                             #(0 1 2 3 4 5)))
           (zoom-locs   (map 'vector
                             (lambda (i) (gl:get-uniform-location
                                          program (format nil "uZoom[~a]" i)))
                             #(0 1 2 3 4 5))))

      (gl:bind-vertex-array vao)

      ;; vertex buffer
      (gl:bind-buffer :array-buffer vbo)
      (let ((arr (gl:alloc-gl-array :float (length *vertices*))))
        (dotimes (i (length *vertices*))
          (setf (gl:glaref arr i) (aref *vertices* i)))
        (gl:buffer-data :array-buffer :static-draw arr)
        (gl:free-gl-array arr))

      ;; index buffer
      (gl:bind-buffer :element-array-buffer ebo)
      (let ((arr (gl:alloc-gl-array :unsigned-int (length *indices*))))
        (dotimes (i (length *indices*))
          (setf (gl:glaref arr i) (aref *indices* i)))
        (gl:buffer-data :element-array-buffer :static-draw arr)
        (gl:free-gl-array arr))

      ;; position attrib
      (gl:vertex-attrib-pointer 0 3 :float nil (* 4 6) 0)
      (gl:enable-vertex-attrib-array 0)
      ;; normal attrib
      (gl:vertex-attrib-pointer 1 3 :float nil (* 4 6) (* 4 3))
      (gl:enable-vertex-attrib-array 1)

      (loop while (and *running* (not (glfw:window-should-close-p)))
            do (progn
                 (incf *angle* 0.5)
                 (incf *palette-offset* *palette-speed*)

                 ;; update all 6 face zoom animations
                 (dotimes (i 6) (update-face! (aref *face-states* i)))

                 (gl:clear-color 0.05 0.05 0.05 1.0)
                 (gl:clear :color-buffer-bit :depth-buffer-bit)
                 (gl:use-program program)

                 (let* ((model (3d-matrices:nmrotate
                                (3d-matrices:meye 4)
                                (3d-vectors:vec 0 1 0.3)
                                (* *angle* (/ pi 180))))
                        (view  (3d-matrices:mtranslation (3d-vectors:vec 0 0 -3)))
                        (proj  (3d-matrices:mperspective 45.0 (/ 800 600) 0.1 100.0))
                        (mvp   (3d-matrices:m* proj view model)))
                   (gl:uniform-matrix-4fv mvp-loc   (3d-matrices:marr mvp)   t)
                   (gl:uniform-matrix-4fv model-loc (3d-matrices:marr model) t)
                   (gl:uniformi iter-loc    *max-iter*)
                   (gl:uniformf palette-loc *palette-offset*)
                   (gl:uniformf light-loc
                                (first *light-pos*)
                                (second *light-pos*)
                                (third *light-pos*))
                   (gl:uniformf view-loc 0.0 0.0 3.0)

                   ;; pass per-face center and zoom
                   (dotimes (i 6)
                     (let ((face (aref *face-states* i)))
                       (gl:uniformf (aref center-locs i)
                                    (getf face :cx)
                                    (getf face :cy))
                       (gl:uniformf (aref zoom-locs i)
                                    (getf face :zoom)))))

                 (gl:bind-vertex-array vao)
                 (%gl:draw-elements :triangles (length *indices*)
                                    :unsigned-int (cffi:null-pointer))
                 (glfw:swap-buffers)
                 (glfw:poll-events)))

      (gl:delete-buffers (list vbo ebo))
      (gl:delete-vertex-arrays (list vao))
      (gl:delete-program program))))
