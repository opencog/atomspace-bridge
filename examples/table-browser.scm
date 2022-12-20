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
	(format #t "Table '~A' columns:\n" (cog-name PRED))
	(for-each
		(lambda (TYVAR)
			(format #t "   ~A \ttype: ~A\n"
				(cog-name (cog-value-ref TYVAR 0))
				(cog-name (cog-value-ref TYVAR 1))))
		(cog-outgoing-set varli))
	(format #t "\n"))

; ROW is assumed to be an EvaluationLink
(define (print-row ROW)
	(define table (gar ROW))
	(define naked (gdr ROW))
	(define siggy (car (cog-incoming-by-type table 'Signature)))
	(define varli (cog-value-ref siggy 1))
	(format #t "Table '~A' columns:\n" (cog-name table))
	(for-each
		(lambda (TYVAR VALU)
			(when (not (equal? 0 (string-length (cog-name VALU))))
				(format #t "   ~A \tvalue: ~A\n"
					(cog-name (cog-value-ref TYVAR 0))
					(cog-name VALU))))
		(cog-outgoing-set varli)
		(cog-outgoing-set naked)))

;; ---------------------------------------------------
;
; Select a table and load it.
(define (table-select)
	(format #t "Enter the name of a table to load. Enter '?' to get a list of tables.\n")
	(format #t "Caution: some tables are huge, and require dozens of GB to load.\n")
	(format #t "Recommend table 'stock' to start with.\n")
	(format #t "select-table> ~!")
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

	(format #t "Loading '~A'. This might take a few minutes; please be patient!\n" tbl-str)
	(fetch-incoming-set tablename)
	(format #t "Loaded '~A' in ~A seconds\n" tbl-str (- (current-time) start))
	(print-table tablename)

	; Return the table name
	tbl-str
	))))))

;; ---------------------------------------------------

; Get the TypedVariable for string COL, else #f
(define (get-vardecl COL)
	(define varname (cog-node 'Variable COL))
	(if (nil? varname) #f
		(car (cog-incoming-by-type varname 'TypedVariable))))

(define (valid-col? COL) (get-vardecl COL))

;; ---------------------------------------------------
(define (valid-table? TBL)
	#t)

(define (foo-walk TBL COL VALU)
	(format #t "duuude yo ~A col=~A join=~A\n" TBL COL VALU))

;; ---------------------------------------------------
; Return the value for COL in ROW
(define (get-column-value ROW COL)
	#f
)

; Given a string COL-STR naming a column, print all of the
; tables that have that column. Let the user pick a table,
; then bounce to that table. Once there, load the row that
; joins to the same column value.
;
(define (table-walk ROW COL-STR)
	(define vardecl (get-vardecl COL-STR))
	(define varlis (cog-incoming-by-type vardecl 'VariableList))
	(define sigs (map
		(lambda (VARLI) (car (cog-incoming-by-type VARLI 'Signature)))
		varlis))
	(define preds (map gar sigs))
	(format #t "Tables containg the column '~A' are:\n" COL-STR)
	(for-each (lambda (PRED) (format #t "   ~A\n" (cog-name PRED))) preds)
	(format #t "Pick a table from the above:\n")
	(format #t "select-target> ~!")
	(define tbl-str (get-line (current-input-port)))
	(cond
		((equal? 0 (string-length tbl-str)) (table-walk ROW COL-STR))
		((equal? "q" tbl-str) #f)
		((valid-table? tbl-str)
			(join-walk tbl-str COL-STR (get-column-value ROW COL-STR)))
		(else
			(begin
				(format #t "Unknown table '~A'\n" tbl-str)
				(table-walk ROW COL-STR)))))

;; ---------------------------------------------------
; Given a row in a table, ask user to pick a column from that table.
; Then bound to a dialog that shows all other tables with the same column.
; Here, ROW is expected to be an EvaluationLink holding the row.
(define (edge-walk ROW)
	(print-row ROW)
	(format #t "Enter a column name. Enter 'q' to return to the main prompt.\n")
	(format #t "select-edge> ~!")
	(define col-str (get-line (current-input-port)))
	(cond
		((equal? 0 (string-length col-str)) (edge-walk ROW))
		((equal? "q" col-str) #f)
		((valid-col? col-str) (table-walk ROW col-str))
		(else
			(begin
				(format #t "Unknown column '~A'\n" col-str)
				(edge-walk ROW)))))

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
	(format #t "Enter a command. Enter '?' for a list of commands.\n")
	(format #t "browser> ~!")
	(define cmd-str (get-line (current-input-port)))
	(cond
		((eof-object? cmd-str) (exit))
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
					(format #t "This may take a few minutes for large tables\n")
					(set! curr-rows
						(cog-incoming-by-type (Predicate curr-table) 'Evaluation)))
				(edge-walk (list-ref curr-rows (random (length curr-rows))))))

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
