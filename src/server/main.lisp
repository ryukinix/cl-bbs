(in-package :cl-bbs/server)

(defvar *server* nil)
(defvar *app* nil)

;; Initialize colorize and HyperSpec lookup paths safely
(defun init-colorize ()
  (setf colorize:*debug* nil)
  (handler-case
      (let* ((base-dir (asdf:system-source-directory :cl-bbs/server))
             (local-clhs-dir (and base-dir (merge-pathnames "src/HyperSpec/" base-dir)))
             (local-map-file (and local-clhs-dir (merge-pathnames "Data/Map_Sym.txt" local-clhs-dir)))
             (mop-map-file (and local-clhs-dir (merge-pathnames "Mop_Sym.txt" local-clhs-dir))))
        (if (and local-map-file (probe-file local-map-file))
            (progn
              (setf clhs-lookup::*hyperspec-pathname* local-clhs-dir)
              (setf clhs-lookup::*hyperspec-map-file* local-map-file)
              (setf clhs-lookup::*mop-map-file* mop-map-file))
            (setf clhs-lookup::*hyperspec-map-file* #p"nonexistent-map-sym.txt")))
    (error (e)
      (declare (ignore e))
      (setf clhs-lookup::*hyperspec-map-file* #p"nonexistent-map-sym.txt"))))


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
  (init-colorize)
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
