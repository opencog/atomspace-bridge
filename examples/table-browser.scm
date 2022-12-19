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

;; ---------------------------------------------------

(define (print-table PRED)
	(define siggy (car (cog-incoming-by-type PRED 'Signature)))
	(define varli (cog-value-ref siggy 1))
	(format #t "Table >>~A<< columns:\n" (cog-name PRED))
	(for-each (lambda (TYVAR)
		(format #t "   ~A \ttype: ~A\n"
			(cog-name (cog-value-ref TYVAR 0))
			(cog-name (cog-value-ref TYVAR 1))))
		(cog-outgoing-set varli)))

(define (print-row ROW)
	(format #t "duuude ~A\n" ROW)
)

;; ---------------------------------------------------
;
; Select a table and load it.
(define (table-select)
	(format #t "Select a table to load. Enter '?' to get a list of tables:\n")
	(define tbl-str (get-line (current-input-port)))

	;; (format #t "Read >>~A<<\n" tbl-str)
	(cond
		((equal? 0 (string-length tbl-str))
			(table-select))

		((equal? "?" tbl-str)
			(begin
				(for-each (lambda (PRED)
					(format #t "   ~A\n" (cog-name PRED)))
					(cog-get-atoms 'Predicate))
				(table-select)))

		(else
			(let ((tablename (cog-node 'Predicate tbl-str)))
			(if (nil? tablename)
				(begin
					(format #t "Unknown table >>~A<<\n" tbl-str)
					(table-select))
				(let ((start (current-time)))

	(format #t "Loading ~A. This might take a few minutes; please be patient!\n" tbl-str)
	(fetch-incoming-set tablename)
	(format #t "Loaded ~A in ~A seconds\n" tbl-str (- (current-time) start))
	(print-table tablename)

	; Return the table name
	tbl-str
	))))))

;; ---------------------------------------------------

(define (prt-commands)
	(format #t "Available commands:\n")
	(format #t "   exit -- quit\n")
	(format #t "   shell -- escape into the guile shell\n")
	(format #t "   load-table -- to load an entire SQL table\n")
	(format #t "   set-table -- to set the current SQL table to browse\n")
	(format #t "   random-row -- print a random row in the current table\n")
)

; State:
(define curr-table #f)
(define curr-rows #f)

(define (browser-shell)
	(format #t "Enter a command. Enter '?' for a list of commands\n")
	(define cmd-str (get-line (current-input-port)))
	(format #t "yo ~A\n" cmd-str)
	(cond
		((equal? 0 (string-length cmd-str)) #f)

		((equal? "?" cmd-str) (prt-commands))
		((equal? "exit" cmd-str) (exit))
		((equal? "shell" cmd-str) #f)

		((equal? "load-table" cmd-str)
			(begin
				(set! curr-table (table-select))
				(set! curr-rows #f)))

		((equal? "set-table" cmd-str)
			(begin
				(set! curr-table cmd-str)
				(set! curr-rows #f)))

		((equal? "random-row" cmd-str)
			(begin
				(when (not curr-rows)
					(set! curr-rows
						(cog-incoming-by-type (Predicate curr-table) 'Evaluation)))
				(print-row (list-ref curr-rows (random (length curr-rows))))))

		(else
			(format #t "Unknown command ~A\n" cmd-str)))

	(if (not (equal? "shell" cmd-str))
		(browser-shell)))

(browser-shell)


#! ---------
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
