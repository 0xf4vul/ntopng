/*
 *
 * (C) 2013-15 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#ifndef _MYSQL_DB_CLASS_H_
#define _MYSQL_DB_CLASS_H_

#include "ntop_includes.h"

#ifdef HAVE_MYSQL

class MySQLDB : public DB {
 private:
  MYSQL mysql;
  bool db_operational;

  bool connectToDB(bool select_db);
  char* get_last_db_error() { return((char*)mysql_error(&mysql)); }
  int exec_sql_query(char *sql, int do_reconnect = 1);
  bool dumpV4Flow(time_t when, Flow *f, char *json);
  bool dumpV6Flow(time_t when, Flow *f, char *json);
  
 public:
  MySQLDB(NetworkInterface *_iface = NULL);
  ~MySQLDB();
  
  bool dumpFlow(time_t when, Flow *f, char *json);
};

#endif

#endif /* _MYSQL_DB_CLASS_H_ */
