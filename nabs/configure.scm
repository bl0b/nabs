(define-module (nabs configure)
               :use-module (nabs tools)
               :use-module (nabs find)
               :use-module (nabs predicates)
               ;:use-module (ice-9 match)
               :use-module (ice-9 vlist)
               :use-module (srfi srfi-1)
               :use-module (gnu make)
               :re-export (checks)
               :re-export (find-file-by-prefix)
               :re-export (find-file-by-path-suffix)
               :re-export (find-file-by-exact-name)
               :export (declare
                        verifies
                        add-search-path
                        ~add-search-path
                        configure-include
                        configure-frontend
                        write-frontend
                        ))

; export predicates
;(module-for-each (lambda (k v) (print k " --> " v "\n")(re-export (k v))) (resolve-interface '(nabs predicates)))

(define configurables '())
(define-public (dump-configurables) configurables)

(define ~search-path vlist-null)
(define-public (dump-search-path) (vhash-fold-right (lambda (k v r) (cons (list k v) r)) '() ~search-path))

(define (~add-search-path tag . path)
  (let ((exists? (vhash-assoc tag ~search-path)))
    (set! ~search-path
      (if exists?
        (vhash-fold-right (lambda (k v r)
                            (if (equal? k tag)
                              (vhash-cons k (append v path) r))) vlist-null ~search-path)
        (vhash-cons tag path ~search-path)))))

(define-syntax add-search-path
  (syntax-rules ()
    ((_ key path ...)
     (~add-search-path
       (if (string? (quote key)) (string->symbol (quote key)) (quote key))
       (if (symbol? (quote path)) (symbol->string (quote path)) (quote path)) ...))))


(define (get-search-path tag)
  (let ((exists? (vhash-assoc tag ~search-path)))
    (if exists?
      (cdr exists?)
      (begin (print (dump-search-path) "\n")
      (error (concat "Search path for '" (symbol->string tag) " was not defined!"))))))

;(define (find-candidates search-path find-mode-tag find-target predicates . other)
;  (let ((candidates (filter predicates (find-file search-path find-mode-tag find-target))))
;    (if (null? other)
;      candidates
;      (append candidates (find-candidates search-path . other)))))

(define (find-candidates search-path find-mode-tag find-target predicates . other)
  (filter predicates (find-file search-path find-mode-tag find-target)))

(define-syntax verifies
  (syntax-rules ()
    ;((verifies (pred-name . args) ...) (checks (list (quote pred-name) . args) ...))))
    ((verifies (pred-name . args) ...) (lambda (f) (and (pred-name f . args) ...)))))

(define-syntax format-find-candidates
  (syntax-rules ()
    ((format-find-candidates search-path find-mode-tag find-target predicates)
     (pk (find-candidates search-path (quote find-mode-tag) (symbol->string (quote find-target)) predicates)))))

(define-syntax format-find-multiple-candidates-impl
  (syntax-rules ()
    ((_ sp fmt ft p) (pk (format-find-candidates sp fmt ft p)))
    ((_ sp fmt ft p . rest)
     (pk (append (format-find-candidates sp fmt ft p) (format-find-multiple-candidates-impl sp . rest))))))

(define-syntax format-find-multiple-candidates
  (syntax-rules ()
    ((_ . whatever) (lambda () (format-find-multiple-candidates-impl . whatever)))))

(define (declare-impl tag name make-var-name candidates)
  (set! configurables
        (append configurables
                (list (list make-var-name
                            (lambda () (pick-unique name (candidates))))))))

(define-syntax declare
  (syntax-rules ()
    ((declare t n mvn . rest)
     (declare-impl (quote t) n (symbol->string (quote mvn))
                   (format-find-multiple-candidates (get-search-path (quote t)) . rest)))))


;; RENDER CONFIGURATION

(define (eval-configurables)
  "Turn the list of configurables into a string that can be directly fed to Make."
  (string-concatenate
    (map (lambda (p) (concat (car p) "=" ((cadr p)) "\n"))
         configurables)))


(define (write-configuration filename)
  (let ((f (open-output-file filename)))
    (write f (eval-configurables))
    (close f)))

(define (gmk-var var-name)
  (gmk-expand (concat "$(" var-name ")")))

(define (configure-include)
  (gmk-eval "
.configuration:
\t$(guile (write-configuration \".configuration\"))

include .configuration
"))

(define (configure-frontend)
  (let* ((makefiles (gmk-var "MAKEFILE_LIST"))
         (project-path (string-join (map dirname (string-split makefiles #\ )) ":" 'infix)))
    ;(print "makefiles " makefiles "\n")
    ;(print "project-path " project-path "\n")
    (gmk-eval (concat "
.configure:
\t@$(guile (write-frontend \"Makefile\" \"" project-path "\" '(" makefiles ")))

"))))

(define (write-frontend filename vpath makefiles)
;  (if (false-if-exception
        (let ((f (open-output-file filename)))
          (display (eval-configurables) f)
          ;(print "vpath " vpath " vpath " vpath "\n")
          (display (concat "vpath % " vpath "\n") f)
          (display (string-join (map (lambda (m) (concat "include " (symbol->string m))) makefiles) "\n" 'infix) f)
          (close f)))
;    "true"
;    "false"))

