(in-package :cl-bbs/tests)

(define-test test-update-thread-data
  :parent unit
  (let* ((thread-data (list (list 'cl-bbs/models:headline "test")
                            (list 'cl-bbs/models:posts
                                  '((1 (cl-bbs/models:date . "now")
                                       (cl-bbs/models:content . "first"))))))
         (new-post '(2 (cl-bbs/models:date . "later") (cl-bbs/models:content . "second")))
         (result (cl-bbs/handlers::update-thread-data thread-data new-post)))
    (is equal "test" (cadr (assoc 'cl-bbs/models:headline result)))
    (let* ((posts-assoc (assoc 'cl-bbs/models:posts result))
           (posts-list (cdr posts-assoc))
           (actual-posts (car posts-list)))
      (is = 2 (length actual-posts))
      (is = 1 (car (first actual-posts)))
      (is = 2 (car (second actual-posts)))
      (is equal "second" (cdr (assoc 'cl-bbs/models:content (cdr (second actual-posts))))))))

(define-test test-parse-cookies
  :parent unit
  (is equal nil (cl-bbs/handlers::parse-cookies nil))
  (is equal nil (cl-bbs/handlers::parse-cookies ""))
  (let ((cookies (cl-bbs/handlers::parse-cookies "theme=dark; foo=bar;  baz = hello ")))
    (is equal "dark" (cdr (assoc "theme" cookies :test #'string=)))
    (is equal "bar" (cdr (assoc "foo" cookies :test #'string=)))
    (is equal "hello" (cdr (assoc "baz" cookies :test #'string=)))))

(define-test test-theme-query-and-sanitization
  :parent unit
  ;; Test sanitization
  (is equal "dark" (cl-bbs/handlers::sanitize-theme-name "dark"))
  (is equal "theme-123" (cl-bbs/handlers::sanitize-theme-name "theme-123"))
  (is equal "theme_classic" (cl-bbs/handlers::sanitize-theme-name "theme_classic"))
  (is equal nil (cl-bbs/handlers::sanitize-theme-name "theme.css"))
  (is equal nil (cl-bbs/handlers::sanitize-theme-name "../../etc/passwd"))
  (is equal nil (cl-bbs/handlers::sanitize-theme-name "dark;cookie=foo"))
  (is equal nil (cl-bbs/handlers::sanitize-theme-name "<script>"))

  ;; Test get-theme-from-env with query string
  (let ((env-query (list :query-string "theme=colored")))
    (is equal "colored" (cl-bbs/handlers::get-theme-from-env env-query)))

  ;; Test get-theme-from-env with query string overriding cookie
  (let* ((headers (make-hash-table :test 'equal))
         (env (list :query-string "theme=dark" :headers headers)))
    (setf (gethash "cookie" headers) "theme=colored")
    (is equal "dark" (cl-bbs/handlers::get-theme-from-env env)))

  ;; Test get-theme-from-env fallback to cookie when query string has no theme
  (let* ((headers (make-hash-table :test 'equal))
         (env (list :query-string "other=param" :headers headers)))
    (setf (gethash "cookie" headers) "theme=colored")
    (is equal "colored" (cl-bbs/handlers::get-theme-from-env env)))

  ;; Test get-theme-from-env fallback to default when no theme query and no theme cookie
  (let* ((headers (make-hash-table :test 'equal))
         (env (list :query-string "" :headers headers)))
    (setf (gethash "cookie" headers) "other=cookie")
    (is equal "default" (cl-bbs/handlers::get-theme-from-env env)))

  ;; Test get-theme-from-env fallback to default when query theme is invalid/malicious
  (let* ((headers (make-hash-table :test 'equal))
         (env (list :query-string "theme=../../malicious" :headers headers)))
    (setf (gethash "cookie" headers) "theme=dark")
    (is equal "dark" (cl-bbs/handlers::get-theme-from-env env))))

(define-test test-search-posts
  :parent unit
  ;; Ensure board dirs are created for testing board 'searchtest'
  (cl-bbs/storage:ensure-board-dirs "searchtest")
  (let ((thread-path (merge-pathnames "sexp/searchtest/1" cl-bbs/storage:*base-dir*))
        (thread-data '((cl-bbs/models:headline . "Unicorns and Rainbows")
                        (cl-bbs/models:posts . ((1 (cl-bbs/models:date . "2026-06-12")
                                                    (cl-bbs/models:vip . nil)
                                                    (cl-bbs/models:content . "I love magical creatures!")))))))
    (cl-bbs/storage:write-sexp-file thread-path thread-data)
    (unwind-protect
         (progn
           ;; 1. Search for a query that matches the content
           (let ((res1 (cl-bbs/handlers::search-posts "magical")))
             (is = 1 (length res1))
             (is equal "searchtest" (getf (first res1) :board))
             (is equal "Unicorns and Rainbows" (getf (first res1) :headline))
             (is equal "I love magical creatures!" (getf (first res1) :content)))

           ;; 2. Search for a query that matches the headline
           (let ((res2 (cl-bbs/handlers::search-posts "unicorn")))
             (is = 1 (length res2))
             (is equal "1" (getf (first res2) :thread-id)))

           ;; 3. Search with board filter
           (let ((res3 (cl-bbs/handlers::search-posts "magical" "searchtest")))
             (is = 1 (length res3)))

           ;; 4. Search with board filter that doesn't match
           (let ((res4 (cl-bbs/handlers::search-posts "magical" "nonexistent")))
             (is = 0 (length res4)))

           ;; 5. Search for a query that does not exist
           (let ((res5 (cl-bbs/handlers::search-posts "impossible-query")))
             (is = 0 (length res5))))
      (when (probe-file thread-path)
        (delete-file thread-path))
      ;; Delete the board directory created
      (let ((board-dir (merge-pathnames "sexp/searchtest/" cl-bbs/storage:*base-dir*)))
        (when (probe-file board-dir)
          (uiop:delete-directory-tree board-dir :validate t))))))

(define-test test-shame-thread-file
  :parent unit
  (cl-bbs/storage:ensure-board-dirs "shametest")
  (cl-bbs/storage:ensure-board-dirs "shame")
  (let ((thread-path (merge-pathnames "sexp/shametest/1" cl-bbs/storage:*base-dir*))
        (thread-data '((cl-bbs/models:headline . "Shame Test Thread")
                       (cl-bbs/models:posts . ((1 (cl-bbs/models:date . "2026-06-12")
                                                   (cl-bbs/models:vip . nil)
                                                   (cl-bbs/models:content . "This thread deserves shame.")))))))
    (cl-bbs/storage:write-sexp-file thread-path thread-data)
    (cl-bbs/handlers::regenerate-board-index "shametest")
    (cl-bbs/handlers::shame-thread-file "shametest" "1")
    ;; Check if the thread was moved to "shame" board
    (let* ((shame-dir (merge-pathnames "sexp/shame/" cl-bbs/storage:*base-dir*))
           (files (and (probe-file shame-dir) (uiop:directory-files shame-dir))))
      ;; There should be at least one file that is the moved thread (its name will be an integer)
      (true (some (lambda (file)
                       (let ((name (pathname-name file)))
                         (handler-case (and (parse-integer name)
                                            (string= (cdr (assoc 'cl-bbs/models:headline (cl-bbs/storage:read-sexp-file file)))
                                                     "Shame Test Thread"))
                           (error () nil))))
                     files))
      ;; The original thread in "shametest" should be gone
      (false (probe-file thread-path))
      ;; Clean up moved files in "shame" board
      (dolist (file files)
        (let ((name (pathname-name file)))
          (when (handler-case (parse-integer name) (error () nil))
            (let ((data (cl-bbs/storage:read-sexp-file file)))
              (when (string= (cdr (assoc 'cl-bbs/models:headline data)) "Shame Test Thread")
                (delete-file file))))))
      ;; Regenerate indexes to clean up
      (cl-bbs/handlers::regenerate-board-index "shame"))
    ;; Clean up shametest board
    (let ((board-dir (merge-pathnames "sexp/shametest/" cl-bbs/storage:*base-dir*)))
      (when (probe-file board-dir)
        (uiop:delete-directory-tree board-dir :validate t)))))
