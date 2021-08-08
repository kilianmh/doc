(uiop:define-package #:40ants-doc/commondoc/page
  (:use #:cl)
  (:import-from #:common-doc)
  (:import-from #:common-html.emitter)
  (:import-from #:40ants-doc/commondoc/html
                #:with-html)
  (:import-from #:common-html.emitter
                #:define-emitter)
  (:import-from #:40ants-doc/commondoc/bullet)
  (:import-from #:40ants-doc/commondoc/section)
  (:import-from #:40ants-doc/reference-api)
  (:import-from #:40ants-doc/commondoc/mapper)
  (:import-from #:40ants-doc/ignored-words
                #:ignored-in-package
                #:ignored-words
                #:supports-ignored-words-p)
  (:import-from #:40ants-doc/commondoc/piece
                #:doc-reference
                #:documentation-piece)
  (:import-from #:40ants-doc/utils
                #:make-relative-path
                #:is-external)
  (:import-from #:40ants-doc/object-package)
  (:import-from #:40ants-doc/commondoc/format)
  (:import-from #:40ants-doc/page
                #:page-base-url
                #:base-filename
                #:page-format)
  (:import-from #:40ants-doc/rewrite)
  (:export #:make-page
           #:page
           #:make-page-toc
           #:warn-on-missing-exports
           #:warn-on-undocumented-exports
           #:full-filename))
(in-package 40ants-doc/commondoc/page)


(defclass page (40ants-doc/page::page-common-mixin
                common-doc:content-node)
  ())


(defgeneric full-filename (page &key from)
  (:method :around ((page t) &key from)
    (declare (ignore from))
    
    (40ants-doc/rewrite::rewrite-file
     (call-next-method)))
  
  (:method ((page (eql :no-page)) &key from)
    (declare (ignore from))
    "")
  
  (:method ((page page) &key from)
    (check-type from (or page
                         null))
    (let ((base (if from
                    (40ants-doc/utils:make-relative-path (base-filename from)
                                                         (base-filename page))
                    (base-filename page)))
          (extension (if (page-format page)
                         (40ants-doc/commondoc/format:files-extension (page-format page))
                         (40ants-doc/commondoc/format:current-files-extension))))
      ;; Base name can be empty only if FROM argument was given and
      ;; we are generating a link for a cross reference. In this case
      ;; we need to return an empty string to make links use only HTML fragment.
      (if (string= base "")
          base
          (concatenate 'string
                       base
                       "."
                       extension)))))


(defmethod base-filename ((obj (eql :no-page)))
  "If page is unknown, then we'll return an empty name for a file. We need this for unit-tests only."
  "")


(defun make-page (sections base-filename &key format base-dir base-url)
  (make-instance 'page
                 :children (uiop:ensure-list sections)
                 :base-filename base-filename
                 :base-dir base-dir
                 :base-url base-url
                 :format format))


(defgeneric make-page-toc (page)
  (:method ((page t))
    nil))


(defun call-with-page-template (func uri &optional toc)
  (check-type uri string)
  
  (let ((theme-uri (make-relative-path uri "theme.css"))
        (highlight-css-uri (make-relative-path uri "highlight.min.css"))
        (highlight-js-uri (make-relative-path uri "highlight.min.js"))
        (jquery-uri (make-relative-path uri "jquery.js"))
        (toc-js-uri (make-relative-path uri "toc.js")))

    (with-html
      (:html
       (:head
        (:meta :name "viewport"
               :content "width=device-width, initial-scale=1")
        (:title "Example page")
        (:link :rel "stylesheet"
               :type "text/css"
               :href theme-uri)
        (:script :type "text/javascript"
                 :src jquery-uri)
        (:script :type "text/javascript"
                 :src toc-js-uri)
        (:link :rel "stylesheet"
               :type "text/css"
               :href highlight-css-uri)
        (:script :type "text/javascript"
                 :src highlight-js-uri)
        (:script "hljs.highlightAll();")
        ;; MathJax configuration to display inline formulas
        (:script :type "text/javascript"
                 :src "http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS_HTML")
        (:script :type "text/x-mathjax-config"
                         "
             MathJax.Hub.Config({
               tex2jax: {
                 inlineMath: [['$','$']],
                 processEscapes: true
               }
             });
        "))
       (:body
        (:div :id "content-container"
              (when toc
                (:div :id "toc"
                      (:form :method "GET"
                             :action (40ants-doc/rewrite::rewrite-url
                                      (make-relative-path uri "search/index.html"))
                             :class "search"
                             (:input :type "text"
                                     :name "q")
                             (:input :type "submit"
                                     :value "Search")
                             (:span :id "search-progress"))
                              
                      (:div :id "page-toc"
                            (common-html.emitter::emit toc))
                      (:div :id "toc-footer"
                            (:a :href "https://40ants.com/doc"
                                "[generated by 40ANTS-DOC]"))))
              (:div :id "content"
                    ;; This role is required for Sphinx Doc's
                    ;; Javascript code. It searches texts inside
                    ;; the role[main] block
                    :role "main"
                    (funcall func))))))))


(defmacro with-page-template ((uri &optional toc) &body body)
  `(call-with-page-template
    (lambda ()
      ,@body)
    ,uri
    ,toc))


(define-emitter (obj page)
  "Emit an piece of documentation."
  (with-page-template ((make-page-uri obj)
                       (make-page-toc obj))
    (mapc #'common-html.emitter::emit
          (common-doc::children obj))))


(defun emit-search-page (page)
  "Emit an piece of documentation."
  (let* ((uri (make-page-uri page)))
    (with-page-template (uri
                         (make-page-toc page))
      (with-html
        ;; This should go before doctools
        ;; URL_ROOT: document.getElementById('documentation_options').getAttribute('data-url_root'),
        (:script
         "
var DOCUMENTATION_OPTIONS = {
    URL_ROOT: '',
    VERSION: '5.0.0+',
    LANGUAGE: 'en',
    COLLAPSE_INDEX: false,
    BUILDER: 'html',
    FILE_SUFFIX: '.html',
    LINK_SUFFIX: '.html',
    HAS_SOURCE: true,
    SOURCELINK_SUFFIX: '.txt',
    NAVIGATION_WITH_KEYS: false
};
")
        (:script :src (make-relative-path uri "underscore.js"))
        (:script :src (make-relative-path uri "doctools.js"))
        (:script :src (make-relative-path uri "language_data.js"))
        (:script :src (make-relative-path uri "searchtools.js"))
        (:script :src (make-relative-path uri "searchindex.js"))
        
        (:div :id "search-results")))))


(defun collect-references (node &aux current-page results)
  "Returns a list of pairs where the CAR is 40ANTS-DOC/REFERENCE:REFERENCE object
   and CDR is 40ANTS-DOC/COMMONDOC/PAGE:PAGE."
  
  (flet ((track-page (node)
           (typecase node
             (page
              (setf current-page
                    node))))
         (collector (node)
           (let ((node
                   (when (typep node 'documentation-piece)
                     (doc-reference node))))
             (when node
               (push (cons node
                           (or current-page
                               :no-page))
                     results)))
           node))
    (40ants-doc/commondoc/mapper:map-nodes node #'collector
                                           :on-going-down #'track-page))

  results)


(defun warn-on-missing-exports (node)
  "Checks all documentation pieces if there are some documented but not exported symbols."
  
  (flet ((checker (node)
           (when (and (typep node 'documentation-piece)
                      ;; It is OK to have some documentation section which are not
                      ;; exported, because these can be some inner chapters.
                      (not (typep node '40ants-doc/commondoc/section:documentation-section)))
             (let* ((reference (40ants-doc/commondoc/piece::doc-reference node))
                    (obj (40ants-doc/reference::reference-object reference)))
               (typecase obj
                 (symbol
                  (unless (is-external obj)
                    (warn "Symbol ~S is documented but not exported from it's package."
                          obj))))))
           node))
    (40ants-doc/commondoc/mapper:map-nodes node #'checker))
  node)


(defun warn-on-undocumented-exports (node references)
  "Checks all documentation pieces if there are some documented but not exported symbols."
  
  (let ((packages nil)
        (common-lisp-package (find-package :common-lisp))
        (references-symbols
          (loop for (reference . page) in references
                for obj = (40ants-doc/reference:reference-object reference)
                when (typep obj 'symbol)
                collect obj)))
    (flet ((checker (node)
             (let ((package (40ants-doc/object-package:object-package node)))
               (when (and package
                          (not (eql package
                                    common-lisp-package))
                          (not (str:starts-with-p "ASDF/"
                                                  (package-name package))))
                 (pushnew package packages)))
             node)
           (documented-p (symbol)
             (member symbol references-symbols)))
      (40ants-doc/commondoc/mapper:map-nodes node #'checker)

      ;; Now we'll check if some external symbols are absent from REFERENCES
      (loop with undocumented-symbols = nil
            for package in packages
            do (do-external-symbols (symbol package)
                 (unless (or (documented-p symbol)
                             (ignored-in-package symbol package)
                             (and (boundp symbol)
                                  (typep (symbol-value symbol)
                                         '40ants-doc:section)))
                   (push symbol undocumented-symbols)))
            finally (when undocumented-symbols
                      (let ((*package* (find-package :keyword)))
                        (warn "These symbols are external, but not documented: ~{~S~^, ~}"
                              (sort undocumented-symbols #'string<
                                    :key #'symbol-name)))))))
  
  node)


(defun remove-references-to-other-document-formats (current-page found-references)
  "If there are two references with the same locative, then we need only one leading
   to the page having the same format as the CURRENT-PAGE argument's format."
  (let* ((current-format (page-format current-page))
         (seen-locatives nil)
         (same-format-references
           (loop for (reference . page) in found-references
                 when (eql (page-format page)
                           current-format)
                 do (push (40ants-doc/reference:reference-locative reference)
                          seen-locatives)
                 and collect (cons reference page))))
    (append same-format-references
            (loop for (reference . page) in found-references
                  when (and (not (eql (page-format page)
                                      current-format))
                            ;; Here the place where we are filtering out
                            ;; references we've already have in the same format
                            ;; as the CURRENT-PAGE's format:
                            (not (member (40ants-doc/reference:reference-locative reference)
                                         seen-locatives
                                         :test #'equal)))
                  collect (cons reference page)))))


(defun make-page-uri (page &key from-page base-url)
  (let ((filename (full-filename page :from from-page))
        (base-url (or (page-base-url page)
                      base-url)))
    (40ants-doc/rewrite::rewrite-url
     (cond
       ;; Links to HTML pages will be made absolute
       ;; if base HTML URL is known. This could be
       ;; the case when you are rendering a documentation
       ;; to be hosted on site and a README.md to be hosted
       ;; at the GitHub and README references items from
       ;; HTML version of documentation.
       ((and (eql (or (page-format page)
                      40ants-doc/commondoc/format::*current-format*)
                  'common-html:html)
             base-url)
        (format nil "~A/~A"
                (string-right-trim '(#\/)
                                   base-url)
                filename))
       ;; When URL should remain relative:
       (t
        filename)))))

(defun replace-xrefs (node known-references
                      &key base-url
                      &aux ignored-words
                           sections
                           current-page
                           inside-code-block
                           pages-stack
                           (common-lisp-package (find-package :common-lisp))
                           (keywords-package (find-package :keyword)))
  "Replaces XREF with COMMON-DOC:DOCUMENT-LINK.

   If XREFS corresponds to HTML page format, and BASE-URL argument is not none,
   then it URL will be absolute otherwise a relative link will be generated.

   Returns links which were not replaced because there wasn't
   a corresponding reference in the KNOWN-REFERENCES argument.

   KNOWING-REFERENCE argument should be a list of pairs
   of a COMMON-DOC:REFERENCE and a 40ANTS-DOC/COMMON-DOC/PAGE:PAGE objects.

   IGNORED-WORDS will be a list of list of strings where each sublist
   contains words, specified as IGNORE-WORDS argument of the 40ANTS-DOC:DEFSECTION macro.
  "
  
  (labels ((collect-ignored-words (node)
             (when (supports-ignored-words-p node)
               (let ((words (ignored-words node)))
                 (push words
                       ignored-words))))
           (pop-ignored-words (node)
             (when (supports-ignored-words-p node)
               (pop ignored-words)))
           (collect-section (node)
             (when (typep node '40ants-doc/commondoc/section:documentation-section)
               (push node sections)))
           (pop-section (node)
             (when (typep node '40ants-doc/commondoc/section:documentation-section)
               (pop sections)))
           (push-page (node)
             (when (typep node 'page)
               (push node pages-stack)
               (setf current-page node)))
           (pop-page (node)
             (when (typep node 'page)
               (pop pages-stack)
               (setf current-page
                     (car pages-stack))))
           (set-inside-code-block-if-needed (node)
             (when (typep node 'common-doc:code)
               (setf inside-code-block t)))
           (unset-inside-code-block-if-needed (node)
             (when (typep node 'common-doc:code)
               (setf inside-code-block nil)))
           (go-down (node)
             (collect-ignored-words node)
             (collect-section node)
             (push-page node)
             (set-inside-code-block-if-needed node))
           (go-up (node)
             (pop-ignored-words node)
             (pop-section node)
             (pop-page node)
             (unset-inside-code-block-if-needed node))
           (make-code-if-needed (node)
             (if inside-code-block
                 node
                 (common-doc:make-code node)))
           (package-specified (text)
             (find #\: text))
           (should-be-ignored-p (text symbol locative)
             (or (and symbol
                      (not (package-specified text))
                      (not (40ants-doc/utils:is-external symbol)))

                 (eql locative
                      '40ants-doc/locatives:argument)
                 (loop for sublist in ignored-words
                       thereis (member text sublist
                                       :test #'string=))
                 ;; This is a special case
                 ;; because we can't distinguish between absent SYMBOL
                 ;; and NIL.
                 (string= text
                          "NIL")
                 (and symbol
                      (or (eql (symbol-package symbol)
                               common-lisp-package)
                          (eql (symbol-package symbol)
                               keywords-package)))))
           (apply-replacer (node)
             (40ants-doc/commondoc/mapper:map-nodes node #'replacer
                                                    :on-going-down #'go-down
                                                    :on-going-up #'go-up))
           (replacer (node)
             (typecase node
               (common-doc:code
                ;; Here we replace CODE nodes having only one XREF child
                ;; with this child
                (let* ((children (common-doc:children node))
                       (first-child (first children)))
                  ;; We also need to continue replacing on results
                  (cond
                    ((and (= (length children) 1)
                          (typep first-child '40ants-doc/commondoc/xref::xref))
                     (replacer first-child))
                    (t node))))
               (40ants-doc/commondoc/xref:xref
                (let* ((text (40ants-doc/commondoc/xref:xref-name node))
                       (symbol (40ants-doc/commondoc/xref:xref-symbol node))
                       (locative (40ants-doc/commondoc/xref:xref-locative node))
                       (found-references
                         (loop for (reference . page) in known-references
                               ;; This can be a symbol or a string.
                               ;; For example, for SYSTEM locative, object
                               ;; is a string name of a system.
                               ;; 
                               ;; TODO: Think about a GENERIC to compare
                               ;;       XREF with references of different locative types.
                               for reference-object = (40ants-doc/reference::reference-object reference)
                               when (and (etypecase reference-object
                                           (symbol
                                            (eql reference-object
                                                 symbol))
                                           (string
                                            ;; Here we intentionally use case insensitive
                                            ;; comparison, because a canonical reference
                                            ;; to ASDF system contains it's name in a lowercase,
                                            ;; but some other locatives like a PACKAGE, might
                                            ;; keep a name in the uppercase.
                                            (string-equal reference-object
                                                          text)))
                                         (or (null locative)
                                             (eql (40ants-doc/reference::reference-locative-type reference)
                                                  locative)))
                               collect (cons reference
                                             page)))
                       (found-references
                         (if current-page
                             (remove-references-to-other-document-formats current-page
                                                                          found-references)
                             found-references))
                       (should-be-ignored
                         (unless found-references
                           (should-be-ignored-p text symbol locative))))

                  (cond
                    (should-be-ignored
                     (make-code-if-needed
                      (common-doc:make-text text)))
                    (found-references
                     (labels ((make-link (reference page text)
                                (let ((page-uri
                                        (when page
                                          (make-page-uri page :from-page current-page
                                                              :base-url base-url)))
                                      (html-fragment
                                        (40ants-doc/utils::html-safe-name
                                         (40ants-doc/reference::reference-to-anchor reference))))
                                  (common-doc:make-document-link page-uri
                                                                 html-fragment
                                                                 (make-code-if-needed
                                                                  (common-doc:make-text text))))))

                       (cond ((= (length found-references) 1)
                              (destructuring-bind (reference . page)
                                  (first found-references)
                                (let* ((object (40ants-doc/reference::resolve reference))
                                       (text (or (40ants-doc/commondoc/xref:link-text object)
                                                 text)))
                                  (make-link reference
                                             page
                                             text))))
                             (t
                              (common-doc:make-content
                               (append (list (make-code-if-needed
                                              (common-doc:make-text text))
                                             (common-doc:make-text " ("))
                                       (loop for (reference . page) in found-references
                                             for index upfrom 1
                                             for text = (format nil "~A" index)
                                             collect (make-link reference page text)
                                             unless (= index (length found-references))
                                             collect (common-doc:make-text " "))
                                       (list (common-doc:make-text ")"))))))))
                    
                    (t
                     (warn "Unable to find target for reference ~A mentioned at ~{~A~^ / ~}"
                           node
                           (loop for section in (reverse sections)
                                 for title = (common-doc.ops:collect-all-text
                                              (common-doc:title section))
                                 collect title))
                     node))))
               (t
                node))))
    (apply-replacer node)))
