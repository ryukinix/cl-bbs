(defpackage :cl-bbs/views
  (:use :cl :spinneret :cl-bbs/models)
  (:export #:render-index
           #:render-list
           #:render-thread))

(in-package :cl-bbs/views)

(defmacro layout (title &body body)
  `(with-html-string
     (:doctype)
     (:html
      (:head
       (:meta :charset "utf-8")
       (:title ,title)
       (:link :rel "stylesheet" :href "/static/core.css"))
      (:body
       (:div :class "content"
             (raw (progn ,@body)))))))

(defun render-index (board threads)
  (declare (ignore threads))
  (layout (format nil "/~a/ - SchemeBBS" board)
    (with-html-string
      (:h1 (format nil "Board /~a/" board))
      (:p "Frontpage (TODO)"))))

(defun render-list (board threads)
  (declare (ignore threads))
  (layout (format nil "/~a/ - SchemeBBS" board)
    (with-html-string
      (:h1 (format nil "Board /~a/" board))
      (:p "List (TODO)"))))

(defun render-thread (board thread posts)
  (declare (ignore posts))
  (layout (format nil "/~a/ - SchemeBBS" board)
    (with-html-string
      (:h1 (format nil "Thread ~a TODO" thread))
      (:p "Posts TODO"))))