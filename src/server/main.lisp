(in-package :cl-bbs/server)

(defvar *server* nil)
(defvar *app* nil)

(defun make-real-ip-middleware (app)
  (lambda (env)
    (let ((x-forwarded-for (gethash "x-forwarded-for" (getf env :headers))))
      ;; If X-Forwarded-For exists, update REMOTE_ADDR to the first IP in the list
      (when x-forwarded-for
        (let ((real-ip (first (uiop:split-string x-forwarded-for :separator '(#\,)))))
          (setf (getf env :remote-addr) (string-trim " " real-ip)))))
    (funcall app env)))

(defun build-app ()
  (lack:builder
   (:static :path "/static/"
            :root (merge-pathnames "src/static/" (asdf:system-source-directory :cl-bbs/server)))
   (lambda (app) (make-real-ip-middleware app))
   :accesslog
   (lambda (env)
     (cl-bbs/handlers:handle-request env))))

(defun start-app (host port &key (async t))
  "Starts the Hunchentoot server running the cl-bbs application on the specified PORT."
  (when *server*
    (stop-app))
  (setf *app* (build-app))
  (setf *server* (clack:clackup *app* :address host
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
