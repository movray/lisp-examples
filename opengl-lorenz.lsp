(ql:quickload '(:cl-opengl :cl-glfw3 :3d-vectors :3d-matrices))

(defpackage #:lorenz
  (:use #:cl)
  (:export #:run #:start #:*running*
           #:*angle* #:*speed*
           #:*sigma* #:*rho* #:*beta*
           #:*palette-offset* #:*palette-speed*
           #:*n-points* #:*dt*))

(in-package #:lorenz)

;;; z is passed through to fragment shader; color computed there
;;; so palette animates live via uniform without CPU rebuild
(defparameter *vertex-shader*
  "#version 330 core
layout (location = 0) in vec3 aPos;
out float vZ;
uniform mat4 uMVP;
void main() {
    gl_Position = uMVP * vec4(aPos, 1.0);
    vZ = aPos.z;
}")

(defparameter *fragment-shader*
  "#version 330 core
in float vZ;
out vec4 FragColor;
uniform float uPaletteOffset;
void main() {
    float t     = (vZ - 2.0) / 45.0;
    float phase = 6.28318 * (t + uPaletteOffset);
    vec3 color  = 0.5 + 0.5 * cos(phase + vec3(0.0, 2.094, 4.189));
    FragColor   = vec4(color, 1.0);
}")

(defparameter *sigma*          10.0)
(defparameter *rho*            28.0)
(defparameter *beta*           (/ 8.0 3.0))
(defparameter *dt*             0.005)
(defparameter *n-points*       200000)
(defparameter *angle*          0.0)
(defparameter *speed*          0.15)
(defparameter *palette-offset* 0.0)
(defparameter *palette-speed*  0.003)
(defparameter *running*        t)

;;; RK4 integration of the Lorenz system
(defun lorenz-step (x y z)
  (flet ((deriv (x y z)
           (values (* *sigma* (- y x))
                   (- (* x (- *rho* z)) y)
                   (- (* x y) (* *beta* z)))))
    (multiple-value-bind (k1x k1y k1z) (deriv x y z)
      (let ((h (* 0.5 *dt*)))
        (multiple-value-bind (k2x k2y k2z)
            (deriv (+ x (* h k1x)) (+ y (* h k1y)) (+ z (* h k1z)))
          (multiple-value-bind (k3x k3y k3z)
              (deriv (+ x (* h k2x)) (+ y (* h k2y)) (+ z (* h k2z)))
            (multiple-value-bind (k4x k4y k4z)
                (deriv (+ x (* *dt* k3x)) (+ y (* *dt* k3y)) (+ z (* *dt* k3z)))
              (let ((s (/ *dt* 6.0)))
                (values (+ x (* s (+ k1x (* 2 k2x) (* 2 k3x) k4x)))
                        (+ y (* s (+ k1y (* 2 k2y) (* 2 k3y) k4y)))
                        (+ z (* s (+ k1z (* 2 k2z) (* 2 k3z) k4z))))))))))))

;;; integrate and store xyz positions only (color computed in shader)
(defun build-attractor ()
  (format t "~&Integrating ~a points..." *n-points*)
  (finish-output)
  (let ((buf (make-array (* *n-points* 3) :element-type 'single-float))
        (x 0.1) (y 0.0) (z 20.0))
    ;; discard transient
    (dotimes (_ 5000)
      (multiple-value-setq (x y z) (lorenz-step x y z)))
    (dotimes (i *n-points*)
      (multiple-value-setq (x y z) (lorenz-step x y z))
      (let ((base (* i 3)))
        (setf (aref buf base)       (float x 1.0)
              (aref buf (+ base 1)) (float y 1.0)
              (aref buf (+ base 2)) (float z 1.0))))
    (format t " done.~%")
    buf))

(defun make-shader (type source)
  (let ((s (gl:create-shader type)))
    (gl:shader-source s source)
    (gl:compile-shader s)
    (unless (gl:get-shader s :compile-status)
      (error "Shader: ~a" (gl:get-shader-info-log s)))
    s))

(defun make-program ()
  (let* ((vs (make-shader :vertex-shader   *vertex-shader*))
         (fs (make-shader :fragment-shader *fragment-shader*))
         (p  (gl:create-program)))
    (gl:attach-shader p vs)
    (gl:attach-shader p fs)
    (gl:link-program p)
    (unless (gl:get-program p :link-status)
      (error "Link: ~a" (gl:get-program-info-log p)))
    (gl:delete-shader vs)
    (gl:delete-shader fs)
    p))

(defun start ()
  (setf *running* nil)
  (sleep 0.2)
  (setf *running* t)
  (sb-thread:make-thread #'run :name "opengl")
  nil)

(defun run ()
  (glfw:with-init-window (:title "Lorenz Attractor" :width 800 :height 600
                          :opengl-profile :opengl-core-profile
                          :context-version-major 3
                          :context-version-minor 3
                          :opengl-forward-compat t)
    (gl:enable :depth-test)
    (let ((attractor (build-attractor)))   ; compute after window/context exists

      (let* ((prog        (make-program))
             (vao         (first (gl:gen-vertex-arrays 1)))
             (vbo         (first (gl:gen-buffers 1)))
             (mvp-loc     (gl:get-uniform-location prog "uMVP"))
             (palette-loc (gl:get-uniform-location prog "uPaletteOffset")))

        (gl:bind-vertex-array vao)
        (gl:bind-buffer :array-buffer vbo)

        (let ((arr (gl:alloc-gl-array :float (length attractor))))
          (dotimes (i (length attractor))
            (setf (gl:glaref arr i) (aref attractor i)))
          (gl:buffer-data :array-buffer :static-draw arr)
          (gl:free-gl-array arr))

        (gl:vertex-attrib-pointer 0 3 :float nil (* 4 3) 0)
        (gl:enable-vertex-attrib-array 0)

        (loop while (and *running* (not (glfw:window-should-close-p)))
              do (progn
                   (incf *angle* *speed*)
                   (incf *palette-offset* *palette-speed*)

                   (gl:clear-color 0.0 0.0 0.02 1.0)
                   (gl:clear :color-buffer-bit :depth-buffer-bit)
                   (gl:use-program prog)

                   (let* (;; center attractor at z=25, then rotate
                          (t-center (3d-matrices:mtranslation
                                     (3d-vectors:vec 0.0 0.0 -25.0)))
                          (rot      (3d-matrices:mrotation
                                     (3d-vectors:vec 0 1 0.3)
                                     (* *angle* (/ pi 180))))
                          (model    (3d-matrices:m* rot t-center))
                          (view     (3d-matrices:mtranslation
                                     (3d-vectors:vec 0.0 0.0 -70.0)))
                          (proj     (3d-matrices:mperspective
                                     45.0 (/ 800.0 600.0) 0.1 500.0))
                          (mvp      (3d-matrices:m* proj view model)))
                     (gl:uniform-matrix-4fv mvp-loc (3d-matrices:marr mvp) t)
                     (gl:uniformf palette-loc *palette-offset*))

                   (gl:bind-vertex-array vao)
                   (gl:draw-arrays :line-strip 0 *n-points*)
                   (glfw:swap-buffers)
                   (glfw:poll-events)))

        (gl:delete-buffers (list vbo))
        (gl:delete-vertex-arrays (list vao))
        (gl:delete-program prog))))))
