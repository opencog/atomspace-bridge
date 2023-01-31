/*
 * opencog/persist/bridge/BridgePersistSCM.cc
 * Scheme Guile API wrappers for the backend.
 *
 * Copyright (c) 2020 Linas Vepstas <linasvepstas@gmail.com>
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

#include <libguile.h>

#include <opencog/atomspace/AtomSpace.h>
#include <opencog/persist/api/PersistSCM.h>
#include <opencog/persist/api/StorageNode.h>
#include <opencog/guile/SchemePrimitive.h>

#include "BridgeStorage.h"
#include "BridgePersistSCM.h"

using namespace opencog;


// =================================================================

BridgePersistSCM::BridgePersistSCM(AtomSpace *as)
{
	if (as)
		_as = AtomSpaceCast(as->shared_from_this());

	static bool is_init = false;
	if (is_init) return;
	is_init = true;
	scm_with_guile(init_in_guile, this);
}

void* BridgePersistSCM::init_in_guile(void* self)
{
	scm_c_define_module("opencog persist-bridge", init_in_module, self);
	scm_c_use_module("opencog persist-bridge");
	return NULL;
}

void BridgePersistSCM::init_in_module(void* data)
{
   BridgePersistSCM* self = (BridgePersistSCM*) data;
   self->init();
}

void BridgePersistSCM::init(void)
{
	define_scheme_primitive("cog-bridge-load-tables",
		&BridgePersistSCM::do_load_tables, this, "persist-bridge");
	define_scheme_primitive("cog-bridge-load-rows",
		&BridgePersistSCM::do_load_rows, this, "persist-bridge");
}

BridgePersistSCM::~BridgePersistSCM()
{
}

#define GET_STNP(FUNC) \
	BridgeStorageNodePtr stnp = BridgeStorageNodeCast(ston); \
	if (nullptr == stnp) \
		throw RuntimeException(TRACE_INFO, \
			FUNC ": Error: Bad StorageNode! Got %s", \
			ston->to_short_string().c_str());

HandleSeq BridgePersistSCM::do_load_tables(const Handle& ston)
{
	GET_STNP("cog-bridge-load-tables");
	return stnp->load_tables();
}

HandleSeq BridgePersistSCM::do_load_rows(const Handle& ston,
                                          const Handle& table,
                                          const Handle& column,
                                          const Handle& entry)
{
	GET_STNP("cog-bridge-load-rows");
	return stnp->load_rows(table, column, entry);
}

void opencog_persist_bridge_init(void)
{
	static BridgePersistSCM patty(nullptr);
}
