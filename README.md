# lisp-examples

A collection of Common Lisp examples and experiments.

**Requirements for all OpenGL examples:** SBCL, Quicklisp with `cl-opengl`, `cl-glfw3`, `3d-vectors`, `3d-matrices`

Start SLIME first, then load Quicklisp:
```
M-x slime
```
```lisp
(load "~/quicklisp/setup.lisp")
```

---

## Examples

### opengl-cube-blue-waves.lsp

<video src="https://github.com/user-attachments/assets/1b4d35d6-cdc1-4dbb-b5a0-0de365a87338" autoplay loop muted width="640"></video>

Rotating 3D cube with a procedural animated water shader.

```lisp
(load "/home/sugras/pproj/lisp/lisp-examples/opengl-cube-blue-waves.lsp")
(cube:start)
```

```lisp
(setf cube:*angle* 0.0)    ; reset rotation
(setf cube:*time* 0.0)     ; reset wave animation
(setf cube:*running* nil)  ; stop
(cube:start)               ; restart
```

---

### opengl-lighting.lsp
Rotating cube with Phong lighting (ambient + diffuse + specular). Introduces normals and a light source.

```lisp
(load "/home/sugras/pproj/lisp/lisp-examples/opengl-lighting.lsp")
(lighting:start)
```

```lisp
(setf lighting:*angle* 0.0)          ; reset rotation
(setf lighting:*running* nil)        ; stop
(lighting:start)                     ; restart

; move the light around:
(setf lighting:*light-pos* '(2.0 2.0 2.0))   ; default
(setf lighting:*light-pos* '(-2.0 2.0 2.0))  ; light from left
(setf lighting:*light-pos* '(0.0 5.0 0.0))   ; light from above
```

---

### opengl-colored-lighting.lsp
Rotating cube combining per-face colors with Phong lighting. Each face has its own color (red, green, blue, yellow, cyan, magenta) lit by ambient + diffuse + specular.

```lisp
(load "/home/sugras/pproj/lisp/lisp-examples/opengl-colored-lighting.lsp")
(cube-mandelbrot:start)
```

```lisp
(setf cube-mandelbrot:*light-pos* '(2.0 2.0 2.0))   ; default
(setf cube-mandelbrot:*light-pos* '(-2.0 3.0 1.0))  ; light from left
(setf cube-mandelbrot:*running* nil)                 ; stop
```

---

### opengl-cube-mandelbrot.lsp
Rotating cube with the Mandelbrot set mapped onto each face + Phong lighting. All faces share the same view. Pan, zoom and colors controllable via REPL.

```lisp
(load "/home/sugras/pproj/lisp/lisp-examples/opengl-cube-mandelbrot.lsp")
(cube-mandelbrot:start)
```

```lisp
(setf cube-mandelbrot:*zoom* 3.0)              ; zoom in
(setf cube-mandelbrot:*center-x* -0.7435)     ; pan to seahorse valley
(setf cube-mandelbrot:*center-y*  0.1314)
(setf cube-mandelbrot:*max-iter* 200)          ; more detail
(setf cube-mandelbrot:*palette-speed* 0.02)   ; faster color flow
(setf cube-mandelbrot:*light-pos* '(-2.0 3.0 2.0))
(setf cube-mandelbrot:*running* nil)           ; stop
```

---

### opengl-cube-mandelbrot-animated.lsp
Same as above but each of the 6 faces independently zooms into a different boundary point of the Mandelbrot set. Faces automatically wander along the boundary, zoom in and out, and cycle through interesting locations — all running simultaneously.

![Mandelbrot Animated Cube](mandelbrot-animated.png)

```lisp
(load "/home/sugras/pproj/lisp/lisp-examples/opengl-cube-mandelbrot-animated.lsp")
(cube-mandelbrot:start)
```

```lisp
(setf cube-mandelbrot:*palette-speed* 0.02)   ; faster color flow
(setf cube-mandelbrot:*max-iter* 200)          ; more detail
(setf cube-mandelbrot:*light-pos* '(-2.0 3.0 2.0))
(setf cube-mandelbrot:*running* nil)           ; stop
```

---

### opengl-cube-sphere-morph.lsp

<video src="https://github.com/user-attachments/assets/832423e1-5283-42b1-ae57-dee24487c165" autoplay loop muted width="640"></video>

