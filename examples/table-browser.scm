;
; table-browser.scm - Plain-ASCII browser of Chado tables (and other SQL DB's)
;
; This assumes you have a database which has a lot of tables (dozens
; or hundreds) which are all tied together with each other using
; FOREIGN KEY constraints. Each such constraint can be thought of as
; the edge of a giant graph. This browser lets you walk those edges,
; bouncing from table to table, and looking what's there.
;
; It would be much better if we had a graphical browser for this, but
; they are currently all in disrepair. Alas.
;
; The run this, just say `guile -l table-browser.scm` and then
; follow the prompts.
;
; Make sure you have a running Postgres database with data in it.
; If not, see the `basic-demo.scm` file for instructions.

(use-modules (srfi srfi-1))
(use-modules (ice-9 textual-ports))
(use-modules (opencog) (opencog persist))
(use-modules (opencog persist-bridge))

(format #t "SQL Table Browser Demo\n\n")
(format #t "Enter a Postgres DB to open:\n")
(format #t "   For example, \"postgres:///flybase\"\n")
(format #t "   If you just hit enter, flybase will be used.\n")

(define db-str (get-line (current-input-port)))
(newline)
(if (eof-object? db-str) (exit))

(if (equal? 0 (string-length db-str))
	(set! db-str "postgres:///flybase"))

(define flystore (BridgeStorageNode db-str))
(format #t "Opening ~A\n" flystore)
(cog-open flystore)
(define table-descs (cog-bridge-load-tables flystore))
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

; ROW is assumed to be an EdgeLink
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
; Get the TypedVariable for string COL-STR, else #f
(define (get-vardecl COL-STR)
	(define varname (cog-node 'Variable COL-STR))
	(if (nil? varname) #f
		(car (cog-incoming-by-type varname 'TypedVariable))))

;; ---------------------------------------------------
; Return the value for COL-STR in ROW
; The returned value will be a ConceptNode or NumberNode
(define (get-column-value ROW COL-STR)
	(define vardecl (get-vardecl COL-STR)) ; TypedVariable
	(define table (gar ROW))  ; Predicate
	(define naked (gdr ROW))  ; ListLink
	(define siggy (car (cog-incoming-by-type table 'Signature)))
	(define varli (cog-value-ref siggy 1))  ; VariableList
	(define offset
		(list-index
			(lambda (TYVAR) (equal? TYVAR vardecl))
			(cog-outgoing-set varli)))
	(list-ref (cog-outgoing-set naked) offset))

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
		((eof-object? tbl-str) (exit))
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
;
; Given a selected table (as PredicateNode) and a selected column
; (as string) and a value for that column, load all rows in that table,
; having this value for this column.  If there are no such rows, return '().
(define (load-joins TBL COL-STR VALU)

	; Load if from SQL. For example:
	;    (cog-bridge-load-rows flystore
	;        (Predicate "genotype") (Variable "genotype_id") (Number 464522))
	(define lro
		(cog-bridge-load-rows flystore TBL (Variable COL-STR) VALU))
	(if (< 0 (length lro))
		(format #t "Loaded ~A joining rows for '~A.~A=~A'\n"
			(length lro) (cog-name TBL) COL-STR (cog-name VALU)))
	lro
)

;; ---------------------------------------------------
;
; Given a selected table (as string) and a selected column (as string)
; and a value for that column, load a row in that table, having this
; value for this column.  Then bounce to the edge secletion menu again.
(define (join-walk TBL-STR COL-STR VALU)

	(define table (cog-node 'Predicate TBL-STR))
	(define new-rows (load-joins table COL-STR VALU))
	(define numr (length new-rows))
	(define rr (random numr))

	; Hmm earlier menus now guarantee that new-rows is not nil.
	(if (nil? new-rows)
		(format #t
			"Oh no! Table '~A' doesn't have any rows with '~A' in them!\n"
			TBL-STR (cog-name VALU))
		(begin
			(format #t
				"Found ~A rows in '~A', which join to column value '~A'.\n"
				numr TBL-STR (cog-name VALU))

			; Bounce back to the table menu
			(format #t "Randomly selected row ~A/~A and bouncing to it.\n"
				rr numr)
			(edge-walk (list-ref new-rows rr))))
)

;; ---------------------------------------------------
; Given a string COL-STR naming a column, print all of the
; tables that have that column. Let the user pick a table,
; then bounce to that table. Once there, load the row that
; joins to the same column value.
;
(define (table-walk ROW COL-STR)
	(define vardecl (get-vardecl COL-STR)) ; TypedVariable
	(define varlis (cog-incoming-by-type vardecl 'VariableList))
	(define sigs (map
		(lambda (VARLI) (car (cog-incoming-by-type VARLI 'Signature)))
		varlis))
	(define preds (map gar sigs))  ; List of PredicateNodes

	; The value in this row and this column
	(define join-value (get-column-value ROW COL-STR))

	; Filter away tables that don't have any content for this join
	(define tabs (filter
			(lambda (TAB) (not (nil? (load-joins TAB COL-STR join-value))))
		preds))
	(define ntabs (length tabs))

	(define (valid-table? TBL-STR)
		(define tabname (cog-node 'Predicate TBL-STR))
		(if (not tabname) #f
			(any (lambda (PRED) (equal? PRED tabname)) tabs)))

	(define (pick-table)
		(format #t "Tables containing the column '~A' are:\n" COL-STR)
		(for-each (lambda (PRED) (format #t "   ~A\n" (cog-name PRED))) tabs)
		(format #t "Pick a table from the above:\n")
		(format #t "select-target> ~!")
		(define tbl-str (get-line (current-input-port)))
		(newline)
		(cond
			((equal? 0 (string-length tbl-str)) (table-walk ROW COL-STR))
			((equal? "q" tbl-str) #f)
			((valid-table? tbl-str) (join-walk tbl-str COL-STR join-value))
			(else
				(begin
					(format #t "Unknown table '~A'\n" tbl-str)
					(table-walk ROW COL-STR)))))

	(cond
		((equal? 0 ntabs) #f)
		((equal? 1 ntabs)
			(begin
				(format #t
					"Only one table contains the column '~A'; jumping to it\n"
					 COL-STR)
				(join-walk (cog-name (car tabs)) COL-STR join-value)))
		(else
			(pick-table)))
)

;; ---------------------------------------------------
; Given a row in a table, ask user to pick a column from that table.
; Then bound to a dialog that shows all other tables with the same column.
; Here, ROW is expected to be an EdgeLink holding the row.
(define (edge-walk ROW)
	(print-row ROW)
	(format #t "\nEnter a column name. Enter 'q' to return to the main prompt.\n")
	(format #t "select-edge> ~!")
	(define col-str (get-line (current-input-port)))
	(newline)
	(define (valid-col? COL-STR) (get-vardecl COL-STR))
	(cond
		((eof-object? col-str) #f)
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
	(format #t "            Say '(browser-shell)' to get back to the browser\n")
	(format #t "   load-table -- to load an entire SQL table\n")
	(format #t "   set-table -- to set the current SQL table to browse\n")
	(format #t "   random-row -- print a random row in the current table\n")
)

; State:
(define curr-table #f)
(define curr-rows #f)

(define (jump-to-random-row)
	(when (nil? curr-rows)
		(format #t "This may take a few minutes for large tables\n")
		(set! curr-rows
			(cog-incoming-by-type (Predicate curr-table) 'EdgeLink)))

	(define nrows (length curr-rows))
	(define rr (random nrows))
	(format #t "Jump randomly to row ~A of ~A\n" rr nrows)
	(edge-walk (list-ref curr-rows rr)))

(define (browser-shell)
	(format #t "Enter a command. Enter '?' for a list of commands.\n")
	(format #t "browser> ~!")
	(define cmd-str (get-line (current-input-port)))
	(newline)
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

		((equal? "random-row" cmd-str) (jump-to-random-row))

		(else
			(format #t "Unknown command ~A\n" cmd-str)))

	(if (not (equal? "shell" cmd-str))
		(browser-shell)))

(browser-shell)

; --------------------- END OF FILE -----------------
