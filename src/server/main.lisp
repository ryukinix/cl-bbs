(in-package :cl-bbs/package)

(defvar *server* nil)
(defvar *app* nil)

(defun build-app ()
  (lack:builder
   (:static :path "/static/"
            :root (merge-pathnames "static/" (asdf:system-source-directory :cl-bbs/server)))
   (lambda (env)
     (cl-bbs/handlers:handle-request env))))

(defun start-app (port)
  (when *server*
    (stop-app))
  (setf *app* (build-app))
  (setf *server* (clack:clackup *app* :port port :server :hunchentoot))
  (format t "cl-bbs running on port ~a~%" port)
  t)

(defun stop-app ()
  (when *server*
    (clack:stop *server*)
    (setf *server* nil))
  t)