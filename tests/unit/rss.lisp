(in-package :cl-bbs/tests)

(define-test test-get-request-base-url
  :parent unit
  ;; Test with string url-scheme
  (let* ((headers (make-hash-table :test #'equal))
         (env (list :headers headers :url-scheme "http" :request-uri "/rss")))
    (setf (gethash "host" headers) "127.0.0.1:8222")
    (is equal "http://127.0.0.1:8222" (cl-bbs/rss::get-request-base-url env)))

  ;; Test with symbol url-scheme
  (let* ((headers (make-hash-table :test #'equal))
         (env (list :headers headers :url-scheme :https :request-uri "/rss")))
    (setf (gethash "host" headers) "example.com")
    (is equal "https://example.com" (cl-bbs/rss::get-request-base-url env)))

  ;; Test with x-forwarded-proto
  (let* ((headers (make-hash-table :test #'equal))
         (env (list :headers headers :url-scheme :http :request-uri "/rss")))
    (setf (gethash "host" headers) "proxy.example.com")
    (setf (gethash "x-forwarded-proto" headers) "https")
    (is equal "https://proxy.example.com" (cl-bbs/rss::get-request-base-url env)))

  ;; Test with missing host
  (let* ((headers (make-hash-table :test #'equal))
         (env (list :headers headers :url-scheme :http :request-uri "/rss")))
    (is equal "" (cl-bbs/rss::get-request-base-url env))))

(define-test test-convert-to-rfc822
  :parent unit
  (let ((rfc822 (cl-bbs/rss::convert-to-rfc822 "2026-06-25 16:50:57")))
    (true (not (null (search "2026" rfc822))))
    (true (not (null (search "Jun" rfc822))))))
