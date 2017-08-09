/*
 *
 * (C) 2013-17 - ntop.org
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

#ifndef _SNMP_H_
#define _SNMP_H_

#include "ntop_includes.h"

#define SNMP_MAX_NUM_OIDS          5

/* ******************************* */

class SNMP {
 private:
  int udp_sock;

  int _get(char *agentIP, char *community, char *oid, u_int8_t snmp_version);
  int _getnext(char *agentIP, char *community, char *oid, u_int8_t snmp_version);
  int snmp_get_fctn(lua_State* vm, int operation);  
  void send_snmp_request(char *agent_host, char *community, int operation, char *oid[SNMP_MAX_NUM_OIDS], u_int version);
  int snmp_read_response(lua_State* vm, u_int timeout);
  
  public:
  SNMP();
  ~SNMP();

  int get(lua_State* vm);
  int getnext(lua_State* vm);
};
  
#endif /* _SNMP_H_ */
