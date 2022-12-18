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
printf("duuude found table ==>%s<==\n", tablename.c_str());
#if 0
	Response rp(conn_pool);

	// udt_name is better than data_type
	// If same table in two schemas, then add `AND table_schema = 'foo'`
	// This will get bad results for user-defined types...
	std::string buff =
		"SELECT column_name, udt_name FROM information_schema.columns "
		"WHERE table_name =  '" + tablename + "';";
	rp.exec(buff);

	rp.rs->foreach_row(&Response::strvecvec_cb, &rp);
#endif
	Handle tabh = _atom_space->add_node(PREDICATE_NODE, std::string(tablename));
	return tabh;
}

void ForeignStorage::load_tables(void)
{
	std::vector<std::string> tabnames;

	Response rp(conn_pool);
	rp.strvec = &tabnames;

	rp.exec("SELECT tablename FROM pg_tables WHERE schemaname != 'pg_catalog';");
	rp.rs->foreach_row(&Response::strvec_cb, &rp);

printf("duude found %lu tables\n", tabnames.size());
	for (const std::string& tn : tabnames)
		load_one_table(tn);
}

/* ================================================================ */

void ForeignStorage::getAtom(const Handle&)
{
}

Handle ForeignStorage::getLink(Type, const HandleSeq&)
{
	return Handle::UNDEFINED;
}

void ForeignStorage::fetchIncomingSet(AtomSpace*, const Handle&)
{
}

void ForeignStorage::fetchIncomingByType(AtomSpace*, const Handle&, Type t)
{
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
