(in-package :cl-bbs/tests)

(define-test test-routes-and-handlers
  :parent integration
  ;; Ensure board dirs are created for testing board 'foo'
  (cl-bbs/storage:ensure-board-dirs "foo")

  ;; 0. Test footer renders with commit link
  (let* ((env (list :path-info "/foo" :request-method :get))
         (res (cl-bbs/handlers:handle-request env))
         (html-body (first (third res))))
    (is equal t (not (null (search "cl-bbs version:" html-body))))
    (is equal t (not (null (search "github.com/ryukinix/cl-bbs" html-body)))))

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
  (let* ((body-str "theme=dark&default_board=foo")
         (body-bytes (flexi-streams:string-to-octets body-str :external-format :utf-8))
         (stream (flexi-streams:make-in-memory-input-stream body-bytes))
         (env (list :path-info "/foo/preferences"
                    :request-method :post
                    :content-length (length body-bytes)
                    :raw-body stream))
         (res (cl-bbs/handlers:handle-request env))
         (headers (second res))
         (has-theme-cookie nil)
         (has-board-cookie nil))
    (loop for (key val) on headers by #'cddr
          when (and (keywordp key) (string-equal (symbol-name key) "set-cookie"))
            do (cond
                 ((search "theme=dark;" val) (setf has-theme-cookie t))
                 ((search "default_board=foo;" val) (setf has-board-cookie t))))
    (is = 303 (first res))
    (is equal "/foo/preferences" (getf headers :location))
    (true has-theme-cookie)
    (true has-board-cookie))

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

    ;; Test range-based comment retrieval for single post "1"
    (let* ((env (list :path-info "/foo/1/1" :request-method :get))
           (res (cl-bbs/handlers:handle-request env)))
      (is = 200 (first res))
      (is equal "text/html; charset=utf-8" (getf (second res) :content-type))
      (is equal t (not (null (search "This is a test post" (first (third res)))))))

    (when (probe-file thread-path)
      (delete-file thread-path))))

(define-test test-empty-post-validation
  :parent integration
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
