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

Status
------
***Version 0.0.0 ***
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

Attempt #1
----------
For each row in tablename, create a conventional EvaluationLink.
It contains *only* the columns that are not foreign keys:
```
	Evaluation
		Predicate "tablename"
		List
			Concept "column 1" ; If column type is a string
			Concept "column 2"
			...
			NumberNode NNN	; If column type is a number.
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

			Evaluation	;; row in the target table.
				Predicate "target tablename"
				List
					Concept ...
```

That's it. Is there more?

-----------------------------------------------------------------------
