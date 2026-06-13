(defpackage :cl-bbs/views
  (:use :cl)
  (:import-from :cl-who
                #:with-html-output-to-string
                #:htm
                #:str
                #:esc
                #:fmt)
  (:export #:render-index
           #:render-list
           #:render-thread
           #:render-preferences
           #:render-moderation
           #:render-error-page))

(in-package :cl-bbs/views)

(defun get-hash-hue (id-val)
  (let ((id-num (cond ((integerp id-val) id-val)
                      ((stringp id-val) (or (handler-case (parse-integer id-val :junk-allowed t)
                                              (error () nil))
                                            0))
                      (t 0))))
    (mod (* id-num 137) 360)))

(defmacro layout (title class theme &body body)
  `(cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>" :indent t)
     (:html
      (:head
       (:meta :charset "utf-8")
       (:meta :name "viewport" :content "width=device-width, initial-scale=1.0")
       (:title (cl-who:esc ,title))
       (:link :rel "manifest" :href "/manifest.json")
       (:link :rel "icon" :href "/static/favicon.ico" :type "image/png")
       (:link :rel "stylesheet" :href (format nil "/static/styles/themes/~a.css" (or ,theme "default")) :type "text/css")
       (:script "if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js');
  });
}")
       (:script "
function validatePostForm(form, errorId) {
  const content = form.epistula.value.trim();
  const errorEl = document.getElementById(errorId);
  if (!content) {
    if (errorEl) {
      errorEl.textContent = 'Post body cannot be empty!';
      errorEl.style.display = 'block';
    } else {
      alert('Post body cannot be empty!');
    }
    return false;
  }
  if (errorEl) {
    errorEl.style.display = 'none';
  }
  return true;
}
"))
      (:body :class ,class
             (cl-who:str (render-boards-header))
             (:hr)
             (cl-who:str (progn ,@body))))))

(defun render-error-page (error-message &optional theme)
  "Renders an HTML error page displaying the given ERROR-MESSAGE, using the specified layout THEME."
  (layout "Error - SchemeBBS" "error-page" theme
    (cl-who:with-html-output-to-string (s nil :indent t)
      (:h1 "Error")
      (:hr)
      (:div :class "error-container"
            (:p :class "error-title" (cl-who:esc error-message))
            (:p "We were unable to process your post because it does not meet the validation requirements.")
            (:p (:button :class "error-back-button" :onclick "history.back();" "← Go Back and Edit Post")))
      (:hr)
      (:p :class "footer" "SchemeBBS Common Lisp port"))))

(defun render-boards-header ()
  (let* ((sexp-dir (merge-pathnames "sexp/" cl-bbs/storage:*base-dir*))
         (paths (and (probe-file sexp-dir) (uiop:subdirectories sexp-dir)))
         (boards (sort (mapcar (lambda (path)
                                 (car (last (pathname-directory path))))
                               paths)
                       #'string<)))
    (cl-who:with-html-output-to-string (s nil :indent t)
      (:p :class "boards" :style "text-align: left; font-size: 0.9em; margin: 0.5em 2% 1em 2%;"
          "[ "
          (loop for board in boards
                for i from 0
                unless (zerop i)
                do (cl-who:str " | ")
                do (cl-who:htm (:a :href (format nil "/~a/" board) (cl-who:esc board))))
          " ]"))))

(defun render-menu (board selected)
  (cl-who:with-html-output-to-string (s nil :indent t)
    (:p :class "nav"
        (if (string= selected "frontpage")
            (cl-who:str "frontpage")
            (cl-who:htm (:a :href (format nil "/~a" board) "frontpage")))
        " - "
        (if (string= selected "thread list")
            (cl-who:str "thread list")
            (cl-who:htm (:a :href (format nil "/~a/list" board) "thread list")))
        " - "
        (if (string= selected "frontpage")
            (cl-who:htm (:a :href "#newthread" "new thread"))
            (cl-who:htm (:a :href (format nil "/~a#newthread" board) "new thread")))
        " - "
        (:a :href (format nil "/~a/preferences" board) "preferences")
        " - "
        (:a :href "/" "?"))))

(defun render-thread-form (board)
  (cl-who:with-html-output-to-string (s nil :indent t)
    (:div :class "newthread-form"
          (:h2 :id "newthread" "New thread")
          (:p :id "newthread-error" :style "color: red; font-weight: bold; display: none;")
          (:form :action (format nil "/~a/post" board)
                 :method "POST"
                 :onsubmit "return validatePostForm(this, 'newthread-error');"
                 (:p (:input :type "text" :name "titulus" :size 35 :placeholder "Headline"))
                 (:p (:textarea :name "epistula"
                                :rows 5
                                :cols 50
                                :placeholder "Message"
                                :onkeydown "if(event.ctrlKey && event.key === 'Enter') {
  if (validatePostForm(this.form, 'newthread-error')) {
    this.form.submit();
  }
}"))
                 (:p (:input :type "text" :name "name" :style "display:none")
                     (:input :type "text" :name "message" :style "display:none")
                     (:input :type "submit" :value "Post"))))))

(defun format-text (text &optional thread-id)
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
           "https?://[\\w\\-\\.\\/\\?\\=\\&\\%\\#\\+]+"
           processed
           "<a href=\"\\&\" target=\"_blank\">\\&</a>"))
    (setf processed
          (cl-ppcre:regex-replace-all
           (concatenate 'string
                        "<a href=\"(https?://[\\w\\-\\.\\/\\?\\=\\&\\%\\#\\+]+"
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
           "image\\+<a href=\"(https?://[\\w\\-\\.\\/\\?\\=\\&\\%\\#\\+]+)\" target=\"_blank\">.*?</a>"
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
                 (format nil "</p><pre>~a</pre><p>" content))
               :simple-calls t))))
    (setf processed
          (cl-ppcre:regex-replace-all
           "<p>\\s*</p>"
           processed
           ""))
    processed))

(defun render-post-form (board thread-id)
  (let ((error-id (format nil "reply-error-~a" thread-id)))
    (cl-who:with-html-output-to-string (s nil :indent t)
      (:p :id error-id :style "color: red; font-weight: bold; display: none;")
      (:form :action (format nil "/~a/~a/post" board thread-id)
             :method "POST"
             :onsubmit (format nil "return validatePostForm(this, '~a');" error-id)
             (:p (:textarea :name "epistula"
                            :rows 8
                            :cols 78
                            :placeholder "Message"
                            :onkeydown (format nil "if(event.ctrlKey && event.key === 'Enter') {
  if (validatePostForm(this.form, '~a')) {
    this.form.submit();
  }
}" error-id))
                 (:br)
                 (:input :type "text" :name "name" :class "name" :style "display:none")
                 (:input :type "text" :name "message" :class "message" :style "display:none")
                 (:input :type "submit" :value "POST"))))))

(defun render-frontpage-thread (board thread-data index &optional theme)
  (let* ((thread-id (car thread-data))
         (props (cdr thread-data))
         (headline (cdr (assoc 'cl-bbs/models:headline props)))
         (posts (second (assoc 'cl-bbs/models:posts props)))
         (next-post-number (if posts (1+ (reduce #'max posts :key #'car :initial-value 0)) 1))
         (truncated (cdr (assoc 'cl-bbs/models:truncated props))))
    (declare (ignore truncated))
    (cl-who:with-html-output-to-string (s nil :indent t)
      (:pre :class "jump"
            (:a :id (format nil "d~a" index)
                :href (if (= index 10) "#d1" (format nil "#d~a" (1+ index))) "↓")
            (cl-who:str "&nbsp;"))
      (let ((heading-style (if (string= theme "colored")
                               (format nil (concatenate 'string
                                                        "border-left: 5px solid hsl(~D, 80%, 45%); "
                                                        "padding-left: 10px; margin-left: 2%;")
                                       (get-hash-hue thread-id))
                               "")))
        (cl-who:htm
         (:h2 :style heading-style
              (:a :href (format nil "/~a/~a" board thread-id) (cl-who:esc headline)))))
      (:dl
       (loop for post in posts
             for post-id = (car post)
             for post-data = (cdr post)
             for content = (cdr (assoc 'cl-bbs/models:content post-data))
             for date = (cdr (assoc 'cl-bbs/models:date post-data))
             do (let ((post-style (if (string= theme "colored")
                                      (let ((hue (get-hash-hue post-id)))
                                        (format nil (concatenate 'string
                                                                 "background-color: hsl(~D, 85%, 96%); "
                                                                 "border-left: 4px solid hsl(~D, 85%, 45%); "
                                                                 "padding: 0.5em 1em; "
                                                                 "margin: 0.3em 2% 1.2em 2%; "
                                                                 "border-radius: 0 4px 4px 0;")
                                                hue hue))
                                      "")))
                  (cl-who:htm
                   (:dt (:a :href (format nil "/~a/~a#t~ap~a" board thread-id thread-id post-id)
                            :id (format nil "t~ap~a" thread-id post-id)
                            (cl-who:str (format nil "~a" post-id)))
                        " "
                        (:samp (cl-who:esc date)))
                   (:dd :style post-style (cl-who:str (format-text content thread-id))))))
       (:dt (:a :href (format nil "#t~ap~a" thread-id next-post-number)
                :id (format nil "t~ap~a" thread-id next-post-number)
                (cl-who:str (format nil "~a" next-post-number))))
       (:dd (cl-who:str (render-post-form board thread-id))))
      (:hr))))

(defun render-index (board threads &optional theme)
  "Renders the board index (frontpage) HTML with the list of active THREADS
and the new thread form, using layout THEME."
  (layout (format nil "/~a/ - SchemeBBS" board) nil theme
    (cl-who:with-html-output-to-string (s nil :indent t)
      (:h1 (cl-who:esc board))
      (cl-who:str (render-menu board "frontpage"))
      (:hr)
      (loop for t-data in threads
            for i from 1
            do (cl-who:htm (cl-who:str (render-frontpage-thread board t-data i theme))))
      (cl-who:str (render-thread-form board))
      (:hr)
      (:p :class "footer" "SchemeBBS Common Lisp port"))))

(defun render-list (board threads &optional theme)
  "Renders the board thread-list HTML page, showing all THREADS in tabular format, using layout THEME."
  (layout (format nil "/~a/ - SchemeBBS" board) nil theme
    (cl-who:with-html-output-to-string (s nil :indent t)
      (:h1 (cl-who:esc board))
      (cl-who:str (render-menu board "thread list"))
      (:hr)
      (:table :summary "Thread list"
              (:thead (:tr (:th "#") (:th "headline") (:th "posts") (:th "last update")))
              (:tbody
               (loop for t-data in threads
                     for i from 1
                     do (let* ((thread-id (car t-data))
                               (props (cdr t-data))
                               (headline (cdr (assoc 'cl-bbs/models:headline props)))
                               (messages (cdr (assoc 'cl-bbs/models:messages props)))
                               (date (cdr (assoc 'cl-bbs/models:date props))))
                          (cl-who:htm
                           (:tr (:td (cl-who:str (format nil "~a" i)))
                                (:td (:a :href (format nil "/~a/~a" board thread-id) (cl-who:esc headline)))
                                (:td (cl-who:str (format nil "~a" messages)))
                                (:td (:samp (cl-who:esc date)))))))))
      (:hr)
      (:p :class "footer" "SchemeBBS Common Lisp port"))))

(defun render-thread (board thread-id thread-data &optional range-string theme)
  "Renders a single thread page HTML for THREAD-ID under BOARD with THREAD-DATA (comments),
optionally filtered by RANGE-STRING, using layout THEME."
  (let* ((raw-thread (if (and (consp thread-data)
                             (consp (car thread-data))
                             (consp (caar thread-data)))
                         (car thread-data)
                         thread-data))
         (headline (if (consp (car raw-thread))
                       (cdr (assoc 'cl-bbs/models:headline raw-thread))
                       (cdr (assoc 'cl-bbs/models:headline (list raw-thread)))))
         (posts-assoc (if (consp (car raw-thread)) (assoc 'cl-bbs/models:posts raw-thread) (cadr thread-data)))
         (posts-list (if (and posts-assoc (listp (cdr posts-assoc)) (not (keywordp (cdr posts-assoc))))
                         (if (listp (cadr posts-assoc)) (cadr posts-assoc) (cdr posts-assoc))
                         (cdr posts-assoc)))
         (posts (if (listp (car posts-list)) posts-list (list posts-list)))
         (next-post-number (if posts (1+ (reduce #'max posts :key #'car :initial-value 0)) 1))
         (filter-func (if (and range-string (string/= range-string ""))
                          (let ((allowed-ids (make-hash-table :test #'eql)))
                            (dolist (part (cl-ppcre:split "," range-string))
                              (let ((subparts (cl-ppcre:split "-" part)))
                                (cond
                                  ((= (length subparts) 1)
                                   (let ((id (parse-integer (first subparts) :junk-allowed t)))
                                     (when id
                                       (setf (gethash id allowed-ids) t))))
                                  ((= (length subparts) 2)
                                   (let ((start (parse-integer (first subparts) :junk-allowed t))
                                         (end (parse-integer (second subparts) :junk-allowed t)))
                                     (when (and start end (<= start end))
                                       (loop for id from start to end
                                             do (setf (gethash id allowed-ids) t))))))))
                            (lambda (id) (gethash id allowed-ids)))
                          (lambda (id) (declare (ignore id)) t))))
    (layout (format nil "/~a/ - SchemeBBS" board) "thread" theme
      (cl-who:with-html-output-to-string (s nil :indent t)
        (:h1 (cl-who:esc board))
        (cl-who:str (render-menu board "thread"))
        (:hr)
        (let ((heading-style (if (string= theme "colored")
                                 (format nil "border-left: 5px solid hsl(~D, 80%, 45%); padding-left: 10px;"
                                         (get-hash-hue thread-id))
                                 "")))
          (cl-who:htm
           (:h2 :style heading-style (cl-who:esc headline))))
        (:dl
         (loop for post in posts
               for post-id = (car post)
               for post-data = (cdr post)
               for content = (cdr (assoc 'cl-bbs/models:content post-data))
               for date = (cdr (assoc 'cl-bbs/models:date post-data))
               when (funcall filter-func post-id)
               do (let ((post-style (if (string= theme "colored")
                                        (let ((hue (get-hash-hue post-id)))
                                          (format nil (concatenate 'string
                                                                   "background-color: hsl(~D, 85%, 96%); "
                                                                   "border-left: 4px solid hsl(~D, 85%, 45%); "
                                                                   "padding: 0.5em 1em; margin: 0.3em 0 1.2em 0; "
                                                                   "border-radius: 0 4px 4px 0;")
                                                      hue hue))
                                        "")))
                    (cl-who:htm
                     (:dt (:a :href (format nil "/~a/~a#t~ap~a" board thread-id thread-id post-id)
                              :id (format nil "t~ap~a" thread-id post-id)
                              (cl-who:str (format nil "~a" post-id)))
                          " "
                          (:samp (cl-who:esc date)))
                     (:dd :style post-style (cl-who:str (format-text content thread-id))))))
         (:dt (:a :href (format nil "#t~ap~a" thread-id next-post-number)
                  :id (format nil "t~ap~a" thread-id next-post-number)
                  (cl-who:str (format nil "~a" next-post-number))))
         (:dd (cl-who:str (render-post-form board thread-id))))
        (:hr)
        (:p :class "footer" "SchemeBBS Common Lisp port")))))

(defun render-preferences (board &optional theme)
  "Renders the board preferences HTML page, allowing users to choose a custom stylesheet THEME."
  (layout (format nil "/~a/ - Preferences" board) "preferences" theme
    (cl-who:with-html-output-to-string (s nil :indent t)
      (:h1 (cl-who:esc board))
      (cl-who:str (render-menu board "preferences"))
      (:hr)
      (:h2 "Preferences")
      (:form :action (format nil "/~a/preferences" board) :method "POST" :class "preferences-form"
             (:p :class "theme-options-title" "Choose theme:")
             (:div :class "theme-selector-container"
                   (dolist (item '("default" "dark" "no" "colored" "matrix"))
                     (cl-who:htm
                      (:label :class "theme-option-label"
                              (:input :type "radio"
                                      :name "theme"
                                      :value item
                                      :checked (and theme (string= theme item))
                                      :onchange "updateThemePreview(this.value)")
                              (:span :class "theme-option-text" (cl-who:str item))))))
             (:p (:input :type "submit" :value "Save Preferences")))
      (:script "
function updateThemePreview(themeValue) {
  // Find all stylesheet links
  const links = document.querySelectorAll('link[rel=\"stylesheet\"]');
  for (const link of links) {
    if (link.href.includes('/static/styles/themes/')) {
      link.href = '/static/styles/themes/' + themeValue + '.css';
    }
  }
}
")
      (:hr)
      (:p :class "footer" "SchemeBBS Common Lisp port"))))

(defun render-moderation (boards &optional board threads thread comments theme headline)
  "Renders the admin/moderation control panel HTML page showing BOARDS and allowing deletions/edits."
  (layout "cl-bbs Moderation Panel" "moderation" theme
    (cl-who:with-html-output-to-string (s nil :indent t)
      (:h1 "Moderation Panel")
      (:p (:a :href "/" "Back to Home"))
      (:hr)
      (:h2 "Boards")
      (:ul
       (dolist (b boards)
         (cl-who:htm
          (:li (:strong (:a :href (format nil "/admin?board=~a" b) (cl-who:esc b)))
               " &nbsp; "
               (:form :action "/admin/action" :method "POST" :style "display:inline;"
                      (:input :type "hidden" :name "action" :value "delete-board")
                      (:input :type "hidden" :name "board" :value b)
                      (:input :type "submit" :value "Delete Board" :class "delete-button"
                              :onclick (concatenate 'string
                                                    "return confirm('Are you sure you want to delete the ENTIRE board? "
                                                    "This cannot be undone.');")))))))
      (when board
        (cl-who:htm
         (:hr)
         (:h2 (cl-who:fmt "Threads in /~a/" board))
         (if threads
             (cl-who:htm
              (:table :border 1 :cellpadding 5
                      (:thead (:tr (:th "ID") (:th "Headline") (:th "Date") (:th "Actions")))
                      (:tbody
                       (dolist (t-data threads)
                         (let* ((tid (car t-data))
                                (props (cdr t-data))
                                (headline (cdr (assoc 'cl-bbs/models:headline props))))
                           (cl-who:htm
                            (:tr (:td (cl-who:str (format nil "~a" tid)))
                                 (:td (:a :href (format nil "/admin?board=~a&thread=~a" board tid)
                                          (cl-who:esc headline)))
                                 (:td (cl-who:str (format nil "~a" (cdr (assoc 'cl-bbs/models:date props)))))
                                 (:td (:form :action "/admin/action" :method "POST" :style "display:inline;"
                                             (:input :type "hidden" :name "action" :value "delete-thread")
                                             (:input :type "hidden" :name "board" :value board)
                                             (:input :type "hidden" :name "thread" :value tid)
                                             (:input :type "submit" :value "Delete Thread" :class "delete-button"
                                                     :onclick (concatenate 'string
                                                                           "return confirm('Are you sure you want "
                                                                           "to delete this thread?');")))))))))))
             (cl-who:htm (:p "No threads found on this board.")))))
      (when (and board thread)
        (cl-who:htm
         (:hr)
         (:h2 (cl-who:fmt "Comments in Thread #~a (~a)" thread board))
         (if comments
             (cl-who:htm
              (:dl
               (dolist (p comments)
                 (let* ((pid (car p))
                        (pdata (cdr p))
                        (content (cdr (assoc 'cl-bbs/models:content pdata)))
                        (date (cdr (assoc 'cl-bbs/models:date pdata))))
                   (cl-who:htm
                    (:dt "No." (cl-who:str (format nil "~a" pid)) " " (:samp (cl-who:esc date))
                         " &nbsp; "
                         (:form :action "/admin/action" :method "POST" :style "display:inline;"
                                (:input :type "hidden" :name "action" :value "delete-comment")
                                (:input :type "hidden" :name "board" :value board)
                                (:input :type "hidden" :name "thread" :value thread)
                                (:input :type "hidden" :name "comment" :value pid)
                                (:input :type "submit" :value "Delete Comment" :class "delete-button"
                                        :onclick "return confirm('Are you sure you want to delete this comment?');")))
                    (:dd
                     (:div :class "comment-preview"
                           (cl-who:str (format-text content thread)))
                     (:form :action "/admin/action" :method "POST" :style "margin-top: 0.5em;"
                            (:input :type "hidden" :name "action" :value "edit-comment")
                            (:input :type "hidden" :name "board" :value board)
                            (:input :type "hidden" :name "thread" :value thread)
                            (:input :type "hidden" :name "comment" :value pid)
                            (when (and (= pid 1) headline)
                              (cl-who:htm
                               (:p (:label :for "headline" "Thread Headline: ")
                                   (:br)
                                   (:input :type "text" :name "headline" :id "headline" :size 60 :value headline))))
                            (:textarea :name "content" :rows 3 :cols 60 (cl-who:str content))
                            (:br)
                            (:input :type "submit" :value "Save Changes"))))))))
             (cl-who:htm (:p "No comments found."))))))))
