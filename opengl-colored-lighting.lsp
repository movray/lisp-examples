(ql:quickload '(:cl-opengl :cl-glfw3 :3d-vectors :3d-matrices))

(defpackage #:cube-mandelbrot
  (:use #:cl)
  (:export #:run #:start #:*running* #:*angle* #:*light-pos*))

(in-package #:cube-mandelbrot)

;;; shaders
(defparameter *vertex-shader*
  "#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;
layout (location = 2) in vec3 aNormal;
out vec3 vColor;
out vec3 vFragPos;
out vec3 vNormal;
uniform mat4 uMVP;
uniform mat4 uModel;
void main() {
    gl_Position = uMVP * vec4(aPos, 1.0);
    vColor   = aColor;
    vFragPos = vec3(uModel * vec4(aPos, 1.0));
    vNormal  = mat3(transpose(inverse(uModel))) * aNormal;
}")

(defparameter *fragment-shader*
  "#version 330 core
in vec3 vColor;
in vec3 vFragPos;
in vec3 vNormal;
out vec4 FragColor;
uniform vec3 uLightPos;
uniform vec3 uViewPos;
void main() {
    vec3 ambient  = 0.2 * vColor;
    vec3 norm     = normalize(vNormal);
    vec3 lightDir = normalize(uLightPos - vFragPos);
    float diff    = max(dot(norm, lightDir), 0.0);
    vec3 diffuse  = diff * vColor;
    vec3 viewDir    = normalize(uViewPos - vFragPos);
    vec3 reflectDir = reflect(-lightDir, norm);
    float spec      = pow(max(dot(viewDir, reflectDir), 0.0), 32.0);
    vec3 specular   = 0.4 * spec * vec3(1.0);
    FragColor = vec4(ambient + diffuse + specular, 1.0);
}")

;;; geometry: xyz + rgb + normal(xyz) per vertex, 4 vertices per face
(defparameter *vertices*
  (coerce
   '(;; front  red    (0, 0, 1)
     -0.5 -0.5  0.5   1.0 0.0 0.0   0.0  0.0  1.0
      0.5 -0.5  0.5   1.0 0.0 0.0   0.0  0.0  1.0
      0.5  0.5  0.5   1.0 0.0 0.0   0.0  0.0  1.0
     -0.5  0.5  0.5   1.0 0.0 0.0   0.0  0.0  1.0
     ;; back   magenta (0, 0, -1)
      0.5 -0.5 -0.5   1.0 0.0 1.0   0.0  0.0 -1.0
     -0.5 -0.5 -0.5   1.0 0.0 1.0   0.0  0.0 -1.0
     -0.5  0.5 -0.5   1.0 0.0 1.0   0.0  0.0 -1.0
      0.5  0.5 -0.5   1.0 0.0 1.0   0.0  0.0 -1.0
     ;; left   green  (-1, 0, 0)
     -0.5 -0.5 -0.5   0.0 1.0 0.0  -1.0  0.0  0.0
     -0.5 -0.5  0.5   0.0 1.0 0.0  -1.0  0.0  0.0
     -0.5  0.5  0.5   0.0 1.0 0.0  -1.0  0.0  0.0
     -0.5  0.5 -0.5   0.0 1.0 0.0  -1.0  0.0  0.0
     ;; right  cyan   (1, 0, 0)
      0.5 -0.5  0.5   0.0 1.0 1.0   1.0  0.0  0.0
      0.5 -0.5 -0.5   0.0 1.0 1.0   1.0  0.0  0.0
      0.5  0.5 -0.5   0.0 1.0 1.0   1.0  0.0  0.0
      0.5  0.5  0.5   0.0 1.0 1.0   1.0  0.0  0.0
     ;; bottom blue   (0, -1, 0)
     -0.5 -0.5 -0.5   0.0 0.0 1.0   0.0 -1.0  0.0
      0.5 -0.5 -0.5   0.0 0.0 1.0   0.0 -1.0  0.0
      0.5 -0.5  0.5   0.0 0.0 1.0   0.0 -1.0  0.0
     -0.5 -0.5  0.5   0.0 0.0 1.0   0.0 -1.0  0.0
     ;; top    yellow (0, 1, 0)
     -0.5  0.5  0.5   1.0 1.0 0.0   0.0  1.0  0.0
      0.5  0.5  0.5   1.0 1.0 0.0   0.0  1.0  0.0
      0.5  0.5 -0.5   1.0 1.0 0.0   0.0  1.0  0.0
     -0.5  0.5 -0.5   1.0 1.0 0.0   0.0  1.0  0.0)
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

(defparameter *angle*     0.0)
(defparameter *light-pos* '(2.0 2.0 2.0))
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
  (glfw:with-init-window (:title "Mandelbrot Cube" :width 800 :height 600
                          :opengl-profile :opengl-core-profile
                          :context-version-major 3
                          :context-version-minor 3
                          :opengl-forward-compat t)
    (gl:enable :depth-test)

    (let* ((program    (make-program))
           (vao        (first (gl:gen-vertex-arrays 1)))
           (vbo        (first (gl:gen-buffers 1)))
           (ebo        (first (gl:gen-buffers 1)))
           (mvp-loc   (gl:get-uniform-location program "uMVP"))
           (model-loc (gl:get-uniform-location program "uModel"))
           (light-loc (gl:get-uniform-location program "uLightPos"))
           (view-loc  (gl:get-uniform-location program "uViewPos")))

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
      (gl:vertex-attrib-pointer 0 3 :float nil (* 4 9) 0)
      (gl:enable-vertex-attrib-array 0)
      ;; color attrib
      (gl:vertex-attrib-pointer 1 3 :float nil (* 4 9) (* 4 3))
      (gl:enable-vertex-attrib-array 1)
      ;; normal attrib
      (gl:vertex-attrib-pointer 2 3 :float nil (* 4 9) (* 4 6))
      (gl:enable-vertex-attrib-array 2)

      (loop while (and *running* (not (glfw:window-should-close-p)))
            do (progn
                 (incf *angle* 0.5)
                 (gl:clear-color 0.05 0.05 0.05 1.0)
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
                   (gl:uniform-matrix-4fv mvp-loc   (3d-matrices:marr mvp)   t)
                   (gl:uniform-matrix-4fv model-loc (3d-matrices:marr model) t)
                   (gl:uniformf light-loc
                                (first *light-pos*)
                                (second *light-pos*)
                                (third *light-pos*))
                   (gl:uniformf view-loc 0.0 0.0 3.0))

                 (gl:bind-vertex-array vao)
                 (%gl:draw-elements :triangles (length *indices*)
                                    :unsigned-int (cffi:null-pointer))
                 (glfw:swap-buffers)
                 (glfw:poll-events)))

      (gl:delete-buffers (list vbo ebo))
      (gl:delete-vertex-arrays (list vao))
      (gl:delete-program program))))
