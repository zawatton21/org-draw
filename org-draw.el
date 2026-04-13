;;; org-draw.el --- Tools for org excalidraw / tldraw link  -*- lexical-binding: t; -*-

;; URL: https://github.com/4honor/org-draw
;; Version: 0.2.0
;; Keywords: orgmode, excalidraw, tldraw
;; Package-Requires: ((org "9.7") (emacs "30.0"))

;;; Commentary:
;; This file adds tldraw support in addition to the existing excalidraw support.
;;
;; - tldraw: *.tldr files
;; - Exporting via the CLI: `tldraw export <file>.tldr --format svg ...`
;;
;; See: https://github.com/kitschpatrol/tldraw-cli

;;; Code:


;;; Code:

(require 'org)
(require 'org-element)
(require 'org-id)


;;; Customizations

(defgroup org-draw nil
  "Group for org-draw."
  :group 'org)

(defcustom org-draw-url-protocol "excalidraw"
  "Protocol identifier for excalidraw links."
  :group 'org-draw
  :type 'string)

(defcustom org-draw-url-protocol-tldraw "tldraw"
  "Protocol identifier for tldraw links."
  :group 'org-draw
  :type 'string)

(defcustom org-draw-default-directory nil
  "Default directory for new diagrams (both excalidraw / tldraw).
When non-nil, .excalidraw / .tldr and .svg live together here."
  :group 'org-draw
  :type 'string)

(defcustom org-draw-directory-excal "~/org-excalidraw/excal"
  "Directory to store .excalidraw files when not using `org-draw-default-directory'."
  :group 'org-draw
  :type 'string)

(defcustom org-draw-directory-svg "~/org-excalidraw/svg"
  "Directory to store .svg thumbnails when not using `org-draw-default-directory'."
  :group 'org-draw
  :type 'string)

(defcustom org-draw-directory-tldraw "~/org-excalidraw/tldraw"
  "Directory to store .tldr files when not using `org-draw-default-directory'."
  :group 'org-draw
  :type 'string)

(defcustom org-draw-use-org-id t
  "Whether to use `org-id-new' for file names."
  :type 'boolean
  :group 'org-draw)

(defcustom org-draw-file-prefix nil
  "Optional prefix for file names."
  :type 'string
  :group 'org-draw)

(defcustom org-draw-file-name (format-time-string "%Y%m%d%H%M%S")
  "Timestamp-based name for new drawings when not using `org-id-new'."
  :type 'string
  :group 'org-draw)

(defvar org-draw--watch-descriptors nil
  "List of file notification descriptors used by org-draw.")

(defcustom org-draw-inline-image-background-excal nil
  "Background color used for Excalidraw inline images. 
If nil, the image remains transparent (shows through the buffer background)."
  :type '(choice (string :tag "Color (e.g. #ffffff)") (const :tag "Transparent" nil))
  :group 'org-draw)

(defcustom org-draw-inline-image-background-tldraw nil
  "Background color used for tldraw inline images.
If nil, the image remains transparent (shows through the buffer background)."
  :type '(choice (string :tag "Color (e.g. #ffffff)") (const :tag "Transparent" nil))
  :group 'org-draw)

(defcustom org-draw-default-width-excal nil
  "Default width for inserted Excalidraw image links.
If nil, do not insert \"#+attr_org: :width N\"."
  :type '(choice (const :tag "No width" nil)
                 (integer :tag "Width in pixels"))
  :group 'org-draw)

(defcustom org-draw-default-width-tldraw nil
  "Default width for inserted tldraw image links.
If nil, do not insert \"#+attr_org: :width N\"."
  :type '(choice (const :tag "No width" nil)
                 (integer :tag "Width in pixels"))
  :group 'org-draw)

(defcustom org-draw-excalidraw-converter 'auto
  "Which converter to use for .excalidraw => .svg.
Possible values:
- `auto`:  Try `excalidraw-brute-export-cli`, then `excalidraw_export`, then `kroki`.
- `excalidraw_brute_export_cli`: Force using excalidraw-brute-export-cli.
- `excalidraw_export`: Force using excalidraw_export CLI.
- `kroki`: Force using `kroki convert`.
- nil: Do not attempt to convert at all (error if no converter is found)."
  :type '(choice (const :tag "Auto" auto)
                 (const :tag "excalidraw-brute-export-cli" excalidraw_brute_export_cli)
                 (const :tag "excalidraw_export" excalidraw_export)
                 (const :tag "kroki" kroki)
                 (const :tag "No converter" nil))
  :group 'org-draw)

(defcustom org-draw-kroki-server "https://demo.kroki.io"
  "Base URL of the Kroki server for Excalidraw->SVG conversion.
Only used if `org-draw-excalidraw-converter' is 'kroki or 'auto and `kroki` is actually used."
  :type 'string
  :group 'org-draw)

;;; Excalidraw: Default template

(defconst org-draw-default-template-excalidraw
  "{
    \"type\": \"excalidraw\",
    \"version\": 2,
    \"source\": \"https://excalidraw.com\",
    \"elements\": [],
    \"appState\": {
      \"gridSize\": null,
      \"viewBackgroundColor\": \"#ffffff\"
    },
    \"files\": {}
  }"
  "Default .excalidraw file template.")


;;; tldraw: Default template
(defconst org-draw-default-template-tldraw
  "{
    \"tldrawFileFormatVersion\":1,
    \"schema\":{
      \"schemaVersion\":2,
      \"sequences\":{
        \"com.tldraw.store\":4,
        \"com.tldraw.asset\":1,
        \"com.tldraw.camera\":1,
        \"com.tldraw.document\":2,
        \"com.tldraw.instance\":25,
        \"com.tldraw.instance_page_state\":5,
        \"com.tldraw.page\":1,
        \"com.tldraw.instance_presence\":6,
        \"com.tldraw.pointer\":1,
        \"com.tldraw.shape\":4,
        \"com.tldraw.asset.bookmark\":2,
        \"com.tldraw.asset.image\":5,
        \"com.tldraw.asset.video\":5,
        \"com.tldraw.shape.group\":0,
        \"com.tldraw.shape.text\":2,
        \"com.tldraw.shape.bookmark\":2,
        \"com.tldraw.shape.draw\":2,
        \"com.tldraw.shape.geo\":9,
        \"com.tldraw.shape.note\":8,
        \"com.tldraw.shape.line\":5,
        \"com.tldraw.shape.frame\":0,
        \"com.tldraw.shape.arrow\":5,
        \"com.tldraw.shape.highlight\":1,
        \"com.tldraw.shape.embed\":4,
        \"com.tldraw.shape.image\":4,
        \"com.tldraw.shape.video\":2,
        \"com.tldraw.binding.arrow\":0}},
    \"records\":[{
      \"gridSize\":10,
      \"name\":\"\",
      \"meta\":{},
      \"id\":\"document:document\",
      \"typeName\":\"document\"},
    {
      \"id\":\"pointer:pointer\",
      \"typeName\":\"pointer\",
      \"x\":0,\"y\":43,
      \"lastActivityTimestamp\":1736815237799,
      \"meta\":{}},
    {
      \"meta\":{},
      \"id\":\"page:page\",
      \"name\":\"Page 1\",
      \"index\":\"a1\",
      \"typeName\":\"page\"},
    {
      \"followingUserId\":null,
      \"opacityForNextShape\":1,
      \"stylesForNextShape\":{},
      \"brush\":null,
      \"scribbles\":[],
      \"cursor\":{
        \"type\":\"default\",
        \"rotation\":0},
      \"isFocusMode\":false,
      \"exportBackground\":true,
      \"isDebugMode\":false,
      \"isToolLocked\":false,
      \"screenBounds\":{\"x\":0,
        \"y\":0,\"w\":1439.3333740234375,
        \"h\":810},
      \"insets\":[false,false,false,false],
      \"zoomBrush\":null,
      \"isGridMode\":false,
      \"isPenMode\":false,
      \"chatMessage\":\"\",
      \"isChatting\":false,
      \"highlightedUserIds\":[],
      \"isFocused\":true,
      \"devicePixelRatio\":1.5,
      \"isCoarsePointer\":false,
      \"isHoveringCanvas\":false,
      \"openMenus\":[],
      \"isChangingStyle\":false,
      \"isReadonly\":false,
      \"meta\":{},
      \"duplicateProps\":null,
      \"id\":\"instance:instance\",
      \"currentPageId\":\"page:page\",
      \"typeName\":\"instance\"},
      {
        \"editingShapeId\":null,
        \"croppingShapeId\":null,
        \"selectedShapeIds\":[],
        \"hoveredShapeId\":null,
        \"erasingShapeIds\":[],
        \"hintingShapeIds\":[],
        \"focusedGroupId\":null,
        \"meta\":{},
        \"id\":\"instance_page_state:page:page\",
        \"pageId\":\"page:page\",
        \"typeName\":\"instance_page_state\"},
      {
        \"x\":0,
        \"y\":0,
        \"z\":1,
        \"meta\":{},
        \"id\":\"camera:page:page\",
        \"typeName\":\"camera\"}]}"
  "Default JSON template string for newly created .tldr files.")


;;; Excalidraw: open & create

(defun org-draw-link-open (link)
  "Open excalidraw LINK (.excalidraw) in the system default viewer."
  (let ((path (expand-file-name link)))
    (unless (string-suffix-p ".excalidraw" path t)
      (error "Excalidraw file must end with .excalidraw"))
    (pcase system-type
      ('gnu/linux (call-process "xdg-open" nil 0 nil path))
      ('darwin    (call-process "open"     nil 0 nil path))
      ('windows-nt
       (shell-command (concat "cmd /c start \"\" " (format "\"%s\"" path))))
      (_ (message "Unsupported system type for auto-open")))))

(defun org-draw-create-excalidraw ()
  "Create a new .excalidraw file and insert a link at point."
  (interactive)
  (setq org-draw-file-name (format-time-string "%Y%m%d%H%M%S"))
  (let* ((use-default (and org-draw-default-directory
                           (y-or-n-p "Use `org-draw-default-directory'? ")))
         (excal-dir
          (file-name-as-directory
           (if (and org-draw-default-directory use-default)
               (expand-file-name org-draw-default-directory)
             (expand-file-name org-draw-directory-excal)))))
    (unless (file-directory-p excal-dir)
      (make-directory excal-dir t))

    (let* ((base (if org-draw-use-org-id
                     (org-id-new)
                   org-draw-file-name))
           (default-suggest
            (if (and org-draw-file-prefix
                     (not (string-empty-p org-draw-file-prefix)))
                (concat org-draw-file-prefix base)
              base))
           (prompt (format "Enter .excalidraw filename (default: %s): " default-suggest))
           (user-input (read-file-name prompt excal-dir default-suggest nil default-suggest))
           (file-base (file-name-nondirectory user-input))
           (final-name
            (if (string-empty-p file-base)
                default-suggest
              file-base))
           (final-path
            (expand-file-name
             (if (string-suffix-p ".excalidraw" final-name)
                 final-name
               (concat final-name ".excalidraw"))
             excal-dir))
           (abbrev-path (abbreviate-file-name final-path))
           (link (format "[[%s:%s]]" org-draw-url-protocol abbrev-path)))
      (unless (file-exists-p final-path)
        (with-temp-file final-path
          (insert org-draw-default-template-excalidraw)))

      ;; ;;; ADD: ここで、org-draw-default-width-excal が指定されていれば
      ;;         "#+attr_org: :width XXX" を挿入する
      (when org-draw-default-width-excal
        (insert (format "#+attr_org: :width %d\n" org-draw-default-width-excal)))

      (insert link) 
      (org-draw-link-open final-path))))


;;; tldraw: open & create

(defun org-draw-tldraw-link-open (link)
  "Open tldraw LINK (.tldr) in the system default viewer."
  (let ((path (expand-file-name link)))
    (unless (string-suffix-p ".tldr" path t)
      (error "tldraw file must end with .tldr"))
    (pcase system-type
      ('gnu/linux (call-process "xdg-open" nil 0 nil path))
      ('darwin    (call-process "open"     nil 0 nil path))
      ('windows-nt
       (shell-command (concat "cmd /c start \"\" " (format "\"%s\"" path))))
      (_ (message "Unsupported system type for auto-open")))))

(defun org-draw-create-tldraw ()
  "Create a new .tldr file and insert a link at point."
  (interactive)
  (setq org-draw-file-name (format-time-string "%Y%m%d%H%M%S"))
  (let* ((use-default (and org-draw-default-directory
                           (y-or-n-p "Use `org-draw-default-directory'? ")))
         (tldraw-dir
          (file-name-as-directory
           (if (and org-draw-default-directory use-default)
               (expand-file-name org-draw-default-directory)
             (expand-file-name org-draw-directory-tldraw)))))
    (unless (file-directory-p tldraw-dir)
      (make-directory tldraw-dir t))

    (let* ((base (if org-draw-use-org-id
                     (org-id-new)
                   org-draw-file-name))
           (default-suggest
            (if (and org-draw-file-prefix
                     (not (string-empty-p org-draw-file-prefix)))
                (concat org-draw-file-prefix base)
              base))
           (prompt (format "Enter .tldr filename (default: %s): " default-suggest))
           (user-input (read-file-name prompt tldraw-dir default-suggest nil default-suggest))
           (file-base (file-name-nondirectory user-input))
           (final-name
            (if (string-empty-p file-base)
                default-suggest
              file-base))
           (final-path
            (expand-file-name
             (if (string-suffix-p ".tldr" final-name)
                 final-name
               (concat final-name ".tldr"))
             tldraw-dir))
           (abbrev-path (abbreviate-file-name final-path))
           (link (format "[[%s:%s]]" org-draw-url-protocol-tldraw abbrev-path)))
      (unless (file-exists-p final-path)
        (with-temp-file final-path
          (insert org-draw-default-template-tldraw)))

      ;; ;;; ADD: ここで org-draw-default-width-tldraw が指定されていれば
      ;;         "#+attr_org: :width XXX" を挿入
      (when org-draw-default-width-tldraw
        (insert (format "#+attr_org: :width %d\n" org-draw-default-width-tldraw)))

      (insert link)
      (org-draw-tldraw-link-open final-path))))


;;; Convert to SVG (excalidraw)

(defun org-draw-svg-thumbnail-path (path)
  "Return .svg path for PATH.

If `org-draw-default-directory' is non-nil and PATH is under that directory,
we keep the .svg in the same directory as PATH.

Otherwise (org-draw-default-directory is nil):
  - If PATH is .excalidraw => .svg goes to `org-draw-directory-excal'
  - If PATH is .tldr       => .svg goes to `org-draw-directory-tldraw'
  - Otherwise              => .svg goes to `org-draw-directory-svg' (fallback)."
  (if (and org-draw-default-directory
           (string-prefix-p (expand-file-name org-draw-default-directory)
                            (expand-file-name path)))
      ;; org-draw-default-directory が non-nil & path がそこに含まれている => 同じ階層へ
      (concat (file-name-sans-extension path) ".svg")
    ;; org-draw-default-directory が nil => 拡張子に応じて振り分け
    (cond
     ((string-suffix-p ".excalidraw" path t)
      (concat (file-name-as-directory (expand-file-name org-draw-directory-excal))
              (file-name-nondirectory (file-name-sans-extension path))
              ".svg"))
     ((string-suffix-p ".tldr" path t)
      (concat (file-name-as-directory (expand-file-name org-draw-directory-tldraw))
              (file-name-nondirectory (file-name-sans-extension path))
              ".svg"))
     (t
      ;; その他は fallback
      (concat (file-name-as-directory (expand-file-name org-draw-directory-svg))
              (file-name-nondirectory (file-name-sans-extension path))
              ".svg")))))

(defun org-draw-to-svg-thumbnail (file)
  "Export .excalidraw FILE to .svg using the chosen converter (`org-draw-excalidraw-converter')."
  (let* ((path (expand-file-name file))
         (svg-path (org-draw-svg-thumbnail-path path)))
    (unless (string-suffix-p ".excalidraw" path t)
      (error "Excalidraw file must end with .excalidraw extension."))
    (pcase org-draw-excalidraw-converter
      ('auto
       (cond
        ((executable-find "excalidraw-brute-export-cli")
         (start-process
          "excalidraw-brute-export-cli-proc" "*excalidraw-brute-export-cli-output*"
          "excalidraw-brute-export-cli"
          "--input" path
          "--background" "1"
          "--embed-scene" "0"
          "--dark-mode" "0"
          "--scale" "1"
          "--format" "svg"
          "--output" svg-path))
        
        ((executable-find "excalidraw_export")
         (start-process
          "excalidraw-export-proc" "*excalidraw-export-output*"
          "excalidraw_export"
          "--rename_fonts" path))
        
        ((executable-find "kroki")
         (start-process
          "kroki-convert-proc" "*kroki-convert-output*" "kroki"
          "convert" path
          "--type" "excalidraw"
          "--format" "svg"
          "--server" org-draw-kroki-server
          "--out-file" svg-path))
        (t
         (error "[org-draw] No suitable tool found for .excalidraw -> .svg"))))

      ('excalidraw_brute_export_cli
       (unless (executable-find "excalidraw-brute-export-cli")
         (error "[org-draw] excalidraw-brute-export-cli not found in PATH."))
       (start-process
        "excalidraw-brute-export-cli-proc" "*excalidraw-brute-export-cli-output*"
        "excalidraw-brute-export-cli"
        "--input" path
        "--background" "1"
        "--embed-scene" "0"
        "--dark-mode" "0"
        "--scale" "1"
        "--format" "svg"
        "--output" svg-path))

      ('excalidraw_export
       (unless (executable-find "excalidraw_export")
         (error "[org-draw] excalidraw_export not found in PATH"))
       (start-process
        "excalidraw-export-proc" "*excalidraw-export-output*" "excalidraw_export"
        "--rename_fonts" path))

      ('kroki
       (unless (executable-find "kroki")
         (error "[org-draw] kroki CLI not found in PATH"))
       (start-process
        "kroki-convert-proc" "*kroki-convert-output*" "kroki"
        "convert" path
        "--type" "excalidraw"
        "--format" "svg"
        "--server" org-draw-kroki-server
        "--out-file" svg-path))

      (_
       (error "[org-draw] No converter configured (org-draw-excalidraw-converter is nil?).")))))


;;; Convert to SVG (tldraw)

(defun org-draw-tldraw-to-svg-thumbnail (file)
  "Export .tldr FILE to .svg using `tldraw` CLI (from @kitschpatrol/tldraw-cli)."
  (let* ((filename (file-name-nondirectory file))
         (dir      (file-name-directory file))
         (svg-path (org-draw-svg-thumbnail-path file))
         (svg-dir  (file-name-directory svg-path))
         (svg-name (file-name-base svg-path)))
    (unless (string-suffix-p ".tldr" filename t)
      (error "tldraw file must end with .tldr extension."))
    (unless (executable-find "tldraw")
      (error "tldraw CLI not found in PATH (npm i -g @kitschpatrol/tldraw-cli)"))
    ;; Use relative path to avoid Windows absolute path bug
    (let ((default-directory dir))
      (start-process
       "tldraw-export-proc"
       "*tldraw-export-output*"
       "tldraw" "export"
       (concat ".\\" filename)
       "--format" "svg"
       "--transparent" "false" ;; これを指定してもしなくても背景色が透明である. tldraw-cli のバグ？
       "--output" svg-dir
       "--name"   svg-name))))


;;; Export for org-export

(defun org-draw-link-export (link _description backend)
  "Export .excalidraw LINK to BACKEND (producing a .svg link)."
  (let* ((path (expand-file-name link))
         (svg-path (org-draw-svg-thumbnail-path path)))
    ;; Convert first
    (org-draw-to-svg-thumbnail path)
    ;; Insert a link to the .svg in the exported text
    (org-export-string-as (format "[[%s]]" svg-path) backend t)))

(defun org-draw-tldraw-link-export (link _description backend)
  "Export .tldr LINK to BACKEND (producing a .svg link)."
  (let* ((path (expand-file-name link))
         (svg-path (org-draw-svg-thumbnail-path path)))
    (org-draw-tldraw-to-svg-thumbnail path)
    (org-export-string-as (format "[[%s]]" svg-path) backend t)))


;;; File watchers

(defun org-draw--file-notify-callback (event)
  "Callback for file watcher EVENT. Auto-convert .excalidraw/.tldr => .svg if changed."
  (let ((file (nth 2 event))) ;; nth 2 => changed file path
    (when (and (stringp file)
               org-draw-auto-convert-on-change)
      (cond
       ((string-suffix-p ".excalidraw" file t)
        (message "org-draw: detected .excalidraw change -> converting to SVG")
        (org-draw-to-svg-thumbnail file))
       ((string-suffix-p ".tldr" file t)
        (message "org-draw: detected .tldr change -> converting to SVG")
        (org-draw-tldraw-to-svg-thumbnail file))))))

(defun org-draw--stop-file-watch ()
  "Stop all watchers in `org-draw--watch-descriptors'."
  (dolist (desc org-draw--watch-descriptors)
    (file-notify-rm-watch desc))
  (setq org-draw--watch-descriptors nil)
  (message "org-draw: stopped all watchers."))

(defcustom org-draw-auto-convert-on-change nil
  "If non-nil, automatically convert changed .excalidraw/.tldr to .svg."
  :type 'boolean
  :group 'org-draw
  :set (lambda (var val)
         (set-default var val)
         (if val
             (org-draw--start-file-watch)
           (org-draw--stop-file-watch))))

(defun org-draw--start-file-watch ()
  "Start watchers on relevant directories if `org-draw-auto-convert-on-change' is non-nil."
  (org-draw--stop-file-watch)
  (when org-draw-auto-convert-on-change
    (let ((dirs
           (if org-draw-default-directory
               ;; If using one default directory, just watch that
               (list (file-name-as-directory (expand-file-name org-draw-default-directory)))
             ;; Otherwise, watch excal, tldraw, (and possibly svg) separately
             (list (file-name-as-directory (expand-file-name org-draw-directory-excal))
                   (file-name-as-directory (expand-file-name org-draw-directory-tldraw))
                   ;; If you also want to watch the SVG dir, uncomment:
                   ;; (file-name-as-directory (expand-file-name org-draw-directory-svg))
                   ))))
      (message "org-draw: watchers => %S" dirs)
      (dolist (dir dirs)
        (when (and dir (file-directory-p dir))
          (message "org-draw: add watch => %s" dir)
          (push (file-notify-add-watch
                 dir
                 '(change attribute-change)
                 #'org-draw--file-notify-callback)
                org-draw--watch-descriptors))))))

(add-hook 'after-inir-hook #'org-draw--start-file-watch)


;;; Display inline images

;; すでに定義済み `org-draw-data-fun` / `org-draw-data-fun-tldraw` がある想定:
(defun org-draw-data-fun (_protocol link _description)
  "Return raw SVG data for an excalidraw link."
  (let* ((path (expand-file-name link))
         (svg-path (org-draw-svg-thumbnail-path path)))
    (org-draw-to-svg-thumbnail path)
    (condition-case nil
        (with-temp-buffer
          (set-buffer-multibyte nil)
          (insert-file-contents-literally svg-path)
          (let ((image-data (buffer-string)))
            (if (> (string-bytes image-data) 0)
                image-data
              nil)))
      (error nil))))

(defun org-draw-data-fun-tldraw (_protocol link _description)
  "Return raw SVG data for a tldraw link."
  (let* ((path (expand-file-name link))
         (svg-path (org-draw-svg-thumbnail-path path)))
    (org-draw-tldraw-to-svg-thumbnail path)
    (condition-case nil
        (with-temp-buffer
          (set-buffer-multibyte nil)
          (insert-file-contents-literally svg-path)
          (let ((image-data (buffer-string)))
            (if (> (string-bytes image-data) 0)
                image-data
              nil)))
      (error nil))))

;; ---- (以下がオリジナル相当の「ユーザー定義インライン画像表示」の仕組み) ----
(defun org-draw-image-update-overlay (file link &optional data-p refresh)
  "Create image overlay for FILE associated with org-element LINK.
If DATA-P is non-nil, FILE is not a file name but an image data string.
If REFRESH is non-nil, flush the old image and re-display it."

  (when (or data-p (file-exists-p file))
    (let* (;; 幅の算出などは既存コードのまま
           (width
            (cond
             ((eq org-image-actual-width t)
              nil)
             ((listp org-image-actual-width)
              (or
               (let ((paragraph
                      (let ((e link))
                        (while (and (setq e (org-element-property :parent e))
                                    (not (eq (org-element-type e) 'paragraph)) ))
                        e)))
                 (when paragraph
                   (save-excursion
                     (goto-char (org-element-property :begin paragraph))
                     (when (re-search-forward
                            "^[ \t]*#\\+attr_.*?: +.*?:width +\\(\\S-+\\)"
                            (org-element-property :post-affiliated paragraph) t)
                       (string-to-number (match-string 1))))))
               (car org-image-actual-width)))
             ((numberp org-image-actual-width)
              org-image-actual-width)))
           (old
            (get-char-property-and-overlay (org-element-property :begin link)
                                           'org-image-overlay))
           ;; 追加部分：リンク文字列を取得して、excalidraw/tldraw かどうかを判定
           (raw-link (org-element-property :raw-link link))
           (bg-color
            (cond
             ;; 例: "excalidraw:/path/to/foo.excalidraw"
             ((string-prefix-p (concat org-draw-url-protocol ":") raw-link)
              org-draw-inline-image-background-excal)
             ;; 例: "tldraw:/path/to/bar.tldr"
             ((string-prefix-p (concat org-draw-url-protocol-tldraw ":") raw-link)
              org-draw-inline-image-background-tldraw)
             (t
              ;; それ以外なら背景色を付けない
              nil))))
      (if (and (car-safe old) refresh)
          ;; すでに overlay があり refresh 指定されている場合は一度フラッシュ
          (image-flush (overlay-get (cdr old) 'display))
        ;; 新しく overlay を作る
        (let ((image (create-image
                      file
                      (and (image-type-available-p 'imagemagick) width 'imagemagick)
                      data-p
                      :width width
                      ;; ★ ここで背景色を指定 (bg-color が nil なら透明扱い)
                      :background bg-color)))
          (when image
            (let* ((parent (org-element-property :parent link))
                   (actual-link (if (eq (org-element-type parent) 'link)
                                    parent
                                  link))
                   (ov (make-overlay
                        (org-element-property :begin actual-link)
                        (progn
                          (goto-char (org-element-property :end actual-link))
                          (skip-chars-backward " \t")
                          (point)))))
              (overlay-put ov 'display image)
              (overlay-put ov 'face 'default)
              (overlay-put ov 'org-image-overlay t)
              (overlay-put ov 'modification-hooks
                           (list 'org-display-inline-remove-overlay))
              (push ov org-inline-image-overlays)
              ov)))))))

(defun org-draw-display-user-inline-images (&optional _include-linked _refreshed beg end)
  "Like `org-display-inline-images' but for image data links.

We look for links that have a :image-data-fun in `org-link-parameters'.
If that function returns non-nil (the raw image data), we display it as an overlay."
  (interactive)
  (when (and (called-interactively-p 'any) (use-region-p))
    (setq beg (region-beginning)
          end (region-end)))

  (when (display-graphic-p)
    (org-with-wide-buffer
     (goto-char (or beg (point-min)))
     ;; Collect link-pars that have :image-data-fun
     (when-let
         ((image-data-link-parameters
           (cl-loop
            for link-par-entry in org-link-parameters
            with fun
            when (setq fun (plist-get (cdr link-par-entry) :image-data-fun))
            collect (cons (car link-par-entry) fun)))
          (image-data-link-re (regexp-opt (mapcar #'car image-data-link-parameters)))
          (re (format "\\[\\[\\(%s\\):\\([^]]+\\)\\]\\(?:\\[\\([^]]+\\)\\]\\)?\\]"
                      image-data-link-re)))
       (while (re-search-forward re end t)
         (let* ((protocol (match-string-no-properties 1))
                (link     (match-string-no-properties 2))
                (desc     (match-string-no-properties 3))
                (image-data-link (assoc-string protocol image-data-link-parameters))
                (el (save-excursion
                      (goto-char (match-beginning 1))
                      (org-element-context)))
                image-data)
           (when el
             ;; Already have an old overlay?
             (setq image-data
                   (or (let ((old
                              (get-char-property-and-overlay
                               (org-element-property :begin el) 'org-image-overlay)))
                         (and old (car-safe old) (overlay-get (cdr old) 'display)))
                       ;; or call the :image-data-fun
                       (funcall (cdr image-data-link) protocol link desc)))
             (when image-data
               (let ((ov (org-draw-image-update-overlay image-data el t t)))
                 (when (and ov desc)
                   (overlay-put ov 'after-string desc)))))))))))

;; org-display-inline-images の後に、我々の追加処理を実行
(advice-add #'org-display-inline-images
            :after
            #'org-draw-display-user-inline-images)


;;; Link definitions

(org-link-set-parameters
 org-draw-url-protocol
 :follow #'org-draw-link-open
 :export #'org-draw-link-export
 :image-data-fun #'org-draw-data-fun
 :complete (lambda (&optional arg)
             (let ((file (read-file-name "Excalidraw File: "))
                   (pwd  (abbreviate-file-name (expand-file-name "."))))
               (if (and arg (equal arg '(16)))
                   (concat org-draw-url-protocol ":" (abbreviate-file-name file))
                 (string-replace pwd "" (concat org-draw-url-protocol ":" file))))))

(org-link-set-parameters
 org-draw-url-protocol-tldraw
 :follow #'org-draw-tldraw-link-open
 :export #'org-draw-tldraw-link-export
 :image-data-fun #'org-draw-data-fun-tldraw
 :complete (lambda (&optional arg)
             (let ((file (read-file-name "tldraw File: "))
                   (pwd  (abbreviate-file-name (expand-file-name "."))))
               (if (and arg (equal arg '(16)))
                   (concat org-draw-url-protocol-tldraw ":" (abbreviate-file-name file))
                 (string-replace pwd "" (concat org-draw-url-protocol-tldraw ":" file))))))

(provide 'org-draw)
;;; org-draw.el ends here