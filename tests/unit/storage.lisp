(in-package :cl-bbs/tests)

(define-test test-storage-sexp
  :parent unit
  (uiop:with-temporary-file (:pathname temp-path)
    (let ((test-data '((:key . "value") (1 2 3))))
      (cl-bbs/storage:write-sexp-file temp-path test-data)
      (let ((read-data (cl-bbs/storage:read-sexp-file temp-path)))
        (is equal test-data read-data)))))
