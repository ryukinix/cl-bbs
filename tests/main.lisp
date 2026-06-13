(in-package :cl-bbs/tests)

(define-test basic-test
  (is equal 1 1))

(define-test test-update-thread-data
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
  (is equal nil (cl-bbs/handlers::parse-cookies nil))
  (is equal nil (cl-bbs/handlers::parse-cookies ""))
  (let ((cookies (cl-bbs/handlers::parse-cookies "theme=dark; foo=bar;  baz = hello ")))
    (is equal "dark" (cdr (assoc "theme" cookies :test #'string=)))
    (is equal "bar" (cdr (assoc "foo" cookies :test #'string=)))
    (is equal "hello" (cdr (assoc "baz" cookies :test #'string=)))))

(define-test test-theme-query-and-sanitization
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

(define-test test-format-text
  ;; Bold
  (is equal "<p>This is <b>bold</b> text</p>" (cl-bbs/views::format-text "This is **bold** text"))
  ;; Italic
  (is equal "<p>This is <i>italic</i> text</p>" (cl-bbs/views::format-text "This is __italic__ text"))
  ;; Monospace
  (is equal "<p>This is <code>code</code> text</p>" (cl-bbs/views::format-text "This is `code` text"))
  ;; Spoiler
  (is equal "<p>This is <del>spoiler</del> text</p>" (cl-bbs/views::format-text "This is ~~spoiler~~ text"))
  ;; Quote
  (is equal "<p><blockquote>quoted text</blockquote></p>" (cl-bbs/views::format-text ">quoted text"))
  ;; Post reference without thread-id
  (is equal "<p><a href=\"#t7\">&gt;&gt;7</a></p>" (cl-bbs/views::format-text ">>7"))
  ;; Post reference with thread-id
  (is equal "<p><a href=\"#t4p7\">&gt;&gt;7</a></p>" (cl-bbs/views::format-text ">>7" "4"))
  ;; Standard URL
  (is equal (concatenate 'string
                         "<p>Check <a href=\"https://example.com/page\" target=\"_blank\">"
                         "https://example.com/page</a></p>")
      (cl-bbs/views::format-text "Check https://example.com/page"))
  ;; Direct image URL
  (is equal (concatenate 'string
                         "<p>Check <br /><a href=\"https://example.com/pic.png\" target=\"_blank\">"
                         "<img src=\"https://example.com/pic.png\" "
                         "style=\"max-width:300px; max-height:300px; display:block; margin:0.5em 0;\" "
                         "alt=\"preview\" /></a><br /></p>")
      (cl-bbs/views::format-text "Check https://example.com/pic.png"))
  ;; Explicit image prefix override URL
  (is equal (concatenate 'string
                         "<p>Check <br /><a href=\"https://example.com/dynamic-image?id=1\" "
                         "target=\"_blank\"><img src=\"https://example.com/dynamic-image?id=1\" "
                         "style=\"max-width:300px; max-height:300px; display:block; margin:0.5em 0;\" "
                         "alt=\"preview\" /></a><br /></p>")
      (cl-bbs/views::format-text "Check image+https://example.com/dynamic-image?id=1"))
  ;; Code block (using literal newlines in CL strings)
  (is equal "<pre>;;; code block
(list 1 2 3)</pre>"
      (cl-bbs/views::format-text "```
;;; code block
(list 1 2 3)
```")))

(define-test test-routes-and-handlers
  ;; Ensure board dirs are created for testing board 'foo'
  (cl-bbs/storage:ensure-board-dirs "foo")

  ;; 1. GET Root /
  (let* ((env (list :path-info "/" :request-method :get))
         (res (cl-bbs/handlers:handle-request env)))
    (is = 200 (first res)))

  ;; 2. GET Board Index /foo/
  (let* ((env (list :path-info "/foo" :request-method :get))
         (res (cl-bbs/handlers:handle-request env)))
    (is = 200 (first res)))

  ;; 3. GET Thread List /foo/list
  (let* ((env (list :path-info "/foo/list" :request-method :get))
         (res (cl-bbs/handlers:handle-request env)))
    (is = 200 (first res)))

  ;; 4. GET Preferences /foo/preferences
  (let* ((env (list :path-info "/foo/preferences" :request-method :get))
         (res (cl-bbs/handlers:handle-request env)))
    (is = 200 (first res))
    (is equal "text/html; charset=utf-8" (second (second res))))

  ;; 5. POST Preferences /foo/preferences
  (let* ((body-str "theme=dark")
         (body-bytes (flexi-streams:string-to-octets body-str :external-format :utf-8))
         (stream (flexi-streams:make-in-memory-input-stream body-bytes))
         (env (list :path-info "/foo/preferences"
                    :request-method :post
                    :content-length (length body-bytes)
                    :raw-body stream))
         (res (cl-bbs/handlers:handle-request env)))
    (is = 303 (first res))
    (is equal "/foo/preferences" (getf (second res) :location))
    (is equal "theme=dark; Path=/; Max-Age=31536000"
        (getf (second res) (find "Set-Cookie" (second res) :test #'string=))))

  ;; 6. GET sw.js /sw.js
  (let* ((env (list :path-info "/sw.js" :request-method :get))
         (res (cl-bbs/handlers:handle-request env)))
    (is = 200 (first res))
    (is equal "application/javascript" (getf (second res) :content-type)))

  ;; 7. GET manifest.json /manifest.json
  (let* ((env (list :path-info "/manifest.json" :request-method :get))
         (res (cl-bbs/handlers:handle-request env)))
    (is = 200 (first res))
    (is equal "application/json" (getf (second res) :content-type)))

  ;; 7b. GET about page /about
  (let* ((env (list :path-info "/about" :request-method :get))
         (res (cl-bbs/handlers:handle-request env)))
    (is = 200 (first res))
    (is equal "text/html; charset=utf-8" (getf (second res) :content-type)))

  ;; 8. GET Moderation Panel /admin (Unauthorized)
  (let* ((env (list :path-info "/admin" :request-method :get))
         (res (cl-bbs/handlers:handle-request env)))
    (is = 401 (first res)))

  ;; 9. GET Moderation Panel /admin (Authorized)
  (let* ((auth-val (concatenate 'string "Basic " (cl-base64:string-to-base64-string "admin:superchanner")))
         (env (list :path-info "/admin" :request-method :get
                    :headers (alexandria:plist-hash-table (list "authorization" auth-val) :test 'equal)))
         (res (cl-bbs/handlers:handle-request env)))
    (is = 200 (first res))
    (is equal "text/html; charset=utf-8" (getf (second res) :content-type)))

  ;; 9b. GET Thread View /foo/1 (404 Not Found initially)
  (let* ((env (list :path-info "/foo/1" :request-method :get))
         (res (cl-bbs/handlers:handle-request env)))
    (is = 404 (first res)))

  ;; 9c. GET Thread View /foo/1 (200 OK once created)
  (let ((thread-path (merge-pathnames "sexp/foo/1" cl-bbs/storage:*base-dir*))
        (thread-data '((cl-bbs/models:headline . "Mock Thread")
                        (cl-bbs/models:posts . ((1 (cl-bbs/models:date . "2026-06-12")
                                                    (cl-bbs/models:vip . nil)
                                                    (cl-bbs/models:content . "This is a test post")))))))
    (cl-bbs/storage:write-sexp-file thread-path thread-data)
    (let* ((env (list :path-info "/foo/1" :request-method :get))
           (res (cl-bbs/handlers:handle-request env)))
      (is = 200 (first res))
      (is equal "text/html; charset=utf-8" (getf (second res) :content-type))
      (is equal t (not (null (search "Mock Thread" (first (third res)))))))
    (when (probe-file thread-path)
      (delete-file thread-path))))

(define-test test-empty-post-validation
  ;; Ensure board dirs are created for testing board 'foo'
  (cl-bbs/storage:ensure-board-dirs "foo")

  ;; 1. POST New Thread with Empty Body (should 400 with HTML error page)
  (let* ((body-str "titulus=NoBody&epistula=   ")
         (body-bytes (flexi-streams:string-to-octets body-str :external-format :utf-8))
         (stream (flexi-streams:make-in-memory-input-stream body-bytes))
         (env (list :path-info "/foo/post"
                    :request-method :post
                    :content-length (length body-bytes)
                    :raw-body stream))
         (res (cl-bbs/handlers:handle-request env)))
    (is = 400 (first res))
    (is equal "text/html; charset=utf-8" (getf (second res) :content-type))
    (is equal t (not (null (search "Go Back and Edit Post"
                                   (first (third res)))))))

  ;; 2. POST Reply with Empty Body (should 400 with HTML error page)
  ;; Let's assume thread 1 exists (or doesn't, but the validation check is executed first anyway)
  (let* ((body-str "epistula=")
         (body-bytes (flexi-streams:string-to-octets body-str :external-format :utf-8))
         (stream (flexi-streams:make-in-memory-input-stream body-bytes))
         (env (list :path-info "/foo/1/post"
                    :request-method :post
                    :content-length (length body-bytes)
                    :raw-body stream))
         (res (cl-bbs/handlers:handle-request env)))
    (is = 400 (first res))
    (is equal "text/html; charset=utf-8" (getf (second res) :content-type))
    (is equal t (not (null (search "Go Back and Edit Post"
                                   (first (third res))))))))

;; Individual Administrative Commands Tests
(define-test test-admin-get-flat-posts
  (is equal '((1 :content "hello")) (cl-bbs-admin::get-flat-posts '((1 :content "hello"))))
  (is equal '((1 :content "hello")) (cl-bbs-admin::get-flat-posts '(((1 :content "hello"))))))

(define-test test-admin-lookup-def
  (let ((alist '((cl-bbs/models:posts (1 :content "hello")))))
    (is equal '((1 :content "hello")) (cl-bbs-admin::lookup-def 'cl-bbs/models:posts alist))))

(define-test test-admin-find-duplicates
  (let ((posts '((1 (cl-bbs/models:content . "test")) (2 (cl-bbs/models:content . "test")))))
    (is = 1 (length (cl-bbs-admin::find-duplicates posts)))))

(define-test test-admin-add-timezone-offset
  (is equal "2026-06-08 01:00" (cl-bbs-admin::add-timezone-offset "2026-06-08 00:00" 1)))

(defun run-tests ()
  "Runs all test cases within the cl-bbs/tests package."
  (test 'cl-bbs/tests))
