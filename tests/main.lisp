(in-package :cl-bbs/tests)

(defun run-tests (&optional (level 'cl-bbs/tests))
  "Runs all test cases within the cl-bbs/tests package."
  (let ((report (test level)))
    (when (eq (status report) :failed)
      (uiop:quit 1))))
