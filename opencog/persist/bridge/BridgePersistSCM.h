/*
 * opencog/persist/bridge/BridgePersistSCM.h
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

#ifndef _OPENCOG_FOREIGN_PERSIST_SCM_H
#define _OPENCOG_FOREIGN_PERSIST_SCM_H

#include <opencog/atomspace/AtomSpace.h>

namespace opencog
{
/** \addtogroup grp_persist
 *  @{
 */

class BridgePersistSCM
{
private:
	static void* init_in_guile(void*);
	static void init_in_module(void*);
	void init(void);

	AtomSpacePtr _as;

public:
	BridgePersistSCM(AtomSpace*);
	~BridgePersistSCM();

	HandleSeq do_load_tables(const Handle&);
	HandleSeq do_load_rows(const Handle&, const Handle&, const Handle&, const Handle&);

}; // class

/** @}*/
}  // namespace

extern "C" {
void opencog_persist_bridge_init(void);
};

#endif // _OPENCOG_FOREIGN_PERSIST_SCM_H
