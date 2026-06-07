(defpackage :cl-bbs/storage
  (:use :cl :cl-bbs/models)
  (:export #:*base-dir*
           #:read-thread
           #:write-thread
           #:read-board-list
           #:write-board-list
           #:read-board-index
           #:write-board-index
           #:ensure-board-dirs))

(in-package :cl-bbs/storage)

(defvar *base-dir* (merge-pathnames "data/" (asdf:system-source-directory :cl-bbs/server)))

(defun ensure-board-dirs (board-name)
  (let* ((sexp-dir (merge-pathnames (format nil "sexp/~a/" board-name) *base-dir*))
         (html-dir (merge-pathnames (format nil "html/~a/" board-name) *base-dir*)))
    (ensure-directories-exist sexp-dir)
    (ensure-directories-exist html-dir)))