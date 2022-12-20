;
; AtomSpace Foreign SQL Interface module
;

(define-module (opencog persist-foreign))

(use-modules (opencog))
(use-modules (opencog persist))
(use-modules (opencog fdi-config))
(load-extension (string-append opencog-ext-path-persist-fdi "libpersist-fdi") "opencog_persist_fdi_init")

(export cog-foreign-load-tables cog-foreign-load-rows)

(set-procedure-property! cog-foreign-load-tables 'documentation
"
  cog-foreign-load-tables STORAGE - Load table definitions

  Optionally specify the SQL schema name from which to load the tables.
  (not implemeneted)
")

(set-procedure-property! cog-foreign-load-rows 'documentation
"
  cog-foreign-load-rows STORAGE TABLE COLUMN ITEM - Load rows containing ITEM

  The ITEM is assumed to be some entry located in COLUMN in TABLE.
  This returns a list of rows that match; there may be zero, one or more.
  If ITEM is a PRIMARY KEY, there will be at most one row.

  Example:
    (cog-foreign-load-rows
        (ForeignStorage \"postgres:///flybase\")
        (Predicate \"genotype\")
        (Variable \"genotype_id\")
        (Number 362100))
")

;;;(set-procedure-property! sql-open 'documentation
;;;"
;;; sql-open URL - Open a connection to a database.
;;;    Open a connection to the database encoded in the URL. All
;;;    appropriate database credentials must be supplied in the URL,
;;;    including the username and password, if required.
;;;
;;;    The URL must be on one of these formats:
;;;       odbc://USER:PASSWORD/DBNAME
;;;       postgres:///DBNAME
;;;       postgres://USER@HOST/DBNAME
;;;       postgres://USER:PASSWORD@HOST/DBNAME
;;;       postgres:///DBNAME?user=USER
;;;       postgres:///DBNAME?user=USER&host=HOST
;;;       postgres:///DBNAME?user=USER&password=PASS
;;;
;;;    Other key-value pairs following the question-mark are interpreted
;;;    by the postgres driver, according to postgres documentation.
;;;
;;;  Examples of use with valid URL's:
;;;     (sql-open \"odbc://opencog_tester:cheese/opencog_test\")
;;;     (sql-open \"postgres://opencog_tester@localhost/opencog_test\")
;;;     (sql-open \"postgres://opencog_tester:cheese@localhost/opencog_test\")
;;;     (sql-open \"postgres:///opencog_test?user=opencog_tester\")
;;;     (sql-open \"postgres:///opencog_test?user=opencog_tester&host=localhost\")
;;;     (sql-open \"postgres:///opencog_test?user=opencog_tester&password=cheese\")
;;;")
