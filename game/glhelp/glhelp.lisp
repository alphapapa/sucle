(defpackage #:glhelp
  (:use #:cl))

(in-package :glhelp)

(defun array-flatten (array)
  (make-array (array-total-size array)
	      :displaced-to array
	      :element-type (array-element-type array)))

(defun create-texture (tex-data width height format &optional (type :unsigned-byte))
  (let ((tex (car (gl:gen-textures 1))))
    (gl:bind-texture :texture-2d tex)
    (gl:tex-image-2d :texture-2d 0 format width height 0 format type tex-data)
    tex))


(defparameter *default-tex-params* (quote ((:texture-min-filter . :nearest)
					   (:texture-mag-filter . :nearest)
;					   (:texture-wrap-s . :repeat)
;					   (:texture-wrap-t . :repeat)
					   )))
;;;;tex-parameters is an alist of pairs (a . b) with
;;;;(lambda (a b) (gl:tex-parameter :texture-2d a b))
(defun pic-texture (thepic type)
  (let ((dims (array-dimensions thepic)))
    (let ((h (pop dims))
	  (w (pop dims)))
      (let ((texture (create-texture (array-flatten thepic) w h type)))
	texture))))

(export '(apply-tex-params))
(defun apply-tex-params (tex-parameters)
  (dolist (param tex-parameters)
    (gl:tex-parameter :texture-2d (car param) (cdr param))))

(defun compile-string-into-shader (shader string)
  (gl:shader-source shader string)
  (gl:compile-shader shader)
  (let ((success (gl:get-shader-info-log shader)))
    (unless (zerop (length success))
      (print success)
      (error "~S" success))))

;;;;attribs is an alist of pairs (a . b) with
;;;;(lambda (a b) (gl:bind-attrib-location ...[the program].. a b)
(defun make-shader-program-from-strings (vs-string fs-string attribs)
  (let ((vert (gl:create-shader :vertex-shader))
	(frag (gl:create-shader :fragment-shader))
	(program (gl:create-program)))

    (compile-string-into-shader frag fs-string)
    (compile-string-into-shader vert vs-string)
    
    (gl:attach-shader program vert)
    (gl:attach-shader program frag)

    (dolist (val attribs)
      (gl:bind-attrib-location program
			       (cdr val)
			       (car val)))
    
    (gl:link-program program)
    (let ((success (gl:get-program-info-log program)))
      (unless (zerop (length success))
	(print success)
	(error "~S" success)))
    (gl:detach-shader program vert)
    (gl:detach-shader program frag)
    
    (gl:delete-shader vert)
    (gl:delete-shader frag)
    program))

(export (quote (pic-texture make-shader-program-from-strings)))


(defun sizeof (type-keyword)
  "gets the size of a foreign c type"
  (cffi:foreign-type-size type-keyword))

(defun get-gl-constant (keyword)
  "gets a gl-constant"
  (cffi:foreign-enum-value '%gl:enum keyword))

(progn
  (defconstant +gltexture0+ (cffi:foreign-enum-value (quote %gl:enum) :texture0))
  (defun set-active-texture (num)
    (gl:active-texture (+ num +gltexture0+))))

(defun bind-default-framebuffer ()
  (gl:bind-framebuffer-ext :framebuffer-ext 0))


(defun create-framebuffer (w h)
  (let ((framebuffer (first (gl:gen-framebuffers-ext 1)))
        (depthbuffer (first (gl:gen-renderbuffers-ext 1)))
        (texture (first (gl:gen-textures 1))))
    ;; setup framebuffer
    (gl:bind-framebuffer-ext :framebuffer-ext framebuffer)

    (progn
      ;; setup texture and attach it to the framebuffer
      (gl:bind-texture :texture-2d texture)
      (gl:tex-parameter :texture-2d :texture-min-filter :nearest)
      (gl:tex-parameter :texture-2d :texture-mag-filter :nearest)
      (gl:tex-image-2d :texture-2d 0 :rgba w h 0 :rgba :unsigned-byte (cffi:null-pointer))
      (gl:bind-texture :texture-2d 0)
      (gl:framebuffer-texture-2d-ext :framebuffer-ext
				     :color-attachment0-ext
				     :texture-2d
				     texture
				     0))
    (progn
      ;; setup depth-buffer and attach it to the framebuffer
      (gl:bind-renderbuffer-ext :renderbuffer-ext depthbuffer)
      (gl:renderbuffer-storage-ext :renderbuffer-ext :depth-component24 w h)
      (gl:framebuffer-renderbuffer-ext :framebuffer-ext
				       :depth-attachment-ext
				       :renderbuffer-ext
				       depthbuffer))

    ;; validate framebuffer
    (let ((framebuffer-status (gl:check-framebuffer-status-ext :framebuffer-ext)))
      (unless (gl::enum= framebuffer-status :framebuffer-complete-ext)
        (error "Framebuffer not complete: ~A." framebuffer-status)))

    #+nil
    (gl:clear-color 0.0 0.0 0.0 0.0)
    #+nil
    (gl:clear :color-buffer-bit
	      :depth-buffer-bit)
    #+nil
    (gl:enable :depth-test ;:multisample
	       )
    (values texture framebuffer depthbuffer)))
