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

#ifndef _ALERTS_MANAGER_H_
#define _ALERTS_MANAGER_H_

#include "ntop_includes.h"

//class Host;

class AlertsManager : protected StoreManager {
 private:
  char queue_name[CONST_MAX_LEN_REDIS_KEY];
  bool store_opened, store_initialized;
  int openStore();
  
  /* methods used for alerts that have a timespan */
  bool isAlertEngaged(AlertEntity alert_entity, const char *alert_entity_value, const char *engaged_alert_id);
  int engageAlert(AlertEntity alert_entity, const char *alert_entity_value,
		  const char *engaged_alert_id,
		  AlertType alert_type, AlertLevel alert_severity, const char *alert_json);
  int releaseAlert(AlertEntity alert_entity, const char *alert_entity_value,
		   const char *engaged_alert_id,
		   AlertType alert_type, AlertLevel alert_severity, const char *alert_json);
  int storeAlert(AlertEntity alert_entity, const char *alert_entity_value,
		 AlertType alert_type, AlertLevel alert_severity, const char *alert_json);

  int engageReleaseHostAlert(Host *h,
			     const char *engaged_alert_id,
			     AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
			     bool engage);
  int engageReleaseNetworkAlert(const char *cidr,
				const char *engaged_alert_id,
				AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
				bool engage);
  int engageReleaseInterfaceAlert(NetworkInterface *n,
				  const char *engaged_alert_id,
				  AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
				  bool engage);

  /* methods used to retrieve alerts and counters with possible sql clause to filter */
  int getAlerts(lua_State* vm, patricia_tree_t *allowed_hosts,
		u_int32_t start_offset, u_int32_t end_offset,
		bool engaged, const char *sql_where_clause);
  int getNumAlerts(bool engaged, const char *sql_where_clause);

  /* private methods to check the goodness of submitted inputs and possible return the input database string */
  bool isValidHost(Host *h, char *host_string, size_t host_string_len);
  bool isValidFlow(Flow *f);
  bool isValidNetwork(const char *cidr);
  bool isValidInterface(NetworkInterface *n);

 public:
  AlertsManager(int interface_id, const char *db_filename);
  ~AlertsManager() {};

#ifdef NOTUSED
  int storeAlert(AlertType alert_type, AlertLevel alert_severity, const char *alert_json);
  int storeAlert(lua_State *L, int index);
#endif

  /*
    ========== HOST alerts API =========
   */
  inline int engageHostAlert(Host *h,
			     const char *engaged_alert_id,
			     AlertType alert_type, AlertLevel alert_severity, const char *alert_json) {
    return engageReleaseHostAlert(h, engaged_alert_id, alert_type, alert_severity, alert_json, true /* engage */);
  };
  inline int releaseHostAlert(Host *h,
			      const char *engaged_alert_id,
			      AlertType alert_type, AlertLevel alert_severity, const char *alert_json) {
    return engageReleaseHostAlert(h, engaged_alert_id, alert_type, alert_severity, alert_json, false /* release */);
  };
  int storeHostAlert(Host *h, AlertType alert_type, AlertLevel alert_severity, const char *alert_json);

  int getHostAlerts(Host *h,
		    lua_State* vm, patricia_tree_t *allowed_hosts,
		    u_int32_t start_offset, u_int32_t end_offset,
		    bool engaged);
  
  int getHostAlerts(const char *host_ip, u_int16_t vlan_id,
		    lua_State* vm, patricia_tree_t *allowed_hosts,
		    u_int32_t start_offset, u_int32_t end_offset,
		    bool engaged);

  int getNumHostAlerts(const char *host_ip, u_int16_t vlan_id, bool engaged);

  /*
    ========== FLOW alerts API =========
   */
  inline int storeFlowAlert(Flow *f, AlertType alert_type, AlertLevel alert_severity, const char *alert_json) {
    return storeAlert(alert_entity_flow, ""/* TODO: possibly add an unique id for flows */,
		 alert_type, alert_severity, alert_json);
  };

  /*
    ========== NETWORK alerts API ======
   */
  inline int engageNetworkAlert(const char *cidr,
			     const char *engaged_alert_id,
			     AlertType alert_type, AlertLevel alert_severity, const char *alert_json) {
    return engageReleaseNetworkAlert(cidr, engaged_alert_id, alert_type, alert_severity, alert_json, true /* engage */);
  };
  inline int releaseNetworkAlert(const char *cidr,
			      const char *engaged_alert_id,
			      AlertType alert_type, AlertLevel alert_severity, const char *alert_json) {
    return engageReleaseNetworkAlert(cidr, engaged_alert_id, alert_type, alert_severity, alert_json, false /* release */);
  };
  int storeNetworkAlert(const char *cidr, AlertType alert_type, AlertLevel alert_severity, const char *alert_json);

  /*
    ========== INTERFACE alerts API ======
   */
  inline int engageInterfaceAlert(NetworkInterface *n,
				  const char *engaged_alert_id,
				  AlertType alert_type, AlertLevel alert_severity, const char *alert_json) {
    return engageReleaseInterfaceAlert(n, engaged_alert_id, alert_type, alert_severity, alert_json, true /* engage */);
  };
  inline int releaseInterfaceAlert(NetworkInterface *n,
				   const char *engaged_alert_id,
				   AlertType alert_type, AlertLevel alert_severity, const char *alert_json) {
    return engageReleaseInterfaceAlert(n, engaged_alert_id, alert_type, alert_severity, alert_json, false /* release */);
  };
  int storeInterfaceAlert(NetworkInterface *n, AlertType alert_type, AlertLevel alert_severity, const char *alert_json);

  
  inline int getAlerts(lua_State* vm, patricia_tree_t *allowed_hosts,
		       u_int32_t start_offset, u_int32_t end_offset,
		       bool engaged){
    return getAlerts(vm, allowed_hosts, start_offset, end_offset, engaged, NULL /* all alerts by default */);
  }

  inline int getNumAlerts(bool engaged) {
    return getNumAlerts(engaged, NULL /* no where clause, all the existing alerts */);
  }
  int deleteAlerts(bool engaged, const int *rowid);
  
  /* Following are the legacy methods that were formally global to the whole ntopng */
#ifdef NOTUSED
  /**
   * @brief Queue an alert in redis
   *
   * @param level The alert level
   * @param s     The alert status (alert on/off)
   * @param t     The alert type
   * @param msg   The alert message
   */
  int queueAlert(AlertLevel level, AlertStatus s, AlertType t, char *msg);
  /**
   * @brief Returns up to the specified number of alerts, and removes them from redis. The first parameter must be long enough to hold the returned results
   * @param allowed_hosts The list of hosts allowed to be returned by this function
   * @param alerts The returned alerts
   * @param start_idx The initial queue index from which extract messages. Zero (0) is the first (i.e. most recent) queue element.
   * @param num The maximum number of alerts to return.
   * @return The number of elements read.
   *
   */
  int getQueuedAlerts(lua_State* vm, patricia_tree_t *allowed_hosts, int start_offset, int end_offset);
  /**
   * @brief Returns the number of queued alerts in redis generated by ntopng
   *
   */
  int getNumQueuedAlerts();
  /**
   * @brief Delete the alert identified by the specified index.
   * @param idx The queued alert index to delete. Zero (0) is the first (i.e. most recent) queue element.
   * @return The number of elements read.
   *
   */
  int deleteQueuedAlert(u_int32_t idx_to_delete);
  /**
   * @brief Flush all queued alerts
   *
   */
  int flushAllQueuedAlerts();
#endif
};

#endif /* _ALERTS_MANAGER_H_ */
