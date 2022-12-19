;
; basic-demo.scm - Basic demo of the most basic features.
;
; This demo is written in scheme. The equivalent of this demo should
; also work fine with the AtomSpace Python bindings.
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
;         This took 5 hours, on my (rather old) system.
;
; Step 3: Start a guile REPL shell. At the guile prompt, cut-n-paste
;         the commands below. Observe, make sure they work.
;

(use-modules (srfi srfi-1))
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

; Load all of the table definitions.
(define table-descs (cog-foreign-load-tables flystore))

; How many table deescriptions were loaded?
(length table-descs)

; Take a quick peek at the third table description. This will print
; a mess, but hopefully, it will be obvious: the name of the table,
; followed by the a list of the column descriptors. Each column consists
; of the column name (the Variable) and the type of the column.
; (Why third? no reason, just for fun.)
(third table-descs)

; What is in the AtomSpace so far?
(cog-prt-atomspace)
(cog-report-counts)

; Take a look at the connection status
(display (monitor-storage flystore))

; Load all data from one table.
(fetch-incoming-set (Predicate "cell_line"))

; What have we found so far?
(cog-report-counts)   ; Reports number of Atoms, by type.
(display (monitor-storage flystore))

; Load all data from all tables having a given column name
(fetch-incoming-set (Variable "cell_line_id"))

; What have we found so far?
(cog-report-counts)
(count-all)  ; Reports a grand-total number of Atoms in the AtomSpace.
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

(define num-tables (length (cog-get-atoms 'PredicateNode)))
(define tabno 0)
(for-each
	(lambda (PRED)
		(define start-time (current-time))
		(set! tabno (+ 1 tabno))
		(format #t "Start loading table ~A/~A  ~A\n"
			tabno num-tables (cog-name PRED))
		(fetch-incoming-set PRED)
		(format #t "... Done loading in ~A secs\n" (- (current-time) start-time))
		(format #t "\nStatus:\n")
		(display (monitor-storage flystore))
		(format #t "----------------------\n"))
	(cog-get-atoms 'PredicateNode))

; Well, the above will take a long time.  And use up a LOT of RAM.
; More than 100 GB so far, and still going. The `featureprop` table
; is quite large, it has 18965184 records.

; Use this to count the number of records:
(cog-incoming-size (Predicate "featureprop"))

; The above count is accurate only *after* loading!

; Perhaps its better to do the loading from another window. So here:
(use-modules (opencog cogserver))
(start-cogserver)

; Then `rlwrap telnet localhost 17001` and run the load from there.
; That way, the main guile prompt is available for monitoring progress.
; This is the prefered way to interact, for any kind of large,
; long-running jobs.

; Here's a row-count monitor:
(for-each
	(lambda (PRED)
		(format #t "Found ~A \trows in table ~A\n"
			(cog-incoming-size-by-type PRED 'EvaluationLink)
			(cog-name PRED)))
	(cog-get-atoms 'PredicateNode))

; Aieeee!
;
; The `featureloc` table is also large. -- it has 97643867 (97 million)
; rows. Pulling in the first 32 million rows took about 100 GB of RAM.
; Clearly, loading all of it requires more RAM, or a much more compact
; representation.

: Time to say goodnight.
; Close the connection to storage.
(cog-close flystore)

; The End! That's all folks!
