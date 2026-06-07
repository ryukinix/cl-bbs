(in-package :cl-bbs/tests)

(define-test basic-test
  (is equal 1 1))

(defun run-tests ()
  (test 'cl-bbs/tests))