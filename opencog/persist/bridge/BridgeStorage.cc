/*
 * FILE:
 * opencog/persist/bridge/BridgeStorage.cc
 *
 * FUNCTION:
 * AtomSpace to SQL Bridge interfaces.
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

#include <opencog/atoms/atom_types/types.h>
#include <opencog/atoms/base/Node.h>
#include <opencog/atomspace/AtomSpace.h>
#include <opencog/persist/storage/storage_types.h>

#include "BridgeStorage.h"

#include "ll-pg-cxx.h"

using namespace opencog;

// Hard-code to 3 threads for now
#define POOL_SIZE 3

/* ================================================================ */
// Constructors

BridgeStorage::BridgeStorage(std::string uri) :
	StorageNode(FOREIGN_STORAGE_NODE, std::move(uri))
{
	const char *yuri = _name.c_str();

#define URIX_LEN (sizeof("postgres://") - 1)  // Should be 11
	// We expect the URI to be for the form
	//    postgres://example.com/dbase?user=foo&passwd=bar
	if (strncmp(yuri, "postgres://", URIX_LEN))
		throw IOException(TRACE_INFO,
			"Unknown URI '%s'\nValid URI's start with 'postgres://'\n", yuri);

	// _name = _uri;
	_initial_conn_pool_size = 0;
	_is_open = false;
}

BridgeStorage::~BridgeStorage()
{
	close();
}

/* ================================================================ */
// Connections and opening

void BridgeStorage::enlarge_conn_pool(int delta, const char* uri)
{
	if (0 >= delta) return;
	for (int i=0; i<delta; i++)
	{
		LLConnection* db_conn = new LLPGConnection(uri);
		conn_pool.push(db_conn);
	}

	_initial_conn_pool_size += delta;
}

// Public function
void BridgeStorage::open(void)
{
	// User might call us twice. If so, ignore the second call.
	if (_is_open) return;

	if (0 == _initial_conn_pool_size)
		enlarge_conn_pool(POOL_SIZE, _name.c_str());

	_is_open = true;
	if (not connected())
		throw IOException(TRACE_INFO,
			"Failed to connect to %s\n", _name.c_str());

	// Initialize stuff
	_num_queries = 0;
	_num_tables = 0;
	_num_rows = 0;

	// We don't really need to do this...
	get_server_version();
printf("Connected to Postgres server version %d\n", _server_version);
}

void BridgeStorage::close(void)
{
	if (not _is_open) return;

	close_conn_pool();
	_is_open = false;
}

bool BridgeStorage::connected(void)
{
	if (0 == _is_open) return false;
	if (0 == _initial_conn_pool_size) return false;

	// This will leak a resource, if db_conn->connected() ever throws.
	LLConnection* db_conn = conn_pool.value_pop();
	bool have_connection = db_conn->connected();
	conn_pool.push(db_conn);

	_is_open = have_connection;
	return have_connection;
}

void BridgeStorage::close_conn_pool(void)
{
   // flushStoreQueue();

   while (not conn_pool.is_empty())
   {
      LLConnection* db_conn = conn_pool.value_pop();
      delete db_conn;
   }
   _initial_conn_pool_size = 0;
}

/* ================================================================== */
/// Drain the pending store queue. This is a fencing operation; the
/// goal is to make sure that all writes that occurred before the
/// barrier really are performed before before all the writes after
/// the barrier.
///
void BridgeStorage::barrier(AtomSpace* as)
{
}

/* ================================================================ */

void BridgeStorage::clear_stats(void)
{
}

std::string BridgeStorage::monitor(void)
{
	std::string rs;
	if (not _is_open)
	{
		rs += "No connection to DB `" + _name + "`\n";
		return rs;
	}

	rs += "Connected to: " + _name + "\n";
	rs += "Posgres server version: " + _server_version;
	rs += "\n";
	rs += "Number of queries issued: " + std::to_string(_num_queries) + "\n";
	rs += "Number of loaded tables: " + std::to_string(_num_tables) + "\n";
	rs += "Number of rows loaded: " + std::to_string(_num_rows) + "\n";
	return rs;
}

void BridgeStorage::print_stats(void)
{
	printf("%s\n", monitor().c_str());
}

DEFINE_NODE_FACTORY(BridgeStorageNode, BRIDGE_STORAGE_NODE)

/* ============================= END OF FILE ================= */
