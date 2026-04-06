;;; cmms.el --- CMMS but in elisp -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Javier Pacheco
;; Author: Javier Pacheco <jpacheco@disroot.org>

;;; Commentary:
;; Sistema simple de gestión de mantenimiento (CMMS) dentro de Emacs.

;;; Code:

(require 'cl-lib)
(require 'tabulated-list)

;;;; ------------------------------------------------------------------
;;;; Variables principales
;;;; ------------------------------------------------------------------

(defvar cmms-company-name "Mi Empresa"
  "Nombre de la empresa mostrado en el dashboard.")

(defvar cmms-equipos nil
  "Base de datos principal de equipos.")

(defvar cmms-tipos-equipo
  '("Motor" "Bomba" "Compresor" "Robot" "Horno")
  "Tipos de equipo disponibles.")

(defvar cmms-areas
  '("Producción" "Mantenimiento" "Facilities")
  "Áreas disponibles en planta.")

(defvar cmms-estados
  '("Activo" "En Reparación" "Detenido")
  "Estados posibles de un equipo.")

(defvar cmms-ultimo-id-numero 0
  "Último ID generado.")

(defvar-local cmms--filtro-actual nil
  "Filtro activo del dashboard.")

;;;; ------------------------------------------------------------------
;;;; Utilidades internas
;;;; ------------------------------------------------------------------

(defun cmms--generar-proximo-id ()
  "Genera el siguiente ID de equipo."
  (setq cmms-ultimo-id-numero (1+ cmms-ultimo-id-numero))
  (intern (format "EQ-%03d" cmms-ultimo-id-numero)))

(defun cmms--asegurar-en-lista (valor lista-var)
  "Si VALOR no está en LISTA-VAR lo agrega."
  (unless (member valor (symbol-value lista-var))
    (set lista-var
         (append (symbol-value lista-var) (list valor)))))

(defun cmms--equipo-en-linea ()
  "Obtiene el ID del equipo en la línea actual."
  (tabulated-list-get-id))

;;;; ------------------------------------------------------------------
;;;; Agregar / editar / eliminar equipos
;;;; ------------------------------------------------------------------

(defun cmms-sincronizar-contador-id ()
  "Ajusta el contador basándose en el ID más alto existente en cmms-equipos'."
  (interactive)
  (let
      ((max-id 0)) (dolist (equipo cmms-equipos)
                     (let* ((id-str (symbol-name (car equipo)))
                            ;; Extraemos el número del string "EQ-005" -> 5
                            (num (if (string-match "[0-9]+" id-str)
                                     (string-to-number (match-string 0 id-str)) 0)))
                       (when (> num max-id) (setq max-id num))))
      (setq cmms-ultimo-id-numero max-id)
      ;; (message "Contador de IDs sincronizado en: %d" max-id)
      ))

(defun cmms-agregar-equipo (id nombre tipo area estado)
  "Agrega o actualiza un equipo."

  (cmms--asegurar-en-lista tipo 'cmms-tipos-equipo)
  (cmms--asegurar-en-lista area 'cmms-areas)

  (setf (alist-get id cmms-equipos)
        (list
         :nombre nombre
         :tipo tipo
         :area area
         :estado estado)))

(defun cmms-prompt-agregar-equipo ()
  "Formulario interactivo para agregar equipo."
  (interactive)

  (cmms-sincronizar-contador-id)
  (let* ((id (cmms--generar-proximo-id))

         (nombre
          (read-string (format "[%s] Nombre: " id)))

         (tipo
          (completing-read
           "Tipo: "
           cmms-tipos-equipo nil nil))

         (area
          (completing-read
           "Área: "
           cmms-areas nil nil))

         (estado
          (completing-read
           "Estado: "
           cmms-estados nil t)))

    (cmms-agregar-equipo id nombre tipo area estado)
    (cmms-refrescar-tabla)))

(defun cmms-editar-equipo ()
  "Editar equipo en la línea actual."
  (interactive)

  (let* ((id (cmms--equipo-en-linea))
         (datos (alist-get id cmms-equipos)))

    (when id

      (let* ((nombre
              (read-string
               "Nombre: "
               (plist-get datos :nombre)))

             (tipo
              (completing-read
               "Tipo: "
               cmms-tipos-equipo nil nil
               (plist-get datos :tipo)))

             (area
              (completing-read
               "Área: "
               cmms-areas nil nil
               (plist-get datos :area)))

             (estado
              (completing-read
               "Estado: "
               cmms-estados nil t
               (plist-get datos :estado))))

        (cmms-agregar-equipo id nombre tipo area estado)
        (cmms-refrescar-tabla)))))

(defun cmms-eliminar-equipo ()
  "Eliminar equipo actual."
  (interactive)

  (let ((id (cmms--equipo-en-linea)))

    (when (and id
               (y-or-n-p
                (format "Eliminar %s ? " id)))

      (setq cmms-equipos
            (assq-delete-all id cmms-equipos))

      (cmms-refrescar-tabla))))


(defun cmms-remove-type (type)
  "Remove EQUIPO from `cmms-tipos-equipo`."
  (interactive
   (list (completing-read "Remove category: " cmms-tipos-equipo nil t)))
  (setq cmms-categorias
        (delete-dups
         (delete type cmms-tipos-equipo)))
  (message "Category removed: %s" type))

(defun cmms-remove-area (area)
  "Remove AREA from `cmms-areas`."
  (interactive
   (list (completing-read "Remove area: " cmms-areas nil t)))
  (setq cmms-categorias
        (delete-dups
         (delete area cmms-areas)))
  (message "Area removed: %s" area))

;;;; ------------------------------------------------------------------
;;;; Filtros
;;;; ------------------------------------------------------------------
(defun cmms-filtrar ()
  "Filtrar equipos."
  (interactive)

  (let* ((campo
          (completing-read
           "Filtrar por: "
           '("Tipo" "Área" "Estado")
           nil t))

         (valor
          (cond
           ((string= campo "Tipo")
            (completing-read "Tipo: " cmms-tipos-equipo nil t))

           ((string= campo "Área")
            (completing-read "Área: " cmms-areas nil t))

           ((string= campo "Estado")
            (completing-read "Estado: " cmms-estados nil t))))

         (prop
          (cond
           ((string= campo "Tipo") :tipo)
           ((string= campo "Área") :area)
           ((string= campo "Estado") :estado))))

    (setq cmms--filtro-actual (cons prop valor))

    (cmms-refrescar-tabla)))

(defun cmms-limpiar-filtro ()
  "Eliminar filtro."
  (interactive)

  (setq cmms--filtro-actual nil)

  (cmms-refrescar-tabla))

;;;; ------------------------------------------------------------------
;;;; Dashboard / Tabla
;;;; ------------------------------------------------------------------

(defun cmms--header-string ()
  "Header dinámico del dashboard."

  (let ((activos 0)
        (reparacion 0)
        (detenidos 0))

    (dolist (e cmms-equipos)

      (pcase (plist-get (cdr e) :estado)

        ("Activo"
         (cl-incf activos))

        ("En Reparación"
         (cl-incf reparacion))

        ("Detenido"
         (cl-incf detenidos))))

    (format
     " %s | Equipos:%d | Activos:%d | Reparación:%d | Detenidos:%d "
     cmms-company-name
     (length cmms-equipos)
     activos
     reparacion
     detenidos)))

(defun cmms--generar-entradas-tabla ()

  (let ((equipos cmms-equipos))

    (when cmms--filtro-actual

      (setq equipos
            (cl-remove-if-not
             (lambda (eq)

               (string=
                (plist-get (cdr eq)
                           (car cmms--filtro-actual))
                (cdr cmms--filtro-actual)))

             equipos)))

    (mapcar

     (lambda (equipo)

       (let ((id (car equipo))
             (p (cdr equipo)))

         (list
          id
          (vector

           (symbol-name id)
           (plist-get p :nombre)
           (plist-get p :tipo)
           (plist-get p :area)
           (plist-get p :estado)))))

     equipos)))

(defun cmms-refrescar-tabla ()
  "Refrescar dashboard."
  (interactive)

  (setq tabulated-list-entries
        (cmms--generar-entradas-tabla))

  (tabulated-list-print t)

  (force-mode-line-update))

;;;; ------------------------------------------------------------------
;;;; Navegación
;;;; ------------------------------------------------------------------

(defun cmms-abrir-equipo ()
  "Abrir detalles del equipo."
  (interactive)

  (let ((id (cmms--equipo-en-linea)))

    (when id
      (message "Abrir ficha del equipo: %s" id))))

;;;; ------------------------------------------------------------------
;;;; Keybindings
;;;; ------------------------------------------------------------------

(defvar cmms-equipos-mode-map

  (let ((map (make-sparse-keymap)))

    (define-key map (kbd "a") #'cmms-prompt-agregar-equipo)
    (define-key map (kbd "e") #'cmms-editar-equipo)
    (define-key map (kbd "d") #'cmms-eliminar-equipo)

    (define-key map (kbd "RET") #'cmms-abrir-equipo)

    (define-key map (kbd "/") #'cmms-filtrar)

    (define-key map (kbd "g") #'cmms-refrescar-tabla)
    (define-key map (kbd "r") #'cmms-limpiar-filtro)

    (define-key map (kbd "q") #'quit-window)

    map))

;;;; ------------------------------------------------------------------
;;;; Evil support
;;;; ------------------------------------------------------------------

(when (featurep 'evil)

  (evil-set-initial-state
   'cmms-equipos-mode
   'normal)

  (evil-define-key
    'normal
    cmms-equipos-mode-map

    (kbd "a") #'cmms-prompt-agregar-equipo
    (kbd "e") #'cmms-editar-equipo
    (kbd "d") #'cmms-eliminar-equipo
    (kbd "RET") #'cmms-abrir-equipo
    (kbd "/") #'cmms-filtrar
    (kbd "g") #'cmms-refrescar-tabla
    (kbd "r") #'cmms-limpiar-filtro
    (kbd "q") #'quit-window))

;;;; ------------------------------------------------------------------
;;;; Major mode
;;;; ------------------------------------------------------------------

(define-derived-mode cmms-equipos-mode
  tabulated-list-mode
  "CMMS"

  "Modo principal del dashboard CMMS."

  (setq header-line-format
        '(:eval (cmms--header-string)))

  (setq tabulated-list-format
        [("ID" 10 t)
         ("Nombre" 25 t)
         ("Tipo" 18 t)
         ("Área" 18 t)
         ("Estado" 12 t)])

  (setq tabulated-list-padding 2)

  (tabulated-list-init-header))

;;;; ------------------------------------------------------------------
;;;; Comando principal
;;;; ------------------------------------------------------------------

(defun cmms ()
  "Abrir dashboard CMMS."
  (interactive)

  (with-current-buffer
      (get-buffer-create "*CMMS*")

    (cmms-equipos-mode)

    (cmms-refrescar-tabla)

    (switch-to-buffer (current-buffer))))

(provide 'cmms)

;;; cmms.el ends here
