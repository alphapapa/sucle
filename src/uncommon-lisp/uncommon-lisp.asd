(asdf:defsystem #:uncommon-lisp
  :author "terminal625"
  :license "MIT"
  :description "Trivially convert from a struct form to an equivalent defclass"
  :depends-on (#:utility)
  :components 
  ((:file "struct-to-clos")))

