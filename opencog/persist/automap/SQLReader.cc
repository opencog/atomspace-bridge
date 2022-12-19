/*
 * FILE:
 * opencog/persist/automap/SQLReader.cc
 *
 * FUNCTION:
 * Foreign SQL to AtomSpace interaces.
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

#include "ForeignStorage.h"

#include "SQLResponse.h"
#include "ll-pg-cxx.h"

using namespace opencog;

/* ================================================================ */

/** get_server_version() -- get version of postgres server */
void ForeignStorage::get_server_version(void)
{
	Response rp(conn_pool);
	rp.exec("SHOW server_version_num;");
	rp.rs->foreach_row(&Response::intval_cb, &rp);
	_server_version = rp.intval;
}

/* ================================================================ */

Handle ForeignStorage::load_one_table(const std::string& tablename)
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

	// Create a signature of the general form:
	//
	//    Signature
	//       Evaluation
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

void ForeignStorage::load_tables(void)
{
	if (not _is_open)
		throw RuntimeException(TRACE_INFO,
			"Error: can't load tables; StorageNode is not open!");

	_num_queries++;
	Response rp(conn_pool);
	// This fetches everything except the postgres tables.
	// Unfortunately, it fetchs view and other non-table things.
	// rp.exec("SELECT tablename FROM pg_tables WHERE schemaname != 'pg_catalog';");

	// This seems like the correct hack-of-the-moment.
	rp.exec("SELECT tablename FROM pg_tables WHERE schemaname = 'public';");

	std::vector<std::string> tabnames;
	rp.strvec = &tabnames;
	rp.rs->foreach_row(&Response::strvec_cb, &rp);

	_num_tables = tabnames.size();
	_num_rows += _num_tables;
	printf("Found %lu tables\n", _num_tables);
	for (const std::string& tn : tabnames)
		load_one_table(tn);
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
Handle ForeignStorage::get_row_desc(const Handle& tablename)
{
	if (not tablename->is_type(PREDICATE_NODE))
		throw RuntimeException(TRACE_INFO,
			"Internal error, expecting the table name to be a Predicate\n");

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
std::string ForeignStorage::make_select(const Handle& tablename)
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
/// tablename must be a PredicateNode holding the name of an SQL table,
/// and the signature of that table must already be known (loaded).
void ForeignStorage::load_table_data(const Handle& tablename)
{
	_num_queries++;

	Response rp(conn_pool);
	rp.exec(make_select(tablename) + ";");

	rp.nrows = 0;
	rp.as = _atom_space;
	rp.pred = tablename;
	rp.cols = get_row_desc(tablename)->getOutgoingSet();
	rp.rs->foreach_row(&Response::tabledata_cb, &rp);
	_num_rows += rp.nrows;
}

/* ================================================================ */

/// Load all rows in all tables holding this column name.
void ForeignStorage::load_column(const Handle& hv)
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

/// Load a single row fom a single table, given just an entry in
/// that row, an ID for the row, and the table name.
void ForeignStorage::load_row(const Handle& entry,     // Concept or Number
                              const Handle& colname,   // TypedVariable
                              const Handle& tablename) // PredicateNode
{
	_num_queries++;

	if (not colname->is_type(TYPED_VARIABLE_LINK))
		throw RuntimeException(TRACE_INFO,
			"Internal error, expecting a TypedVariable\n");

	if (not tablename->is_type(PREDICATE_NODE))
		throw RuntimeException(TRACE_INFO,
			"Internal error, expecting a Predicate\n");

	std::string buff = make_select(tablename);
}

/* ================================================================ */

/// Load rows from tables that have the same column name
void ForeignStorage::load_rows(const Handle& hv)
{
}

/* ================================================================ */

void ForeignStorage::getAtom(const Handle&)
{
}

Handle ForeignStorage::getLink(Type, const HandleSeq&)
{
	return Handle::UNDEFINED;
}

void ForeignStorage::fetchIncomingSet(AtomSpace* as, const Handle& h)
{
	// Multiple different cases are to be handled:
	// 1) h is a PredicateNode, and so we assume it is the name of a table.
	// 2) h is a VariableNode or TypedVariable, so we assume it names
	//    a solumn in one or more tables.
	// 3) h is a ConceptNode; we assume it's some in some row of some
	//    table.
	// 4) h is a NumberNode; we assume it's a primary/foreign key.

	if (h->is_type(PREDICATE_NODE))
		load_table_data(h);
	else
	if (h->is_type(VARIABLE_NODE))
		load_column(h);
	else
		throw RuntimeException(TRACE_INFO,
			"Not supported. Try loading a predicate or variable.\n");
}

void ForeignStorage::fetchIncomingByType(AtomSpace* as, const Handle& h, Type t)
{
	// Ignore the type spec.
	fetchIncomingSet(as, h);
}

void ForeignStorage::storeAtom(const Handle&, bool synchronous)
{
}

void ForeignStorage::removeAtom(AtomSpace*, const Handle&, bool recursive)
{
}

void ForeignStorage::storeValue(const Handle& atom, const Handle& key)
{
}

void ForeignStorage::updateValue(const Handle&, const Handle&, const ValuePtr&)
{
}

void ForeignStorage::loadValue(const Handle& atom, const Handle& key)
{
}

void ForeignStorage::loadType(AtomSpace*, Type)
{
}

void ForeignStorage::loadAtomSpace(AtomSpace*)
{
}

void ForeignStorage::storeAtomSpace(const AtomSpace*)
{
}

/* ============================= END OF FILE ================= */
