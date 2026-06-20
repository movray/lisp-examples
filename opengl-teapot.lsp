(ql:quickload '(:cl-opengl :cl-glfw3 :3d-vectors :3d-matrices))
(load "/home/sugras/pproj/lisp/lisp-examples/teapot-data.lsp")

(defpackage #:glteapot
  (:use #:cl)
  (:export #:run #:start #:*running*
           #:*angle* #:*light-pos* #:*color*))

(in-package #:glteapot)

;;; z-up teapot → y-up OpenGL: swap y↔z in vertex shader
(defparameter *vertex-shader*
  "#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
out vec3 vFragPos;
out vec3 vNormal;
uniform mat4 uMVP;
uniform mat4 uModel;
void main() {
    // Newell data is z-up; remap to y-up for OpenGL
    vec3 p = vec3(aPos.x, aPos.z, -aPos.y);
    vec3 n = vec3(aNormal.x, aNormal.z, -aNormal.y);
    gl_Position = uMVP * vec4(p, 1.0);
    vFragPos    = vec3(uModel * vec4(p, 1.0));
    vNormal     = mat3(transpose(inverse(uModel))) * n;
}")

(defparameter *fragment-shader*
  "#version 330 core
in vec3 vFragPos;
in vec3 vNormal;
out vec4 FragColor;
uniform vec3 uColor;
uniform vec3 uLightPos;
uniform vec3 uViewPos;
void main() {
    vec3 ambient    = 0.15 * uColor;
    vec3 norm       = normalize(vNormal);
    vec3 lightDir   = normalize(uLightPos - vFragPos);
    float diff      = max(dot(norm, lightDir), 0.0);
    vec3 diffuse    = diff * uColor;
    vec3 viewDir    = normalize(uViewPos - vFragPos);
    vec3 reflectDir = reflect(-lightDir, norm);
    float spec      = pow(max(dot(viewDir, reflectDir), 0.0), 64.0);
    vec3 specular   = 0.6 * spec * vec3(1.0);
    FragColor = vec4(ambient + diffuse + specular, 1.0);
}")

(defparameter *angle*     0.0)
(defparameter *light-pos* '(4.0 6.0 4.0))
(defparameter *color*     '(0.85 0.55 0.2))   ; warm clay
(defparameter *running*   t)

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
  ;; tessellate at N=12 for smooth appearance
  (multiple-value-bind (mesh-data vert-count)
      (teapot:tessellate-all 12)
    (glfw:with-init-window (:title "Utah Teapot" :width 800 :height 600
                            :opengl-profile :opengl-core-profile
                            :context-version-major 3
                            :context-version-minor 3
                            :opengl-forward-compat t)
      (gl:enable :depth-test)

      (let* ((prog      (make-program))
             (vao       (first (gl:gen-vertex-arrays 1)))
             (vbo       (first (gl:gen-buffers 1)))
             (mvp-loc   (gl:get-uniform-location prog "uMVP"))
             (model-loc (gl:get-uniform-location prog "uModel"))
             (color-loc (gl:get-uniform-location prog "uColor"))
             (light-loc (gl:get-uniform-location prog "uLightPos"))
             (view-loc  (gl:get-uniform-location prog "uViewPos")))

        (gl:bind-vertex-array vao)
        (gl:bind-buffer :array-buffer vbo)

        (let ((arr (gl:alloc-gl-array :float (length mesh-data))))
          (dotimes (i (length mesh-data))
            (setf (gl:glaref arr i) (aref mesh-data i)))
          (gl:buffer-data :array-buffer :static-draw arr)
          (gl:free-gl-array arr))

        ;; stride = 6 floats (pos xyz + normal xyz)
        (gl:vertex-attrib-pointer 0 3 :float nil (* 4 6) 0)
        (gl:enable-vertex-attrib-array 0)
        (gl:vertex-attrib-pointer 1 3 :float nil (* 4 6) (* 4 3))
        (gl:enable-vertex-attrib-array 1)

        (loop while (and *running* (not (glfw:window-should-close-p)))
              do (progn
                   (incf *angle* 0.3)
                   (gl:clear-color 0.1 0.1 0.12 1.0)
                   (gl:clear :color-buffer-bit :depth-buffer-bit)
                   (gl:use-program prog)

                   (let* ((model (3d-matrices:nmrotate
                                  (3d-matrices:meye 4)
                                  (3d-vectors:vec 0 1 0.3)
                                  (* *angle* (/ pi 180))))
                          ;; camera: pulled back, looking slightly down
                          (view  (3d-matrices:m*
                                  (3d-matrices:mtranslation (3d-vectors:vec 0 -1 -6))
                                  (3d-matrices:mrotation (3d-vectors:vec 1 0 0)
                                                         (/ pi -8))))
                          (proj  (3d-matrices:mperspective 45.0 (/ 800.0 600.0) 0.1 100.0))
                          (mvp   (3d-matrices:m* proj view model)))
                     (gl:uniform-matrix-4fv mvp-loc   (3d-matrices:marr mvp)   t)
                     (gl:uniform-matrix-4fv model-loc (3d-matrices:marr model) t)
                     (gl:uniformf color-loc
                                  (first *color*) (second *color*) (third *color*))
                     (gl:uniformf light-loc
                                  (first *light-pos*) (second *light-pos*) (third *light-pos*))
                     (gl:uniformf view-loc 0.0 4.0 6.0))

                   (gl:bind-vertex-array vao)
                   (gl:draw-arrays :triangles 0 vert-count)
                   (glfw:swap-buffers)
                   (glfw:poll-events)))

        (gl:delete-buffers (list vbo))
        (gl:delete-vertex-arrays (list vao))
        (gl:delete-program prog)))))
