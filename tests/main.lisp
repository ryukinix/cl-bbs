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

(defun run-tests ()
  (test 'cl-bbs/tests))