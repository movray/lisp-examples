(ql:quickload '(:cl-opengl :cl-glfw3))

(defpackage #:mandelbrot
  (:use #:cl)
  (:export #:run #:start #:*running*
           #:*zoom* #:*center-x* #:*center-y* #:*max-iter*))

(in-package #:mandelbrot)

;;; shaders
(defparameter *vertex-shader*
  "#version 330 core
layout (location = 0) in vec2 aPos;
out vec2 vPos;
void main() {
    gl_Position = vec4(aPos, 0.0, 1.0);
    vPos = aPos;
}")

(defparameter *fragment-shader*
  "#version 330 core
in vec2 vPos;
out vec4 FragColor;
uniform float uZoom;
uniform vec2  uCenter;
uniform int   uMaxIter;
uniform float uAspect;
void main() {
    vec2 c = vec2(vPos.x * uAspect, vPos.y) / uZoom + uCenter;
    vec2 z = vec2(0.0);
    int i;
    for (i = 0; i < uMaxIter; i++) {
        z = vec2(z.x*z.x - z.y*z.y, 2.0*z.x*z.y) + c;
        if (dot(z, z) > 4.0) break;
    }
    if (i == uMaxIter) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        float t = float(i) - log2(log2(dot(z,z))) + 4.0;
        t = t / float(uMaxIter);
        vec3 color = 0.5 + 0.5 * cos(6.28318 * (t + vec3(0.0, 0.33, 0.67)));
        FragColor = vec4(color, 1.0);
    }
}")

;;; fullscreen quad
(defparameter *vertices*
  (coerce '(-1.0 -1.0   1.0 -1.0   1.0  1.0
            -1.0 -1.0   1.0  1.0  -1.0  1.0)
          '(simple-array single-float (*))))

;;; live-controllable parameters
(defparameter *zoom*      1.0)
(defparameter *center-x* -0.5)
(defparameter *center-y*  0.0)
(defparameter *max-iter*  100)
(defparameter *running*   t)

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
  (sleep 0.1)
  (setf *running* t)
  (sb-thread:make-thread #'run :name "opengl")
  nil)

(defun run ()
  (glfw:with-init-window (:title "Mandelbrot" :width 800 :height 600
                          :opengl-profile :opengl-core-profile
                          :context-version-major 3
                          :context-version-minor 3
                          :opengl-forward-compat t)

    (let* ((program    (make-program))
           (vao        (first (gl:gen-vertex-arrays 1)))
           (vbo        (first (gl:gen-buffers 1)))
           (zoom-loc   (gl:get-uniform-location program "uZoom"))
           (center-loc (gl:get-uniform-location program "uCenter"))
           (iter-loc   (gl:get-uniform-location program "uMaxIter"))
           (aspect-loc (gl:get-uniform-location program "uAspect")))

      (gl:bind-vertex-array vao)

      (gl:bind-buffer :array-buffer vbo)
      (let ((arr (gl:alloc-gl-array :float (length *vertices*))))
        (dotimes (i (length *vertices*))
          (setf (gl:glaref arr i) (aref *vertices* i)))
        (gl:buffer-data :array-buffer :static-draw arr)
        (gl:free-gl-array arr))

      (gl:vertex-attrib-pointer 0 2 :float nil (* 4 2) 0)
      (gl:enable-vertex-attrib-array 0)

      (loop while (and *running* (not (glfw:window-should-close-p)))
            do (progn
                 (gl:clear :color-buffer-bit)
                 (gl:use-program program)
                 (gl:uniformf  zoom-loc   *zoom*)
                 (gl:uniformf  center-loc *center-x* *center-y*)
                 (gl:uniformi  iter-loc   *max-iter*)
                 (gl:uniformf  aspect-loc (/ 800.0 600.0))
                 (gl:bind-vertex-array vao)
                 (gl:draw-arrays :triangles 0 6)
                 (glfw:swap-buffers)
                 (glfw:poll-events)))

      (gl:delete-buffers (list vbo))
      (gl:delete-vertex-arrays (list vao))
      (gl:delete-program program))))
