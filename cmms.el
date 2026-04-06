;;; cmms.el --- CMMS but in elisp -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Javier Pacheco

;; Author: Javier Pacheco <javier@jpacheco.xyz>
;; Maintainer: Javier Pacheco <javier@jpacheco.xyz>
;; Created: 2026-04-06
;; Version: 0.1
;; Package-Requires: ()
;; Keywords: cmms, maintenance, engineer
;; Homepage: https://github.com/jpachecoxyz/cmms

;;; Commentary:

;; Descripción del paquete

;;; Code:

(require 'cl-lib) ;; Necesario para funciones útiles como cl-remove-if-not

;; 1. Función para agregar o actualizar un equipo
(defun cmms-agregar-equipo (id nombre tipo area estado)
  "Agrega un nuevo equipo a `cmms-equipos' o lo actualiza si el ID ya existe.
ID debe ser un símbolo (ej. 'eq-004)."
  (let ((nuevos-datos (list :nombre nombre :tipo tipo :area area :estado estado)))
    (setf (alist-get id cmms-equipos) nuevos-datos))
  (message "Equipo %s guardado correctamente." id))

;; Ejemplo de uso:
;; (cmms-agregar-equipo 'eq-004 "Compresor B" "Compresor" "Servicios Generales" "Activo")

;; 2. Función para obtener un equipo por su ID
(defun cmms-obtener-equipo (id)
  "Devuelve las propiedades del equipo con el ID dado."
  (cdr (assoc id cmms-equipos)))

;; 3. Función para filtrar equipos por Área
(defun cmms-filtrar-por-area (area-buscada)
  "Devuelve una lista de equipos que pertenecen a AREA-BUSCADA."
  (cl-remove-if-not
   (lambda (equipo)
     (string= (plist-get (cdr equipo) :area) area-buscada))
   cmms-equipos))


;; Definimos nuestro modo derivado de tabulated-list-mode
(define-derived-mode cmms-equipos-mode tabulated-list-mode "CMMS"
  "Modo principal para visualizar el inventario de equipos del CMMS."
  ;; Definimos las columnas y sus anchos (el último parámetro 't' permite ordenar al hacer clic)
  (setq tabulated-list-format [("ID" 10 t)
                               ("Nombre" 25 t)
                               ("Tipo" 20 t)
                               ("Área" 20 t)
                               ("Estado" 15 t)])
  (setq tabulated-list-padding 2)
  (setq tabulated-list-sort-key (cons "ID" nil))
  (tabulated-list-init-header))

;; Función para transformar nuestra Alist al formato que exige tabulated-list
(defun cmms--generar-entradas-tabla ()
  "Convierte `cmms-equipos' en el formato requerido por `tabulated-list-entries'."
  (mapcar (lambda (equipo)
            (let* ((id (car equipo))
                   (props (cdr equipo))
                   (id-str (symbol-name id)))
              ;; Formato: (ID_INTERNO [COL1 COL2 COL3 ...])
              (list id
                    (vector id-str
                            (plist-get props :nombre)
                            (plist-get props :tipo)
                            (plist-get props :area)
                            (plist-get props :estado)))))
          cmms-equipos))

;; Comando interactivo para abrir el CMMS
;; (defun cmms ()
;;   "Abre la interfaz principal del CMMS."
;;   (interactive)
;;   ;; Creamos o cambiamos al buffer del CMMS
;;   (let ((buffer (get-buffer-create "*CMMS Inventario*")))
;;     (with-current-buffer buffer
;;       (cmms-equipos-mode)
;;       (setq tabulated-list-entries (cmms--generar-entradas-tabla))
;;       (tabulated-list-print t)) ; Imprime la tabla
;;     (switch-to-buffer buffer)))

(defvar cmms-areas 
  '("Producción" "Mantenimiento" "Servicios Generales" "Diecasting")
  "Lista de las áreas físicas o departamentos de la planta.")

(defvar cmms-tipos-equipo 
  '("Motor" "Bomba" "DCM" "Compresor" "Tablero Eléctrico" "Horno" "Periferico")
  "Catálogo de los diferentes tipos de equipos.")

(defvar cmms-equipos
  '((eq-001 . (:nombre "Motor Principal" :tipo "Motor" :area "Producción" :estado "Activo"))
    (eq-002 . (:nombre "Bomba de Agua" :tipo "Bomba" :area "Mantenimiento" :estado "En Reparación"))
    (eq-003 . (:nombre "Banda A" :tipo "Banda Transportadora" :area "Empaque" :estado "Activo")))
  "Base de datos principal de los equipos.")

;; Ejemplo de cómo leer datos de un equipo:
;; (plist-get (alist-get 'eq-001 cmms-equipos) :nombre)  => "Motor Principal

(defvar cmms-estados
  '("Activo" "En Reparacion" "Detenido")
  "Estados posibles de un equipo.")

(defun cmms-next-equipo-id ()
  "Genera el siguiente ID secuencial para equipos."
  (let ((n (1+ (length cmms-equipos))))
    (intern (format "eq-%03d" n))))

(defun cmms-prompt-agregar-equipo ()
  "Formulario interactivo para agregar un equipo con ID autosecuencial."
  (interactive)
  (let* ((nuevo-id (cmms--generar-proximo-id))
         ;; Informamos al usuario qué ID se está generando en el prompt del nombre
         (nombre (read-string (format "[ID: %s] Nombre del Equipo: " nuevo-id)))
         (tipo (completing-read "Tipo de Equipo: " cmms-tipos-equipo nil t))
         (area (completing-read "Área: " cmms-areas nil t))
         (estado (completing-read "Estado inicial: " '("Activo" "En Reparación" "Baja") nil t)))
    
    ;; Guardamos el equipo
    (cmms-agregar-equipo nuevo-id nombre tipo area estado)
    
    ;; Refrescamos la tabla si el buffer está abierto
    (when (get-buffer "*CMMS Inventario*")
      (cmms-refrescar-tabla))
    
    (message "Equipo guardado exitosamente con el ID: %s" nuevo-id)))

(defvar-local cmms--filtro-actual nil
  "Almacena el filtro activo en el buffer actual. Formato: (tipo-o-area . \"valor\")")

(defun cmms-refrescar-tabla ()
  "Recalcula las entradas de la tabla aplicando filtros si existen."
  (interactive)
  (let ((equipos-visibles cmms-equipos))
    ;; Si hay un filtro activo, aplicamos la lógica de filtrado
    (when cmms--filtro-actual
      (let ((campo (car cmms--filtro-actual))
            (valor (cdr cmms--filtro-actual)))
        (setq equipos-visibles
              (cl-remove-if-not
               (lambda (eq-pair)
                 (string= (plist-get (cdr eq-pair) campo) valor))
               cmms-equipos))))
    
    ;; Actualizamos el buffer
    (setq tabulated-list-entries 
          (mapcar (lambda (equipo)
                    (let ((id (car equipo))
                          (p (cdr equipo)))
                      (list id (vector (symbol-name id) 
                                       (plist-get p :nombre)
                                       (plist-get p :tipo)
                                       (plist-get p :area)
                                       (plist-get p :estado)))))
                  equipos-visibles))
    (tabulated-list-print t)))

;; Comandos de filtrado interactivo
(defun cmms-filtrar-por-tipo ()
  (interactive)
  (let ((val (completing-read "Filtrar por Tipo: " cmms-tipos-equipo nil t)))
    (setq cmms--filtro-actual (cons :tipo val))
    (cmms-refrescar-tabla)
    (message "Filtrado por tipo: %s" val)))

(defun cmms-filtrar-por-area ()
  (interactive)
  (let ((val (completing-read "Filtrar por Área: " cmms-areas nil t)))
    (setq cmms--filtro-actual (cons :area val))
    (cmms-refrescar-tabla)
    (message "Filtrado por área: %s" val)))

(defun cmms-limpiar-filtro ()
  (interactive)
  (setq cmms--filtro-actual nil)
  (cmms-refrescar-tabla)
  (message "Filtros eliminados."))

;; Definimos los atajos de teclado para el modo CMMS
(defvar cmms-equipos-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c a") 'cmms-prompt-agregar-equipo)
    (define-key map (kbd "C-c f") 'cmms-filtrar-por-tipo)
    (define-key map (kbd "C-c F") 'cmms-filtrar-por-area)
    (define-key map (kbd "C-c c") 'cmms-limpiar-filtro) ;; 'c' de clear/cancelar
    (define-key map (kbd "C-c g")   'cmms-refrescar-tabla)
    map)
  "Keymap para `cmms-equipos-mode'.")

(define-derived-mode cmms-equipos-mode tabulated-list-mode "CMMS"
  "Modo para gestión de mantenimiento."
  (setq tabulated-list-format [("ID" 10 t) ("Nombre" 25 t) ("Tipo" 18 t) ("Área" 18 t) ("Estado" 12 t)])
  (setq tabulated-list-padding 2)
  (tabulated-list-init-header))

;; Modificamos el comando principal para que use la nueva lógica de refresco
(defun cmms ()
  "Inicia la interfaz del CMMS."
  (interactive)
  (with-current-buffer (get-buffer-create "*CMMS Inventario*")
    (cmms-equipos-mode)
    (cmms-refrescar-tabla)
    (switch-to-buffer (current-buffer))))

(defvar cmms-ultimo-id-numero 0
  "Almacena el último número secuencial utilizado para los equipos.")

(defun cmms--generar-proximo-id ()
  "Incrementa el contador y devuelve un símbolo con formato 'EQ-001'."
  (setq cmms-ultimo-id-numero (1+ cmms-ultimo-id-numero))
  (intern (format "EQ-%03d" cmms-ultimo-id-numero)))

(defun cmms-sincronizar-contador-id ()
  "Ajusta el contador basándose en el ID más alto existente en `cmms-equipos'."
  (interactive)
  (let ((max-id 0))
    (dolist (equipo cmms-equipos)
      (let* ((id-str (symbol-name (car equipo)))
             ;; Extraemos el número del string "EQ-005" -> 5
             (num (if (string-match "[0-9]+" id-str)
                      (string-to-number (match-string 0 id-str))
                    0)))
        (when (> num max-id) (setq max-id num))))
    (setq cmms-ultimo-id-numero max-id)
    (message "Contador de IDs sincronizado en: %d" max-id)))

;;; Default Variables

(setq cmms-ultimo-id-numero 0)
(setq cmms-tipos-equipo '("DCM" "Robot" "Sprayer" "Horno"))
(setq cmms-equipos nil)
(setq cmms-areas '("Diecasting" "Facilities"))

(provide 'cmms)

;;; cmms.el ends here
