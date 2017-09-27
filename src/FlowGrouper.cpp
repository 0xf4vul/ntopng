/*
 *
 * (C) 2017 - ntop.org
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

FlowGrouper::FlowGrouper(sortField sf){
  sorter = sf;
  app_protocol = 0;
  client = NULL;
  server = NULL;
  table_index = 1;

  memset(&stats, 0, sizeof(stats));
  pass_verdict = false;
}

/* *************************************** */

FlowGrouper::~FlowGrouper() {}

/* *************************************** */

bool FlowGrouper::inGroup(Flow *flow) {
  switch(sorter) {
    case column_ndpi_peers:
      return ((flow->get_detected_protocol().app_protocol == app_protocol) &&
          (flow->get_cli_host() && flow->get_srv_host()) &&
          (((flow->get_cli_host()->getMac() == client) && (flow->get_srv_host()->getMac() == server)) ||
            ((flow->get_cli_host()->getMac() == server) && (flow->get_srv_host()->getMac() == client))));
    default:
      return false;
  }
}

/* *************************************** */

int FlowGrouper::newGroup(Flow *flow) {
  if(flow == NULL)
    return -1;

  memset(&stats, 0, sizeof(stats));
  pass_verdict = false;

  switch(sorter) {
    case column_ndpi_peers:
      app_protocol = flow->get_detected_protocol().app_protocol;
      client = flow->get_cli_host()->getMac(); // TODO handle NULL
      server = flow->get_srv_host()->getMac(); // TODO handle NULL
      break;
    default:
      return -1;
  }

  return 0;
}

/* *************************************** */

int FlowGrouper::incStats(Flow *flow) {
  if(flow == NULL || !inGroup(flow))
    return -1;

  stats.bytes_cli2srv += flow->get_bytes_cli2srv();
  stats.bytes_srv2cli += flow->get_bytes_srv2cli();
  stats.bytes_thpt += flow->get_bytes_thpt();

  if(stats.first_seen == 0 || flow->get_first_seen() < stats.first_seen)
    stats.first_seen = flow->get_first_seen();
  if(flow->get_last_seen() > stats.last_seen)
    stats.last_seen = flow->get_last_seen();

#ifdef NTOPNG_PRO
  if(flow->isPassVerdict())
#endif
    pass_verdict = true;

  stats.num_flows++;
  return 0;
}

/* *************************************** */

void FlowGrouper::lua(lua_State* vm) {
  lua_newtable(vm);
  char buf[32];

  lua_push_str_table_entry(vm, "client", Utils::formatMac(client->get_mac(), buf, sizeof(buf)));
  lua_push_str_table_entry(vm, "server", Utils::formatMac(server->get_mac(), buf, sizeof(buf)));
  lua_push_int_table_entry(vm, "proto", app_protocol);
  lua_push_bool_table_entry(vm, "verdict.pass", pass_verdict);

  lua_push_int_table_entry(vm, "cli2srv.bytes", stats.bytes_cli2srv);
  lua_push_int_table_entry(vm, "srv2cli.bytes", stats.bytes_srv2cli);
  lua_push_int_table_entry(vm, "seen.first", stats.first_seen);
  lua_push_int_table_entry(vm, "seen.last", stats.last_seen);
  lua_push_int_table_entry(vm, "num_flows", stats.num_flows);
  lua_push_float_table_entry(vm, "throughput_bps", max_val(stats.bytes_thpt, 0));

  lua_rawseti(vm, -2, table_index++);
}
