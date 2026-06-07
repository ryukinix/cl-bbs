(defpackage :cl-bbs/views
  (:use :cl :spinneret :cl-bbs/models)
  (:export #:render-index
           #:render-list
           #:render-thread))

(in-package :cl-bbs/views)

(defmacro layout (title class &body body)
  `(with-html-string
     (:doctype)
     (:html
      (:head
       (:meta :charset "utf-8")
       (:meta :name "viewport" :content "width=device-width, initial-scale=1.0")
       (:title ,title)
       (:link :rel "icon" :href "/static/favicon.ico" :type "image/png")
       (:link :rel "stylesheet" :href "/static/styles/default.css" :type "text/css"))
      (:body :class ,class
             (:raw (progn ,@body))))))

(defun render-menu (board selected)
  (with-html-string
    (:p :class "nav"
        (if (string= selected "frontpage")
            "frontpage"
            (:a :href (format nil "/~a" board) "frontpage"))
        " - "
        (if (string= selected "thread list")
            "thread list"
            (:a :href (format nil "/~a/list" board) "thread list"))
        " - "
        (if (string= selected "frontpage")
            (:a :href "#newthread" "new thread")
            (:a :href (format nil "/~a#newthread" board) "new thread"))
        " - "
        (:a :href (format nil "/~a/preferences" board) "preferences")
        " - "
        (:a :href "/static/" "?"))))

(defun render-thread-form (board)
  (with-html-string
    (:h2 :id "newthread" "New thread")
    (:form :action (format nil "/~a/post" board) :method "POST"
           (:p (:input :type "text" :name "titulus" :size 35 :placeholder "Headline"))
           (:p (:textarea :name "epistula" :rows 5 :cols 50 :placeholder "Message"))
           (:p (:input :type "text" :name "ornamentum" :size 35 :placeholder "hash"))
           (:p (:input :type "text" :name "name" :style "display:none")
               (:input :type "text" :name "message" :style "display:none")
               (:input :type "submit" :value "Post")))))

(defun render-index (board threads)
  (declare (ignore threads))
  (layout (format nil "/~a/ - SchemeBBS" board) nil
    (with-html-string
      (:raw (render-menu board "frontpage"))
      (:h1 (format nil "Board /~a/" board))
      (:p "Frontpage list (TODO)")
      (:hr)
      (:raw (render-thread-form board)))))

(defun render-list (board threads)
  (declare (ignore threads))
  (layout (format nil "/~a/ - SchemeBBS" board) nil
    (with-html-string
      (:raw (render-menu board "thread list"))
      (:h1 (format nil "Board /~a/" board))
      (:p "Thread list (TODO)")
      (:hr)
      (:raw (render-thread-form board)))))

(defun render-thread (board thread posts)
  (declare (ignore posts))
  (layout (format nil "/~a/ - SchemeBBS" board) "thread"
    (with-html-string
      (:raw (render-menu board "thread"))
      (:h1 (format nil "Thread ~a TODO" thread))
      (:p "Posts TODO"))))