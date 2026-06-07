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

(defun render-frontpage-thread (board thread-data index)
  (let* ((thread-id (car thread-data))
         (props (cdr thread-data))
         (headline (cdr (assoc 'cl-bbs/models::headline props)))
         (posts (second (assoc 'cl-bbs/models::posts props)))
         (truncated (cdr (assoc 'cl-bbs/models::truncated props))))
    (declare (ignore truncated))
    (with-html-string
      (:pre :class "jump"
            (:a :id (format nil "d~a" index)
                :href (if (= index 10) "#d1" (format nil "#d~a" (1+ index))) "↓")
            (:raw "&nbsp;"))
      (:h2 (:a :href (format nil "/~a/~a" board thread-id) headline))
      (loop for post in posts
            for post-id = (car post)
            for post-data = (cdr post)
            for content = (cdr (assoc 'cl-bbs/models::content post-data))
            for date = (cdr (assoc 'cl-bbs/models::date post-data))
            do (:p (:strong "Anonymous") " " date " " (:a :href (format nil "/~a/~a#~a" board thread-id post-id) (format nil "No.~a" post-id))
                   (:raw (format nil "<br>~a<br>" content))))
      (:hr))))

(defun render-index (board threads)
  (layout (format nil "/~a/ - SchemeBBS" board) nil
    (with-html-string
      (:h1 board)
      (:raw (render-menu board "frontpage"))
      (:hr)
      (loop for t-data in threads
            for i from 1
            do (:raw (render-frontpage-thread board t-data i)))
      (:raw (render-thread-form board))
      (:hr)
      (:p :class "footer" "SchemeBBS Common Lisp port"))))

(defun render-list (board threads)
  (layout (format nil "/~a/ - SchemeBBS" board) nil
    (with-html-string
      (:h1 board)
      (:raw (render-menu board "thread list"))
      (:hr)
      (:table :summary "Thread list"
              (:thead (:tr (:th "#") (:th "headline") (:th "posts") (:th "last update")))
              (:tbody
               (loop for t-data in threads
                     for i from 1
                     do (let* ((thread-id (car t-data))
                               (props (cdr t-data))
                               (headline (cdr (assoc 'cl-bbs/models::headline props)))
                               (messages (cdr (assoc 'cl-bbs/models::messages props)))
                               (date (cdr (assoc 'cl-bbs/models::date props))))
                          (:tr (:td i)
                               (:td (:a :href (format nil "/~a/~a" board thread-id) headline))
                               (:td messages)
                               (:td (:samp date)))))))
      (:hr)
      (:p :class "footer" "SchemeBBS Common Lisp port"))))

(defun render-post-form (board thread-id)
  (with-html-string
    (:dl
     (:form :action (format nil "/~a/~a/post" board thread-id) :method "POST"
            (:dt (:textarea :name "epistula" :rows 5 :cols 50 :placeholder "Message"))
            (:dd (:input :type "text" :name "ornamentum" :size 35 :placeholder "hash"))
            (:dd (:input :type "text" :name "name" :style "display:none")
                 (:input :type "text" :name "message" :style "display:none")
                 (:input :type "submit" :value "Reply"))))))

(defun render-thread (board thread-id thread-data)
  (let* ((raw-thread (if (and (consp thread-data) (consp (car thread-data))) (car thread-data) thread-data))
         (headline (if (consp (car raw-thread)) (cdr (assoc 'cl-bbs/models::headline raw-thread)) (cdr (assoc 'cl-bbs/models::headline (list raw-thread)))))
         (posts-assoc (if (consp (car raw-thread)) (assoc 'cl-bbs/models::posts raw-thread) (cadr thread-data)))
         (posts-list (if (and posts-assoc (listp (cdr posts-assoc)) (not (keywordp (cdr posts-assoc))))
                         (if (listp (cadr posts-assoc)) (cadr posts-assoc) (cdr posts-assoc))
                         (cdr posts-assoc)))
         (posts (if (listp (car posts-list)) posts-list (list posts-list))))
    (layout (format nil "/~a/ - SchemeBBS" board) "thread"
      (with-html-string
        (:raw (render-menu board "thread"))
        (:h1 headline)
        (loop for post in posts
              for post-id = (car post)
              for post-data = (cdr post)
              for content = (cdr (assoc 'cl-bbs/models::content post-data))
              for date = (cdr (assoc 'cl-bbs/models::date post-data))
              do (:p (:strong "Anonymous") " " date " " (:a :name (format nil "~a" post-id) :href (format nil "/~a/~a#~a" board thread-id post-id) (format nil "No.~a" post-id))
                     (:raw (format nil "<br>~a<br>" content))))
        (:hr)
        (:raw (render-post-form board thread-id))
        (:hr)
        (:p :class "footer" "SchemeBBS Common Lisp port")))))
