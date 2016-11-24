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

#ifndef _ALERTS_PAGINATOR_H_
#define _ALERTS_PAGINATOR_H_

#include "ntop_includes.h"

class AlertsPaginator : public Paginator {
 private:
  bool alert_severity_set;
  AlertLevel alert_severity;
  bool alert_type_set;
  AlertType alert_type;
  bool alert_entity_set;
  AlertEntity alert_entity;
  char * alert_entity_value;

 public:
  AlertsPaginator();
  ~AlertsPaginator();

  void readOptions(lua_State *L, int index);
  
  inline bool severityFilter(AlertLevel *as) {
    if(alert_severity_set) { if(as) *as = alert_severity; return true; } return false;
  };
  inline bool typeFilter(AlertType *at) {
    if(alert_type_set) { if (at) *at = alert_type; return true; } return false;
  };
  inline bool entityFilter(AlertEntity *ae) {
    if(alert_entity_set) { if (ae) *ae = alert_entity; return true; } return false;
  };
  inline bool entityValueFilter(char **ev) {
    if(alert_entity_value) { (*ev) = alert_entity_value; return true; } return false;
  };
};

#endif
