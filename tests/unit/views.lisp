(in-package :cl-bbs/tests)

(define-test test-format-text
  :parent unit
  ;; Bold
  (is equal "<p>This is <b>bold</b> text</p>" (cl-bbs/views::format-text "This is **bold** text"))
  ;; Italic
  (is equal "<p>This is <i>italic</i> text</p>" (cl-bbs/views::format-text "This is __italic__ text"))
  ;; Monospace
  (is equal "<p>This is <code>code</code> text</p>" (cl-bbs/views::format-text "This is `code` text"))
  ;; Spoiler
  (is equal "<p>This is <del>spoiler</del> text</p>" (cl-bbs/views::format-text "This is ~~spoiler~~ text"))
  ;; Quote
  (is equal "<p><blockquote>quoted text</blockquote></p>" (cl-bbs/views::format-text ">quoted text"))
  ;; Post reference without thread-id
  (is equal "<p><a href=\"#t7\">&gt;&gt;7</a></p>" (cl-bbs/views::format-text ">>7"))
  ;; Post reference with thread-id
  (is equal "<p><a href=\"#t4p7\">&gt;&gt;7</a></p>" (cl-bbs/views::format-text ">>7" "4"))
  ;; Standard URL
  (is equal (concatenate 'string
                         "<p>Check <a href=\"https://example.com/page\" target=\"_blank\">"
                         "https://example.com/page</a></p>")
      (cl-bbs/views::format-text "Check https://example.com/page"))
  ;; Direct image URL
  (is equal (concatenate 'string
                         "<p>Check <br /><a href=\"https://example.com/pic.png\" target=\"_blank\">"
                         "<img src=\"https://example.com/pic.png\" "
                         "style=\"max-width:300px; max-height:300px; display:block; margin:0.5em 0;\" "
                         "alt=\"preview\" /></a><br /></p>")
      (cl-bbs/views::format-text "Check https://example.com/pic.png"))
  ;; Explicit image prefix override URL
  (is equal (concatenate 'string
                         "<p>Check <br /><a href=\"https://example.com/dynamic-image?id=1\" "
                         "target=\"_blank\"><img src=\"https://example.com/dynamic-image?id=1\" "
                         "style=\"max-width:300px; max-height:300px; display:block; margin:0.5em 0;\" "
                         "alt=\"preview\" /></a><br /></p>")
      (cl-bbs/views::format-text "Check image+https://example.com/dynamic-image?id=1"))
  ;; Code block (using literal newlines in CL strings)
  (is equal "<pre>;;; code block
(list 1 2 3)</pre>"
      (cl-bbs/views::format-text "```
;;; code block
(list 1 2 3)
```"))
  ;; Executable Lisp code blocks
  (is equal "<pre class=\"lisp-code-block\"><span class=\"\"><span class=\"paren1\">(<span class=\"\">format t <span class=\"string\">\"Hello\"</span></span>)</span></span></pre>"
      (cl-bbs/views::format-text "```lisp
(format t \"Hello\")
```"))
  (is equal "<pre class=\"lisp-code-block\"><span class=\"\"><span class=\"paren1\">(<span class=\"\">format t <span class=\"string\">\"Hello\"</span></span>)</span></span></pre>"
      (cl-bbs/views::format-text "```cl
(format t \"Hello\")
```"))
  (is equal "<pre class=\"lisp-code-block\"><span class=\"\"><span class=\"paren1\">(<span class=\"\">format t <span class=\"string\">\"Hello\"</span></span>)</span></span></pre>"
      (cl-bbs/views::format-text "```common-lisp
(format t \"Hello\")
```")))
