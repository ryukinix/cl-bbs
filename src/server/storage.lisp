(defpackage :cl-bbs/storage
  (:use :cl :cl-bbs/models)
  (:export #:*base-dir*
           #:ensure-board-dirs
           #:read-sexp-file
           #:write-sexp-file))

(in-package :cl-bbs/storage)

(defvar *base-dir* 
  (pathname (or (uiop:getenv "SBBS_DATADIR")
                (merge-pathnames "data/" (asdf:system-source-directory :cl-bbs/server)))))

(defun ensure-board-dirs (board-name)
  (let* ((sexp-dir (merge-pathnames (format nil "sexp/~a/" board-name) *base-dir*))
         (html-dir (merge-pathnames (format nil "html/~a/" board-name) *base-dir*)))
    (ensure-directories-exist sexp-dir)
    (ensure-directories-exist html-dir)))

(defun read-sexp-file (path)
  (with-open-file (stream path :direction :input :if-does-not-exist nil)
    (if stream
        (let ((*read-eval* nil))
          (read stream nil nil))
        nil)))

(defun write-sexp-file (path data)
  (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
    (write data :stream stream :pretty t)
    (terpri stream)))