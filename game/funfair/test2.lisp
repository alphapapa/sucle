(defpackage #:funtext
  (:use #:cl
	#:funfair
	#:funland))
(in-package #:funtext)

(defvar *this-directory* (filesystem-util:this-directory))
(deflazy font-png ()
  (opticl:read-png-file
   (filesystem-util:rebase-path #P"font.png"
				;;#P"terrain.png"
				*this-directory*)))

(deflazy terrain-png ()
  (opticl:read-png-file
   (filesystem-util:rebase-path 
    #P"terrain.png"
    *this-directory*)))
(deflazy terrain-texture (:opengl)
  (prog1
      (glhelp:pic-texture
       (getfnc 'terrain-png)
       :rgba
       )
    (glhelp:apply-tex-params
     (quote ((:texture-min-filter . :nearest)
	     (:texture-mag-filter . :nearest)
	     (:texture-wrap-s . :repeat)
	     (:texture-wrap-t . :repeat))))))
(deflazy font-texture (:opengl)
  (prog1
      (glhelp:pic-texture
       (getfnc 'font-png)
      ;; :rgba
       :luminance
       )
    (glhelp:apply-tex-params
     (quote ((:texture-min-filter . :nearest)
	     (:texture-mag-filter . :nearest)
	     (:texture-wrap-s . :repeat)
	     (:texture-wrap-t . :repeat))))))

(defparameter *identity-mat*
  (cg-matrix:identity-matrix))
(defparameter *view* (make-instance 'funfair::render-area))
(defparameter *view256x256* (make-instance 'funfair::render-area
					   :width 256
					   :height 256))


(defparameter *block-height* nil)
(defparameter *block-width* nil)
(setf (values *block-width* *block-height*)
      (values 8.0 16.0))

(defparameter *mouse-x* 0.0)
(defparameter *mouse-y* 0.0)
(defun per-frame (session)
  (declare (ignorable session))
  (unless (eq (glhelp::gl-program-object-src (getfnc 'text-shader))
	      *shader-test*)
    (gl:delete-program (glhelp::gl-program-object-handle
			(getfnc 'text-shader)))
    (funfair::remove-stuff 'text-shader))
  (unless (eq (glhelp::gl-program-object-src (getfnc 'refraction-shader))
	      *refraction-shader*)
    (gl:delete-program (glhelp::gl-program-object-handle
			(getfnc 'refraction-shader)))
    (funfair::remove-stuff 'refraction-shader))
  (unless (eq (glhelp::gl-program-object-src (getfnc 'flat-shader))
	      *flat-shader*)
    (gl:delete-program (glhelp::gl-program-object-handle
			(getfnc 'flat-shader)))
    (funfair::remove-stuff 'flat-shader))
  (setf (render-area-width *view*) window::*width*
	(render-area-height *view*) window::*height*)

  (setf *mouse-x* (floatify (/ window::*mouse-x* *block-width* 128.0))
	*mouse-y* (floatify (/ (- window::*height* window::*mouse-y*)
			       *block-height*
			       128.0)))
  (when (window::skey-p (window::keyval :g))
   ;; (terpri)
  ;;  (princ "scrambling text")
    (copy-array-buf))

  
  (let ((program (getfnc 'flat-shader)))
    (glhelp::use-gl-program program)
    (gl:bind-framebuffer :framebuffer (handle (getfnc 'text-data)))
    (gl:viewport 0 0
		;; 64 64
		 256 256
		 )
    (glhelp:with-uniforms uniform program
      (gl:uniform-matrix-4fv
       (uniform :pmv)
       (cg-matrix:translate* *mouse-x* *mouse-y* 0.0)
       nil))
    #+nil
    (progn
      (gl:clear-color 0.1 0.11 0.3 0.0)
      (gl:clear :color-buffer-bit))
    (gl:call-list (getfnc 'text))
    )

  (let ((program (getfnc 'text-shader)))
    (glhelp::use-gl-program program)
    (glhelp:with-uniforms uniform program
      (gl:uniform-matrix-4fv
       (uniform :pmv)
       *identity-mat*
       nil)
      (progn
	(gl:uniformi (uniform 'indirection) 0)
	(glhelp::set-active-texture 0)
	(gl:bind-texture :texture-2d
	;;		 (getfnc 'font-texture)
			 (texture (getfnc 'indirection))
			 ))
      (progn
	(gl:uniformi (uniform 'font-texture) 2)
	(glhelp::set-active-texture 2)
	(gl:bind-texture :texture-2d
					;(texture (getfnc 'text-data))
			 (getfnc 'font-texture)
			 ))

      (progn
	(gl:uniformi (uniform 'text-data) 1)
	(glhelp::set-active-texture 1)
	(gl:bind-texture :texture-2d
			 ;;(getfnc 'terrain-texture)
			 ;;	 (getfnc 'font-texture)
			 (texture (getfnc 'text-data))
			 )))
    
    (gl:disable :cull-face)
    (set-render-area *view*)
    (glhelp::bind-default-framebuffer)
    (gl:call-list (getfnc 'huh?))))


(defun uppow2 (n)
  (ash 1 (ceiling (log n 2))))
;;up to next power of two
(defun render-normal-text-refraction (w h)
  (let ((upw (uppow2 w))
	(uph (uppow2 h))
	(refract (getfnc 'refraction-shader)))
    (glhelp::use-gl-program refract)
    (glhelp:with-uniforms uniform refract
      (gl:uniform-matrix-4fv
       (uniform :pmv)
       *identity-mat*
       nil)
      (gl:uniformf (uniform 'size)
		   (/ w
		      *block-width*)
		   (/ h
		      *block-height*)))
    (gl:disable :cull-face)
    (set-render-area (make-instance 'funfair::render-area
				    :width upw
				    :height uph))
    (let ((obj (getfnc 'indirection)))
      (destroy-gl-framebuffer obj))
    (funfair::remove-stuff 'indirection)
    (gl:bind-framebuffer :framebuffer (handle (getfnc 'indirection)))
    (gl:call-list (getfnc 'huh?))))

(defun use-text ()
  (setf *trampoline* 'per-frame)
  (setf *pre-trampoline-hooks* nil)
  (setf window::*resize-hook* 'render-normal-text-refraction))

(defmacro progeach (fun body)
  `(etouq
    (cons 'progn
	  (mapcar ,fun
		  ,body))))

(deflazy huh? (:opengl)
 (let ((a (scratch-buffer:my-iterator))
       (b (scratch-buffer:my-iterator))
       (len 0))
   (iter-ator:bind-iterator-out
    (pos single-float) a
    (iter-ator:bind-iterator-out
     (tex single-float) b

     (progeach
      (lambda (x) (list 'pos x))
      (axis-aligned-quads:quadk+ 0.0 '(-1.0 1.0 -1.0 1.0)))
     (progeach
      (lambda (x) (list 'tex x))
      (axis-aligned-quads:duaq 1 nil '(0.0 1.0 0.0 1.0))))
    (incf len 4)
    )
   (glhelp:with-gl-list
     (gl:with-primitives :quads
       (scratch-buffer:flush-my-iterator a
	 (scratch-buffer:flush-my-iterator b
	   ((lambda (times a b)
	      (iter-ator:bind-iterator-in
	       (xyz single-float) a
	       (iter-ator:bind-iterator-in
		(tex single-float) b
		(dotimes (x times)
		  (%gl:vertex-attrib-2f 2 (tex) (tex))
		  (%gl:vertex-attrib-4f 0 (xyz) (xyz) (xyz) 1.0)))))
	    len a b)))))))

(defparameter *shader-test*
  (let (a)
    (setf
     a
     (make-instance
      'glslgen:shader-program-data
      :version 120
      :vs
      (glslgen2::make-shader-stage
       :out '((texcoord-out "vec2"))
       :in '((position "vec4")
	     (texcoord "vec2")
	     (projection-model-view "mat4"))
       :program
       '(defun "main" void ()
	 (= "gl_Position" (* projection-model-view position))
	 (= texcoord-out texcoord)))
      :frag
      (glslgen2::make-shader-stage
       :in '((texcoord "vec2")
	     (indirection "sampler2D")
	     (text-data "sampler2D")
	     (font-atlas ("vec4" 256))
	     (color-atlas ("vec4" 256))
	     (font-texture "sampler2D"))
       :program
       '(defun "main" void ()

	 ;;;refraction
	 (/**/ vec4 ind)
	 (= ind ("texture2D" indirection texcoord))

	 ;;where text changes go
	 (/**/ ivec4 chardata)
	 (= chardata
	  (ivec4 (* 255.0 ("texture2D" text-data
				       ;(+ (vec2 (/ 1.0 1024.0)))
				       (|.| ind "ba")))))

	 ;;font atlass coordinates
	 (/**/ vec4 fontdata)
	 (= fontdata
	  ([]
	   font-atlas
	   (|.| chardata "r")))

	 ;;font lookup
	 (/**/ vec4 pixcolor)
	 (= pixcolor
	  ("texture2D"
	   font-texture
	   (mix (|.| fontdata "xy")
		(|.| fontdata "zw")
		;(vec2 0.5 0.5)
		(|.| ind "rg")
		)))

;	 #+nil
	 (= :gl-frag-color	  
	  (mix
	   ([] color-atlas (|.| chardata "g"))
	   ([] color-atlas (|.| chardata "b"))
	   pixcolor)
	  )

	 #+nil
	 (=
	  (|.| :gl-frag-color "rgb")
					;(vec3 0.0 1.0 0.0)
	  (|.| pixcolor "rgb")
	  )))
      :attributes
      '((position . 0) 
	(texcoord . 2))
      :varyings
      '((texcoord-out . texcoord))
      :uniforms
      '((:pmv (:vertex-shader projection-model-view))
	(indirection (:fragment-shader indirection))
	(text-data (:fragment-shader text-data))
	(color-data (:fragment-shader color-atlas))
	(font-data (:fragment-shader font-atlas))
	(font-texture (:fragment-shader font-texture)))))
    (glslgen:dump-shader-program-data a)
    a))

(deflazy text-shader (:opengl)
  (let ((shader (glhelp::create-gl-program *shader-test*)))
    (glhelp::use-gl-program shader)
    (glhelp:with-uniforms uniform shader
      (progn
	(%gl:uniform-4fv (uniform 'font-data) 256 (getfnc :glsl-code-lookup))
	(%gl:uniform-4fv (uniform 'color-data) 256 (getfnc :terminal256color-lookup))))
    shader))

(defclass gl-framebuffer ()
  ((handle :accessor handle)
   (texture :accessor texture)
   (depth :accessor depth)
   (x :accessor x)
   (y :accessor y)))

(defun make-gl-framebuffer (width height)
  (let ((inst (make-instance 'gl-framebuffer)))
    (with-slots (x y handle texture depth) inst
      (setf x width
	    y height)
      (setf (values texture handle depth)
	    (glhelp::create-framebuffer width height)))
    inst))

(defun destroy-gl-framebuffer (gl-framebuffer)
  (gl:delete-renderbuffers-ext (list (depth gl-framebuffer)))
  (gl:delete-framebuffers-ext (list (handle gl-framebuffer)))
  (gl:delete-textures (list (texture gl-framebuffer))))

(deflazy indirection (:opengl)
  (make-gl-framebuffer (uppow2 window::*width*)
		       (uppow2 window::*height*)))

(deflazy text-data (:opengl)
  (make-gl-framebuffer 256 256))

(eval-always
  (defparameter *vec-types* (make-hash-table :test 'equalp))
  (defun vec-slots (type args &optional (lookup *vec-types*))
    (let ((type-hash (gethash type lookup)))
      (mapcar (lambda (x)
		(let ((a (first x))
		      (b (second x)))
		  (list (gethash b type-hash) a)))
	      args)))
  (defun register-vec-slots (type args &optional (lookup *vec-types*))
    (let ((new-hash (make-hash-table :test 'equalp)))
      (dolist (x args)
	(setf (gethash (first x) new-hash)
	      (second x)))
      (setf (gethash type lookup) new-hash)))

  (register-vec-slots :rectangle (quote ((:x0 0)
					 (:y0 1)
					 (:x1 2)
					 (:y1 3))))

  (register-vec-slots :point (quote ((:x 0)
				     (:y 1)))))


(defparameter *16x16-tilemap* (rectangular-tilemap:regular-enumeration 16 16))

;;
(deflazy :glsl-code-lookup ()
  (let ((a (cffi:foreign-alloc :float :count (* 4 256))))
    (dotimes (x 256)
      (let ((offset (* 4 x))
	    (tilemap-lookup *16x16-tilemap*))
	(etouq
	 (with-vec-params
	     `((offset ,@(vec-slots :rectangle
				    '((x0 :x0) (y0 :y0) (x1 :x1) (y1 :y1)
				      ))))
	   '(tilemap-lookup)
	   '(progn
	     (setf (cffi:mem-aref a :float (+ offset 0)) x0)
	     (setf (cffi:mem-aref a :float (+ offset 1)) y0)
	     (setf (cffi:mem-aref a :float (+ offset 2)) x1)
	     (setf (cffi:mem-aref a :float (+ offset 3)) y1)
	     )))))
    a))

;;VT100 terminal emulator color uniform
(deflazy :terminal256color-lookup ()
 (let ((a (cffi:foreign-alloc :float :count (* 4 256))))
   (dotimes (x 256)
     (let ((offset (* 4 x)))
       (multiple-value-bind (r g b) (color-rgb x) 
	 (progn
	   (setf (cffi:mem-aref a :float (+ offset 0)) r)
	   (setf (cffi:mem-aref a :float (+ offset 1)) g)
	   (setf (cffi:mem-aref a :float (+ offset 2)) b)
	   (setf (cffi:mem-aref a :float (+ offset 3)) 1.0)))))
   a))

;;VT100 terminal emulator colors
(defun color-rgb (color)
  (labels ((c (r g b)
	     (values (/ r 255.0) (/ g 255.0) (/ b 255.0)))
	   (c6 (x)
	     (let ((b (mod x 6))
		   (g (mod (floor x 6) 6))
		   (r (mod (floor x 36) 6)))
	       (values (/ r 5.0) (/ g 5.0) (/ b 5.0))))
	   (g (x)
	     (let ((gray (/ x 23.0)))
	       (values gray gray gray))))
    (case color
      (0 (c 0 0 0))
      (1 (c 205 0 0))
      (2 (c 0 205 0))
      (3 (c 205 205 0))
      (4 (c 0 0 238))
      (5 (c 205 0 205))
      (6 (c 0 205 205))
      (7 (c 229 229 229))
      (8 (c 127 127 127))
      (9 (c 255 0 0))
      (10 (c 0 255 0))
      (11 (c 255 255 0))
      (12 (c 92 92 255))
      (13 (c 255 0 255))
      (14 (c 0 255 255))
      (15 (c 255 255 255))
      (t (let ((c (- color 16)))
	   (if (< c 216)
	       (c6 c)
	       (g (- c 216))))))))

(defparameter *refraction-shader*
  (let (a)
    (setf
     a
     (make-instance
      'glslgen:shader-program-data
      :version 120
      :vs
      (glslgen2::make-shader-stage
       :out '((texcoord-out "vec2"))
       :in '((position "vec4")
	     (texcoord "vec2")
	     (projection-model-view "mat4"))
       :program
       '(defun "main" void ()
	 (= "gl_Position" (* projection-model-view position))
	 (= texcoord-out texcoord)))
      :frag
      (glslgen2::make-shader-stage
       :in '((texcoord "vec2")
	     (size "vec2"))
       :program
       '(defun "main" void ()

	 ;;rg = fraction
	 ;;ba = text lookup

	 ;;
	 (/**/ vec2 foo)
	 (= foo (/ (floor (* texcoord size))
		 (vec2 255.0)))	 
	 (/**/ vec2 bar)
	 (= bar
	  (fract
	   (* 
	    texcoord
	    size)))
	
	 ;;font lookup
	 (/**/ vec4 pixcolor)

	 ;;fraction
	 (= (|.| pixcolor "rg") bar
	  )
	 ;;text lookup
	 (= (|.| pixcolor "ba") foo
	  )
	 
	 (= :gl-frag-color
	  pixcolor
	  )))
      :attributes
      '((position . 0) 
	(texcoord . 2))
      :varyings
      '((texcoord-out . texcoord))
      :uniforms
      '((:pmv (:vertex-shader projection-model-view))
	(size (:fragment-shader size)))))
    (glslgen:dump-shader-program-data a)
    a))

(deflazy refraction-shader (:opengl)
  (glhelp::create-gl-program *refraction-shader*))

(defparameter *foo*
  (let ((*print-case* :downcase))
    (write-to-string
     '(let ((width 256)
	    (height 256))
       (cffi:with-foreign-object (b :uint8 (etouq (* 256 256 4)))
	 (dobox ((xpos 0 width)
		 (ypos 0 height))		   
		(let ((offset (the fixnum (* 4 (the fixnum (+ xpos (the fixnum (* ypos width))))))))
		  (let ((num
			 (random most-positive-fixnum)))
		    (let ((zero-bits (ldb (byte 8 24) num)))
		      (when (zerop zero-bits))
		      (setf (cffi:mem-aref b :uint8 (+ offset '0)) (ldb (byte 8 16) num)
			    (cffi:mem-aref b :uint8 (+ offset 1)) (ldb (byte 8 8) num)
			    (cffi:mem-aref b :uint8 (+ offset 2)) (logand 255 num) 
			    (cffi:mem-aref b :uint8 (+ offset 3)) zero-bits))
		    )))
	 (gl:bind-texture :texture-2d (texture (getfnc 'text-data)))
	 (gl:tex-sub-image-2d :texture-2d 0 0 0 width height :bgra :unsigned-byte b))))))

(with-unsafe-speed
  (defun copy-array-buf ()
    (progn
      (let ((width 256)
	    (height 256))
	(cffi:with-foreign-object (b :uint8 (etouq (* 256 256 4)))
	  (dobox ((ypos 0 height)
		  (xpos 0 width))
		 (let ((base (the fixnum (+ xpos (the fixnum (* ypos width))))))
		   (let ((offset (the fixnum (* 4 base))))
		     (let ((num
			    (logior (char-code (aref *foo* (mod base 1024)))
				    (ash 0 8)
				    (ash 255 16))
			     ;;(random most-positive-fixnum)
			     #+nil
			     (get-char-num
			      (get-char (the fixnum (+ xpos xstart))
					(the fixnum (+ ypos ystart))))))
		       (let ((zero-bits (ldb (byte 8 24) num)))
			 (when (zerop zero-bits))
			 (setf (cffi:mem-aref b :uint8 (+ offset 0)) (ldb (byte 8 16) num)
			       (cffi:mem-aref b :uint8 (+ offset 1)) (ldb (byte 8 8) num)
			       (cffi:mem-aref b :uint8 (+ offset 2)) (logand 255 num) 
			       (cffi:mem-aref b :uint8 (+ offset 3)) zero-bits))
		       ))))
	  (progn
	    (gl:bind-texture :texture-2d (texture (getfnc 'text-data)))
	    (gl:tex-sub-image-2d :texture-2d 0 0 0 width height :bgra :unsigned-byte b)))))))

(defun floatify (x)
  (coerce x 'single-float))

(deflazy text (:opengl)
 (let ((position (scratch-buffer:my-iterator))
       (value (scratch-buffer:my-iterator))
       (len 0))
   (iter-ator:bind-iterator-out
    (pos single-float) position
    (iter-ator:bind-iterator-out
     (value single-float) value

     (incf len
	   ((lambda (x y string)
	      (let ((start x))
		(let ((len (length string)))
		  (dotimes (index len)
		    (let ((char (aref string index)))
		      (cond ((char= char #\Newline)
			     (setf x start y (1- y)))
			    (t
			     (pos (floatify (/ x 128.0))
			      )
			     (pos (floatify (/ y 128.0))
			      )
			     (pos 0.0)
			     (value (/ (floatify (char-code char))
				       255.0))
			     (value 0.1)
			     (value 0.99)
			     
			     (setf x (1+ x))))))
		  len)))
	    -128.0 -128.0 *foo*))))
   (glhelp:with-gl-list
     (gl:with-primitives :points
       (scratch-buffer:flush-my-iterator position
	 (scratch-buffer:flush-my-iterator value
	   ((lambda (times position value)
	      (iter-ator:bind-iterator-in
	       (xyz single-float) position
	       (iter-ator:bind-iterator-in
		(value single-float) value
		(dotimes (x times)
		  (%gl:vertex-attrib-4f 2 (value) (value) (value) 1.0)
		  (%gl:vertex-attrib-4f 0 (xyz) (xyz) (xyz) 1.0)))))
	    len position value)))))))

(defparameter *flat-shader*
  (let (a)
    (setf
     a
     (make-instance
      'glslgen:shader-program-data
      :version 120
      :vs
      (glslgen2::make-shader-stage
       :out '((value-out "vec4"))
       :in '((position "vec4")
	     (value "vec4")
	     (projection-model-view "mat4"))
       :program
       '(defun "main" void ()
	 (= "gl_Position" (* projection-model-view position))
	 (= value-out value)))
      :frag
      (glslgen2::make-shader-stage
       :in '((value "vec4"))
       :program
       '(defun "main" void ()	 
	 (=
	  :gl-frag-color
	  value
	  )))
      :attributes
      '((position . 0) 
	(value . 2))
      :varyings
      '((value-out . value))
      :uniforms
      '((:pmv (:vertex-shader projection-model-view)))))
    (glslgen:dump-shader-program-data a)
    a))

(deflazy flat-shader (:opengl)
  (glhelp::create-gl-program *flat-shader*))
#+nil
(defparameter *shader-test*
  (let (a)
    (setf
     a
     (make-instance
      'glslgen:shader-program-data
      :version 330
      :vs
      (glslgen2::make-shader-stage
       :out '((color-out "vec3")
	      (texcoord-out "vec2"))
       :in '((position "vec4")
	     (texcoord "vec2")
	     (color "float")
	     (projection-model-view "mat4"))
       :program
       '(defun "main" void ()
	 (= "gl_Position" (* projection-model-view position))
	 (= color-out (vec3 color))
	 (= texcoord-out texcoord)))
      :frag
      (glslgen2::make-shader-stage
       :in '((texcoord "vec2")
	     (color "vec3")
	     (sampler "sampler2D"))
       :program
       '(defun "main" void ()
	 (/**/ vec4 pixdata)
	 (= pixdata ("texture2D" sampler texcoord))
	 (= (|.| :gl-frag-color "rgb")
	  (* color (|.| pixdata "rgb"))
	  )))
      :attributes
      '((position . 2) 
	(texcoord . 8)
	(color . 0))
      :varyings
      '((color-out . color)
	(texcoord-out . texcoord))
      :uniforms
      '((:pmv (:vertex-shader projection-model-view)))))
    (glslgen:dump-shader-program-data a)
    a))

;;distance field fonts?
