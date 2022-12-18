/*
 * SQLResponse.h
 * Utility for parsing results returned from SQL.
 *
 * The SQL queries return rows and columns; these need to be
 * re-assembled into Atoms and Values. This is a utility class that
 * aids in this re-assembly. This interfaces to one of the "LLAPI"
 * database drivers that returns rows and columns.
 *
 * Copyright (c) 2008,2009,2013,2017 Linas Vepstas <linas@linas.org>
 *
 * LICENSE:
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
#include <stdlib.h>
#include <unistd.h>

#include <opencog/atoms/base/Atom.h>
#include <opencog/atomspace/AtomSpace.h>

#include "llapi.h"
#include "ForeignStorage.h"

using namespace opencog;

/**
 * Utility class, hangs on to a single response to an SQL query, and
 * provides routines to parse it, i.e. walk the rows and columns,
 * converting each row into an Atom.
 *
 * Intended to be allocated on stack, to avoid malloc overhead.
 * Methods are intended to be inlined, so as to avoid subroutine
 * call overhead.  It's supposed to be a fast convenience wrapper.
 */
class ForeignStorage::Response
{
	public:
		LLRecordSet *rs;

		// Temporary cache of info about atom being assembled.

	private:
		concurrent_stack<LLConnection*>& _pool;
		LLConnection* _conn;

	public:
		Response(concurrent_stack<LLConnection*>& pool) :
			rs(nullptr),
			_pool(pool),
			_conn(nullptr),
			intval(0)
		{}

		~Response()
		{
			if (rs) rs->release();
			rs = nullptr;

			// Put the SQL connection back into the pool.
			if (_conn) _pool.push(_conn);
			_conn = nullptr;
		}

		void exec(const char * buff)
		{
			if (rs) rs->release();

			// Get an SQL connection.  If the pool is empty, this will
			// block, waiting for a connection to be returned to the pool.
			// Thus, the size of the pool regulates how many outstanding
			// SQL requests can be pending in parallel.
			if (nullptr == _conn) _conn = _pool.value_pop();
			rs = _conn->exec(buff, false);
		}
		void try_exec(const char * buff)
		{
			if (rs) rs->release();
			if (nullptr == _conn) _conn = _pool.value_pop();
			rs = _conn->exec(buff, true);
		}
		void exec(const std::string& str)
		{
			exec(str.c_str());
		}
		void try_exec(const std::string& str)
		{
			try_exec(str.c_str());
		}

		// Generic things --------------------------------------------
		// Get generic positive integer values
		unsigned long intval;
		bool intval_cb(void)
		{
			rs->foreach_column(&Response::intval_column_cb, this);
			return false;
		}

		bool intval_column_cb(const char *colname, const char * colvalue)
		{
			// we're not going to bother to check the column name ...
			intval = strtoul(colvalue, NULL, 10);
			return false;
		}

		// Strings --------------------------------------------
		std::vector<std::string>* strvec;
		bool strvec_cb(void)
		{
			rs->foreach_column(&Response::strval_column_cb, this);
			return false;
		}

		bool strval_column_cb(const char *colname, const char * colvalue)
		{
			// we're not going to bother to check the column name ...
			strvec->emplace_back(colvalue);
			return false;
		}

		// Table descriptions --------------------------------------------
		AtomSpace* as;
		HandleSeq* tentries;
		Handle vcol;
		Handle tcol;
		bool tabledesc_cb(void)
		{
			rs->foreach_column(&Response::table_column_cb, this);
			Handle tyv = as->add_link(TYPED_VARIABLE_LINK, vcol, tcol);
			tentries->emplace_back(tyv);
			return false;
		}
		bool table_column_cb(const char *colname, const char * colvalue)
		{
			if ('c' == colname[0])
			{
				vcol = as->add_node(VARIABLE_NODE, std::string(colvalue));
			}
			else if ('t' == colname[0])
			{
				if (!strcmp(colvalue, "text") or
				    !strcmp(colvalue, "varchar"))
				{
					tcol = as->add_node(TYPE_NODE, "ConceptNode");
				}
				else
				if (!strcmp(colvalue, "int4") or
				    !strcmp(colvalue, "int8"))
				{
					tcol = as->add_node(TYPE_NODE, "NumberNode");
				}
				else
					printf("duuuude unknow coltype >>%s<<\n", colvalue);
			}
			return false;
		}


};

/* ============================= END OF FILE ================= */
