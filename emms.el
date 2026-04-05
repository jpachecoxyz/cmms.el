;;; emms.el --- Emacs Maintenance Management System -*- lexical-binding: t; -*-

;; Author: Ing. Javier Pacheco
;; Version: 0.1
;; Package-Requires: ((emacs "29.1") (org "9.6"))
;; Keywords: org, maintenance, assets
;; URL: https://github.com/jpachecoxyz/emms.el

;;; Commentary:

;; emms.el provides a simple CMMS-style asset management
;; system built on top of Org Mode.

;;; Code:

(require 'org)
(require 'tabulated-list)

;;;; Core

(defgroup emms nil
"Emacs Maintenance Management System."
:group 'applications)

(defcustom emms-directory
(expand-file-name "/tmp/emms/")
"Directory where EMMS stores data."
:type 'directory)

(defcustom emms-assets-file
(expand-file-name "assets.org" emms-directory)
"Assets database file."
:type 'file)

(defcustom emms-workorders-file
(expand-file-name "workorders.org" emms-directory)
"Work orders database file."
:type 'file)

(defun emms--ensure-environment ()
"Ensure EMMS directory and files exist."
(unless (file-directory-p emms-directory)
(make-directory emms-directory t))

(dolist (file (list emms-assets-file emms-workorders-file))
(unless (file-exists-p file)
(with-temp-buffer
(write-file file)))))

;;;; Assets

(defun emms-asset-create (name area)
"Create new asset."
(interactive "sAsset name: \nsArea: ")
(emms--ensure-environment)

(with-current-buffer (find-file-noselect emms-assets-file)
(goto-char (point-max))

(insert
 (format "** %s\n:PROPERTIES:\n:TYPE: asset\n:AREA: %s\n:END:\n\n"
         name area))

(save-buffer)))

;;;; Areas

(defun emms-area-create (name)
"Create a new area."
(interactive "sArea name: ")
(emms--ensure-environment)

(with-current-buffer (find-file-noselect emms-assets-file)
(goto-char (point-max))

(insert
 (format "* Area: %s\n:PROPERTIES:\n:TYPE: area\n:END:\n\n"
         name))

(save-buffer)))

;;;; Workorders

(defun emms-workorder-create (asset description)
"Create work order."
(interactive "sAsset: \nsDescription: ")
(emms--ensure-environment)

(with-current-buffer (find-file-noselect emms-workorders-file)
(goto-char (point-max))

(insert
 (format "* WO-%s\n:PROPERTIES:\n:ASSET: %s\n:STATUS: OPEN\n:END:\n\n%s\n\n"
         (format-time-string "%Y%m%d%H%M")
         asset
         description))

(save-buffer)))

;;;; Dashboard

(defvar emms-dashboard-buffer "*EMMS*")

(define-derived-mode emms-dashboard-mode tabulated-list-mode "EMMS"
  "Major mode for EMMS dashboard."

  (setq tabulated-list-format [("Section" 30 t)])

  (setq tabulated-list-entries
        '(("areas" ["Areas"])
          ("assets" ["Assets"])
          ("workorders" ["Work Orders"])))

  (tabulated-list-init-header)

  (define-key emms-dashboard-mode-map (kbd "RET") #'emms-dashboard-open))

(defun emms-dashboard ()
"Open EMMS dashboard."
(interactive)
(emms--ensure-environment)

(switch-to-buffer emms-dashboard-buffer)
(emms-dashboard-mode)
(tabulated-list-print))

(defun emms-dashboard-open ()
  "Open section at point."
  (interactive)
  (let ((id (tabulated-list-get-id)))
    (pcase id
      ("areas"
       (find-file emms-assets-file))
      ("assets"
       (find-file emms-assets-file))
      ("workorders"
       (find-file emms-workorders-file)))))

;;;; Keybindings

(defvar emms-command-map
(let ((map (make-sparse-keymap)))
(define-key map (kbd "d") #'emms-dashboard)
(define-key map (kbd "a") #'emms-area-create)
(define-key map (kbd "e") #'emms-asset-create)
(define-key map (kbd "w") #'emms-workorder-create)
map)
"Keymap for EMMS commands.")

(define-key global-map (kbd "C-c m") emms-command-map)

(provide 'emms)

;;; emms.el ends here
