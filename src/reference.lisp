(uiop:define-package #:40ants-doc/reference
  (:use #:cl)
  (:import-from #:40ants-doc/reference-api
                #:canonical-reference
                #:collect-reachable-objects)
  (:import-from #:40ants-doc/document)
  (:import-from #:40ants-doc/source-api)
  (:import-from #:40ants-doc/locatives/base)
  (:import-from #:40ants-doc/definitions))
(in-package 40ants-doc/reference)


(defclass reference ()
  ((object :initarg :object :reader reference-object)
   (locative :initarg :locative :reader reference-locative))
  (:documentation "A REFERENCE represents a path (REFERENCE-LOCATIVE)
  to take from an object (REFERENCE-OBJECT)."))

(defun make-reference (object locative)
  (make-instance 'reference :object object :locative locative))

(defmethod print-object ((object reference) stream)
  (print-unreadable-object (object stream :type t)
    (format stream "~S ~S" (reference-object object)
            (reference-locative object))))

(defun reference= (reference-1 reference-2)
  (and (equal (reference-object reference-1)
              (reference-object reference-2))
       (equal (reference-locative reference-1)
              (reference-locative reference-2))))

(defun reference-locative-type (reference)
  (40ants-doc/locatives/base::locative-type (reference-locative reference)))



(defmethod canonical-reference ((reference reference))
  (handler-case
      (let ((object (resolve reference)))
        (if (typep object 'reference)
            object
            (canonical-reference object)))
    (40ants-doc/locatives/base::locate-error ()
      ;; DISLOCATED ends up here
      reference)))


(defmethod collect-reachable-objects (object)
  "This default implementation returns the empty list. This means that
  nothing is reachable from OBJECT."
  (declare (ignore object))
  ())


(defun reachable-canonical-references (objects)
  (mapcan (lambda (object)
            (mapcar #'canonical-reference
                    (cons object (collect-reachable-objects object))))
          objects))


;;; Return the unescaped name of the HTML anchor for REFERENCE. See
;;; HTML-SAFE-NAME.
(defun reference-to-anchor (reference)
  (let ((reference (canonical-reference reference)))
    (with-standard-io-syntax
      (prin1-to-string (list (reference-object reference)
                             (reference-locative reference))))))


;;; A list of all the references extracted from *LINKS* for
;;; convenience.
(defparameter *references*
  ;; KLUDGE: Include T explicitly, because it's oft used and would not
  ;; be recognized without markup because its name is too short. The
  ;; correct solution would be to add links automatically for the
  ;; hyperspec.
  (list (make-reference t 'dislocated)))


;;; Return the references from REFS which are for SYMBOL or which are
;;; for a non-symbol but resolve to the same object with SYMBOL.
(defun references-for-symbol (symbol refs n-chars-read)
  (let ((symbol-name (symbol-name symbol)))
    (or (remove-if-not (lambda (ref)
                         (or (eq symbol (reference-object ref))
                             ;; This function is only called when
                             ;; there is an interned symbol for
                             ;; something named by a string.
                             ;;
                             ;; KLUDGE: If the object of REF is
                             ;; replaced with SYMBOL, does it resolve
                             ;; to the same object? This is necessary
                             ;; to get package and asdf systems right,
                             ;; because the object in their canonical
                             ;; references are strings and we compare
                             ;; to symbols.
                             (equalp symbol-name (reference-object ref))))
                       refs)
        ;; Don't codify A, I and similar.
        (if (< 2 n-chars-read)
            (list (make-reference symbol 'dislocated))
            ()))))


(defun references-for-similar-names (name refs)
  (multiple-value-bind (symbol n-chars-read)
      (40ants-doc/definitions::find-definitions-find-symbol-or-package name)
    (when n-chars-read
      (values (references-for-symbol symbol refs n-chars-read) n-chars-read))))



(defun references-for-the-same-symbol-p (refs)
  (= 1 (length (remove-duplicates (mapcar #'reference-object refs)))))

;;; If there is a DISLOCATED reference, then don't link anywhere
;;; (remove all the other references).
(defun resolve-dislocated (refs)
  (let ((ref (find 'dislocated refs :key #'reference-locative-type)))
    (if ref
        (list ref)
        refs)))

(defun resolve-generic-function-and-methods (refs)
  (flet ((non-method-refs ()
           (remove-if (lambda (ref)
                        (member (reference-locative-type ref)
                                '(accessor reader writer method)))
                      refs)))
    (cond
      ;; If in doubt, prefer the generic function to methods.
      ((find 'generic-function refs :key #'reference-locative-type)
       (non-method-refs))
      ;; No generic function, prefer non-methods to methods.
      ((non-method-refs))
      (t
       refs))))


(defmethod 40ants-doc/source-api::find-source ((reference reference))
  "If REFERENCE can be resolved to a non-reference, call FIND-SOURCE
  with it, else call LOCATE-AND-FIND-SOURCE on the object,
  locative-type, locative-args of REFERENCE"
  (let ((locative (reference-locative reference)))
    (40ants-doc/locatives/base::locate-and-find-source (reference-object reference)
                                                       (40ants-doc/locatives/base::locative-type locative)
                                                       (40ants-doc/locatives/base::locative-args locative))))


;;; REFERENCE-OBJECT on a CANONICAL-REFERENCE of ASDF:SYSTEM is a
;;; string, which makes REFERENCES-FOR-THE-SAME-SYMBOL-P return NIL.
;;; It's rare to link to ASDF systems in an ambiguous situation, so
;;; don't.
(defun filter-asdf-system-references (refs)
  (if (< 1 (length refs))
      (remove 'asdf:system refs :key #'reference-locative-type)
      refs))


(defmethod collect-reachable-objects ((reference reference))
  "If REFERENCE can be resolved to a non-reference, call
  COLLECT-REACHABLE-OBJECTS with it, else call
  LOCATE-AND-COLLECT-REACHABLE-OBJECTS on the object, locative-type,
  locative-args of REFERENCE"
  (let ((object (resolve reference)))
    (if (typep object 'reference)
        (let ((locative (reference-locative reference)))
          (locate-and-collect-reachable-objects (reference-object reference)
                                                (locative-type locative)
                                                (locative-args locative)))
        (collect-reachable-objects object))))


(defun resolve (reference &key (errorp t))
  "A convenience function to LOCATE REFERENCE's object with its
  locative."
  (40ants-doc/locatives/base::locate (reference-object reference)
                                     (reference-locative reference)
                                     :errorp errorp))

