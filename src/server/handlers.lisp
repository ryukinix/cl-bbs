(defpackage :cl-bbs/handlers
  (:use :cl :cl-bbs/storage :cl-bbs/views)
  (:export #:handle-request))

(in-package :cl-bbs/handlers)

(defun get-date ()
  (multiple-value-bind (second minute hour date month year)
      (get-decoded-time)
    (declare (ignore second))
    (format nil "~4,'0d-~2,'0d-~2,'0d ~2,'0d:~2,'0d"
            year month date hour minute)))

(defun get-next-thread-number (threads)
  (if (null threads)
      1
      (1+ (apply #'max (mapcar #'car threads)))))

(defun create-thread (path headline date message)
  (let ((thread `((cl-bbs/models::headline . ,headline)
                  (cl-bbs/models::posts . ((1 (cl-bbs/models::date . ,date) (cl-bbs/models::vip . nil) (cl-bbs/models::content . ,message)))))))
    (write-sexp-file path thread)))

(defun add-thread-to-list (path thread-number headline date)
  (let ((threads (read-sexp-file path)))
    (write-sexp-file path
                     (cons `(,thread-number (cl-bbs/models::headline . ,headline) (cl-bbs/models::date . ,date) (cl-bbs/models::messages . 1))
                           threads))))

(defun add-thread-to-index (path thread-number headline date message)
  (let* ((threads (read-sexp-file path))
         (thread `(,thread-number
                    (cl-bbs/models::headline . ,headline)
                    (cl-bbs/models::truncated . nil)
                    (cl-bbs/models::posts ((1 (cl-bbs/models::date . ,date) (cl-bbs/models::vip . nil) (cl-bbs/models::content . ,message)))))))
    (write-sexp-file path (cons thread threads))))

(defun handle-request (env)
  (let* ((path-info (getf env :path-info))
         (method (getf env :request-method))
         (parts (remove "" (cl-ppcre:split "/" path-info) :test #'string=))
         (query-string (getf env :query-string)))
    
    (cond
      ;; The static middleware intercepts /static/ beforehand.
      ;; We serve the index.html from static dir on root natively.
      ((string= path-info "/")
       (let ((index-file (pathname (or (uiop:getenv "SBBS_INDEX_FILE")
                                       (merge-pathnames "src/static/index.html" (asdf:system-source-directory :cl-bbs/server))))))
         (if (probe-file index-file)
             `(200 (:content-type "text/html; charset=utf-8")
                   (,(uiop:read-file-string index-file)))
             `(200 (:content-type "text/plain") ("SchemeBBS clone root")))))
      
      ((and (eq method :get)
            (= (length parts) 1))
       (let* ((board (first parts))
              (index-path (merge-pathnames (format nil "sexp/~a/index" board) *base-dir*)))
          (if (probe-file index-path)
             (let ((index-data (read-sexp-file index-path)))
                `(200 (:content-type "text/html; charset=utf-8")
                      (,(render-index board index-data))))
             `(200 (:content-type "text/html; charset=utf-8")
                   (,(render-index board nil))))))

      ((and (eq method :get)
            (= (length parts) 2)
            (string= (second parts) "list"))
       (let* ((board (first parts))
              (list-path (merge-pathnames (format nil "sexp/~a/list" board) *base-dir*)))
          (if (probe-file list-path)
             (let ((list-data (read-sexp-file list-path)))
                `(200 (:content-type "text/html; charset=utf-8")
                      (,(render-list board list-data))))
             `(200 (:content-type "text/html; charset=utf-8")
                   (,(render-list board nil))))))

      ;; POST handlers
      ((and (eq method :post)
            (= (length parts) 2)
            (string= (second parts) "post"))
       ;; New thread
       (let* ((board (first parts))
              (body-bytes (make-array (getf env :content-length) :element-type '(unsigned-byte 8)))
              (_ (read-sequence body-bytes (getf env :raw-body)))
              (body-str (flexi-streams:octets-to-string body-bytes :external-format :utf-8))
              (params (quri:url-decode-params body-str))
              (epistula (cdr (assoc "epistula" params :test #'string=)))
              (titulus (cdr (assoc "titulus" params :test #'string=)))
              (date (get-date))
              (list-path (merge-pathnames (format nil "sexp/~a/list" board) *base-dir*))
              (index-path (merge-pathnames (format nil "sexp/~a/index" board) *base-dir*))
              (threads (read-sexp-file list-path))
              (thread-number (get-next-thread-number threads))
              (thread-path (merge-pathnames (format nil "sexp/~a/~a" board thread-number) *base-dir*)))
         
         (ensure-board-dirs board)
         (create-thread thread-path titulus date epistula)
         (add-thread-to-list list-path thread-number titulus date)
         (add-thread-to-index index-path thread-number titulus date epistula)
         
         `(303 (:location ,(format nil "/~a/~a#t~ap1" board thread-number thread-number)) ("Redirecting..."))))

      ((and (eq method :post)
            (= (length parts) 3)
            (string= (third parts) "post"))
       ;; Reply to thread
       (let* ((board (first parts))
              (thread-id (second parts))
              (body-bytes (make-array (getf env :content-length) :element-type '(unsigned-byte 8)))
              (_ (read-sequence body-bytes (getf env :raw-body)))
              (body-str (flexi-streams:octets-to-string body-bytes :external-format :utf-8))
              (params (quri:url-decode-params body-str))
              (epistula (cdr (assoc "epistula" params :test #'string=)))
              (date (get-date))
              (thread-path (merge-pathnames (format nil "sexp/~a/~a" board thread-id) *base-dir*)))
         (if (probe-file thread-path)
             (let* ((thread-data (read-sexp-file thread-path))
                    (raw-thread (if (and (consp thread-data) (consp (car thread-data))) (car thread-data) thread-data))
                    (posts-assoc (let ((assoc-result (assoc 'cl-bbs/models::posts raw-thread))) (if assoc-result assoc-result (cadr (if (consp thread-data) thread-data (list thread-data))))))
                    (posts-list (if (listp (cdr posts-assoc)) (if (listp (cadr posts-assoc)) (cadr posts-assoc) (cdr posts-assoc)) (cdr posts-assoc)))
                    (posts (if (listp (car posts-list)) posts-list (list posts-list)))
                    (new-post `(,(1+ (reduce #'max posts :key #'car :initial-value 0)) (cl-bbs/models::date . ,date) (cl-bbs/models::vip . nil) (cl-bbs/models::content . ,epistula)))
                    (new-thread-data (update-thread-data thread-data new-post)))
               (write-sexp-file thread-path new-thread-data)
               
               ;; Update list metadata
               (let* ((list-path (merge-pathnames (format nil "sexp/~a/list" board) *base-dir*))
                      (threads-list (read-sexp-file list-path))
                      (str-id (if (stringp thread-id) (parse-integer thread-id) thread-id))
                      (target-thread-assoc (assoc str-id threads-list)))
                 (when target-thread-assoc
                   (let* ((rem-threads (remove str-id threads-list :key #'car :test #'equal))
                          (messages-count (length (cadr (assoc 'cl-bbs/models::posts (if (consp (car new-thread-data)) (car new-thread-data) new-thread-data)))))
                          (updated-entry `(,str-id 
                                            (cl-bbs/models::headline . ,(if (stringp (cdr (assoc 'cl-bbs/models::headline target-thread-assoc))) (cdr (assoc 'cl-bbs/models::headline target-thread-assoc)) (cdr (assoc 'headline target-thread-assoc))))
                                            (cl-bbs/models::date . ,date) 
                                            (cl-bbs/models::messages . ,messages-count))))
                     (write-sexp-file list-path (cons updated-entry rem-threads))))
                 
                 ;; Update index metadata
                 (let* ((index-path (merge-pathnames (format nil "sexp/~a/index" board) *base-dir*))
                        (index-list (read-sexp-file index-path))
                        (target-index-assoc (assoc str-id index-list)))
                   (when target-index-assoc
                     (let* ((rem-index (remove str-id index-list :key #'car :test #'equal))
                            (updated-entry `(,str-id 
                                              (cl-bbs/models::headline . ,(if (stringp (cdr (assoc 'cl-bbs/models::headline target-index-assoc))) (cdr (assoc 'cl-bbs/models::headline target-index-assoc)) (cdr (assoc 'headline target-index-assoc))))
                                              (cl-bbs/models::truncated . nil)
                                              (cl-bbs/models::posts ,(cadr (assoc 'cl-bbs/models::posts (if (consp (car new-thread-data)) (car new-thread-data) new-thread-data)))))))
                       (write-sexp-file index-path (cons updated-entry rem-index))))))
               `(303 (:location ,(format nil "/~a/~a#t~ap~a" board thread-id thread-id (car new-post))) ("Redirecting...")))
             `(404 (:content-type "text/plain") ("Thread not found")))))

      (t
       `(404 (:content-type "text/plain") ("Not found"))))))