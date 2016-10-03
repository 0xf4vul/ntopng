/*
 *
 * (C) 2013-16 - ntop.org
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

#include "ntop_includes.h"

/* *************************************** */

Mac::Mac(NetworkInterface *_iface, u_int8_t _mac[6], u_int16_t _vlanId) : GenericHashEntry(_iface) {
  memcpy(mac, _mac, 6), vlan_id = _vlanId;

#ifdef DEBUG
  char buf[32];

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Created %s/%u", 
			       Utils::formatMac(mac, buf, sizeof(buf)), vlan_id);
#endif
}

/* *************************************** */

Mac::~Mac() {
  ;
}

/* *************************************** */

bool Mac::idle() {
  if((num_uses > 0) || (!iface->is_purge_idle_interface()))
    return(false);
  
  return(isIdle(MAX_LOCAL_HOST_IDLE));
}

/* *************************************** */

void Mac::lua(lua_State* vm, bool show_details, bool asListElement) {
  char buf[32], *m;

  lua_newtable(vm);

  lua_push_str_table_entry(vm, "mac", m = Utils::formatMac(mac, buf, sizeof(buf)));
  lua_push_int_table_entry(vm, "vlan", vlan_id);

  lua_push_int_table_entry(vm, "bytes.sent", sent.getNumBytes());
  lua_push_int_table_entry(vm, "bytes.rcvd", rcvd.getNumBytes());

  if(show_details) {
    // TODO
  }

  if(asListElement) {
    lua_pushstring(vm, m);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}
 
/* *************************************** */

bool Mac::equal(u_int16_t _vlanId, const u_int8_t _mac[6]) {
  if((vlan_id == _vlanId) && (memcmp(mac, _mac, 6) == 0))
    return(true);
  else
    return(false);
}
