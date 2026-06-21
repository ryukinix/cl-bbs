;; Common Lisp Script
;; Manoel Vilela

(defpackage :cl-bbs/system
  (:use :cl :asdf :uiop)
  (:export :*author*
           :*version*
           :*build-metadata*
           :*license*
           :custom-system-class
           :component-build-metadata))

(in-package :cl-bbs/system)

(defvar *cl-bbs-default-version* "0.1.0")
(defvar *cl-bbs-default-build-metadata* "-dev")

(defun version-separator (version)
  (or (search "-" version)
      (search "+" version)))

(defun cl-bbs-parse-version (version)
  (let ((index (version-separator version)))
    (if version
        (subseq version 0 index)
        *cl-bbs-default-version*)))

(defun cl-bbs-parse-build-metadata (version)
  (let ((index (version-separator version)))
    (cond ((and version index) (subseq version index))
          ((and version) "")
          (t *cl-bbs-default-build-metadata*))))

(defvar *author* "Manoel Vilela")
(defvar *version* (cl-bbs-parse-version (uiop:getenv "APP_VERSION")))
(defvar *build-metadata* (cl-bbs-parse-build-metadata (uiop:getenv "APP_VERSION")))
(defvar *license* "MIT")

(defclass custom-system-class (asdf:system)
  ((build-metadata :initarg :build-metadata
                   :accessor component-build-metadata
                   :initform nil)))

(in-package #:asdf-user)

(asdf:defsystem :cl-bbs/server
  :class cl-bbs/system:custom-system-class
  :author #.cl-bbs/system:*author*
  :description "SchemeBBS port to Common Lisp"
  :version #.cl-bbs/system:*version*
  :build-metadata #.cl-bbs/system:*build-metadata*
  :license #.cl-bbs/system:*license*
  :depends-on ("clack"
               "clack-handler-hunchentoot"
               "ningle"
               "cl-who"
               "cl-ppcre"
               "local-time"
               "yason"
               "lack"
               "lack-middleware-static"
               "bordeaux-threads")
  :pathname "src"
  :components ((:file "package")
               (:module "server"
                :depends-on ("package")
                :components ((:file "models")
                             (:file "storage" :depends-on ("models"))
                             (:file "views" :depends-on ("models"))
                             (:file "handlers" :depends-on ("storage" "views"))
                             (:file "main" :depends-on ("handlers" "storage"))
                             (:file "admin" :depends-on ("storage"))))))

(asdf:defsystem :cl-bbs
  :class cl-bbs/system:custom-system-class
  :author #.cl-bbs/system:*author*
  :description "SchemeBBS clone in common lisp"
  :version #.cl-bbs/system:*version*
  :build-metadata #.cl-bbs/system:*build-metadata*
  :license #.cl-bbs/system:*license*
  :depends-on ("cl-bbs/server")
  :in-order-to ((test-op (test-op "cl-bbs/tests"))))

(asdf:defsystem :cl-bbs/tests
  :author #.cl-bbs/system:*author*
  :license #.cl-bbs/system:*license*
  :depends-on ("cl-bbs/server"
               "parachute"
               "dexador")
  :pathname "tests"
  :components ((:file "package")
               (:file "suites" :depends-on ("package"))
               (:module "unit"
                :depends-on ("suites")
                :components ((:file "models")
                             (:file "storage")
                             (:file "views")
                             (:file "handlers")
                             (:file "admin")))
               (:module "integration"
                :depends-on ("suites")
                :components ((:file "handlers")))
               (:file "main" :depends-on ("unit" "integration")))
  :perform (test-op (o c)
                    (symbol-call :cl-bbs/tests :run-tests)))
