/*
 * FILE:
 * opencog/persist/bridge/SQLReader.cc
 *
 * FUNCTION:
 * Bridge SQL to AtomSpace interfaces.
 *
 * HISTORY:
 * Copyright (c) 2022 Linas Vepstas <linasvepstas@gmail.com>
 *
 * LICENSE:
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License v3 as
 * published by the Free Software Foundation and including the exceptions
 * at http://opencog.org/wiki/Licenses
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program; if not, write to:
 * Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include <filesystem>
#include <sys/resource.h>

#include <opencog/util/Logger.h>
#include <opencog/atoms/base/Node.h>

#include "BridgeStorage.h"

#include "SQLResponse.h"
#include "ll-pg-cxx.h"

using namespace opencog;

/* ================================================================ */

/** get_server_version() -- get version of postgres server */
void BridgeStorage::get_server_version(void)
{
	Response rp(conn_pool);
	rp.exec("SHOW server_version_num;");
	rp.rs->foreach_row(&Response::intval_cb, &rp);
	_server_version = rp.intval;
}

/* ================================================================ */

Handle BridgeStorage::load_one_table(const std::string& tablename)
{
	// Simple query. Placeholder, see notes for what we really need.
	// udt_name is better than data_type
	// If same table in two schemas, then add `AND table_schema = 'foo'`
	// This will get bad results for user-defined types...
	std::string buff =
		"SELECT column_name AS c, udt_name AS t "
		"FROM information_schema.columns "
		"WHERE table_name = '" + tablename + "';";

	Response rp(conn_pool);
	rp.exec(buff);

	HandleSeq tcols;
	rp.as = _atom_space;
	rp.tentries = &tcols;
	rp.rs->foreach_row(&Response::tabledesc_cb, &rp);

	if (0 == tcols.size())
		throw RuntimeException(TRACE_INFO,
			"Error: can't find a table description for %s", tablename.c_str());

	// Create a signature of the general form:
	//
	//    Signature
	//       Edge
	//          Predicate "gene.allele"
	//          List
	//             TypedVariable
	//                 Variable "symbol"
	//                 Type 'GeneNode

	Handle tabc = _atom_space->add_link(VARIABLE_LIST, std::move(tcols));
	Handle tabn = _atom_space->add_node(PREDICATE_NODE, std::string(tablename));
	Handle tabs = _atom_space->add_link(SIGNATURE_LINK, tabn, tabc);
	// printf("============= Loaded table ==>%s<==\n", tablename.c_str());

	return tabs;
}

HandleSeq BridgeStorage::load_tables(void)
{
	if (not _is_open)
		throw RuntimeException(TRACE_INFO,
			"Error: can't load tables; StorageNode is not open!");

	_num_queries++;
	Response rp(conn_pool);
	// This fetches everything except the postgres tables.
	// Unfortunately, it fetches view and other non-table things.
	// rp.exec("SELECT tablename FROM pg_tables WHERE schemaname != 'pg_catalog';");

	// This seems like the correct hack-of-the-moment.
	rp.exec("SELECT tablename FROM pg_tables WHERE schemaname = 'public';");

	std::vector<std::string> tabnames;
	rp.strvec = &tabnames;
	rp.rs->foreach_row(&Response::strvec_cb, &rp);

	_num_tables = tabnames.size();
	_num_rows += _num_tables;
	// printf("Found %lu tables\n", _num_tables);

	HandleSeq tabs;
	for (const std::string& tn : tabnames)
		tabs.emplace_back(load_one_table(tn));

	return tabs;
}

/* ================================================================ */

/// Obtain and return the VariableList from a Signature for a table.
///
/// We are expecting this structure to be available:
///
///   Signature
///       Predicate "some table"  <-- this is given tablename
///       VariableList            <-- this is what we return.
///           TypedVariable
///               Variable "column name"
///               Type 'AtomType
///           ...
///
/// There should be one and only one such structure in RAM.
///
Handle BridgeStorage::get_row_desc(const Handle& tablename)
{
	if (not tablename->is_type(PREDICATE_NODE))
		throw RuntimeException(TRACE_INFO,
			"Error: Expecting the table name to be a Predicate; got %s\n",
			tablename->to_short_string().c_str());

	HandleSeq sigs = tablename->getIncomingSetByType(SIGNATURE_LINK);
	if (1 != sigs.size())
		throw RuntimeException(TRACE_INFO,
			"Cannot find signature for %s\n",
			tablename->to_short_string().c_str());

	return sigs[0]->getOutgoingAtom(1);
}

