(defpackage #:40ants-doc/locatives/definers
  (:use #:cl)
  (:import-from #:named-readtables)
  (:import-from #:pythonic-string-reader)
  (:import-from #:40ants-doc/locatives/base)
  (:import-from #:40ants-doc/source-api)
  (:import-from #:40ants-doc/builder/bullet)
  (:import-from #:40ants-doc/args)
  (:import-from #:40ants-doc/render/print)
  (:import-from #:40ants-doc/render/args))
(in-package 40ants-doc/locatives/definers)

(named-readtables:in-readtable pythonic-string-reader:pythonic-string-syntax)


(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun check-body-docstring (docstring)
    (assert (or (endp docstring)
                (and (= 1 (length docstring))
                     (string (first docstring)))))))


(defmacro define-symbol-locative-type (locative-type lambda-list
                                       &body docstring)
  """Similar to DEFINE-LOCATIVE-TYPE but it assumes that all things
  locatable with LOCATIVE-TYPE are going to be just symbols defined
  with a definer defined with DEFINE-DEFINER-FOR-SYMBOL-LOCATIVE-TYPE.
  It is useful to attach documentation and source location to symbols
  in a particular context. An example will make everything clear:

  ```commonlisp
  (define-symbol-locative-type direction ()
    "A direction is a symbol. (After this `M-.` on `DIRECTION LOCATIVE`
                                     works and it can also be included in DEFSECTION forms.)")

  (define-definer-for-symbol-locative-type define-direction direction
    "With DEFINE-DIRECTION one can document what a symbol means when
  interpreted as a direction.")

  (define-direction up ()
    "UP is equivalent to a coordinate delta of (0, -1).")
  ```

  After all this, `(UP DIRECTION)` refers to the `DEFINE-DIRECTION`
  form above."""
  (check-body-docstring docstring)
  `(progn
     (40ants-doc/locatives/base::define-locative-type ,locative-type ,lambda-list ,@docstring)
     (defmethod 40ants-doc/locatives/base::locate-object (symbol (locative-type (eql ',locative-type)) locative-args)
       (or (40ants-doc/locatives/base::symbol-lambda-list-method symbol ',locative-type)
           (40ants-doc/locatives/base::locate-error))
       (40ants-doc/reference::make-reference symbol (cons locative-type locative-args)))
     
     (defmethod 40ants-doc/locatives/base::locate-and-document (symbol (locative-type (eql ',locative-type)) locative-args stream)
       (let ((method (40ants-doc/locatives/base::symbol-lambda-list-method symbol ',locative-type))
             (lambda-list (40ants-doc/locatives/base::symbol-lambda-list symbol ',locative-type)))
         (40ants-doc/builder/bullet::locate-and-print-bullet locative-type locative-args symbol stream)
         (40ants-doc/args::with-dislocated-symbols ((40ants-doc/args::macro-arg-names lambda-list))
           (when lambda-list
             (write-char #\Space stream)
             (40ants-doc/render/args::print-arglist lambda-list stream))
           (40ants-doc/builder/bullet::print-end-bullet stream)
           (40ants-doc/render/print::maybe-print-docstring method t stream)))
       (format stream "~&"))
     
     (defmethod 40ants-doc/locatives/base::locate-and-find-source (symbol (locative-type (eql ',locative-type)) locative-args)
       (40ants-doc/source-api::find-source (40ants-doc/locatives/base::symbol-lambda-list-method symbol ',locative-type)))))


(defun expand-define-definer-for-symbol-as-locative-definer-body
    (symbol locative-type lambda-list docstring)
  `(defmethod 40ants-doc/locatives/base::symbol-lambda-list ((symbol (eql ',symbol))
                                  (locative-type (eql ',locative-type)))
     ,@docstring
     ',lambda-list))


(defmacro define-definer-for-symbol-locative-type
    (name locative-type &body docstring)
  "Define a macro with NAME which can be used to attach documentation,
  a lambda-list and source location to a symbol in the context of
  LOCATIVE-TYPE. The defined macro's arglist is (SYMBOL LAMBDA-LIST
  &OPTIONAL DOCSTRING). LOCATIVE-TYPE is assumed to have been defined
  with DEFINE-SYMBOL-LOCATIVE-TYPE."
  `(defmacro ,name (symbol lambda-list &body docstring)
     ,@docstring
     `,(expand-define-definer-for-symbol-as-locative-definer-body
        symbol ',locative-type lambda-list docstring)))
