(ql:quickload '(:cl-opengl :cl-glfw3 :3d-vectors :3d-matrices))

(defpackage #:cube
  (:use #:cl)
  (:export #:run #:start #:*angle* #:*running*))

(in-package #:cube)

;;; shaders
(defparameter *vertex-shader*
  "#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;
out vec3 vPos;
uniform mat4 uMVP;
void main() {
    gl_Position = uMVP * vec4(aPos, 1.0);
    vPos = aPos;
}")

(defparameter *fragment-shader*
  "#version 330 core
in vec3 vPos;
out vec4 FragColor;
uniform float uTime;
void main() {
    float w1 = sin(vPos.x * 10.0 + uTime * 2.0);
    float w2 = sin(vPos.y * 8.0  + uTime * 1.5);
    float w3 = sin((vPos.x + vPos.y) * 6.0 + uTime * 3.0);
    float wave = (w1 + w2 + w3) / 3.0;
    vec3 deep    = vec3(0.0, 0.15, 0.6);
    vec3 shallow = vec3(0.3, 0.75, 1.0);
    FragColor = vec4(mix(deep, shallow, wave * 0.5 + 0.5), 1.0);
}")

;;; geometry: xyz + rgb per vertex
(defparameter *vertices*
  (coerce
   '(;; front
     -0.5 -0.5  0.5   1.0 0.0 0.0
      0.5 -0.5  0.5   0.0 1.0 0.0
      0.5  0.5  0.5   0.0 0.0 1.0
     -0.5  0.5  0.5   1.0 1.0 0.0
     ;; back
     -0.5 -0.5 -0.5   1.0 0.0 1.0
      0.5 -0.5 -0.5   0.0 1.0 1.0
      0.5  0.5 -0.5   1.0 1.0 1.0
     -0.5  0.5 -0.5   0.5 0.5 0.5)
   '(simple-array single-float (*))))

(defparameter *indices*
  (coerce
   '(;; front      back
     0 1 2  2 3 0  4 5 6  6 7 4
     ;; left       right
     4 0 3  3 7 4  1 5 6  6 2 1
     ;; bottom     top
     4 5 1  1 0 4  3 2 6  6 7 3)
   '(simple-array (unsigned-byte 32) (*))))

(defparameter *angle* 0.0)
(defparameter *time* 0.0)
(defparameter *running* t)

(defun make-shader (type source)
  (let ((shader (gl:create-shader type)))
    (gl:shader-source shader source)
    (gl:compile-shader shader)
    (unless (gl:get-shader shader :compile-status)
      (error "Shader error: ~a" (gl:get-shader-info-log shader)))
    shader))

(defun make-program ()
  (let* ((vs (make-shader :vertex-shader *vertex-shader*))
         (fs (make-shader :fragment-shader *fragment-shader*))
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
  (setf *running* t)
      (glfw:with-init-window (:title "Rotierender Wuerfel" :width 800 :height 600
                            :opengl-profile :opengl-core-profile
                            :context-version-major 3
                            :context-version-minor 3
                            :opengl-forward-compat t)
    (gl:enable :depth-test)

    (let* ((program (make-program))
           (vao (first (gl:gen-vertex-arrays 1)))
           (vbo (first (gl:gen-buffers 1)))
           (ebo (first (gl:gen-buffers 1)))
           (mvp-loc  (gl:get-uniform-location program "uMVP"))
           (time-loc (gl:get-uniform-location program "uTime")))

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
      ;; color attrib
      (gl:vertex-attrib-pointer 1 3 :float nil (* 4 6) (* 4 3))
      (gl:enable-vertex-attrib-array 1)

      (loop while (and *running* (not (glfw:window-should-close-p)))
            do (progn
                 (incf *angle* 0.5)
                 (incf *time* 0.016)
                 (gl:clear-color 0.1 0.1 0.1 1.0)
                 (gl:clear :color-buffer-bit :depth-buffer-bit)
                 (gl:use-program program)

                 ;; MVP matrix
                 (let* ((model (3d-matrices:nmrotate
                                (3d-matrices:meye 4)
                                (3d-vectors:vec 0 1 0.3)
                                (* *angle* (/ pi 180))))
                        (view  (3d-matrices:mtranslation (3d-vectors:vec 0 0 -3)))
                        (proj  (3d-matrices:mperspective 45.0 (/ 800 600) 0.1 100.0))
                        (mvp   (3d-matrices:m* proj view model)))
                   (gl:uniform-matrix-4fv mvp-loc (3d-matrices:marr mvp) t)
                   (gl:uniformf time-loc *time*))

                 (gl:bind-vertex-array vao)
                 (%gl:draw-elements :triangles (length *indices*)
                                    :unsigned-int (cffi:null-pointer))
                 (glfw:swap-buffers)
                 (glfw:poll-events)))

      (gl:delete-buffers (list vbo ebo))
      (gl:delete-vertex-arrays (list vao))
      (gl:delete-program program))))
