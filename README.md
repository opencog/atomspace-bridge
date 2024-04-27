AtomSpace-SQL DB Bridge
=======================
The bridge connects pre-existing SQL DB's to the AtomSpace, so that
data can move between the two, in both directions.  It is meant to allow
the AtomSpace to access foreign, external data, and manipulate it using
the AtomSpace software stack.  This is *not* intended for generic
save/restore of AtomSpace contents. For that, see the native
[atomspace-rocks](https://github.com/opencog/atomspace-rocks) RocksDB
[StorageNode](https://wiki.opencog.org/w/StorageNode) and the
[atomspace-cog](https://github.com/opencog/atomspace-cog) network
StorageNode.

The following are desired features:
* Automatic creation of maps from the SQL tables to AtomSpace
  structures. Fully automated, by importing pre-existing SQL table
  schemas. Optionally, this can be overloaded with custom templates.
* Custom mappings or templates would allow more "natural"
  [Atomese](https://wiki.opencog.org/w/Atomese) representations.
  Complex SQL systems tend to have ugly, convoluted table structures
  with complex primary-key/foreign-key interactions. It would be nice
  to hide this in the AtomSpace mapping, so that we don't import the
  grunge and cruft of the SQL table designs.
* The bridge should allow both the read and the update of the contents
  (rows) in the SQL tables (while maintaining all foreign-key
  constraints during writing.)
* The bridge loads data incrementally. The bridge does not require
  a bulk import/export, but rather will access individual rows, columns
  and tables on an as-needed basis. This would allow the AtomSpace to
  work with datasets that are too big to fit in RAM.
* Adherence to the [AtomSpace Sensory](https://github.com/opencog/sensory)
  perception-action API for general agents.

At this time, only Postgres is supported.

Status
------
***Version 0.2.1*** -- The current implementation can load table
descriptions and table contents from Postgres DB's. It can also
load related rows and columns (rows and columns joined by a common
column name). Two demos: a basic demo, showing the basic idea, and
an ASCII table browser, allowing you to pilot around, bouncing from
table to table, along joins. It's an ASCII browser because all of
the graphical browsers for the AtomSpace have been neglected.
(These: [atomspace-explorer](https://github.com/opencog/atomspace-explorer),
[atomspace-typescript](https://github.com/opencog/atomspace-typescript) and
[cogprotolab](https://github.com/opencog/cogprotolab).)

History
-------
Per request of Mike Duncan, Dec 2022. Map the
[FlyBase Drosophila Genome Database](http://flybase.org)
(current release
[here](https://ftp.flybase.net/releases/FB2022_06/psql/FB2022_06.sql.gz))
into the AtomSpace, using the
[Chado](http://gmod.org/wiki/Chado)
schema given [here](http://gmod.org/wiki/Chado_Tables).

Generic Mapping
---------------
Here's a sketch for a generic mapping. This could work for *any*
SQL database.

For each row in some table `tablename`, create a conventional
Atomese [EdgeLink](https://wiki.opencog.org/w/EdgeLink).
```
   Edge                      ; A single row in the table.
      Predicate "tablename"  ; Replace by actual name of table.
      List                   ; This list is one row in the table.
         Concept "thing"     ; Entry in that column, if its a string.
         NumberNode 42       ; If that column type is a number.
         ...
         Concept "stuffs"    ; Last column in the table.
```

Primary and Foreign Keys
------------------------
The biggest design question is what to do with primary and foreign keys.
The simplest solution is to "do nothing" and just import rows from
SQL straight-up. Whatever primary/foreign keys are in the SQL tables,
they will also appear in the AtomSpace. They will join automatically,
due to fundamental AtomSpace architecture. With this solution, writing
complex queries appears to be straight-forward (and easier than writing
SQL queries).  This works and is surprisingly flexible.

Other mappings are possible; however, there is no natural way of asking
Postgres which table columns are foreign keys, and which other tables
they might reference. If this info was available, then we could have a
an Atomese representation that does NOT keep any keys at all in the
AtomSpace, and instead just makes direct links between table rows.
So, for example:

```
   Edge
      Predicate "some join relation"
      Set
         Edge   ;;; row in the host table
            Predicate "some tablename"
            List ...

         Edge   ;; row in the target table.
            Predicate "another tablename"
            List ...

         Edge   ;; if more than two tables are joined.
            Predicate "yet another tablename"
            List ...
```
See the OpenCog wiki:
* [EdgeLink](https://wiki.opencog.org/w/EdgeLink)
* [PredicateNode](https://wiki.opencog.org/w/PredicateNode)

From what I can tell, the above alternate form uses about the same
amount of RAM as having explicit keys in each row. It also takes
just about the same amount of time to query over. So it does not
seem to offer any size or performance advantage over brute-force
primary/foreign keys.

It does seem to make things more readable, more "natural" in Atomese.
It provides more flexibility: you can create and destroy joins at any
time. You can join some rows but not others. All the usual stuff that
makes the AtomSpace more flexible than SQL.

For just right now, we punt, and store the naked PRIMARY/FOREIGN KEY
values as Atoms in the AtomSpace. It feels ugly, but it works.

Table Schemas
-------------
SQL table definitions provide a definition of the columns of that
table.  These are imported into the AtomSpace, where they are used
to find the names of the columns, and the types. (Note that the
`EdgeLink` example above does not contain the column names.)
Below is the current mapping.

The SQL column names are recorded as
[VariableNode](https://wiki.opencog.org/w/VariableNode) names.
The type of each variable *aka* column is given.
```
    Signature
       Predicate "tablename"    ;; Replace by actual table name.
       List
          TypedVariable
              Variable "name of column 1"
              Type 'ConceptNode ;; For SQL text/varchar
          TypedVariable
              Variable "name of column 2"
              Type 'NumberNode  ;; For SQL numbers
          ...
```

See the OpenCog wiki:
* [SignatureLink](https://wiki.opencog.org/w/SignatureLink)
* [VariableNode](https://wiki.opencog.org/w/VariableNode)
* [TypedVariable](https://wiki.opencog.org/w/TypedVariable)
* [TypeNode](https://wiki.opencog.org/w/TypeNode)

The base AtomSpace supports only a few primitive types; there's no
direct analog to the varied primitive types that SQL has. So far,
it doesn't seem to be needed.  Perhaps the set of primitive types
could be enriched, e.g. by creating:
* `StringNode` for SQL `TEXT` and `VARCHAR` (instead of ConceptNode)
* `DateNode` for SQL dates and times.
* `IntegerNode` (the existing
  [NumberNode](https://wiki.opencog.org/w/NumberNode) is a vector of
  floats. It works great, but some people just love ints.)

Specific databases might benefit from custom types:
* `GeneNode`
* `ProteinNode`
* `URLNode`
* `HumanReadableDescriptionNode`
* `YourFavoriteIdeaHereNode`

The [agi-bio](https://github.com/opencog/agi-bio) project provides
the first two types. The
[cheminformatics](https://github.com/opencog/cheminformatics) project
provides types for atomic elements and molecular binding.

Using
-----
Below is a sketch of how things could work. For actual examples that
actually run and actually work correctly, see the
[examples directory](./examples).

Examples of accessing data in a foreign database.

```
; Describe where it is located.
(define foreign-db
   (BridgeStorageNode "postgres://example.com/foo?user=foo&passwd=bar"))

; Open it.
(cog-open foreign-db)

; Load the *entire* table `gene.allele`. Optional; only if you
; actually want the whole table in RAM. The table name is known
; in advance, and is given directly.
(fetch-incoming-set (Predicate "gene.allele"))

; Instead of loading entire tables, perhaps we only want all
; rows of all tables that mention gene CG7069.
(fetch-incoming-set (Concept "CG7069"))

; Perhaps we plan to do a join. So, load *all* tables that have
; a given column name. In this case, all tables having a column
; called "genotype".
(fetch-incoming-set (Variable "genotype"))

; StorageNodes do have the ability to run generic queries, and
; we could, in principle, translate at least some of the simpler
; Atomese queries into SQL, and run those.
(fetch-query (Meet (Edge (Predicate "gene.allele")
    (List (Concept "CG7069") (Glob "rest of the row")))))

; The fetch-query function is already built into the base, core
; AtomSpace. We could also create custom functions:
(cog-bridge-get-row "gene.allele" (Concept "CG7069"))

; Custom functions are not appealing, since they don't work
; with the rest of the StorageNode and ProxNode infrastructure.
```

It could be convenient to introduce special-purpose
[Atom types](https://wiki.opencog.org/w/Atom_types), such as
`GeneNode` from the agi-bio project. This would allow queries such
as
```
(fetch-incoming-set (Gene "CG7069"))
```
which could be marginally more efficient, presuming that the
`gene.allele` table schema was properly declared:
```
    Signature
       Predicate "gene.allele"
       VariableList
          TypedVariable
              Variable "symbol"
              Type 'GeneNode
          TypedVariable
              Variable "is_alleleof"
              Type 'NumberNode
          TypedVariable
              Variable "propagate_transgenic_uses"
              Type 'NumberNode
          TypedVariable
              Variable "gene_is_regulatory_region"
              Type 'NumberNode
          ...
```

Building and Installing
-----------------------
This module works. It can load tables, it can load joining columns,
and it can join rows, all "automatically".  The build process is
identical to that of other modules in OpenCog.

### Prerequisites

##### AtomSpace
* The AtomSpace, of course.
* https://github.com/opencog/atomspace
* It uses exactly the same build procedure as this package. Be sure
  to `sudo make install` at the end.

##### Postgres
* SQL Database
* https://postgres.org | `apt install postgresql postgresql-client libpq-dev`

### Building this module

Be sure to install the pre-requisites first!
Perform the following steps at the shell prompt:
```
    cd to project root dir
    mkdir build
    cd build
    cmake ..
    make -j4
    sudo make install
    make -j4 check
```

Open Questions
--------------
Some issues to ponder:
* What's the right solution to the foreign-key dilemma?

* The flybase dataset seems to have a large number of extremely complex
  SQL stored procedures. What are they? What do they do? What should we
  do with them?

* What to do with views?

* What if the same table appears in multiple schemas?

-----------------------------------------------------------------------
