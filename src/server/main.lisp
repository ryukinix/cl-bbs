(in-package :cl-bbs/server)

(defvar *server* nil)
(defvar *app* nil)

(defun build-app ()
  (lack:builder
   (:static :path "/static/"
            :root (merge-pathnames "static/" (asdf:system-source-directory :cl-bbs/server)))
   (lambda (env)
     (cl-bbs/handlers:handle-request env))))

(defun start-app (host port &key (async t))
  "Starts the Hunchentoot server running the cl-bbs application on the specified PORT."
  (when *server*
    (stop-app))
  (setf *app* (build-app))
  (setf *server* (clack:clackup *app* :host host
                                      :port port
                                      :server :hunchentoot
                                      :use-thread async))
  (format t "cl-bbs running on port ~a~%" port)
  t)

(defun stop-app ()
  "Stops the currently running Hunchentoot server instance if one exists."
  (when *server*
    (clack:stop *server*)
    (setf *server* nil))
  t)
