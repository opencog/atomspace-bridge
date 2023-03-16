;
; basic-demo.scm - Basic demo of the most basic features.
;
; This demo is written in scheme. The equivalent of this demo should
; also work fine with the AtomSpace Python bindings.
;
; Step 0: Install and configure Postgres.
;         $ sudo apt install postgresql
;         $ sudo service postgresql start
;         $ sudo su - postgres
;         $ psql template1
;         Replace `opencog` below with your username.
;         template1=# CREATE ROLE opencog WITH SUPERUSER;
;         template1=# ALTER ROLE opencog WITH LOGIN;
;         template1=# exit
;         $ exit
;         $ createdb opencog
;
; Step 1: Download the flybase DB from off the net.
;         Caution: it is large -- a 13GB compressed file!
;         https://ftp.flybase.net/releases/FB2022_06/psql/FB2022_06.sql.gz
;
; Step 2: Load it into postgres. At the shell:
;            createdb flybase
;            time zcat FB2022_06.sql.gz |psql flybase
;         This will take 5 hours on older systems; an hour on the newest.
;
; Step 3: Start a guile REPL shell. At the guile prompt, cut-n-paste
;         the commands below. Observe, make sure they work.
;

(use-modules (srfi srfi-1))
(use-modules (opencog) (opencog persist))
(use-modules (opencog persist-bridge))

; ----------------------------------------------------
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
(define flystore (BridgeStorageNode "postgres:///flybase"))

; Open it.
(cog-open flystore)

(cog-connected? flystore)

; Load all of the table definitions.
(define table-descs (cog-bridge-load-tables flystore))

; How many table descriptions were loaded?
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

; ----------------------------------------------------
; Lets explore some tables. Start with a known column name,
; say "genotype_id". Column names are written as VariableNodes
; Print the type of the column (the "column descriptor")
(cog-incoming-set (Variable "genotype_id"))

; Create a list of all the tables that this column appears in.
; We'll use a short scheme function to grab this. It just walks
; upwards from the column name, to the column descriptor, to the
; row descriptor, to each table descriptor that the column appears in.
;
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
(fetch-incoming-set (Predicate "genotype"))

; What have we found so far?
(cog-report-counts)   ; Reports number of Atoms, by type.
(count-all)           ; Grand-total number of Atoms in the AtomSpace
(display (monitor-storage flystore))

