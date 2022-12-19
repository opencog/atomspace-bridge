;
; table-browser.scm - Plain-ASCII browser of Chado tables (and other SQL DB's)
;
; Make sure you have a running Postgress database with data in it. If not,
; See the basic-demo.scm for instructions.

(use-modules (srfi srfi-1))
(use-modules (ice-9 textual-ports))
(use-modules (opencog) (opencog persist))
(use-modules (opencog persist-foreign))

(format #t "SQL Table Browser Demo\n\n")
(format #t "Enter a Postgres DB to open:\n")
(format #t "   For example, \"postgres:///flybase\"\n")

(define db-str (get-line (current-input-port)))
(if (equal? 0 (string-length db-str))
	(set! db-str "postgres:///flybase"))

(define flystore (ForeignStorageNode db-str))
(format #t "Opening ~A\n" flystore)
(cog-open flystore)
(define table-descs (cog-foreign-load-tables flystore))
(format #t "Loaded ~A table descriptions\n" (length table-descs))

(define (table-select)
	(format #t "Select a table to load. Enter '?' to get a list of tables:\n")
	(define tbl-str (get-line (current-input-port)))

	;; (format #t "Read >>~A<<\n" tbl-str)
	(if (equal? 0 (string-length tbl-str))
		(table-select)

	(if (equal? "?" tbl-str)
		(begin
			(for-each (lambda (PRED)
				(format #t "   ~A\n" (cog-name PRED)))
				(cog-get-atoms 'Predicate))
			(table-select))

	(let ((tablename (cog-node 'Predicate tbl-str)))
		(if (nil? tablename)
			(begin
				(format #t "Unknown table >>~A<<\n" tbl-str)
				(table-select))
			(let ((start (current-time)))

	(format #t "Loading ~A. This might take a few minutes; please be patient!\n" tbl-str)
	(fetch-incoming-set tablename)
	(format #t "Loaded ~A in ~A seconds\n" tbl-str (- (current-time) start))
	))))))

(table-select)

#! ---------
(define (browser-shell)
	(define inp (get-line (current-input-port)))
	(format #t "yo ~A\n" inp)
	(browser-shell))

(browser-shell)


(define (print-tables NAME)
	(define column (Variable NAME))
	(define coldesc (car (cog-incoming-by-type column 'TypedVariable)))
	(define rowdescs (cog-incoming-by-type coldesc 'VariableList))
	(map
		(lambda (ROWDESC)
			(define siggy (car (cog-incoming-by-type ROWDESC 'Signature)))
			(cog-value-ref siggy 0))
		rowdescs))

; Do it. Print them out.
(print-tables "genotype_id")

; ----------------------------------------------------
; Pick a table, any table. Load all data from that table.
; The genotype table is medium-sized, it contains about
; half-a-million entries.

(fetch-incoming-set (Number 51808))
(cog-get-root (Number 51808))

(cog-foreign-load-row flystore
	(Predicate "genotype")
	(Variable "genotype_id")
	(Number 464522))

!#
