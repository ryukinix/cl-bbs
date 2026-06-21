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