/// Create a SELECT statement for the given table.
/// If will have the general form
///    SELECT clo1, col2, ... FROM tablename
/// with the column names take from the table signature.
std::string BridgeStorage::make_select(const Handle& tablename)
{
	std::string buff = "SELECT ";

	// listl will be a VariableList; tvl will be a TypedVariableLink
	// We build up a SQL string list of column names, based on the
	// table signature.
	Handle listl(get_row_desc(tablename));
	for (const Handle& tvl : listl->getOutgoingSet())
		buff += tvl->getOutgoingAtom(0)->get_name() + ", ";

	// Trim the trailing comma
	buff.pop_back();
	buff.pop_back();
	buff += " FROM " + tablename->get_name() + " ";

	return buff;
}

/* ================================================================ */

/// Load all rows in the table identified by the tablename.
/// `tablename` must be a PredicateNode attached to a Signature
/// describing the the table.
/// `select` must be an SQL SELECT statement.
void BridgeStorage::load_selected_rows(const Handle& tablename,
                                        const std::string& select)
{
	_num_queries++;

	Response rp(conn_pool);
	rp.exec(select);

	rp.nrows = 0;
	rp.as = _atom_space;
	rp.pred = tablename;
	rp.cols = get_row_desc(tablename)->getOutgoingSet();
	rp.rs->foreach_row(&Response::tabledata_cb, &rp);
	_num_rows += rp.nrows;
}

/// Load all rows in the table identified by the tablename.
/// tablename must be a PredicateNode holding the name of an SQL table,
/// and the signature of that table must already be known (loaded).
void BridgeStorage::load_table_data(const Handle& tablename)
{
	load_selected_rows(tablename, make_select(tablename) + ";");
}

/* ================================================================ */

/// Load all rows in all tables holding this column name.
void BridgeStorage::load_column(const Handle& hv)
{
	// Starting at the variable, walk upwards, searching for
	// Signatures holding this column.
	HandleSeq typed_vars = hv->getIncomingSetByType(TYPED_VARIABLE_LINK);
	for (const Handle& tvar : typed_vars)
	{
		HandleSeq varlists = tvar->getIncomingSetByType(VARIABLE_LIST);
		for (const Handle& varli: varlists)
		{
			HandleSeq sigs = varli->getIncomingSetByType(SIGNATURE_LINK);
			for (const Handle& sig: sigs)
			{
				load_table_data(sig->getOutgoingAtom(0));
			}
		}
	}
}

/* ================================================================ */

/// Load rows from a single table, given just an entry in that row,
/// a column descriptor for the entry, and the table name. Note that
/// this can result in multiple rows being loaded, if that entry appears
/// in multiple rows. of course, if 'entry' is a PRIMARY KEY then only
/// one row is returned.
///
/// This creates an SQL 'SELECT ... WHERE ...' statement, and runs it.
///
void BridgeStorage::select_where(const Handle& entry,     // Concept or Number
                                  const Handle& coldesc,   // TypedVariable
                                  const Handle& tablename) // PredicateNode
{
	// make_select() returns `SELECT col1,col2,.. FROM tablename`
	std::string buff = make_select(tablename);

	// Get the column name
	buff += "WHERE " + coldesc->getOutgoingAtom(0)->get_name() + " = ";

	// Strings need quotes. Numbers do not.
	Type ct = coldesc->getOutgoingAtom(1)->get_type();
	if (NUMBER_NODE != ct) buff += "'";
	buff += entry->get_name();
	if (NUMBER_NODE != ct) buff += "'";
	buff += ";";

	load_selected_rows(tablename, buff);
}

/// Load rows from a single table, given just an entry in that row, a
/// column name for that entry, and the table name.
/// Converts the column name into a column descriptor and calls the
/// function above.
HandleSeq BridgeStorage::load_rows(const Handle& tablename, // PredicateNode
                                    const Handle& colname,   // VariableNode
                                    const Handle& entry)     // Concept or Number
{
	if (not colname->is_type(VARIABLE_NODE))
		throw RuntimeException(TRACE_INFO,
			"Error: expecting the column name to be a VariableNode.\n");

	HandleSeq colds(colname->getIncomingSetByType(TYPED_VARIABLE_LINK));
	for (const Handle& coldesc : colds)
		select_where(entry, coldesc, tablename);

	// As a sop to the user, we're going to return what was found.
	// Of course, they user could do this themselves. But, for now,
	// we're trying to coddle them and make them feel good about this.
	HandleSeq found;
	HandleSeq anon_rows(entry->getIncomingSetByType(LIST_LINK));
	for (const Handle& naked : anon_rows)
	{
		Handle maybe = _atom_space->get_link(EDGE_LINK, tablename, naked);
		if (maybe) found.emplace_back(maybe);
	}

	return found;
}

