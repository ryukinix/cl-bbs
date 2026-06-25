(in-package :cl-bbs/tests)

(define-test test-format-text
  :parent unit
  ;; Bold
  (is equal "<p>This is <b>bold</b> text</p>"
      (cl-bbs/markup:format-text "This is **bold** text"))
  ;; Italic
  (is equal "<p>This is <i>italic</i> text</p>"
      (cl-bbs/markup:format-text "This is __italic__ text"))
  ;; Monospace
  (is equal "<p>This is <code>code</code> text</p>"
      (cl-bbs/markup:format-text "This is `code` text"))
  ;; Spoiler
  (is equal "<p>This is <del>spoiler</del> text</p>"
      (cl-bbs/markup:format-text "This is ~~spoiler~~ text"))
  ;; Quote
  (is equal "<p><blockquote>quoted text</blockquote></p>"
      (cl-bbs/markup:format-text ">quoted text"))
  ;; Post reference without thread-id
  (is equal "<p><a href=\"#t7\">&gt;&gt;7</a></p>"
      (cl-bbs/markup:format-text ">>7"))
  ;; Post reference with thread-id
  (is equal "<p><a href=\"#t4p7\">&gt;&gt;7</a></p>"
      (cl-bbs/markup:format-text ">>7" "4"))
  ;; Standard URL
  (is equal (concatenate 'string
                         "<p>Check <a href=\"https://example.com/page\" target=\"_blank\">"
                         "https://example.com/page</a></p>")
      (cl-bbs/markup:format-text "Check https://example.com/page"))
  ;; Direct image URL
  (is equal (concatenate 'string
                         "<p>Check <br /><a href=\"https://example.com/pic.png\" target=\"_blank\">"
                         "<img src=\"https://example.com/pic.png\" "
                         "style=\"max-width:300px; max-height:300px; display:block; margin:0.5em 0;\" "
                         "alt=\"preview\" /></a><br /></p>")
      (cl-bbs/markup:format-text "Check https://example.com/pic.png"))
  ;; Explicit image prefix override URL
  (is equal (concatenate 'string
                         "<p>Check <br /><a href=\"https://example.com/dynamic-image?id=1\" "
                         "target=\"_blank\"><img src=\"https://example.com/dynamic-image?id=1\" "
                         "style=\"max-width:300px; max-height:300px; display:block; margin:0.5em 0;\" "
                         "alt=\"preview\" /></a><br /></p>")
      (cl-bbs/markup:format-text "Check image+https://example.com/dynamic-image?id=1"))
  ;; Code block (using literal newlines in CL strings)
  (is equal "<pre>;;; code block
(list 1 2 3)</pre>"
      (cl-bbs/markup:format-text "```
;;; code block
(list 1 2 3)
```"))
  ;; Executable Lisp code blocks
  (is equal (concatenate 'string
                         "<pre class=\"lisp-code-block\">"
                         "<span class=\"\"><span class=\"paren1\">"
                         "(<span class=\"\">format t <span class=\"string\">\"Hello\"</span></span>)</span></span>"
                         "</pre>")
      (cl-bbs/markup:format-text "```lisp
(format t \"Hello\")
```"))
  (is equal (concatenate 'string
                         "<pre class=\"lisp-code-block\">"
                         "<span class=\"\"><span class=\"paren1\">"
                         "(<span class=\"\">format t <span class=\"string\">\"Hello\"</span></span>)</span></span>"
                         "</pre>")
      (cl-bbs/markup:format-text "```cl
(format t \"Hello\")
```"))
  (is equal (concatenate 'string
                         "<pre class=\"lisp-code-block\">"
                         "<span class=\"\"><span class=\"paren1\">"
                         "(<span class=\"\">format t <span class=\"string\">\"Hello\"</span></span>)</span></span>"
                         "</pre>")
      (cl-bbs/markup:format-text "```common-lisp
(format t \"Hello\")
```"))
  ;; Issue #17 URL tests (colons and semicolons in URL)
  (is equal (concatenate 'string
                         "<p>Check <a href=\"https://encrypted-tbn0.gstatic.com/"
                         "images?q=tbn:ANd9GcQL--f01xIZCRt7R0w6xxdR5v76IRrZ"
                         "Imu6OCETYL01n0J0fx4cFud3Y4gY&amp;s=10\" target="
                         "\"_blank\">https://encrypted-tbn0.gstatic.com/"
                         "images?q=tbn:ANd9GcQL--f01xIZCRt7R0w6xxdR5v76IRrZ"
                         "Imu6OCETYL01n0J0fx4cFud3Y4gY&amp;s=10</a></p>")
      (cl-bbs/markup:format-text
       (concatenate 'string
                    "Check https://encrypted-tbn0.gstatic.com/"
                    "images?q=tbn:ANd9GcQL--"
                    "f01xIZCRt7R0w6xxdR5v76IR"
                    "rZImu6OCETYL01n0J0"
                    "fx4cFud3Y4gY&s=10")))
  (is equal (concatenate 'string
                         "<p>Check <a href=\"https://www.reddit.com/r/"
                         "Common_Lisp/comments/1pqghsx/comment/nuvmq9z/?"
                         "utm_source=share&amp;;utm_medium=mweb3x&amp;"
                         "utm_name=mweb3xcss&amp;utm_term=2&amp;"
                         "utm_content=share_button\" target=\"_blank\">"
                         "https://www.reddit.com/r/Common_Lisp/"
                         "comments/1pqghsx/comment/nuvmq9z/?"
                         "utm_source=share&amp;;utm_medium=mweb3x&amp;"
                         "utm_name=mweb3xcss&amp;utm_term=2&amp;"
                         "utm_content=share_button</a></p>")
      (cl-bbs/markup:format-text
       (concatenate 'string
                    "Check https://www.reddit.com/r/"
                    "Common_Lisp/comments/1pqghsx/"
                    "comment/nuvmq9z/?utm_source=share&;"
                    "utm_medium=mweb3x&"
                    "utm_name=mweb3xcss&"
                    "utm_term=2&"
                    "utm_content=share_button"))))
