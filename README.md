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

Status
------
***Version 0.0.0***
At this time, this is just a collection of design notes; nothing has
been implemented.

History
-------
Per request of Mike Duncan. Map the
[FlyBase Drosophila Genome Database](http://flybase.org)
(current release
[here](https://ftp.flybase.net/releases/FB2022_06/psql/FB2022_06.sql.gz)
into the AtomSpace, using the
[Chado](http://gmod.org/wiki/Chado)
schema given [here](http://gmod.org/wiki/Chado_Tables).

Generic Mapping
---------------
Here's a sketch for a generic mapping.

For each row in tablename, create a conventional EvaluationLink.
It contains *only* the columns that are not foreign keys:
```
   Evaluation
      Predicate "tablename"
      List
         Concept "column 1" ; If column type is a string
         Concept "column 2"
         ...
         NumberNode NNN   ; If column type is a number.
```

For each row in tablename having a column that is a foreign key:
```
   Evaluation
      Predicate "host tablename . foreign key"
      List
         Evaluation ;;; row in the host table
            Predicate "host tablename"
            List
               Concept ...

         Evaluation   ;; row in the target table.
            Predicate "target tablename"
            List
               Concept ...
```
See the OpenCog wiki:
* [EvaluationLink](https://wiki.opencog.org/w/EvaluationLink)
* [PredicateNode](https://wiki.opencog.org/w/PredicateNode)


Table Schemas
-------------
SQL table definitions are schemas that provide a definition of the
columns of that table.  It is presumably useful to import these into
the AtomSpace. Below is a proposed mapping.

```
 DefineLink
    DefinedSchema "tablename"
    SignatureLink
       Evaluation
          Predicate "tablename"
          List
             TypeNode 'ConceptNode  ;; For SQL text/varchar
             TypeNode 'ConceptNode
             ...
             TypeNode 'NumberNode   ;; For SQL numbers
```

See the OpenCog wiki:
* [DefineLink](https://wiki.opencog.org/w/DefineLink)
* [DefinedSchemaNode](https://wiki.opencog.org/w/DefinedSchemaNode)
* [SignatureLink](https://wiki.opencog.org/w/SignatureLink)
* [TypeNode](https://wiki.opencog.org/w/TypeNode)

Perhaps the above is not so wise; SQL tables do have column
names, and perhaps we want to capture those names. For this,
use a labelled type signature aka a "variable node".
```
 DefineLink
    DefinedSchema "tablename"
    SignatureLink
       Evaluation
          Predicate "tablename"
          List
             TypedVariable
                 Variable "name of column 1"
                 TypeNode 'ConceptNode  ;; For SQL text/varchar
             TypedVariable
                 Variable "name of column 2"
                 TypeNode 'NumberNode  ;; For SQL numbers
             ...
```
See the OpenCog wiki:
* [VariableNode](https://wiki.opencog.org/w/VariableNode)
* [TypedVariable](https://wiki.opencog.org/w/TypedVariable)

Using
-----
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
       Evaluation
          Predicate "gene.allele"
          List
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

-----------------------------------------------------------------------
