/*
 * FILE:
 * opencog/persist/automap/ForeignPG.cc
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

/** get_server_version() -- get version of postgres server */
void ForeignStorage::get_server_version(void)
{
	Response rp(conn_pool);
	rp.exec("SHOW server_version_num;");
	rp.rs->foreach_row(&Response::intval_cb, &rp);
	_server_version = rp.intval;
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

void ForeignStorage::storeAtom(const Handle&, bool synchronous = false)
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
