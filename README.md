Automapping of SQL DB's
=======================

Design goals: Automatically map pre-existing SQL DB's to/from the
AtomSpace. This is *not* intended for generic save/restore of the
AtomSpace itself. For that, see the native
[atomspace-rocks](https://github.com/opencog/atomspace-rocks) RocksDB
[StorageNode](https://wiki.opencog.org/w/StorageNode) and the
[atomspace-cog](https://github.com/opencog/atomspace-cog) network
StorageNode.

The following are desired features:
* Mapping from the SQL tables to AtomSpace structures is mostly
  automated, by importing pre-existing SQL table schemas.
* Customization of the mapping is possible, so as to allow more
  "natural" [Atomese](https://wiki.opencog.org/w/Atomese)
  representations.
* Both the reading and the update of the SQL tables is possible.

This could be called a "Foreign Data Interface" (FDI) to the AtomSpace.
At this time, it supports Postgres only.

Status
------
***Version 0.0.3*** -- Mostly a collection of design notes. Initial
boilerplate to connect to Postgres.

History
-------
Per request of Mike Duncan, Dec 2022. Map the
[FlyBase Drosophila Genome Database](http://flybase.org)
(current release
[here](https://ftp.flybase.net/releases/FB2022_06/psql/FB2022_06.sql.gz)
into the AtomSpace, using the
[Chado](http://gmod.org/wiki/Chado)
schema given [here](http://gmod.org/wiki/Chado_Tables).

Generic Mapping
---------------
Here's a sketch for a generic mapping. This could work for *any*
SQL database.

For each row in some table `tablename`, create a conventional
Atomese [EvaluationLink](https://wiki.opencog.org/w/EvaluationLink).
```
   Evaluation
      Predicate "tablename"
      List
         Concept "column 1" ; If column type is a string
         Concept "column 2"
         ...
         NumberNode NNN   ; If column type is a number.
```

Primary and Foreign Keys
------------------------
The primary mapping problem is what to do with primary and foreign keys.
The simplest solution is to "do nothing" and let the user just wing it.
That is, to join tables together, the user would write Atomese queries
using the [IdenticalLink](https://wiki.opencog.org/w/IdenticalLink)
to trace between two different predicates (aka tables). This works and
is surprisingly flexible.

Other mappings are possible; however, there is no natural way of asking
Postgres which table columns are foreign keys, and which other tables
they might reference. If this info was possible, then we could have a
an Atomese representation that does NOT keep any keys at all in the
AtomSpace, and instead just makes direct links between table rows.
So, for example:

```
   Evaluation
      Predicate "key join relation"
      Set
         Evaluation ;;; row in the host table
            Predicate "some tablename"
            List ...

         Evaluation   ;; row in the target table.
            Predicate "another tablename"
            List ...

         Evaluation   ;; if more than two tables are joined.
            Predicate "yet another tablename"
            List ...
```
See the OpenCog wiki:
* [EvaluationLink](https://wiki.opencog.org/w/EvaluationLink)
* [PredicateNode](https://wiki.opencog.org/w/PredicateNode)

For just right now, we punt, and store indexes in the AtomSpace.
Its simple and easy. It wastes some RAM, but so what.

Table Schemas
-------------
SQL table definitions are schemas that provide a definition of the
columns of that table.  It is presumably useful to import these into
the AtomSpace. Below is a proposed mapping.

The SQL column names are recorded as
[VariableNode](https://wiki.opencog.org/w/VariableNode) names.
The type of each variable *aka* column is given.
```
 DefineLink
    DefinedSchema "tablename"
    Signature
       Predicate "tablename"
       List
          TypedVariable
              Variable "name of column 1"
              Type 'ConceptNode  ;; For SQL text/varchar
          TypedVariable
              Variable "name of column 2"
              Type 'NumberNode  ;; For SQL numbers
          ...
```

See the OpenCog wiki:
* [DefineLink](https://wiki.opencog.org/w/DefineLink)
* [DefinedSchemaNode](https://wiki.opencog.org/w/DefinedSchemaNode)
* [SignatureLink](https://wiki.opencog.org/w/SignatureLink)
* [VariableNode](https://wiki.opencog.org/w/VariableNode)
* [TypedVariable](https://wiki.opencog.org/w/TypedVariable)
* [TypeNode](https://wiki.opencog.org/w/TypeNode)

The base AtomSpace supports only a few primitive types that
correspond to conventional SQL DB types. Perhaps this could be
enriched, e.g. by creating:
* `StringNode` for SQL `TEXT` and `VARCHAR`
* `DateNode` for SQL dates and times
* `IntegerNode` (the existing
  [NumberNode](https://wiki.opencog.org/w/NumberNode) is a vector of
  floats)

Specific databases might benefit from custom types:
* `GeneNode`
* `ProteinNode`
* `URLNode`

Using
-----
Below is a sketch of how things could work. For actual examples that
actually run and actually do things, see the
[examples directory](./examples).

Examples of accessing data in a foreign database.

```
; Describe where it is located.
(define foreign-db
   (ForeignStoreageNode "postgres://example.com/foo?user=foo&passwd=bar"))

; Open it.
(cog-open foreign-db)

; Load the *entire* table `gene.allele`. Optional; only if you actually
; want the whole table in RAM. We know the table name, and we know that
; we'll be mapping rows to the EvaluationLink.
(fetch-incoming-by-type (Predicate "gene.allele") 'EvaluationLink)

; Instead of loading entire tables, perhaps we only want all rows of
; all tables that mention gene CG7069.
(fetch-incoming-by-type (Concept "CG7069") 'List)

; StorageNodes do have the ability to run generic queries, and we could,
; in principle, translate at least some of the simpler Atomese queries
; into SQL, and run those.
(fetch-query (Meet (Evaluation (Predicate "gene.allele")
    (List (Concept "CG7069") (Glob "rest of the row")))))

; The fetch-query function is already built into the base, core
; AtomSpace. We could, of course, create custom functions:
(automap-get-row "gene.allele" (Concept "CG7069"))
```

It could be conventient to introduce special-purpose
[Atom types](https://wiki.opencog.org/w/Atom_types), such as
`GeneNode` from the agi-bio project. This would allow queries such
as
```
(fetch-incoming-by-type (Gene "CG7069") 'List)
```
which could be marginally more efficient, presuming that the
`gene.allele` table schema was properly declared:
```
 DefineLink
    DefinedSchema "gene.allele"
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
As of now, this module can be built. It compiles and sort-of-ish does
stuff.  The build process is identical to that of other modules in
OpenCog.

### Prerequisites

###### AtomSpace
* The AtomSpace, of course.
* https://github.com/opencog/atomspace
* It uses exactly the same build procedure as this package. Be sure
  to `sudo make install` at the end.

###### Postgres
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
* The flybase dataset seems to have a large number of extremely complex
  SQL stored procedures. What are they? What do they do? What should we
  do with them?

* What to do with views?

* What if the same table appears in multiple schemas?

-----------------------------------------------------------------------