A subdivided cube (8×8 quads per face = 768 triangles total) that continuously morphs between a cube and a sphere. Each of the 6 faces independently zooms into a different boundary region of the Mandelbrot set, exactly like the animated cube above — but the geometry underneath slowly transforms. Normals are interpolated so the Phong lighting stays correct throughout the morph.

```lisp
(load "/home/sugras/pproj/lisp/lisp-examples/opengl-cube-sphere-morph.lsp")
(morph:start)
```

```lisp
; control the morph directly (0.0 = cube, 1.0 = sphere)
(setf morph:*morph* 0.0)             ; snap to cube
(setf morph:*morph* 1.0)             ; snap to sphere
(setf morph:*morph* 0.5)             ; halfway

; auto-animation
(setf morph:*morph-speed* 0.003)     ; default — slow morph cycle
(setf morph:*morph-speed* 0.01)      ; faster
(setf morph:*morph-speed* 0.0)       ; freeze morph, keep Mandelbrot animating

; Mandelbrot and lighting
(setf morph:*palette-speed* 0.02)    ; faster color flow
(setf morph:*max-iter* 200)          ; more detail
(setf morph:*light-pos* '(-2.0 3.0 2.0))
(setf morph:*running* nil)           ; stop
```

---

### opengl-mandelbrot.lsp
Mandelbrot set rendered in real-time entirely in the fragment shader. Each pixel independently computes whether it belongs to the set. Pan and zoom via REPL.

```lisp
(load "/home/sugras/pproj/lisp/lisp-examples/opengl-mandelbrot.lsp")
(mandelbrot:start)
```

```lisp
(setf mandelbrot:*zoom* 2.0)                ; zoom in
(setf mandelbrot:*zoom* 0.5)                ; zoom out
(setf mandelbrot:*center-x* -0.7)          ; pan left
(setf mandelbrot:*center-y*  0.27)         ; pan up
(setf mandelbrot:*max-iter* 200)           ; more detail
(setf mandelbrot:*running* nil)            ; stop
```

---

### opengl-lorenz.lsp

<video src="https://github.com/user-attachments/assets/e2931641-7065-45f6-8842-38a7149d3ade" autoplay loop muted width="640"></video>

The Lorenz attractor — a classic example of chaos theory. The system is defined by three coupled differential equations (σ=10, ρ=28, β=8/3) that produce a trajectory which never repeats but stays bounded in a butterfly-shaped region of space. The equations are integrated with RK4 on the CPU (200,000 steps), the resulting point cloud is uploaded as a line strip to the GPU, and colored by height using a flowing cosine palette.

```lisp
(load "/home/sugras/pproj/lisp/lisp-examples/opengl-lorenz.lsp")
(lorenz:start)
```

```lisp
(setf lorenz:*palette-speed* 0.02)   ; faster color flow
(setf lorenz:*speed* 0.3)            ; faster rotation
(setf lorenz:*speed* 0.0)            ; freeze rotation
(setf lorenz:*n-points* 50000)       ; fewer lines, more visible structure
(setf lorenz:*running* nil)          ; stop
; after changing *n-points*, *sigma*, *rho* or *beta*: restart
(lorenz:start)
```

---

### teapot-data.lsp + opengl-teapot.lsp

<video src="https://github.com/user-attachments/assets/7449a1eb-985e-44d5-a832-3468a2f0b452" autoplay loop muted width="640"></video>

The classic Utah Teapot (Martin Newell, 1975) — the "Hello World" of 3D graphics. The geometry is defined by 32 bicubic Bézier patches with 306 control points. The Lisp code tessellates the patches on the CPU (evaluating the Bernstein basis polynomials and computing surface normals analytically), then uploads the resulting triangle mesh to the GPU for Phong rendering.

`teapot-data.lsp` is the geometry foundation (no OpenGL — just the math). `opengl-teapot.lsp` loads it and renders.

```lisp
(load "/home/sugras/pproj/lisp/lisp-examples/opengl-teapot.lsp")
(glteapot:start)
```

```lisp
(setf glteapot:*color* '(0.85 0.55 0.2))    ; warm clay (default)
(setf glteapot:*color* '(0.2 0.6 0.9))      ; blue
(setf glteapot:*color* '(0.9 0.9 0.9))      ; white/silver
(setf glteapot:*light-pos* '(4.0 6.0 4.0))  ; default
(setf glteapot:*light-pos* '(-6.0 8.0 2.0)) ; light from left
(setf glteapot:*running* nil)                ; stop
```
