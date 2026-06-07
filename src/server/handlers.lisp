(defpackage :cl-bbs/handlers
  (:use :cl :cl-bbs/storage :cl-bbs/views)
  (:export #:handle-request))

(in-package :cl-bbs/handlers)

(defun handle-request (env)
  (let* ((path-info (getf env :path-info))
         (method (getf env :request-method)))
    ;; very minimal routing for now just to boot
    (cond
      ((string= path-info "/")
       `(200 (:content-type "text/plain") ("SchemeBBS clone root")))
      (t
       `(404 (:content-type "text/plain") ("Not found"))))))