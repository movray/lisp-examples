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
