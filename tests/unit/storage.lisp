(in-package :cl-bbs/tests)

(define-test test-storage-sexp
  :parent unit
  (uiop:with-temporary-file (:pathname temp-path)
    (let ((test-data '((:key . "value") (1 2 3))))
      (cl-bbs/storage:write-sexp-file temp-path test-data)
      (let ((read-data (cl-bbs/storage:read-sexp-file temp-path)))
        (is equal test-data read-data)))))

(define-test test-is-board-locked
  :parent unit
  (let ((old-env (uiop:getenv "SBBS_LOCKED_BOARDS")))
    (unwind-protect
         (progn
           ;; Test with no locked boards (empty)
           (setf (uiop:getenv "SBBS_LOCKED_BOARDS") "")
           (false (cl-bbs/storage:is-board-locked "foo"))
           (false (cl-bbs/storage:is-board-locked 'foo))

           ;; Test with locked boards
           (setf (uiop:getenv "SBBS_LOCKED_BOARDS") "foo,bar")
           (true (cl-bbs/storage:is-board-locked "foo"))
           (true (cl-bbs/storage:is-board-locked 'foo))
           (true (cl-bbs/storage:is-board-locked "bar"))
           (true (cl-bbs/storage:is-board-locked 'bar))
           (false (cl-bbs/storage:is-board-locked "baz"))
           (false (cl-bbs/storage:is-board-locked 'baz)))
      (setf (uiop:getenv "SBBS_LOCKED_BOARDS") old-env))))
