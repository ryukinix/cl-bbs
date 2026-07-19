(defpackage #:cl-bbs/rss
  (:use #:cl)
  (:local-nicknames (#:models #:cl-bbs/models)
                    (#:storage #:cl-bbs/storage))
  (:export #:generate-rss
           #:get-all-boards-rss-threads))

(in-package #:cl-bbs/rss)

(defun get-url-scheme (env headers)
  (if (string= "https" (gethash "x-forwarded-proto" headers))
      "https"
      (let ((url-scheme (getf env :url-scheme)))
        (if url-scheme
            (string-downcase (string url-scheme))
            "http"))))

(defun get-request-base-url (env)
  "Construct the base URL from the request environment."
  (let* ((headers (getf env :headers))
         (scheme (get-url-scheme env headers))
         (host (gethash "host" headers)))
    (if host
        (format nil "~a://~a" scheme host)
        "")))

(defun get-tz-offset-string ()
  "Returns the basic timezone offset of the machine like '-0300' or '+0000'."
  (multiple-value-bind (sec min hr date month year day-of-week dst-p tz)
      (get-decoded-time)
    (declare (ignore sec min hr date month year day-of-week dst-p))
    (let* ((offset-hours (- tz))
           (sign (if (>= offset-hours 0) #\+ #\-))
           (abs-hours (abs offset-hours)))
      (format nil "~c~2,'0d00" sign (truncate abs-hours)))))

(defun convert-to-rfc822 (iso-8601-string)
  "Convert simple ISO 8601 string to RFC1123/RFC822 retaining literal parsing and appending manual offset."
  (let ((clean-string (cl-ppcre:regex-replace-all " " iso-8601-string "T")))
    (handler-case
        (let* ((parsed (local-time:parse-timestring clean-string))
               (utc-str (local-time:format-rfc1123-timestring nil parsed :timezone local-time:+utc-zone+)))
          (cl-ppcre:regex-replace "(?:GMT|\\+0000)$" utc-str (get-tz-offset-string)))
      (error ()
        (let ((now-utc (local-time:format-rfc1123-timestring nil (local-time:now) :timezone local-time:+utc-zone+)))
          (cl-ppcre:regex-replace "(?:GMT|\\+0000)$" now-utc (get-tz-offset-string)))))))



(defun get-all-boards-rss-threads (limit)
  "Fetch latest threads from all boards combining them for RSS."
  (let ((all-threads nil)
        (sexp-base (merge-pathnames "sexp/" storage:*base-dir*)))
    (when (probe-file sexp-base)
      (loop for board-dir in (uiop:subdirectories sexp-base) do
        (let ((board-name (car (last (pathname-directory board-dir))))
               (list-path (merge-pathnames "list" board-dir)))
          (when (probe-file list-path)
            (let ((board-threads (storage:read-sexp-file list-path)))
              (loop for thread in board-threads do
                ;; thread is (ID (models:headline . "...") (models:date . "..."))
                (push (cons (car thread) (cons `(models:board . ,board-name) (cdr thread))) all-threads)))))))
    ;; Sort by date descending
    (setf all-threads (sort all-threads
                            (lambda (a b)
                              (string> (cdr (assoc 'models:date (cdr a)))
                                       (cdr (assoc 'models:date (cdr b)))))))
    ;; Take top LIMIT
    (if (> (length all-threads) limit)
        (subseq all-threads 0 limit)
        all-threads)))

(defun generate-rss (board threads env)
  "Generate an RSS feed for the given board and threads."
  (let* ((now (local-time:now))
         (utc-str (local-time:format-rfc1123-timestring nil now))
         (rfc822-date utc-str)
         (base-url (get-request-base-url env))
         (request-url (format nil "~a~a" base-url (getf env :request-uri))))
    (with-output-to-string (s)
      (format s "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>~%")
      (format s "<rss version=\"2.0\" xmlns:content=\"http://purl.org/rss/1.0/modules/content/\">~%")
      (format s "  <channel>~%")
      (if (string= board "all")
          (progn
            (format s "    <title>cl-bbs - all boards</title>~%")
            (format s "    <description>Latest threads from all boards on cl-bbs.</description>~%"))
          (progn
            (format s "    <title>cl-bbs - /~a/</title>~%" board)
            (format s "    <description>Latest threads from /~a/.</description>~%" board)))
      (format s "    <link>~a</link>~%" request-url)
      (format s "    <pubDate>~a</pubDate>~%" rfc822-date)
      (format s "    <generator>cl-bbs RSS generator</generator>~%")

      (loop for t-entry in threads do
        (let* ((id (car t-entry))
               (thread-data (cdr t-entry))
               (board-val (if (string= board "all")
                              (or (cdr (assoc 'models:board thread-data)) board)
                              board))
               (headline (or (cdr (assoc 'models:headline thread-data)) "Untitled"))
               (date (or (cdr (assoc 'models:date thread-data)) rfc822-date)) ; ISO 8601
               (pub-date (if (string= date rfc822-date) rfc822-date (convert-to-rfc822 date)))
               (thread-url (if (not (string= base-url ""))
                               (format nil "~a/~a/~a" base-url board-val id)
                               (format nil "/~a/~a" board-val id)))
               (thread-path (merge-pathnames (format nil "sexp/~a/~a" board-val id) storage:*base-dir*))
               (thread-full-data (when (probe-file thread-path) (storage:read-sexp-file thread-path)))
               (posts (cdr (assoc 'models:posts thread-full-data)))
               (first-post (when posts (cdar (car posts))))
               (content (if first-post (cdr (assoc 'models:content first-post)) "")))
          (format s "    <item>~%")
          (format s "      <title><![CDATA[~a]]></title>~%" headline)
          (format s "      <link>~a</link>~%" thread-url)
          (format s "      <description><![CDATA[~a]]></description>~%" headline) ;; Fallback to headline
          (format s "      <content:encoded><![CDATA[~a]]></content:encoded>~%" content)
          (format s "      <pubDate>~a</pubDate>~%" pub-date)
          (format s "      <guid>~a</guid>~%" thread-url)
          (format s "    </item>~%")))

      (format s "  </channel>~%")
      (format s "</rss>~%"))))
