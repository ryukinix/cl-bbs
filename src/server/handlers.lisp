(defpackage :cl-bbs/handlers
  (:use :cl :cl-bbs/storage :cl-bbs/views)
  (:export #:handle-request))

(in-package :cl-bbs/handlers)

(defun handle-request (env)
  (let* ((path-info (getf env :path-info))
         (method (getf env :request-method))
         (parts (remove "" (cl-ppcre:split "/" path-info) :test #'string=)))
    
    (cond
      ;; The static middleware intercepts /static/ beforehand.
      ;; We serve the index.html from static dir on root natively.
      ((string= path-info "/")
       (let ((index-file (pathname (or (uiop:getenv "SBBS_INDEX_FILE")
                                       (merge-pathnames "src/static/index.html" (asdf:system-source-directory :cl-bbs/server))))))
         (if (probe-file index-file)
             `(200 (:content-type "text/html; charset=utf-8")
                   (,(uiop:read-file-string index-file)))
             `(200 (:content-type "text/plain") ("SchemeBBS clone root")))))
      
      ((and (eq method :get)
            (= (length parts) 1))
       (let* ((board (first parts))
              (index-path (merge-pathnames (format nil "sexp/~a/index" board) *base-dir*)))
          (if (probe-file index-path)
             (let ((index-data (read-sexp-file index-path)))
                `(200 (:content-type "text/html; charset=utf-8")
                      (,(render-index board index-data))))
             `(200 (:content-type "text/html; charset=utf-8")
                   (,(render-index board nil))))))

      ((and (eq method :get)
            (= (length parts) 2)
            (string= (second parts) "list"))
       (let* ((board (first parts))
              (list-path (merge-pathnames (format nil "sexp/~a/list" board) *base-dir*)))
          (if (probe-file list-path)
             (let ((list-data (read-sexp-file list-path)))
                `(200 (:content-type "text/html; charset=utf-8")
                      (,(render-list board list-data))))
             `(200 (:content-type "text/html; charset=utf-8")
                   (,(render-list board nil))))))

      (t
       `(404 (:content-type "text/plain") ("Not found"))))))