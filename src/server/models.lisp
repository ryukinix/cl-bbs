(defpackage :cl-bbs/models
  (:use :cl)
  (:export #:thread
           #:post
           #:board))

(in-package :cl-bbs/models)

(defclass post ()
  ((id :initarg :id :accessor post-id)
   (date :initarg :date :accessor post-date)
   (vip :initarg :vip :accessor post-vip :initform nil)
   (content :initarg :content :accessor post-content)))

(defclass thread ()
  ((id :initarg :id :accessor thread-id)
   (headline :initarg :headline :accessor thread-headline)
   (date :initarg :date :accessor thread-date)
   (messages :initarg :messages :accessor thread-messages :initform 1)
   (truncated :initarg :truncated :accessor thread-truncated :initform nil)
   (posts :initarg :posts :accessor thread-posts :initform nil)))

(defclass board ()
  ((name :initarg :name :accessor board-name)))