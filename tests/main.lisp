(in-package :cl-bbs/tests)

(defun run-tests (&optional (level 'cl-bbs/tests))
  "Runs all test cases within the cl-bbs/tests package."
  (setf colorize:*debug* nil)
  (let ((report (test level)))
    (when (eq (status report) :failed)
      (uiop:quit 1))))