; Before we look at any rows in that table, lets take a look at
; the table description. This will give us a hint of what we're
; going to see next.
(cog-incoming-by-type (Predicate "genotype") 'Signature)

; The above should look like this:
;
; (Signature (Predicate "genotype")
;    (VariableList
;       (TypedVariable (Variable "genotype_id") (Type "NumberNode"))
;       (TypedVariable (Variable "uniquename") (Type "ConceptNode"))
;       (TypedVariable (Variable "description") (Type "ConceptNode"))
;       (TypedVariable (Variable "name") (Type "ConceptNode"))
;       (TypedVariable (Variable "is_obsolete") (Type "NumberNode"))))
;
; The Variables are the column names, and the Type is the column type.

; Take a look at the 42nd row in the table.
(list-ref (cog-incoming-set (Predicate "genotype")) 42)

; The above is a bit sloppy: it first gets all half-a-million rows,
; and then picks the 42nd one. So it takes a second to do this.
; No matter; we're just sampling to see what's going on.
; BTW, these "row numbers" are not reproducible; they will change
; from session to session, and they will change if rows are added.

; ----------------------------------------------------
; Lets do some table joins. From the above, we saw that the 42nd
; entry has the "genotype_id" of (Number "362100"). That is, the
; Signature showed "genotype_id" as the first column, and that
; got printed as (Number "362100"). Lets now fetch the matching
; rows from other tables that have this same ID. In SQL, this is
; called a "join".

; Note, by the way, that this won't work if there hasn't been at
; least one row from one table loaded, having this column. That's
; because a number, pulled out of thin air, doesn't have enough
; info on it to know where it belongs, what it's associated with.
; The next section deals with this.

(fetch-incoming-set (Number 362100))

; What happened? Well, we saw previously that there were ten tables
; that "genotype_id" as a column. So, ten rows, from ten tables, were
; loaded. Lets look at them, row by row. Hmm. Apparently, not all of
; the tables have a row for this genotype, and one table, the
; "feature_genotype" table, has three rows for it. OK.

(cog-get-root (Number 362100))

; Holy cow. Well, that's pretty boring. Apparently, most tables are just
; relations, pointing to things in other tables. Well, that should not
; be a surprise. The genotypes form a large, complex tangled graph, with
; edges going from here to there, everywhere. There's no easy way to
; encode a graph in SQL, except to use lots of FOREIGN KEY's connecting
; hundreds of tables together.  And that's exactly what flybase does.

; Here's another one, that's a little more interesting.
; Apparently, it's a "Class II allele. Eye discs are very small. Larval
; survival rate of homozygotes is 30% of heterozygotes with wild type."
(fetch-incoming-set (Number 51808))
(cog-get-root (Number 51808))

; ----------------------------------------------------
; Suppose that we know, a priori some entry in some column in some table.
; It can be fetdhed directly, as follows. We happen to "just know" that
; (Number 464522) is a valid "genotype_id". So go get that row, only.

(cog-bridge-load-row flystore
	(Predicate "genotype")
	(Variable "genotype_id")
	(Number 464522))

; ----------------------------------------------------
; OK. So the above is getting boring. Lets do some bulk loads.
; Load all data from all tables having a given column name.
; Somewhat incautiously, we pick the genotype_id column. There's
; some fair amount of data there. This load will take 1 to 5 minutes,
; and will chew up about 7GBytes of RAM.
(fetch-incoming-set (Variable "genotype_id"))

; What have we get?
(cog-report-counts)
(count-all)      ; Over 10 million atoms, it seems.
(display (monitor-storage flystore))  ; Almost 4 million rows.

; ----------------------------------------------------
; Let's get greedy, and just try to load *everything*.
; This will turn out to be a mistake. But let's make it.
;
; Be prepared to kill the guile process, else it will use up all the RAM
; on your system. The OOM killer will eventually run, but, until it does,
; your mouse and keyboard will be unresponsive. So kill it manually,
; before it gets out of control.
;
; Because this takes a long time, it is more convenient to run it
; from a CogServer shell. This frees up the main guile prompt for
; poking around and exploring, while the loading happens in a different
; thread. This is the preferred way to interact, for any kind of large,
; long-running job.  Do this like so:

(use-modules (opencog cogserver))
(start-cogserver)

; Now, `rlwrap telnet localhost 17001` and run the big load from there.
;
; Some of the large tables are:
; * "featureloc" -- 97643867 (97 million) rows, 340M Atoms, 250GB RSS
; * "feature"                  -- 90989753 (90 million) rows
; * "analysisfeature"          -- 77900179 (78 million) rows
; * "feature_relationship"     -- 72903395 (73 million) rows
; * "library_featureprop"      -- 45768412 (46 million) rows
; * "feature_dbxref"           -- 33640286 (34 million) rows
; * "dbxref"                   -- 25890450 (26 million)
; * "library_feature"          -- 25483996 (25 million)
; * "featureprop"              -- 18965183 (18 million)
; * "feature_relationshipprop" -- 10450127 (10 million)
; * "dbxrefprop"               -- 7368898 (7.4 million)
; * "feature_synonym"          -- 7219870 (7.2 million)
;
; In total, there are 458 million rows, in all tables. (458126237 total)
;
; Loading the `featureloc` table requires approx 250 GB RAM to load.
; It will take approx 35 min on a fast machine, so about 46K rows/sec.
; It uses approx 340M Atoms, so 3.4 Atoms/row, and 730 Bytes/Atom.
;
; The average for all but the 9 largest tables (the "smaller-tables"
; list, below) works out to 540 Bytes/Atom. These contain a total of
; 66584583 (about 67 million) rows, for an average of 2.893 Atoms/row.
;
; Loading all but the top 7 tables requires
; 166.7 GB RAM, 111033762 rows, 2.754 Atoms/row, 545 Bytes/Atom.
;
; Loading all but the top 5 tables requires
; 254.0 GB RAM, 170564498 rows, 2.76 Atoms/row, 540 Bytes/Atom.
;
; Loading all but the top 4 tables requires
; 318.0 GB RAM, 216332910 rows, 2.66 Atoms/row, 552 Bytes/Atom.
;
; Loading all but the top 3 tables requires
; 432.9 GB RAM, 289236305 rows, 2.63 Atoms/row, 570 Bytes/Atom.
;
; Loading additional tables *reduces* the number of Atoms/row, with
; the average trending to 2.6 Atoms/row. This is because most Atoms
; are shared by multiple rows. Assuming 570 Bytes/Atom, this works
; works out to about 680 GBytes RAM total.
; -----------------------------------

; List of all of the tables.
(define all-tables (cog-get-atoms 'PredicateNode))
(length all-tables)

; The big tables account for 391 million rows.
(define big-tables (list
	(Predicate "featureloc")
	(Predicate "feature")
	(Predicate "analysisfeature")
	(Predicate "feature_relationship")
	(Predicate "library_featureprop")
	(Predicate "feature_dbxref")
	(Predicate "dbxref")
	(Predicate "library_feature")
	(Predicate "featureprop")
))

; All of the tables, except the largest ones.
; These contain 66584583 (67 million) rows.
(define smaller-tables (atoms-subtract all-tables big-tables))

; Function that loads all tables in TABLE-LIST
; It loads them one at a time, instead of in parallel,
; so it will be slower than it could be.
; It prints some performance stats for ech table.
(define (load-tables TABLE-LIST)
	(define tabno 0)
	(for-each
		(lambda (PRED)
			(define start-time (current-time))
			(set! tabno (+ 1 tabno))
			(format #t "Start loading table ~A/~A  ~A\n"
				tabno (length TABLE-LIST) (cog-name PRED))
			(fetch-incoming-set PRED)
			(let* ((elapsed (- (current-time) start-time))
					(num-rows (cog-incoming-size PRED)))
				(format #t "... Done loading ~A rows in ~A secs\n"
					num-rows elapsed)
				(when (< 20 elapsed)
					(format #t "... Rate: ~8,1F rows/sec\n"
						(exact->inexact (/ num-rows elapsed))))
			)
			; (format #t "\nStatus:\n")
			; (display (monitor-storage flystore))
			(format #t "----------------------\n"))
		TABLE-LIST))

; Load everything except the big ones. This requires 104 GBytes of RAM.
; It will load about 193 million Atoms. There are about 67 million rows.
(load-tables smaller-tables)

; Print a report about the loaded tables:
(for-each
	(lambda (PRED)
		(format #t "Found ~A \trows in table ~A\n"
			(cog-incoming-size-by-type PRED 'EdgeLink)
			(cog-name PRED)))
	(cog-get-atoms 'PredicateNode))

; Total number of loaded rows:
(define all-sizes (map cog-incoming-size (cog-get-atoms 'PredicateNode)))
(fold + 0 all-sizes)

; Atoms per row:
(/ (count-all) (fold + 0.0 all-sizes))

: Time to say goodnight.
; Close the connection to storage.
(cog-close flystore)

; The End! That's all folks!
