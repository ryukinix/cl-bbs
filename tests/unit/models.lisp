(in-package :cl-bbs/tests)

(define-test test-models-creation
  :parent unit
  (let ((post (make-instance 'cl-bbs/models:post
                             :id 1
                             :date "2026-06-21"
                             :vip nil
                             :content "Hello World")))
    (is = 1 (cl-bbs/models::post-id post))
    (is equal "2026-06-21" (cl-bbs/models::post-date post))
    (is equal "Hello World" (cl-bbs/models::post-content post)))

  (let ((thread (make-instance 'cl-bbs/models:thread
                               :id 1
                               :headline "Welcome"
                               :date "2026-06-21")))
    (is = 1 (cl-bbs/models::thread-id thread))
    (is equal "Welcome" (cl-bbs/models::thread-headline thread))
    (is = 1 (cl-bbs/models::thread-messages thread))))
