(in-package :cl-bbs/tests)

(define-test basic-test
  (is equal 1 1))

(define-test test-update-thread-data
  (let* ((thread-data (list (list 'cl-bbs/models::headline "test")
                            (list 'cl-bbs/models::posts '((1 (cl-bbs/models::date . "now") (cl-bbs/models::content . "first"))))))
         (new-post '(2 (cl-bbs/models::date . "later") (cl-bbs/models::content . "second")))
         (result (cl-bbs/handlers::update-thread-data thread-data new-post)))
    (is equal "test" (cadr (assoc 'cl-bbs/models::headline result)))
    (let* ((posts-assoc (assoc 'cl-bbs/models::posts result))
           (posts-list (cdr posts-assoc))
           (actual-posts (car posts-list)))
      (is = 2 (length actual-posts))
      (is = 1 (car (first actual-posts)))
      (is = 2 (car (second actual-posts)))
      (is equal "second" (cdr (assoc 'cl-bbs/models::content (cdr (second actual-posts))))))))

(define-test test-parse-cookies
  (is equal nil (cl-bbs/handlers::parse-cookies nil))
  (is equal nil (cl-bbs/handlers::parse-cookies ""))
  (let ((cookies (cl-bbs/handlers::parse-cookies "theme=dark; foo=bar;  baz = hello ")))
    (is equal "dark" (cdr (assoc "theme" cookies :test #'string=)))
    (is equal "bar" (cdr (assoc "foo" cookies :test #'string=)))
    (is equal "hello" (cdr (assoc "baz" cookies :test #'string=)))))

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
  (is equal "<p>Check <a href=\"https://example.com/page\" target=\"_blank\">https://example.com/page</a></p>"
      (cl-bbs/views::format-text "Check https://example.com/page"))
  ;; Direct image URL
  (is equal "<p>Check <br /><a href=\"https://example.com/pic.png\" target=\"_blank\"><img src=\"https://example.com/pic.png\" style=\"max-width:300px; max-height:300px; display:block; margin:0.5em 0;\" alt=\"preview\" /></a><br /></p>"
      (cl-bbs/views::format-text "Check https://example.com/pic.png"))
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
         (env (list :path-info "/foo/preferences" :request-method :post :content-length (length body-bytes) :raw-body stream))
         (res (cl-bbs/handlers:handle-request env)))
    (is = 303 (first res))
    (is equal "/foo/preferences" (getf (second res) :location))
    (is equal "theme=dark; Path=/; Max-Age=31536000" (getf (second res) (find "Set-Cookie" (second res) :test #'string=)))))

(defun run-tests ()
  (test 'cl-bbs/tests))
