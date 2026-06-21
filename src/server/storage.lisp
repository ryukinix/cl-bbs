(defpackage :cl-bbs/storage
  (:use :cl)
  (:export #:*base-dir*
           #:ensure-board-dirs
           #:read-sexp-file
           #:write-sexp-file
           #:is-board-locked))

(in-package :cl-bbs/storage)

(defvar *base-dir*
  (pathname (or (uiop:getenv "SBBS_DATADIR")
                (merge-pathnames "data/" (asdf:system-source-directory :cl-bbs/server)))))

(defun ensure-board-dirs (board-name)
  "Ensures that directories for storing the board S-expressions and HTML exist."
  (let ((sexp-dir (merge-pathnames (format nil "sexp/~a/" board-name) *base-dir*))
        (html-dir (merge-pathnames (format nil "html/~a/" board-name) *base-dir*)))
    (ensure-directories-exist sexp-dir)
    (ensure-directories-exist html-dir)))

(defun read-sexp-file (path)
  "Reads a safe S-expression from the specified file path, or returns NIL if file does not exist."
  (with-open-file (stream path :direction :input :if-does-not-exist nil)
    (if stream
        (let ((*read-eval* nil))
          (read stream nil nil))
        nil)))

(defun write-sexp-file (path data)
  "Writes the given data as a pretty-printed S-expression to the specified file path."
  (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
    (write data :stream stream :pretty t)
    (terpri stream)))

(defun is-board-locked (board-name)
  "Checks if a board is locked by examining the SBBS_LOCKED_BOARDS environment variable.
BOARD-NAME can be a string or a symbol."
  (let ((locked-env (uiop:getenv "SBBS_LOCKED_BOARDS"))
        (board-str (if (symbolp board-name) (string-downcase (symbol-name board-name)) board-name)))
    (when (and locked-env board-str)
      (let ((locked-boards (cl-ppcre:split "," locked-env)))
        (member board-str locked-boards :test #'string=)))))
