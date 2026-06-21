(defpackage :cl-bbs/models
  (:use :cl)
  (:export #:thread
           #:post
           #:board
           #:headline
           #:posts
           #:truncated
           #:content
           #:date
           #:messages
           #:vip
           #:name
           #:ip))

(in-package :cl-bbs/models)

(defclass post ()
  ((id :initarg :id :accessor post-id)
   (date :initarg :date :accessor post-date)
   (vip :initarg :vip :accessor post-vip :initform nil)
   (ip :initarg :ip :accessor post-ip :initform nil)
   (content :initarg :content :accessor post-content))
  (:documentation "Represents a single post on a message board."))

(defclass thread ()
  ((id :initarg :id :accessor thread-id)
   (headline :initarg :headline :accessor thread-headline)
   (date :initarg :date :accessor thread-date)
   (messages :initarg :messages :accessor thread-messages :initform 1)
   (truncated :initarg :truncated :accessor thread-truncated :initform nil)
   (posts :initarg :posts :accessor thread-posts :initform nil))
  (:documentation "Represents a thread consisting of a series of posts."))

(defclass board ()
  ((name :initarg :name :accessor board-name))
  (:documentation "Represents a message board."))
