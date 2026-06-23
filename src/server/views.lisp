(defpackage :cl-bbs/views
  (:use :cl)
  (:import-from :cl-who
                #:with-html-output-to-string
                #:htm
                #:str
                #:esc
                #:fmt)
  (:import-from :cl-bbs/storage
                #:is-board-locked)
  (:export #:render-index
           #:render-list
           #:render-thread
           #:render-preferences
           #:render-moderation
           #:render-error-page
           #:render-search-results
           #:render-playground
           #:preferences
           #:make-preferences
           #:preferences-theme
           #:preferences-default-board
           #:preferences-search-hide-input
           #:preferences-search-local-only
           #:preferences-search-position
           #:*preferences*))

(in-package :cl-bbs/views)

(defstruct preferences
  (theme "default")
  (default-board "")
  (search-hide-input "no")
  (search-local-only "no")
  (search-position "top"))

(defvar *preferences* (make-preferences))

(defun get-git-commit-hash ()
  "Gets the git commit hash from environmental dynamics (APP_COMMIT_HASH) with a fallback to uiop:run-program."
  (let ((env-hash (uiop:getenv "APP_COMMIT_HASH")))
    (if (and env-hash (string/= env-hash ""))
        env-hash
        (or (handler-case
                (string-trim '(#\Space #\Tab #\Newline #\Return)
                             (uiop:run-program '("git" "rev-parse" "--short" "HEAD")
                                               :output :string))
              (error () nil))
            "unknown"))))

(defun render-footer-html ()
  "Renders the common footer HTML with cl-bbs version hash and a GitHub link."
  (let ((hash (get-git-commit-hash)))
    (cl-who:with-html-output-to-string (s nil :indent t)
      (:p :class "footer"
          "cl-bbs version:"
          (:a :href (format nil "https://github.com/ryukinix/cl-bbs/commit/~a" hash)
              :target "_blank"
              (cl-who:esc hash))))))

(defun render-board-name (board)
  (cl-who:with-html-output-to-string (s nil :indent t)
    (:h1
     (cl-who:esc
      (if (is-board-locked board)
          (concatenate 'string board " 🔒")
          board)))))

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
       (:link :rel "stylesheet"
              :href (format nil "/static/styles/themes/~a.css" (or ,theme "default"))
              :type "text/css")
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
")
       (:script :src "/static/jscl-snippets.js" :defer t))
      (:body :class ,class
             (cl-who:str (render-boards-header))
             (:hr)
             (cl-who:str (progn ,@body))
             (when (show-search-at-bottom-p)
               (cl-who:htm
                (:hr)
                (cl-who:str (render-search-form))))))))

(defun render-error-page (error-message &optional (prefs *preferences*))
  "Renders an HTML error page displaying the given ERROR-MESSAGE, using the specified layout PREFS."
  (layout "Error - SchemeBBS" "error-page" (preferences-theme prefs)
    (cl-who:with-html-output-to-string (s nil :indent t)
      (:h1 "Error")
      (:hr)
      (:div :class "error-container"
            (:p :class "error-title" (cl-who:esc error-message))
            (:p "We were unable to process your post because it does not meet the validation requirements.")
            (:p (:button :class "error-back-button" :onclick "history.back();" "← Go Back and Edit Post")))
      (:hr)
      (cl-who:str (render-footer-html)))))

(defun board-view-p (path)
  "Checks if the given PATH represents a board-specific view."
  (and path
       (string/= path "/")
       (string/= path "/index.html")
       (not (uiop:string-prefix-p "/search" path))
       (not (uiop:string-prefix-p "/admin" path))
       (not (uiop:string-prefix-p "/about" path))
       (not (uiop:string-prefix-p "/sw.js" path))
       (not (uiop:string-prefix-p "/manifest.json" path))
       (not (uiop:string-prefix-p "/playground" path))))

(defun get-current-board-from-path (path)
  "Extracts the board name from the request PATH."
  (when (and path (string/= path "") (char= (char path 0) #\/))
    (let ((parts (cl-ppcre:split "/" path)))
      (when (>= (length parts) 2)
        (let ((b (second parts)))
          (and (string/= b "") b))))))

(defun show-search-at-top-p ()
  "Determines whether the search form should be rendered at the top header."
  (let* ((env (and (boundp 'ningle:*request*) ningle:*request* (lack.request:request-env ningle:*request*)))
         (path (and env (getf env :path-info)))
         (is-board (board-view-p path)))
    (and (not (and is-board (string= (preferences-search-hide-input *preferences*) "yes")))
         (string= (preferences-search-position *preferences*) "top"))))

(defun show-search-at-bottom-p ()
  "Determines whether the search form should be rendered at the bottom of the page."
  (and (not (string= (preferences-search-hide-input *preferences*) "yes"))
       (string= (preferences-search-position *preferences*) "bottom")))

(defun render-search-form ()
  "Renders the search form as a standalone block, with board filter if local search is configured."
  (let* ((env (and (boundp 'ningle:*request*) ningle:*request* (lack.request:request-env ningle:*request*)))
         (path (and env (getf env :path-info)))
         (board (and (board-view-p path) (get-current-board-from-path path))))
    (cl-who:with-html-output-to-string (s nil :indent t)
      (:form :action "/search" :method "GET" :style "margin: 1em 2%; display: inline-flex;"
             (when (and (string= (preferences-search-local-only *preferences*) "yes") board)
               (cl-who:htm (:input :type "hidden" :name "board" :value board)))
             (:input :type "text" :name "q" :placeholder "Search posts..."
                     :style "padding: 2px 5px; font-size: 0.85em; margin-right: 5px;")
             (:input :type "submit" :value "Search" :style "padding: 2px 8px; font-size: 0.85em;")))))

(defun render-boards-header ()
  (let* ((sexp-dir (merge-pathnames "sexp/" cl-bbs/storage:*base-dir*))
         (paths (and (probe-file sexp-dir) (uiop:subdirectories sexp-dir)))
         (boards (sort (mapcar (lambda (path)
                                 (car (last (pathname-directory path))))
                               paths)
                       #'string<))
         (env (and (boundp 'ningle:*request*) ningle:*request* (lack.request:request-env ningle:*request*)))
         (path (and env (getf env :path-info)))
         (board (and (board-view-p path) (get-current-board-from-path path))))
    (cl-who:with-html-output-to-string (s nil :indent t)
      (:div :style "display: flex; justify-content: space-between; align-items: center; margin: 0.5em 2% 1em 2%;"
            (:p :class "boards" :style "font-size: 0.9em; margin: 0;"
                "[ "
                (loop for board in boards
                      for i from 0
                      unless (zerop i)
                      do (cl-who:str " | ")
                      do (cl-who:htm (:a :href (format nil "/~a/" board) (cl-who:esc board))))
                " ]")
            (when (show-search-at-top-p)
              (cl-who:htm
               (:form :action "/search" :method "GET" :style "margin: 0; display: inline-flex;"
                      (when (and (string= (preferences-search-local-only *preferences*) "yes") board)
                        (cl-who:htm (:input :type "hidden" :name "board" :value board)))
                      (:input :type "text" :name "q" :placeholder "Search posts..."
                     :style "padding: 2px 5px; font-size: 0.85em; margin-right: 5px;")
                      (:input :type "submit" :value "Search" :style "padding: 2px 8px; font-size: 0.85em;"))))))))

(defun render-menu (board selected)
  (cl-who:with-html-output-to-string (s nil :indent t)
    (:p :class "nav"
        (if (string= selected "front")
            (cl-who:str "front")
            (cl-who:htm (:a :href (format nil "/~a" board) "front")))
        " - "
        (if (string= selected "list")
            (cl-who:str "list")
            (cl-who:htm (:a :href (format nil "/~a/list" board) "list")))
        " - "
        (if (string= selected "front")
            (cl-who:htm (:a :href "#newthread" "new"))
            (cl-who:htm (:a :href (format nil "/~a#newthread" board) "new")))
        " - "
        (:a :href (format nil "/~a/preferences" board) "preferences")
        " - "
        (if (string= selected "playground")
            (cl-who:str "λ")
            (cl-who:htm (:a :href (format nil "/~a/playground" board) "λ")))
        " - "
        (:a :href "/index.html" "?"))))

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

(defun unescape-html (string)
  (let ((s string))
    (setf s (cl-ppcre:regex-replace-all "&quot;" s "\""))
    (setf s (cl-ppcre:regex-replace-all "&lt;" s "<"))
    (setf s (cl-ppcre:regex-replace-all "&gt;" s ">"))
    (setf s (cl-ppcre:regex-replace-all "&#39;" s "'"))
    (setf s (cl-ppcre:regex-replace-all "&amp;" s "&"))
    s))

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
                 (multiple-value-bind (match-start match-end reg-starts reg-ends)
                     (cl-ppcre:scan "^(?i)(lisp|cl|common-lisp)\\r?\\n" content)
                   (declare (ignore reg-starts reg-ends))
                   (if match-start
                       (let* ((escaped-code (subseq content match-end))
                              (raw-code (unescape-html escaped-code))
                              (colorized-code (handler-case (colorize:html-colorization :common-lisp raw-code)
                                                (error () (cl-who:escape-string raw-code)))))
                         ;; Note: colorize already wraps the result in <span class="..."><span class="paren1">...</span></span>
                         ;; We wrap it in <pre class="lisp-code-block"> but keep a data-raw-code attribute or just use content for JS execution.
                         ;; JSCL needs the raw text. To avoid JSCL trying to parse HTML, we'll embed the raw code in a hidden div,
                         ;; or rely on JS `textContent` which extracts raw text from nested HTML elements. `textContent` works well.
                         (format nil "</p><pre class=\"lisp-code-block\">~a</pre><p>" colorized-code))
                       (format nil "</p><pre>~a</pre><p>" content))))
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

(defun render-frontpage-thread (board thread-data index &optional (prefs *preferences*))
  (let* ((thread-id (car thread-data))
         (props (cdr thread-data))
         (headline (cdr (assoc 'cl-bbs/models:headline props)))
         (posts (second (assoc 'cl-bbs/models:posts props)))
         (next-post-number (if posts (1+ (reduce #'max posts :key #'car :initial-value 0)) 1))
         (truncated (cdr (assoc 'cl-bbs/models:truncated props)))
         (theme (preferences-theme prefs)))
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
       (let ((prev-id nil))
         (dolist (post posts)
           (let* ((post-id (car post))
                  (post-data (cdr post))
                  (content (cdr (assoc 'cl-bbs/models:content post-data)))
                  (date (cdr (assoc 'cl-bbs/models:date post-data))))
             (when (and prev-id (> post-id (1+ prev-id)))
               ;; Instead of hard assumption based just on IDs, actually check via truncated list if
               ;; the missing IDs are meant to be rendered as collapsed (i.e. they actually exist in the background).
               ;; Find the maximum contiguous subsegment of truncated IDs bridging prev-id and post-id.
               (let* ((missing-ids (loop for id from (1+ prev-id) to (1- post-id) collect id))
                      (actual-missing (if (listp truncated)
                                          (remove-if-not (lambda (id) (member id truncated)) missing-ids)
                                          missing-ids)))
                 (when (>= (length actual-missing) 2)
                   (let ((fst (car actual-missing))
                         (lst (car (last actual-missing))))
                     (cl-who:htm
                      (:dt :class "collapsed" :style "margin: 0.5em 2%; margin-left: 0; padding-left: 0;"
                           (:a :href (format nil "/~a/~a#t~ap~a" board thread-id thread-id fst)
                               (cl-who:str (format nil "~D" fst)))
                           (when (> lst fst)
                             (cl-who:htm
                              (cl-who:str "...")
                              (:a :href (format nil "/~a/~a#t~ap~a" board thread-id thread-id lst)
                                  (cl-who:str (format nil "~D" lst)))))))))))
             (setf prev-id post-id)
             (let ((post-style (if (string= theme "colored")
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
                (:dt :style "margin: 0.5em 2%; margin-left: 0; padding-left: 0;"
                     (:a :href (format nil "/~a/~a#t~ap~a" board thread-id thread-id post-id)
                         :id (format nil "t~ap~a" thread-id post-id)
                         (cl-who:str (format nil "~a" post-id)))
                     " "
                     (:samp (cl-who:esc date)))
                (:dd :style post-style (cl-who:str (format-text content thread-id))))))))
       (unless (is-board-locked board)
         (cl-who:htm
          (:dt :style "margin: 0.5em 2%; margin-left: 0; padding-left: 0;"
               (:a :href (format nil "#t~ap~a" thread-id next-post-number)
                   :id (format nil "t~ap~a" thread-id next-post-number)
                   (cl-who:str (format nil "~a" next-post-number))))
          (:dd (cl-who:str (render-post-form board thread-id))))))
      (:hr))))

(defun render-index (board threads &optional (prefs *preferences*))
  "Renders the board index (frontpage) HTML with the list of active THREADS
and the new thread form, using layout PREFS."
  (layout (format nil "/~a/ - SchemeBBS" board) nil (preferences-theme prefs)
    (cl-who:with-html-output-to-string (s nil :indent t)
      (cl-who:str (render-board-name board))
      (cl-who:str (render-menu board "front"))
      (:hr)
      (loop for t-data in threads
            for i from 1
            do (cl-who:htm (cl-who:str (render-frontpage-thread board t-data i prefs))))
      (unless (is-board-locked board)
        (cl-who:htm (cl-who:str (render-thread-form board))))
      (:hr)
      (cl-who:str (render-footer-html)))))

(defun render-list (board threads &optional (prefs *preferences*))
  "Renders the board thread-list HTML page, showing all THREADS in tabular format, using layout PREFS."
  (layout (format nil "/~a/ - SchemeBBS" board) nil (preferences-theme prefs)
    (cl-who:with-html-output-to-string (s nil :indent t)
      (cl-who:str (render-board-name board))
      (cl-who:str (render-menu board "list"))
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
      (cl-who:str (render-footer-html)))))

(defun render-thread (board thread-id thread-data &optional range-string (prefs *preferences*))
  "Renders a single thread page HTML for THREAD-ID under BOARD with THREAD-DATA (comments),
optionally filtered by RANGE-STRING, using layout PREFS."
  (let* ((theme (preferences-theme prefs))
         (raw-thread (if (and (consp thread-data)
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
        (cl-who:str (render-board-name board))
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
         (unless (is-board-locked board)
           (cl-who:htm
            (:dt (:a :href (format nil "#t~ap~a" thread-id next-post-number)
                     :id (format nil "t~ap~a" thread-id next-post-number)
                     (cl-who:str (format nil "~a" next-post-number))))
            (:dd (cl-who:str (render-post-form board thread-id))))))
        (:hr)
        (cl-who:str (render-footer-html))))))

(defun render-preferences (board &optional (prefs *preferences*))
  "Renders the board preferences HTML page, allowing users to choose a custom
stylesheet THEME, default-board and search configuration."
  (let* ((sexp-dir (merge-pathnames "sexp/" cl-bbs/storage:*base-dir*))
         (paths (and (probe-file sexp-dir) (uiop:subdirectories sexp-dir)))
         (boards (sort (mapcar (lambda (path)
                                 (car (last (pathname-directory path))))
                               paths)
                       #'string<))
         (theme (preferences-theme prefs))
         (default-board (preferences-default-board prefs))
         (search-hide-input (preferences-search-hide-input prefs))
         (search-local-only (preferences-search-local-only prefs))
         (search-position (preferences-search-position prefs)))
    (layout (format nil "/~a/ - Preferences" board) "preferences" theme
      (cl-who:with-html-output-to-string (s nil :indent t)
        (cl-who:str (render-board-name board))
        (cl-who:str (render-menu board "preferences"))
        (:hr)
        (:h2 "Preferences")
        (:form :action (format nil "/~a/preferences" board) :method "POST" :class "preferences-form"
               (:div :style "margin-bottom: 2em;"
                     (:h3 :style "margin-bottom: 0.5em;" "Style Theme")
                     (:p :style "color: #555; font-size: 0.9em; margin-bottom: 0.8em;"
                         "Customize the look and feel of the textboard.")
                     (:div :class "theme-selector-container"
                           (dolist (item '("default" "dark" "no" "colored" "matrix"))
                             (cl-who:htm
                              (:label :class "theme-option-label" :style "margin-right: 15px;"
                                      (:input :type "radio"
                                              :name "theme"
                                              :value item
                                              :checked (and theme (string= theme item))
                                              :onchange "updateThemePreview(this.value)")
                                      (:span :class "theme-option-text" (cl-who:str item)))))))

               (:div :style "margin-bottom: 2em;"
                     (:h3 :style "margin-bottom: 0.5em;" "Default Board")
                     (:p :style "color: #555; font-size: 0.9em; margin-bottom: 0.8em;"
                         "Select the board you land on when visiting the root domain.")
                     (:div :class "board-selector-container"
                           (:select :name "default_board" :style "padding: 4px; font-size: 0.95em;"
                                    (:option :value ""
                                             :selected (or (null default-board) (string= default-board ""))
                                             "None (Main Page)")
                                    (dolist (item boards)
                                      (cl-who:htm
                                       (:option :value item
                                                :selected (and default-board (string= default-board item))
                                                (cl-who:str (format nil "/~a/" item))))))))

               (:div :style "margin-bottom: 2em;"
                     (:h3 :style "margin-bottom: 0.5em;" "Search Settings")
                     (:p :style "color: #555; font-size: 0.9em; margin-bottom: 0.8em;"
                         "Configure how the search bar behaves on board indices and thread views.")
                     (:div :class "search-preferences-container" :style "line-height: 1.8em;"
                           (:div :style "margin-bottom: 0.8em;"
                                 (:label :style "font-weight: bold;"
                                         "Hide search input in board view: ")
                                 (:br)
                                 (:select :name "search_hide_input" :style "padding: 4px; font-size: 0.95em;"
                                          (:option :value "no" :selected (string= search-hide-input "no") "No")
                                          (:option :value "yes" :selected (string= search-hide-input "yes") "Yes")))
                           (:div :style "margin-bottom: 0.8em;"
                                 (:label :style "font-weight: bold;"
                                         "Only make local searches in the current board: ")
                                 (:br)
                                 (:select :name "search_local_only"
                                          :style "padding: 4px; font-size: 0.95em;"
                                          (:option :value "no"
                                                   :selected (string= search-local-only "no")
                                                   "No (Global)")
                                          (:option :value "yes"
                                                   :selected (string= search-local-only "yes")
                                                   "Yes (Local)")))
                           (:div :style "margin-bottom: 0.8em;"
                                 (:label :style "font-weight: bold;"
                                         "Placement of search input: ")
                                 (:br)
                                 (:select :name "search_position"
                                          :style "padding: 4px; font-size: 0.95em;"
                                          (:option :value "top"
                                                   :selected (string= search-position "top")
                                                   "Top (Header)")
                                          (:option :value "bottom"
                                                   :selected (string= search-position "bottom")
                                                   "Bottom (Footer)")))))

               (:p :style "margin-top: 2em;"
                   (:input :type "submit" :value "Save Preferences"
                           :style "padding: 6px 16px; font-size: 1em; cursor: pointer;
                                   font-weight: bold; background-color: #ededed;
                                   border: 1px solid #bababa; border-radius: 4px;")))
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
        (cl-who:str (render-footer-html))))))

(defun render-moderation (boards &optional board threads thread comments (prefs *preferences*) headline)
  "Renders the admin/moderation control panel HTML page showing BOARDS and allowing deletions/edits."
  (let ((theme (preferences-theme prefs)))
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
                                                      "return confirm('Are you sure you want to "
                                                      "delete the ENTIRE board? "
                                                      "This cannot be undone.');")))))))
        (:h2 "Create Board")
        (:p "Enter a board name below to create a new board. Board names must be in "
            (:strong "kebab-case")
            " (only lowercase letters, numbers, and hyphens; no spaces or underlines).")
        (:div :style "margin: 1em 0;"
              (:form :action "/admin/action" :method "POST" :onsubmit "return validateCreateBoard()"
                     (:input :type "hidden" :name "action" :value "create-board")
                     (:input :type "text" :name "board" :id "new-board-name" :placeholder "board-name"
                             :style "padding: 6px; font-size: 1em; border: 1px solid #bababa;
                                     border-radius: 4px; font-family: monospace;")
                     " "
                     (:input :type "submit" :value "Create Board"
                             :style "padding: 6px 12px; font-size: 1em; background-color: #ededed;
                                     border: 1px solid #b5b5b5; border-radius: 4px; cursor: pointer;
                                     font-weight: bold;"))
              (:p :id "board-error" :style "color: red; font-size: 0.9em; margin: 0.5em 0; display: none;"))
        (:script :type "text/javascript"
                 "function validateCreateBoard() {
        const input = document.getElementById('new-board-name');
        const error = document.getElementById('board-error');
        const boardName = input.value.trim();

        // Regex for kebab-case (lowercase alphanumeric and hyphens only, no start/end hyphens)
        const kebabRegex = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

        if (!boardName) {
        error.textContent = 'Please enter a board name.';
        error.style.display = 'block';
        return false;
        }

        if (!kebabRegex.test(boardName)) {
    error.textContent = 'Invalid board name! Must contain only lowercase ' +
      'alphanumeric characters and hyphens (e.g. \"lisp-board\", no spaces, ' +
      'underlines or capitals).';
    error.style.display = 'block';
    return false;
  }

  error.style.display = 'none';
  return true;
}")
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
                                                                           "to delete this thread?');")))
                                      (unless (string-equal board "shame")
                                        (cl-who:htm
                                         (:form :action "/admin/action" :method "POST" :style "display:inline; margin-left: 5px;"
                                                (:input :type "hidden" :name "action" :value "shame-thread")
                                                (:input :type "hidden" :name "board" :value board)
                                                (:input :type "hidden" :name "thread" :value tid)
                                                (:input :type "submit" :value "Shame" :class "shame-button"
                                                        :onclick (concatenate 'string
                                                                              "return confirm('Are you sure you want "
                                                                              "to move this thread to the shame board?');")))))))))))))
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
             (cl-who:htm (:p "No comments found.")))))))))

(defun render-search-results (query results &optional (prefs *preferences*))
  "Renders the search results page HTML, showing matching posts for the given QUERY, using layout PREFS."
  (let ((theme (preferences-theme prefs)))
    (layout (format nil "Search: ~a - SchemeBBS" query) "search-results" theme
      (cl-who:with-html-output-to-string (s nil :indent t)
        (:h1 "Search Results")
        (:p :style "margin: 0.5em 2%;"
            (:button :onclick "history.back();"
                     :style "padding: 3px 10px; font-size: 0.85em; cursor: pointer;
                             background-color: #ededed; border: 1px solid #bababa;
                             border-radius: 4px; font-weight: bold;"
                     "← Go Back")
            " - Query: "
            (:strong (cl-who:esc query)))
        (:hr)
        (if (null results)
            (cl-who:htm (:p :style "margin: 2em; text-align: center;" "No results found matching your query."))
            (cl-who:htm
             (:dl :style "margin: 1em 2%;"
                  (dolist (match results)
                    (let* ((board (getf match :board))
                           (thread-id (getf match :thread-id))
                           (headline (getf match :headline))
                           (post-id (getf match :post-id))
                           (date (getf match :date))
                           (content (getf match :content))
                           (post-style (if (string= theme "colored")
                                           (let ((hue (get-hash-hue post-id)))
                                             (format nil (concatenate 'string
                                                                      "background-color: hsl(~D, 85%, 96%); "
                                                                      "border-left: 4px solid hsl(~D, 85%, 45%); "
                                                                      "padding: 0.5em 1em; "
                                                                      "margin: 0.3em 0 1.2em 0; "
                                                                      "border-radius: 0 4px 4px 0;")
                                                     hue hue))
                                           "")))
                      (cl-who:htm
                       (:dt :style "margin-top: 1.5em; font-size: 0.95em;"
                            "[" (:a :href (format nil "/~a/" board) (cl-who:esc board)) "] "
                            (:a :href (format nil "/~a/~a" board thread-id) (:strong (cl-who:esc headline)))
                            " - Post "
                            (:a :href (format nil "/~a/~a#t~ap~a" board thread-id thread-id post-id)
                                (cl-who:str (format nil "#~a" post-id)))
                            " "
                            (:samp (cl-who:esc date)))
                       (:dd :style post-style
                            (cl-who:str (format-text content thread-id)))))))))
        (:hr)
        (cl-who:str (render-footer-html))))))

(defun render-playground (&optional board (prefs *preferences*))
  "Renders the interactive Common Lisp playground view."
  (let ((theme (preferences-theme prefs)))
    (layout (if board (format nil "/~a/ - Lisp Playground" board) "Lisp Playground")
            "playground-page"
            theme
      (cl-who:with-html-output-to-string (s nil :indent t)
        (when board
          (cl-who:htm (cl-who:str (render-menu board "playground"))))
        (:h2 "Common Lisp Playground")
        (:p :style "margin: 0.5em 2%; font-size: 0.95em;"
            "Write and execute Common Lisp code directly in your browser using "
            (:a :href "https://github.com/jscl-project/jscl" :target "_blank" "JSCL")
            ". Everything runs completely client-side in a sandboxed environment.")
        (:div :class "playground-container" :style "margin: 1.5em 2%;"
              (:div :style "margin-bottom: 1em; display: flex; gap: 10px; align-items: center; flex-wrap: wrap;"
                    (:span "Load Example: ")
                    (:select :id "playground-examples" :style "padding: 4px;"
                             (:option :value "" "-- Select Example --")
                             (:option :value "hello" "Hello World")
                             (:option :value "fib" "Fibonacci Numbers")
                             (:option :value "loop" "Loop Macro")
                             (:option :value "clos" "Common Lisp Object System (CLOS)")))
              (:div :id "example-data-hello" :style "display:none;" (cl-who:str (colorize:html-colorization :common-lisp "(format t \"Hello, World!~%\")")))
              (:div :id "example-data-fib" :style "display:none;" (cl-who:str (colorize:html-colorization :common-lisp "(defun fib (n)
  (if (< n 2)
      n
      (+ (fib (- n 1)) (fib (- n 2)))))

(format t \"Fibonacci of 10 is: ~a~%\" (fib 10))")))
              (:div :id "example-data-loop" :style "display:none;" (cl-who:str (colorize:html-colorization :common-lisp "(loop for x from 1 to 5
      do (format t \"Square of ~d is ~d~%\" x (* x x)))")))
              (:div :id "example-data-clos" :style "display:none;" (cl-who:str (colorize:html-colorization :common-lisp "(defclass person ()
  ((name :accessor person-name :initarg :name)
   (age :accessor person-age :initarg :age)))

(defmethod introduce ((p person))
  (format t \"Hi, I am ~a and I am ~a years old.~%\"
          (person-name p)
          (person-age p)))

(let ((p (make-instance 'person :name \"Alice\" :age 30)))
  (introduce p))")))
              (:pre :id "playground-editor"
                    :class "lisp-code-block"
                    :contenteditable "true"
                    :spellcheck "false"
                    :style "min-height: 200px; width: 96%; max-width: 800px; font-family: monospace; font-size: 1.1em; padding: 10px; border: 1px solid currentColor; background: transparent; color: inherit; margin-bottom: 1em; outline: none; overflow: auto; white-space: pre-wrap;"
                    "")
              (:div :style "display: flex; gap: 10px; margin-bottom: 1em;"
                    (:button :id "playground-run" :style "padding: 6px 15px; font-size: 1em; cursor: pointer; font-weight: bold;" "Run Code")
                    (:button :id "playground-clear" :style "padding: 6px 15px; font-size: 1em; cursor: pointer;" "Clear Output"))
              (:h3 "Output Console")
              (:pre :id "playground-output"
                    :style "display: none; padding: 10px; width: 96%; max-width: 800px; border: 1px dashed currentColor; background-color: rgba(128, 128, 128, 0.05); white-space: pre-wrap; word-break: break-all; font-family: monospace; font-size: 1.1em; line-height: 1.4em;"
                    ""))
        (:hr)
        (cl-who:str (render-footer-html))))))
