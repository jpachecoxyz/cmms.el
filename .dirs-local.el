;;; Directory Local Variables
;;; For more information see (info "(emacs) Directory Variables")

((emacs-lisp-mode
  . ((indent-tabs-mode . nil)
     (eval . (load-file (expand-file-name "emms.el"
                                          (locate-dominating-file default-directory ".dir-locals.el"))))

     (eval . (load-file (expand-file-name "cmms.el"
                                          (locate-dominating-file default-directory ".dir-locals.el")))))))
