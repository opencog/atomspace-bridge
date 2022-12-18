;
; bringup-demo.scm - Crude script used for development debugging.
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

(cog-close flystore)
