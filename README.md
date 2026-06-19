# lisp-examples

A collection of Common Lisp examples and experiments.

## Examples

### opengl-cube-blue-waves.lsp
A rotating 3D cube with a procedural animated water shader, using cl-opengl and cl-glfw3.

**Requirements:** SBCL, Quicklisp with `cl-opengl`, `cl-glfw3`, `3d-vectors`, `3d-matrices`

```
M-x slime
```

```lisp
(load "~/quicklisp/setup.lisp")
(load "/home/sugras/pproj/lisp/lisp-examples/opengl-cube-blue-waves.lsp")
(cube:start)
```

Live control via REPL:

```lisp
(setf cube:*angle* 0.0)    ; reset rotation angle
(setf cube:*time* 0.0)     ; reset wave animation
(setf cube:*running* nil)  ; stop
(cube:start)               ; restart
```
