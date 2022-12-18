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
;         createdb flybase
;         zcat FB2022_06.sql.gz |psql flybase
;
; Step 3: Start a guile REPL shell. At the guile prompt, cut-n-paste
;         the commands below. Observe, make sure they work.

(use-modules (opencog) (opencog persist))
(use-modules (opencog persist-foreign))

(define flystore (ForeignStorageNode "postgres://flybase"))

(cog-open flystore)