/* ================================================================ */

/// Given an single entry from some row in some table, and a column
/// description for that entry, find all tables that same column name,
/// and load the corresponding row from those tables.
///
/// This is effectively assuming that `colname` is either a FOREIGN KEY
/// or a PRIMARY KEY in some tables somewhere. We join *everything* with
/// that key, and load it into the AtomSpace.
void BridgeStorage::load_join(const Handle& entry,     // Concept or Number
                               const Handle& coldesc)   // TypedVariable
{
	if (not coldesc->is_type(TYPED_VARIABLE_LINK))
		throw RuntimeException(TRACE_INFO,
			"Internal error, expecting a column description as a TypedVariable\n");

	HandleSeq vlists(coldesc->getIncomingSetByType(VARIABLE_LIST));
	for (const Handle& varli : vlists)
	{
		HandleSeq sigs(varli->getIncomingSetByType(SIGNATURE_LINK));
		for (const Handle& sig : sigs)
			select_where(entry, coldesc, sig->getOutgoingAtom(0));
	}
}

/// Given an single entry from some row in some table, find the column
/// that it belongs to. Then join all other rows in all other tables
/// having that same column name.
///
void BridgeStorage::load_joined_rows(const Handle& entry)
{
	// Que pasa?
	// arow is of the form  (List (Concept "foo") (Concept "bar"))
	// trow is (Edge (Predicate "table") arow)
	// tablename is (Predicate "table")
	// varli is (VariableList (TypedVariale ...) (TypedVariable ...))
	//
	// The loops below start with (Concept "bar"), find all the tables
	// it is in (there must be at least one, or this fails) and then
	// finds the matching (TypedVariable ...) for (Concept "bar").
	// Recall the (TypedVariable ...) is a column descriptor.
	// This is sent upstream, to load all other rows having the same
	// column descriptor and entry.
	HandleSeq anonrows(entry->getIncomingSetByType(LIST_LINK));
	for (const Handle& arow : anonrows)
	{
		HandleSeq trows(arow->getIncomingSetByType(EDGE_LINK));
		for (const Handle& row : trows)
		{
			const Handle& tablename(row->getOutgoingAtom(0));
			const Handle& varli(get_row_desc(tablename));
			const HandleSeq& cols(arow->getOutgoingSet());
			for (size_t i=0; i<cols.size(); i++)
			{
				if (cols[i] == entry)
					load_join(entry, varli->getOutgoingAtom(i));
			}
		}
	}
}

/* ================================================================ */

void BridgeStorage::getAtom(const Handle&)
{
}

Handle BridgeStorage::getLink(Type, const HandleSeq&)
{
	return Handle::UNDEFINED;
}

void BridgeStorage::fetchIncomingSet(AtomSpace* as, const Handle& h)
{
	// Multiple different cases are to be handled:
	// 1) h is a PredicateNode, and so we assume it is the name of a table.
	// 2) h is a VariableNode or TypedVariable, so we assume it is a
	//    column descriptor for one or more tables.
	// 3) h is a ConceptNode or NumberNode; we assume it's some primary or
	//    foreign key in some other tables. Load all of those rows in all
	//    of those tables.

	if (h->is_type(PREDICATE_NODE))
		load_table_data(h);
	else
	if (h->is_type(VARIABLE_NODE))
		load_column(h);
	else
	if (h->is_type(CONCEPT_NODE) or h->is_type(NUMBER_NODE))
		load_joined_rows(h);
	else
		throw RuntimeException(TRACE_INFO,
			"Not supported. Try loading a predicate or variable.\n");
}

void BridgeStorage::fetchIncomingByType(AtomSpace* as, const Handle& h, Type t)
{
	// Ignore the type spec.
	fetchIncomingSet(as, h);
}

void BridgeStorage::storeAtom(const Handle&, bool synchronous)
{
}

void BridgeStorage::removeAtom(AtomSpace*, const Handle&, bool recursive)
{
}

void BridgeStorage::storeValue(const Handle& atom, const Handle& key)
{
}

void BridgeStorage::updateValue(const Handle&, const Handle&, const ValuePtr&)
{
}

void BridgeStorage::loadValue(const Handle& atom, const Handle& key)
{
}

void BridgeStorage::loadType(AtomSpace*, Type)
{
}

void BridgeStorage::loadAtomSpace(AtomSpace*)
{
}

void BridgeStorage::storeAtomSpace(const AtomSpace*)
{
}

/* ============================= END OF FILE ================= */
