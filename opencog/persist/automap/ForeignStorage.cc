/*
 * FILE:
 * opencog/persist/automap/ForeignStorage.cc
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

using namespace opencog;

/* ================================================================ */
// Constructors

void ForeignStorage::init(const char * uri)
{
#define URIX_LEN (sizeof("postgres://") - 1)  // Should be 11
	// We expect the URI to be for the form
	//    postgres://example.com/dbase?user=foo&passwd=bar
	std::string file(uri + URIX_LEN);

}

void ForeignStorage::open()
{
	// User might call us twice. If so, ignore the second call.
	// if (_rfile) return;
	init(_name.c_str());
}

ForeignStorage::ForeignStorage(std::string uri) :
	StorageNode(FOREIGN_STORAGE_NODE, std::move(uri))
{
	const char *yuri = _name.c_str();

	// We expect the URI to be for the form (note: three slashes)
	//    rocks:///path/to/file
	if (strncmp(yuri, "rocks://", URIX_LEN))
		throw IOException(TRACE_INFO,
			"Unknown URI '%s'\nValid URI's start with 'rocks://'\n", yuri);

	_uri = "rocks://" + file;
	_name = _uri;
}

ForeignStorage::~ForeignStorage()
{
	close();
}

void ForeignStorage::close()
{
	// if (nullptr == _rfile) return;
}

std::string ForeignStorage::get_version(void)
{
	return "none";
}

bool ForeignStorage::connected(void)
{
	// return nullptr != _rfile;
	return false;
}

/* ================================================================== */
/// Drain the pending store queue. This is a fencing operation; the
/// goal is to make sure that all writes that occurred before the
/// barrier really are performed before before all the writes after
/// the barrier.
///
void ForeignStorage::barrier(AtomSpace* as)
{
}

/* ================================================================ */

void ForeignStorage::clear_stats(void)
{
}

std::string ForeignStorage::monitor(void)
{
	std::string rs;
	rs += "Connected to `" + _uri + "`\n";
	return rs;
}

void ForeignStorage::print_stats(void)
{
	printf("%s\n", monitor().c_str());
}

DEFINE_NODE_FACTORY(ForeignStorageNode, FOREIGN_STORAGE_NODE)

/* ============================= END OF FILE ================= */
