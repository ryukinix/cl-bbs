(in-package :cl-bbs/tests)

;; Individual Administrative Commands Tests
(define-test test-admin-get-flat-posts
  :parent unit
  (is equal '((1 :content "hello")) (cl-bbs-admin::get-flat-posts '((1 :content "hello"))))
  (is equal '((1 :content "hello")) (cl-bbs-admin::get-flat-posts '(((1 :content "hello"))))))

(define-test test-admin-lookup-def
  :parent unit
  (let ((alist '((cl-bbs/models:posts (1 :content "hello")))))
    (is equal '((1 :content "hello")) (cl-bbs-admin::lookup-def 'cl-bbs/models:posts alist))))

(define-test test-admin-find-duplicates
  :parent unit
  (let ((posts '((1 (cl-bbs/models:content . "test")) (2 (cl-bbs/models:content . "test")))))
    (is = 1 (length (cl-bbs-admin::find-duplicates posts)))))

(define-test test-admin-add-timezone-offset
  :parent unit
  (is equal "2026-06-08 01:00" (cl-bbs-admin::add-timezone-offset "2026-06-08 00:00" 1)))
