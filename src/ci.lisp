(uiop:define-package #:40ants-doc/ci
  (:use #:cl)
  (:import-from #:40ants-ci/workflow
                #:defworkflow)
  (:import-from #:40ants-ci/jobs/linter)
  (:import-from #:40ants-ci/jobs/run-tests)
  (:import-from #:40ants-ci/jobs/docs))
(in-package #:40ants-doc/ci)


(defworkflow linter
  :on-push-to "master"
  :on-pull-request t
  :jobs ((40ants-ci/jobs/linter:linter
          :asdf-systems ("40ants-doc"
                         "40ants-doc-full"
                         "40ants-doc-test")
          :check-imports t)))


(defworkflow ci
  :on-push-to "master"
  :by-cron "0 10 * * 1"
  :on-pull-request t
  :jobs ((40ants-ci/jobs/run-tests:run-tests
          :asdf-system "40ants-doc-full"
          :quicklisp ("quicklisp"
                      "ultralisp")
          :lisp ("sbcl"
                 "ccl-bin/1.12.1"
                 "abcl-bin"
                 "allegro"
                 "clasp"
                 "lispworks"
                 "mkcl"
                 "npt"
                 "ecl")
          :coverage t)))


(defworkflow docs
  :on-push-to "master"
  :on-pull-request t
  :jobs ((40ants-ci/jobs/docs:build-docs
          :asdf-system "40ants-doc-full")))
