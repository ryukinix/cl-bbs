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
  (let* ((body-str "theme=dark&default_board=foo&search_hide_input=yes&search_local_only=yes&search_position=bottom")
         (body-bytes (flexi-streams:string-to-octets body-str :external-format :utf-8))
         (stream (flexi-streams:make-in-memory-input-stream body-bytes))
         (env (list :path-info "/foo/preferences"
                    :request-method :post
                    :content-length (length body-bytes)
                    :raw-body stream))
         (res (cl-bbs/handlers:handle-request env))
         (headers (second res))
         (has-theme-cookie nil)
         (has-board-cookie nil)
         (has-hide-cookie nil)
         (has-local-cookie nil)
         (has-pos-cookie nil))
    (loop for (key val) on headers by #'cddr
          when (and (keywordp key) (string-equal (symbol-name key) "set-cookie"))
            do (cond
                 ((search "theme=dark;" val) (setf has-theme-cookie t))
                 ((search "default_board=foo;" val) (setf has-board-cookie t))
                 ((search "search_hide_input=yes;" val) (setf has-hide-cookie t))
                 ((search "search_local_only=yes;" val) (setf has-local-cookie t))
                 ((search "search_position=bottom;" val) (setf has-pos-cookie t))))
    (is = 303 (first res))
    (is equal "/foo/preferences" (getf headers :location))
    (true has-theme-cookie)
    (true has-board-cookie)
    (true has-hide-cookie)
    (true has-local-cookie)
    (true has-pos-cookie))

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

(define-test test-search-route-integration
  :parent integration
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
           ;; 1. Request GET /search?q=magical
           (let* ((env (list :path-info "/search" :request-method :get :query-string "q=magical"))
                  (res (cl-bbs/handlers:handle-request env)))
             (is = 200 (first res))
             (is equal "text/html; charset=utf-8" (getf (second res) :content-type))
             (is equal t (not (null (search "Unicorns and Rainbows" (first (third res))))))
             (is equal t (not (null (search "I love magical creatures!" (first (third res)))))))

           ;; 2. Request GET /search?q=impossible-query (should render empty message)
           (let* ((env (list :path-info "/search" :request-method :get :query-string "q=impossible-query"))
                  (res (cl-bbs/handlers:handle-request env)))
             (is = 200 (first res))
             (is equal t (not (null (search "No results found matching your query." (first (third res))))))))
      (when (probe-file thread-path)
        (delete-file thread-path))
      ;; Delete the board directory created
      (let ((board-dir (merge-pathnames "sexp/searchtest/" cl-bbs/storage:*base-dir*)))
        (when (probe-file board-dir)
          (uiop:delete-directory-tree board-dir :validate t))))))

(define-test test-admin-create-board
  :parent integration
  (let ((board-dir (merge-pathnames "sexp/testboard/" cl-bbs/storage:*base-dir*)))
    (when (probe-file board-dir)
      (uiop:delete-directory-tree board-dir :validate t))
    (unwind-protect
         (progn
           ;; 1. Valid board name creation
           (let* ((auth-val (concatenate 'string "Basic " (cl-base64:string-to-base64-string "admin:superchanner")))
                  (body-str "action=create-board&board=testboard")
                  (body-bytes (flexi-streams:string-to-octets body-str :external-format :utf-8))
                  (stream (flexi-streams:make-in-memory-input-stream body-bytes))
                  (env (list :path-info "/admin/action"
                             :request-method :post
                             :headers (alexandria:plist-hash-table (list "authorization" auth-val) :test 'equal)
                             :content-length (length body-bytes)
                             :raw-body stream))
                  (res (cl-bbs/handlers:handle-request env)))
             ;; Expect redirect to /admin
             (is = 303 (first res))
             (is equal "/admin" (getf (second res) :location))
             ;; Check directory exists
             (true (probe-file board-dir)))

           ;; 2. Invalid board name creation (should return 400)
           (let* ((auth-val (concatenate 'string "Basic " (cl-base64:string-to-base64-string "admin:superchanner")))
                  (body-str "action=create-board&board=invalid_name_with_invalid_char*")
                  (body-bytes (flexi-streams:string-to-octets body-str :external-format :utf-8))
                  (stream (flexi-streams:make-in-memory-input-stream body-bytes))
                  (env (list :path-info "/admin/action"
                             :request-method :post
                             :headers (alexandria:plist-hash-table (list "authorization" auth-val) :test 'equal)
                             :content-length (length body-bytes)
                             :raw-body stream))
                  (res (cl-bbs/handlers:handle-request env)))
             (is = 400 (first res))))
      (when (probe-file board-dir)
        (uiop:delete-directory-tree board-dir :validate t)))))

(define-test test-locked-board-posting
  :parent integration
  ;; Ensure board dirs are created for testing board 'lockedboard'
  (cl-bbs/storage:ensure-board-dirs "lockedboard")
  (let ((old-env (uiop:getenv "SBBS_LOCKED_BOARDS")))
    (unwind-protect
         (progn
           (setf (uiop:getenv "SBBS_LOCKED_BOARDS") "lockedboard")

           ;; 1. Try to POST a new thread (should return 403 Forbidden with error page)
           (let* ((body-str "titulus=Test&epistula=Hello")
                  (body-bytes (flexi-streams:string-to-octets body-str :external-format :utf-8))
                  (stream (flexi-streams:make-in-memory-input-stream body-bytes))
                  (env (list :path-info "/lockedboard/post"
                             :request-method :post
                             :content-length (length body-bytes)
                             :raw-body stream))
                  (res (cl-bbs/handlers:handle-request env)))
             (is = 403 (first res))
             (is equal "text/html; charset=utf-8" (getf (second res) :content-type))
             (is equal t (not (null (search "This board is read-only" (first (third res)))))))

           ;; 2. Try to POST a reply (should return 403 Forbidden with error page)
           (let* ((body-str "epistula=Reply")
                  (body-bytes (flexi-streams:string-to-octets body-str :external-format :utf-8))
                  (stream (flexi-streams:make-in-memory-input-stream body-bytes))
                  (env (list :path-info "/lockedboard/1/post"
                             :request-method :post
                             :content-length (length body-bytes)
                             :raw-body stream))
                  (res (cl-bbs/handlers:handle-request env)))
             (is = 403 (first res))
             (is equal "text/html; charset=utf-8" (getf (second res) :content-type))
             (is equal t (not (null (search "This board is read-only" (first (third res))))))))
      (if old-env
          (setf (uiop:getenv "SBBS_LOCKED_BOARDS") old-env)
          #+sbcl (sb-posix:unsetenv "SBBS_LOCKED_BOARDS")
          #-sbcl (setf (uiop:getenv "SBBS_LOCKED_BOARDS") ""))
      (let ((board-dir (merge-pathnames "sexp/lockedboard/" cl-bbs/storage:*base-dir*)))
        (when (probe-file board-dir)
          (uiop:delete-directory-tree board-dir :validate t))))))
