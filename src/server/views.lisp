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
         (headline (cdr (assoc 'headline props)))
         (posts (second (assoc 'posts props)))  ;; (posts ((1 (date . "...") ...))) structure
         (truncated (cdr (assoc 'truncated props))))
    (declare (ignore truncated))
    (with-html-string
      (:pre :class "jump"
            (:a :id (format nil "d~a" index)
                :href (if (= index 10) "#d1" (format nil "#d~a" (1+ index))) "↓")
            (:raw "&nbsp;"))
      (:h2 (:a :href (format nil "/~a/~a" board thread-id) headline))
      ;; we iterate rendering posts here later. For now, a mock block.
      (:p (format nil "Thread ID: ~a, Posts in index block... TODO" thread-id))
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
                               (headline (cdr (assoc 'headline props)))
                               (messages (cdr (assoc 'messages props)))
                               (date (cdr (assoc 'date props))))
                          (:tr (:td i)
                               (:td (:a :href (format nil "/~a/~a" board thread-id) headline))
                               (:td messages)
                               (:td (:samp date)))))))
      (:hr)
      (:p :class "footer" "SchemeBBS Common Lisp port"))))

(defun render-thread (board thread posts)
  (declare (ignore posts))
  (layout (format nil "/~a/ - SchemeBBS" board) "thread"
    (with-html-string
      (:raw (render-menu board "thread"))
      (:h1 (format nil "Thread ~a TODO" thread))
      (:p "Posts TODO"))))