(defpackage #:40ants-doc/locatives/dislocated
  (:use #:cl)
  (:import-from #:40ants-doc/locatives/base
                #:locate-error
                #:locate-object
                #:define-locative-type))
(in-package 40ants-doc/locatives/dislocated)


(define-locative-type dislocated ()
  "Refers to a symbol in a non-specific context. Useful for preventing
  autolinking. For example, if there is a function called `FOO` then

      `FOO`

  will be linked to (if *DOCUMENT-LINK-CODE*) its definition. However,

      [`FOO`][dislocated]

  will not be. On a dislocated locative LOCATE always fails with a
  LOCATE-ERROR condition.")

(defmethod locate-object (symbol (locative-type (eql 'dislocated))
                          locative-args)
  (declare (ignore symbol locative-args))
  (locate-error))
