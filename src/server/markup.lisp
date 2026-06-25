(defpackage :cl-bbs/markup
  (:use :cl)
  (:export #:format-text
           #:unescape-html))

(in-package :cl-bbs/markup)

(defun unescape-html (string)
  "Unescapes basic HTML entities found in the STRING back to raw format."
  (let ((s string))
    (setf s (cl-ppcre:regex-replace-all "&quot;" s "\""))
    (setf s (cl-ppcre:regex-replace-all "&lt;" s "<"))
    (setf s (cl-ppcre:regex-replace-all "&gt;" s ">"))
    (setf s (cl-ppcre:regex-replace-all "&#39;" s "'"))
    (setf s (cl-ppcre:regex-replace-all "&#039;" s "'"))
    (setf s (cl-ppcre:regex-replace-all "&apos;" s "'"))
    (setf s (cl-ppcre:regex-replace-all "&#[xX]([0-9a-fA-F]+);" s
                                        (lambda (match-string hex-str)
                                          (declare (ignore match-string))
                                          (string (code-char (parse-integer hex-str :radix 16))))
                                        :simple-calls t))
    (setf s (cl-ppcre:regex-replace-all "&#([0-9]+);" s
                                        (lambda (match-string dec-str)
                                          (declare (ignore match-string))
                                          (string (code-char (parse-integer dec-str :radix 10))))
                                        :simple-calls t))
    (setf s (cl-ppcre:regex-replace-all "&amp;" s "&"))
    s))

(defun format-text (text &optional thread-id)
  "Converts raw markdown-like TEXT into processed HTML.
Supports bold, italic, code-blocks and optionally scoped references matching on THREAD-ID."
  (let* ((escaped (cl-who:escape-string text))
         ;; 1. Extract code blocks
         (code-blocks '())
         (code-block-placeholder-format "<!--CODEBLOCK-PLACEHOLDER-~a-->")
         (placeholder-idx 0)
         (processed escaped))
    (setf processed
          (cl-ppcre:regex-replace-all
           "(?s)```\\n*(.*?)\\n*```"
           processed
           (lambda (match-string &optional content &rest others)
             (declare (ignore match-string others))
             (let ((placeholder (format nil code-block-placeholder-format (incf placeholder-idx))))
               (push (cons placeholder (or content "")) code-blocks)
               placeholder))
           :simple-calls t))
    (setf processed
          (cl-ppcre:regex-replace-all
           "(?m)^&gt;(?!&gt;)\\s*(.*?)$"
           processed
           "<blockquote>\\1</blockquote>"))
    (setf processed
          (cl-ppcre:regex-replace-all
           "\\*\\*(.*?)\\*\\*"
           processed
           "<b>\\1</b>"))
    (setf processed
          (cl-ppcre:regex-replace-all
           "__(.*?)__"
           processed
           "<i>\\1</i>"))
    (setf processed
          (cl-ppcre:regex-replace-all
           "`([^`]+)`"
           processed
           "<code>\\1</code>"))
    (setf processed
          (cl-ppcre:regex-replace-all
           "~~(.*?)~~"
           processed
           "<del>\\1</del>"))
    (setf processed
          (cl-ppcre:regex-replace-all
           "&gt;&gt;(\\d+)"
           processed
           (lambda (match-string &optional num &rest others)
             (declare (ignore match-string others))
             (let ((num-val (or num "")))
               (if thread-id
                   (format nil "<a href=\"#t~ap~a\">&gt;&gt;~a</a>" thread-id num-val num-val)
                   (format nil "<a href=\"#t~a\">&gt;&gt;~a</a>" num-val num-val))))
           :simple-calls t))
    (setf processed
          (cl-ppcre:regex-replace-all
           "https?://[\\w\\-\\.\\/\\?\\=\\&\\%#\\+:\\;]+"
           processed
           "<a href=\"\\&\" target=\"_blank\">\\&</a>"))
    (setf processed
          (cl-ppcre:regex-replace-all
           (concatenate 'string
                        "<a href=\"(https?://[\\w\\-\\.\\/\\?\\=\\&\\%#\\+:\\;]+"
                        "\\.(?:png|jpg|jpeg|gif|webp|bmp))\" "
                        "target=\"_blank\">.*?</a>")
           processed
           (concatenate 'string
                        "<br /><a href=\"\\1\" target=\"_blank\">"
                        "<img src=\"\\1\" style=\"max-width:300px; "
                        "max-height:300px; display:block; margin:0.5em 0;\" "
                        "alt=\"preview\" /></a><br />")))
    (setf processed
          (cl-ppcre:regex-replace-all
           "image\\+<a href=\"(https?://[\\w\\-\\.\\/\\?\\=\\&\\%#\\+:\\;]+)\" target=\"_blank\">.*?</a>"
           processed
           (concatenate 'string
                        "<br /><a href=\"\\1\" target=\"_blank\">"
                        "<img src=\"\\1\" style=\"max-width:300px; "
                        "max-height:300px; display:block; margin:0.5em 0;\" "
                        "alt=\"preview\" /></a><br />")))
    (setf processed
          (cl-ppcre:regex-replace-all
           "\\r\\n"
           processed
           (string #\Newline)))
    (setf processed
          (cl-ppcre:regex-replace-all
           "\\n\\n+"
           processed
           "</p><p>"))
    (setf processed
          (cl-ppcre:regex-replace-all
           "\\n"
           processed
           "<br />"))
    (setf processed (format nil "<p>~a</p>" processed))
    (dolist (pair code-blocks)
      (let ((placeholder (car pair))
            (content (cdr pair)))
        (setf processed
              (cl-ppcre:regex-replace-all
               placeholder
               processed
               (lambda (match-string &optional regs)
                 (declare (ignore match-string regs))
                 (multiple-value-bind (match-start match-end reg-starts reg-ends)
                     (cl-ppcre:scan "^(?i)(lisp|cl|common-lisp)\\r?\\n" content)
                   (declare (ignore reg-starts reg-ends))
                   (if match-start
                       (let* ((escaped-code (subseq content match-end))
                              (raw-code (unescape-html escaped-code))
                              (colorized-code (handler-case (colorize:html-colorization :common-lisp raw-code)
                                                (error () (cl-who:escape-string raw-code)))))
                         (format nil "</p><pre class=\"lisp-code-block\">~a</pre><p>" colorized-code))
                       (format nil "</p><pre>~a</pre><p>" content))))
               :simple-calls t))))
    (setf processed
          (cl-ppcre:regex-replace-all
           "<p>\\s*</p>"
           processed
           ""))
    processed))
