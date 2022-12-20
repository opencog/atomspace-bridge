/*
 * opencog/persist/automap/ForeignPersistSCM.cc
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

#include "ForeignStorage.h"
#include "ForeignPersistSCM.h"

using namespace opencog;


// =================================================================

ForeignPersistSCM::ForeignPersistSCM(AtomSpace *as)
{
	if (as)
		_as = AtomSpaceCast(as->shared_from_this());

	static bool is_init = false;
	if (is_init) return;
	is_init = true;
	scm_with_guile(init_in_guile, this);
}

void* ForeignPersistSCM::init_in_guile(void* self)
{
	scm_c_define_module("opencog persist-foreign", init_in_module, self);
	scm_c_use_module("opencog persist-foreign");
	return NULL;
}

void ForeignPersistSCM::init_in_module(void* data)
{
   ForeignPersistSCM* self = (ForeignPersistSCM*) data;
   self->init();
}

void ForeignPersistSCM::init(void)
{
	define_scheme_primitive("cog-foreign-load-tables",
		&ForeignPersistSCM::do_load_tables, this, "persist-foreign");
	define_scheme_primitive("cog-foreign-load-rows",
		&ForeignPersistSCM::do_load_rows, this, "persist-foreign");
}

ForeignPersistSCM::~ForeignPersistSCM()
{
}

#define GET_STNP(FUNC) \
	ForeignStorageNodePtr stnp = ForeignStorageNodeCast(ston); \
	if (nullptr == stnp) \
		throw RuntimeException(TRACE_INFO, \
			FUNC ": Error: Bad StorageNode! Got %s", \
			ston->to_short_string().c_str());

HandleSeq ForeignPersistSCM::do_load_tables(const Handle& ston)
{
	GET_STNP("cog-foreign-load-tables");
	return stnp->load_tables();
}

HandleSeq ForeignPersistSCM::do_load_rows(const Handle& ston,
                                          const Handle& table,
                                          const Handle& column,
                                          const Handle& entry)
{
	GET_STNP("cog-foreign-load-rows");
	return stnp->load_rows(table, column, entry);
}

void opencog_persist_fdi_init(void)
{
	static ForeignPersistSCM patty(nullptr);
}
