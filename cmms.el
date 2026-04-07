;;; cmms.el --- Simple CMMS inside Emacs -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Javier Pacheco
;; Author: Javier Pacheco [jpacheco@disroot.org](mailto:jpacheco@disroot.org)

;;; Commentary:
;; A simple Computerized Maintenance Management System (CMMS)
;; implemented entirely inside Emacs.

;;; Code:

(require 'cl-lib)
(require 'tabulated-list)

;;;; ------------------------------------------------------------------
;;;; Core variables
;;;; ------------------------------------------------------------------

(defvar cmms-company-name "My Company"
  "Company name displayed in the dashboard.")

(defvar cmms-equipment-db nil
  "Main equipment database.")

(defvar cmms-equipment-types
  '("Motor" "Pump" "Compressor" "Robot" "Furnace")
  "Available equipment types.")

(defvar cmms-areas
  '("Production" "Maintenance" "Facilities")
  "Available plant areas.")

(defvar cmms-status-list
  '("Active" "Under Repair" "Stopped")
  "Possible equipment states.")

(defvar cmms-last-id-number 0
  "Last generated equipment ID.")

(defvar-local cmms--current-filter nil
  "Active dashboard filter.")

;;;; ------------------------------------------------------------------
;;;; Internal utilities
;;;; ------------------------------------------------------------------

(defun cmms--generate-next-id ()
  "Generate the next equipment ID."
  (setq cmms-last-id-number (1+ cmms-last-id-number))
  (intern (format "EQ-%03d" cmms-last-id-number)))

(defun cmms--ensure-in-list (value list-var)
  "Ensure VALUE exists inside LIST-VAR."
  (unless (member value (symbol-value list-var))
    (set list-var
         (append (symbol-value list-var) (list value)))))

(defun cmms--equipment-at-point ()
  "Return the equipment ID at the current line."
  (tabulated-list-get-id))

;;;; ------------------------------------------------------------------
;;;; Equipment management
;;;; ------------------------------------------------------------------

(defun cmms-sync-id-counter ()
  "Synchronize ID counter with the highest existing ID."
  (interactive)

  (let ((max-id 0))

    (dolist (eq cmms-equipment-db)

      (let* ((id-str (symbol-name (car eq)))
             (num (if (string-match "[0-9]+" id-str)
                      (string-to-number (match-string 0 id-str))
                    0)))

        (when (> num max-id)
          (setq max-id num))))

    (setq cmms-last-id-number max-id)))

(defun cmms-add-equipment (id name type area status)
  "Add or update equipment."

  (cmms--ensure-in-list type 'cmms-equipment-types)
  (cmms--ensure-in-list area 'cmms-areas)

  (setf (alist-get id cmms-equipment-db)
        (list
         :name name
         :type type
         :area area
         :status status)))

(defun cmms-prompt-add-equipment ()
  "Interactive form to add equipment."
  (interactive)
  (cmms-sync-id-counter)
  (let* ((id (cmms--generate-next-id))
         (name
          (read-string (format "[%s] Name: " id)))
         (type
          (completing-read
           "Type: "
           cmms-equipment-types nil nil))
         (area
          (completing-read
           "Area: "
           cmms-areas nil nil))
         (status
          (completing-read
           "Status: "
           cmms-status-list nil t)))
    (cmms-add-equipment id name type area status)
    (cmms-refresh-table)))

(defun cmms-edit-equipment ()
  "Edit equipment at point."
  (interactive)
  (let* ((id (cmms--equipment-at-point))
         (data (alist-get id cmms-equipment-db)))
    (when id
      (let* ((name
              (read-string
               "Name: "
               (plist-get data :name)))
             (type
              (completing-read
               "Type: "
               cmms-equipment-types nil nil
               (plist-get data :type)))
             (area
              (completing-read
               "Area: "
               cmms-areas nil nil
               (plist-get data :area)))
             (status
              (completing-read
               "Status: "
               cmms-status-list nil t
               (plist-get data :status))))
        (cmms-add-equipment id name type area status)
        (cmms-refresh-table)))))

(defun cmms-delete-equipment ()
  "Delete equipment at point."
  (interactive)
  (let ((id (cmms--equipment-at-point)))
    (when (and id
               (y-or-n-p
                (format "Delete %s ? " id)))
      (setq cmms-equipment-db
            (assq-delete-all id cmms-equipment-db))
      (cmms-refresh-table))))

(defun cmms-remove-type (type)
  "Remove TYPE from `cmms-equipment-types`."
  (interactive
   (list (completing-read
          "Remove type: "
          cmms-equipment-types nil t)))

  (setq cmms-equipment-types
        (delete type cmms-equipment-types))
  (message "Type removed: %s" type))

(defun cmms-remove-area (area)
  "Remove AREA from `cmms-areas`."
  (interactive
   (list (completing-read
          "Remove area: "
          cmms-areas nil t)))

  (setq cmms-areas
        (delete area cmms-areas))

  (message "Area removed: %s" area))

;;;; ------------------------------------------------------------------
;;;; Filters
;;;; ------------------------------------------------------------------

(defun cmms-filter ()
  "Filter equipment."
  (interactive)

  (let* ((field
          (completing-read
           "Filter by: "
           '("Type" "Area" "Status") nil t))
         (value
          (cond
           ((string= field "Type")
            (completing-read "Type: " cmms-equipment-types nil t))
           ((string= field "Area")
            (completing-read "Area: " cmms-areas nil t))
           ((string= field "Status")
            (completing-read "Status: " cmms-status-list nil t))))
         (prop
          (cond
           ((string= field "Type") :type)
           ((string= field "Area") :area)
           ((string= field "Status") :status))))

    (setq cmms--current-filter (cons prop value))

    (cmms-refresh-table)))

(defun cmms-clear-filter ()
  "Clear active filter."
  (interactive)
  (setq cmms--current-filter nil)
  (cmms-refresh-table))

;;;; ------------------------------------------------------------------
;;;; Dashboard
;;;; ------------------------------------------------------------------

(defun cmms--header-string ()
  "Dynamic dashboard header."
  (let ((active 0)
        (repair 0)
        (stopped 0))
    (dolist (e cmms-equipment-db)
      (pcase (plist-get (cdr e) :status)
        ("Active"
         (cl-incf active))
        ("Under Repair"
         (cl-incf repair))
        ("Stopped"
         (cl-incf stopped))))
    (format
     " %s | Equipment:%d | Active:%d | Repair:%d | Stopped:%d "
     cmms-company-name
     (length cmms-equipment-db)
     active
     repair
     stopped)))

(defun cmms--generate-table-entries ()
  (let ((equipment cmms-equipment-db))
    (when cmms--current-filter
      (setq equipment
            (cl-remove-if-not
             (lambda (eq)
               (string=
                (plist-get (cdr eq)
                           (car cmms--current-filter))
                (cdr cmms--current-filter)))
             equipment)))
    (mapcar
     (lambda (eq)
       (let ((id (car eq))
             (p (cdr eq)))
         (list
          id
          (vector
           (symbol-name id)
           (plist-get p :name)
           (plist-get p :type)
           (plist-get p :area)
           (plist-get p :status)))))
     equipment)))

(defun cmms-refresh-table ()
  "Refresh dashboard."
  (interactive)
  (setq tabulated-list-entries
        (cmms--generate-table-entries))
  (tabulated-list-print t)
  (force-mode-line-update))

;;;; ------------------------------------------------------------------
;;;; Navigation
;;;; ------------------------------------------------------------------

(defun cmms-open-equipment ()
  "Open equipment details."
  (interactive)
  (let ((id (cmms--equipment-at-point)))
    (when id
      (message "Open equipment record: %s" id))))

;;;; ------------------------------------------------------------------
;;;; Keymap
;;;; ------------------------------------------------------------------

(defvar cmms-dashboard-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "a") #'cmms-prompt-add-equipment)
    (define-key map (kbd "e") #'cmms-edit-equipment)
    (define-key map (kbd "d") #'cmms-delete-equipment)

    (define-key map (kbd "RET") #'cmms-open-equipment)

    (define-key map (kbd "/") #'cmms-filter)

    (define-key map (kbd "g") #'cmms-refresh-table)
    (define-key map (kbd "r") #'cmms-clear-filter)

    (define-key map (kbd "q") #'quit-window)
    map))

;;;; ------------------------------------------------------------------
;;;; Evil integration
;;;; ------------------------------------------------------------------

(when (featurep 'evil)
  (evil-set-initial-state
   'cmms-dashboard-mode
   'normal)

  (evil-define-key
    'normal
    cmms-dashboard-mode-map
    (kbd "a") #'cmms-prompt-add-equipment
    (kbd "e") #'cmms-edit-equipment
    (kbd "d") #'cmms-delete-equipment
    (kbd "RET") #'cmms-open-equipment
    (kbd "/") #'cmms-filter
    (kbd "g") #'cmms-refresh-table
    (kbd "r") #'cmms-clear-filter
    (kbd "q") #'quit-window))

;;;; ------------------------------------------------------------------
;;;; Major mode
;;;; ------------------------------------------------------------------

(define-derived-mode cmms-dashboard-mode
  tabulated-list-mode
  "CMMS"
  "Main CMMS dashboard."
  (setq header-line-format
        '(:eval (cmms--header-string)))
  (setq tabulated-list-format
        [("ID" 10 t)
         ("Name" 25 t)
         ("Type" 18 t)
         ("Area" 18 t)
         ("Status" 12 t)])

  (setq tabulated-list-padding 2)
  (tabulated-list-init-header))

;;;; ------------------------------------------------------------------
;;;; Entry point
;;;; ------------------------------------------------------------------

(defun cmms ()
  "Open the CMMS dashboard."
  (interactive)

  (with-current-buffer
      (get-buffer-create "*CMMS*")
    (cmms-dashboard-mode)
    (cmms-refresh-table)
    (switch-to-buffer (current-buffer))))

(provide 'cmms)
;;; cmms.el ends here
