;
; basic-demo.scm - Basic demo of the most basic features.
;
; Step 0: Install and configure Postgres.
;
; Step 1: Download the flybase DB from off the net.
;         Caution: it is large -- a 13GB compressed file!
;         https://ftp.flybase.net/releases/FB2022_06/psql/FB2022_06.sql.gz
;
; Step 2: Load it into postgres. At the shell:
;            createdb flybase
;            zcat FB2022_06.sql.gz |psql flybase
;         This took 5 hours, on my system.
;
; Step 3: Start a guile REPL shell. At the guile prompt, cut-n-paste
;         the commands below. Observe, make sure they work.

(use-modules (opencog) (opencog persist))
(use-modules (opencog persist-foreign))

; Declare the location of the database.
; If the DB is on the local machine, must use three slashes;
; for a remote DB, use one of these URL's:
; postgres://example.com/flybase
; postgres://example.com/flybase?user=foo
; postgres://example.com/flybase?user=foo&password=bar
;
; The following works if you set up the AtomSpace Unit tests correctly:
; postgres:///opencog_test?user=opencog_tester&password=cheese
;
(define flystore (ForeignStorageNode "postgres:///flybase"))

; Open it.
(cog-open flystore)

(cog-connected? flystore)

; Load all of the table defintions.
(cog-foreign-load-tables flystore)

; What is in the AtomSpace so far?
(cog-prt-atomspace)
(cog-report-counts)

; Take a look at the connection status
(display (monitor-storage flystore))

; Load all data from one table.
(fetch-incoming-set (Predicate "cell_line"))

; What have we found so far?
(cog-report-counts)
(display (monitor-storage flystore))

; Load all data from all tables having a given column name
(fetch-incoming-set (Variable "cell_line_id"))

; What have we found so far?
(cog-report-counts)
(display (monitor-storage flystore))

; So far, all we've done above is to load data. Lets do some simple
; exploring. Here's some gene:  (Concept "S2R+-Gmap-GFP-7") Lets
; look at all the rows that it's in.
(cog-get-root (Concept "S2R+-Gmap-GFP-7"))

; This should print out
; ((Evaluation (Predicate "cell_line")
;    (List (Number "273") (Concept "S2R+-Gmap-GFP-7")
;          (Concept "FBtc0000277") (Number "1") (Number "0"))))
; which is pretty meaningless without a table schema.  What's the
; schema?

(cog-incoming-by-type (Predicate "cell_line") 'Signature)

; So we see that its this:
; ((Signature (Predicate "cell_line")
;    (VariableList
;     (TypedVariable (Variable "cell_line_id") (Type "NumberNode"))
;     (TypedVariable (Variable "name") (Type "ConceptNode"))
;     (TypedVariable (Variable "uniquename") (Type "ConceptNode"))
;     (TypedVariable (Variable "organism_id") (Type "NumberNode"))
;     (TypedVariable (Variable "is_obsolete") (Type "NumberNode")))))
;
; We conclude that (Concept "S2R+-Gmap-GFP-7") lies in a column
; called "name". Woo hoo! Such information!

; -----------
; Let's get greedy, and just try to load *everything*.

(for-each
	(lambda (PRED)
		(define start-time (current-time))
		(format #t "Start loading table ~A\n" (cog-name PRED))
		(fetch-incoming-set PRED)
		(format #t "... Done loading in ~A secs\n" (- (current-time) start-time))
		(format #t "\nStatus:\n")
		(display (monitor-storage flystore))
		(format #t "----------------------\n"))
	(cog-get-atoms 'PredicateNode))

; Well, the above will take a long time.  And use up a LOT of RAM.

; Close the connection to storage.
(cog-close flystore)

; The End! That's all folks!
