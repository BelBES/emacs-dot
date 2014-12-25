(require 'cl-lib)
(require 'dired-x)

;; lose UI early
(if (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(if (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))

;; no splash screen
(setq inhibit-startup-message t)
(setq mac-command-modifier 'meta)
(setq initial-scratch-message nil)

;; ------------------------------------------------------------
;; Set Dark GUI Theme
;; ------------------------------------------------------------
(load-theme 'tango-dark)
(enable-theme 'tango-dark)
;; make background a little darker
(set-background-color "#1d1f21")

;; ------------------------------------------------------------
;; EXTERNAL PACKAGES
;; initialization
;; ------------------------------------------------------------

(setq package-archives '(("org-mode" . "http://orgmode.org/elpa/")
			 ("gnu" . "http://elpa.gnu.org/packages/")
			 ("melpa" . "http://melpa.milkbox.net/packages/")
			 ))
(setq package-enable-at-startup nil)
(package-initialize)
;; check if the required packages are installed; suggest installing if not
(map-y-or-n-p
 "Package %s is missing. Install? "
 '(lambda (package)
    ;; for some reason, package-install doesn't work well if you
    ;; won't call package-refresh-contents beforehand
    (unless (boundp '--package-contents-refreshed-on-init)
      (package-refresh-contents)
      (setq --package-contents-refreshed-on-init 1))
    (package-install package))
 (cl-remove-if 'package-installed-p
	       '(
		 dired-details
		 window-numbering
		 revive
		 cmake-mode
		 auto-complete-clang
		 yasnippet
		 auto-complete
		 auto-complete-c-headers
		 magit
         multiple-cursors
		 ))
 '("package" "packages" "install"))

;; define translations
(define-key key-translation-map [?\C-h] [?\C-?]) ;; translate C-h to DEL

;; ------------------------------------------------------------
;; built-in
;; ------------------------------------------------------------
(require 'ido)
(ido-mode t)
(setq ido-enable-flex-matching t)

(require 'ibuffer nil t)

;; ibuffer groups
(setq-default ibuffer-saved-filter-groups
			  (quote (("default"
					   ("org"  (mode . org-mode))
					   ("dired" (mode . dired-mode))
					   ("D" (mode . d-mode))
					   ("C/C++" (or
								 (mode . cc-mode)
								 (mode . c-mode)
								 (mode . c++-mode)))
					   ("magit" (name . "^\\*magit"))
					   ("Markdown" (mode . markdown-mode))
					   ("emacs" (name . "^\\*Messages\\*$"))
					   ("shell commands" (name . "^\\*.*Shell Command\\*"))))))

(add-hook 'ibuffer-mode-hook
		  (lambda ()
			(ibuffer-switch-to-saved-filter-groups "default")))

(global-set-key (kbd "\C-x \C-b") 'ibuffer)

;; ------------------------------------------------------------
;; Save backup files into specialize directory
;; ------------------------------------------------------------
(setq backup-directory-alist '(("." . "~/.emacs.d/backup"))
      backup-by-copying t    ; Don't delink hardlinks
      version-control t      ; Use version numbers on backups
      delete-old-versions t  ; Automatically delete excess backups
      kept-new-versions 20   ; how many of the newest versions to keep
      kept-old-versions 5    ; and how many of the old
      )

;;----------------------------------------------------------------------------
;; Enable automatic spell checking
;;----------------------------------------------------------------------------
(add-hook 'text-mode-hook 'flyspell-mode)
(add-hook 'prog-mode-hook 'flyspell-mode)

;; dired-details
(eval-after-load "dired-details-autoloads"
  '(progn
     (when (require 'dired-details nil t)
       (add-hook 'dired-mode-hook
		 '(lambda ()
		    (dired-details-install)
		    (setq dired-details-nhidden-string "--- ")
		    (define-key dired-mode-map (kbd "h") 'dired-details-toggle))))))

(eval-after-load "window-numbering-autoloads"
  '(progn
     (if (require 'window-numbering nil t)
	 (window-numbering-mode 1)
       (warn "window-numbering-mode not found"))))


;; ------------------------------------------------------------
;; ADVICES
(defadvice insert-for-yank-1 (after indent-region activate)
  "Indent yanked region in certain modes, C-u prefix to disable"
  (if (and (not current-prefix-arg)
	   (member major-mode '(sh-mode
				emacs-lisp-mode lisp-mode
				c-mode c++-mode objc-mode d-mode java-mode cuda-mode
				LaTeX-mode TeX-mode
				xml-mode html-mode css-mode)))
      (indent-region (region-beginning) (region-end) nil)))

(eval-after-load "revive-autoloads"
  '(progn
     (when (require 'revive nil t)
       (defun revive-save-window-configuration ()
         (interactive)
         (save-window-excursion
           (let ((config (prin1-to-string (current-window-configuration-printable))))
             (find-file "~/.revive-windows.el")
             (erase-buffer)
             (insert config)
             (save-buffer))))
       (defun revive-restore-window-configuration ()
         (interactive)
         (let ((config))
           (save-window-excursion
             (find-file "~/.revive-windows.el")
             (beginning-of-buffer)
             (setq config (read (current-buffer)))
             (kill-buffer))
           (restore-window-configuration config)))
       (define-key ctl-x-map "S" 'revive-save-window-configuration)
       (define-key ctl-x-map "R" 'revive-restore-window-configuration)
       (revive-restore-window-configuration))))

;; ------------------------------------------------------------
;; magit
;; ------------------------------------------------------------
(require 'magit)


;; ------------------------------------------------------------
;; org-mode
;; ------------------------------------------------------------
(add-hook 'org-mode-hook (lambda ()
                           (toggle-truncate-lines -1)))

;; ------------------------------------------------------------
;; multiple-cursor
;; ------------------------------------------------------------
(eval-after-load "multiple-cursors-autoloads"
  '(progn
     (when (require 'multiple-cursors nil t)
       (defun mc/mark-all-dispatch ()
         "- add a fake cursor at current position

- call mc/edit-lines if multiple lines are marked

- call mc/mark-all-like-this if marked region is on a single line"
         (interactive)
         (cond
          ((not (region-active-p))
           (mc/create-fake-cursor-at-point)
           (mc/maybe-multiple-cursors-mode))
          ((> (- (line-number-at-pos (region-end))
                 (line-number-at-pos (region-beginning))) 0)
           (mc/edit-lines))
          (t
           (mc/mark-all-like-this))))

       (defun mc/align ()
         "Aligns all the cursor vertically."
         (interactive)
         (let ((max-column 0)
               (cursors-column '()))
           (mc/for-each-cursor-ordered
            (mc/save-excursion
             (goto-char (overlay-start cursor))
             (let ((cur (current-column)))
               (setq cursors-column (append cursors-column (list cur)))
               (setq max-column (if (< max-column cur) cur max-column)))))

           (defun mc--align-insert-times ()
             (interactive)
             (dotimes (_ times)
               (insert " ")))

           (mc/for-each-cursor-ordered
            (let ((times (- max-column (car cursors-column))))
              (mc/execute-command-for-fake-cursor 'mc--align-insert-times cursor))
            (setq cursors-column (cdr cursors-column)))))

       (setq mc/list-file "~/.mc-lists.el")
       (load mc/list-file t) ;; load, but no errors if it does not exist yet please

       (global-set-key (kbd "C->")  'mc/mark-next-like-this)
       (global-set-key (kbd "C-<")  'mc/mark-previous-like-this)

       (global-set-key (kbd "M-@") 'mc/mark-all-dispatch)
       (global-set-key (kbd "M-#") 'mc/insert-numbers)
       (global-set-key (kbd "M-'") 'mc/align))))

;; ------------------------------------------------------------
;; IDE for C/C++
;; ------------------------------------------------------------

(require 'cc-mode)
(global-set-key (kbd "C-x C-i") 'linum-mode)

(setq-default c-basic-offset 4 c-default-style "linux")
(setq-default tab-width 4 indent-tabs-mode t)
(define-key c-mode-base-map (kbd "RET") 'newline-and-indent)

(defun my-c++-mode-hook ()
  (setq c-basic-offset 4)
  (c-set-offset 'substatement-open 0))
(add-hook 'c++-mode-hook 'my-c++-mode-hook)

; start auto-complete with emacs
(require 'auto-complete)
; do default config for auto-complete
(require 'auto-complete-config)
(ac-config-default)

(c-add-style "my" '("gnu"
                    (c-offsets-alist . ((innamespace . [0])))))

(add-hook 'c++-mode-hook (lambda ()
                           (c-set-style "my")))

;; yasnippet
(require 'yasnippet)
(yas-global-mode 1)

(defun my:ac-c-headers-init ()
  (require 'auto-complete-c-headers)
  (add-to-list 'ac-sources 'ac-source-c-headers)
  (add-to-list 'achead:include-directories '"/usr/lib/gcc/x86_64-linux-gnu/4.8/include")
)

(add-hook 'c++-mode-hook 'my:ac-c-headers-init)
(add-hook 'c-mode-hook 'my:ac-c-headers-init)

; Add cmake listfile names to the mode list.
(require 'cmake-mode)
(setq auto-mode-alist
	  (append
	   '(("CMakeLists\\.txt\\'" . cmake-mode))
	   '(("\\.cmake\\'" . cmake-mode))
	   auto-mode-alist))

(autoload 'cmake-mode "~/CMake/Auxiliary/cmake-mode.el" t)

(defun parent-directory (dir)
  "Returns parent directory of dir"
  (when dir
	(file-name-directory (directory-file-name (expand-file-name dir)))))
(defun search-file-up (name &optional path)
  "Searches for file `name' in parent directories recursively"
  (let* ((file-name (concat path name))
		 (parent (parent-directory path))
		 (path (or path default-directory)))
	(cond
	 ((file-exists-p file-name) file-name)
	 ((string= parent path) nil)
	 (t (search-file-up name parent)))))

(defun update-tags-file (arg)
  "Suggests options to update the TAGS file via ctags.
With prefix arg - makes a call as sudo. Works for remote hosts
also (>=23.4)"
  (interactive "P")
  (let ((tags-file-name
		 (read-file-name
		  "TAGS file: " (let ((fn (search-file-up "TAGS" default-directory)))
						  (if fn
							  (parent-directory fn)
							default-directory))
		  nil nil "TAGS"))
		(ctags-command "")
		(languages (case major-mode
					 ((cc-mode c++-mode c-mode) "--languages=C,C++")
					 ((d-mode) "--languages=D")
					 (t ""))))
	(when tags-file-name
	  (setq ctags-command (concat ctags-command "cd " (replace-regexp-in-string ".*:" "" (file-name-directory tags-file-name)) " && ")))
	(setq ctags-command (concat ctags-command "ctags -e " languages " -R . "))
	(with-temp-buffer
	  (when arg
		(cd (add-sudo-to-filename (expand-file-name default-directory))))
	  (shell-command (read-from-minibuffer "ctags command: " ctags-command)))
	(visit-tags-table tags-file-name)))

(setq-default tab-width 4)
(setq-default indent-tabs-mode nil)
(add-hook 'before-save-hook 'delete-trailing-whitespace)
(setq-default line-number-mode t)
(setq-default column-number-mode t)
(fset 'yes-or-no-p 'y-or-n-p)
;; navigation between buffers
(global-set-key "\C-x\C-p" 'previous-buffer)
(global-set-key "\C-x\C-n" 'next-buffer)
(global-set-key "\C-x\C-\\" 'other-window)

(global-set-key "\C-x\C-u"          'update-tags-file)
(global-set-key "\C-x\C-v"          'visit-tags-table)
(global-set-key "\C-x\C-t"          'tags-reset-tags-tables)
(global-set-key "\C-x\C-l"          'tags-apropos)
