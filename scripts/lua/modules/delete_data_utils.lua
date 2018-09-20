--
-- (C) 2014-18 - ntop.org
--
local dirs = ntop.getDirs()
local ts_utils = require("ts_utils")
local os_utils = require("os_utils")

local delete_data_utils = {}
local dry_run = false

local ALL_INTERFACES_HASH_KEYS = "ntopng.prefs.iface_id"

-- ################################################################

function delete_data_utils.status_to_i18n(err)
   local map = {
      ERR_NO_HOST_FS_DATA = "delete_data.msg_err_no_fs_data",
      ERR_INVALID_HOST = "delete_data.msg_err_invalid_host",
      ERR_TS_DELETE = "delete_data.msg_err_unable_to_delete_ts_data",
      ERR_UNABLE_TO_DELETE_DIR = "delete_data.msg_err_unable_to_delete_dir",
   }

   return map[err] or 'delete_data.msg_err_unknown'
end

-- ################################################################

local function delete_host_timeseries_data(interface_id, host_info)
   local status = "OK"
   local is_mac = isMacAddress(host_info["host"])

   if not is_mac and not isIPv4(host_info["host"]) and not isIPv6(host_info["host"]) then
      status = "ERR_INVALID_HOST"
   else
      local to_delete
      local delete_tags
      local value = hostinfo2hostkey(host_info)

      if is_mac then
	 to_delete = "mac"
	 delete_tags = {ifid=interface_id, mac=value}
      else
	 to_delete = "host"
	 delete_tags = {ifid=interface_id, host=value}
      end

      if not dry_run then
	 if not ts_utils.delete(to_delete, delete_tags) then
	    status = "ERR_TS_DELETE"
	 end
      end
   end

   return {status = status}
end

-- ################################################################

local function delete_host_redis_keys(interface_id, host_info)
   local status = "OK"
   local serialized_k, dns_k, devnames_k, devtypes_k

   if not isMacAddress(host_info["host"]) then
      -- this is an IP address, see HOST_SERIALIZED_KEY (ntop_defines.h)
      serialized_k = string.format("ntopng.serialized_hosts.ifid_%u__%s@%d", interface_id, host_info["host"], host_info["vlan"] or "0")
      dns_k = string.format("ntopng.dns.cache.%s", host_info["host"]) -- neither vlan nor ifid implemented for the dns cache
   elseif isIPv4(host_info["host"]) or isIPv6(host_info["host"]) then
      -- is a mac address, see MAC_SERIALIED_KEY (see ntop_defines.h)
      serialized_k = string.format("ntopng.serialized_macs.ifid_%u__%s", interface_id, host_info["host"])
      devnames_k = string.format("ntopng.cache.devnames.%s", host_info["host"])
      devtypes_k = string.format("ntopng.prefs.device_types.%s", host_info["host"])
   end

   if not dry_run then
      if serialized_k then ntop.delCache(serialized_k) end
      if devnames_k   then ntop.delCache(devnames_k) end
      if devtypes_k   then ntop.delCache(devtypes_k) end
      if dns_k        then ntop.delCache(dns_k) end
   end

   return {status = status}
end

-- ################################################################

local function delete_host_mysql_flows(interface_id, host_info)
   local status = "OK"

   if ntop.getPrefs()["is_dump_flows_to_mysql_enabled"] then
      local addr = host_info["host"]
      local vlan = host_info["vlan"] or 0
      local q

      if isIPv4(addr) then
	 q = string.format("DELETE FROM %s WHERE (IP_SRC_ADDR = INET_ATON('%s') OR IP_DST_ADDR = INET_ATON('%s')) AND VLAN_ID = %u and INTERFACE_ID = %u",
			   "flowsv4", addr, addr, vlan, interface_id)
      elseif isIPv6(addr) then
	 q = string.format("DELETE FROM %s WHERE (IP_SRC_ADDR = '%s' OR IP_DST_ADDR = '%s') AND VLAN_ID = %u AND INTERFACE_ID = %u",
			   "flowsv6", addr, addr, vlan, interface_id)
      end

      if not dry_run and q then
	 interface.execSQLQuery(q)
      end
   end

   return {status = status}
end

-- ################################################################

function delete_data_utils.delete_host(interface_id, host_info)
   local h_ts = delete_host_timeseries_data(interface_id, host_info)
   local h_rk = delete_host_redis_keys(interface_id, host_info)
   local h_db = delete_host_mysql_flows(interface_id, host_info)

   return {delete_host_timeseries_data = h_ts, delete_host_redis_keys = h_rk, delete_host_mysql_flows = h_db}
end

-- ################################################################

local function delete_interfaces_redis_keys(interfaces_list)
   local pref_prefix = "ntopng.prefs"
   local status = "OK"

   for if_id, if_name in pairs(interfaces_list) do
      -- let's match some patterns here (don't write an hexahustive list of keys
      -- as it will become unmanageable)

      local keys_patterns = {
	 -- examples:
	 --  ntopng.prefs.0.host_pools.pool_ids
	 --  ntopng.prefs.0.host_pools.details.0
	 string.format("%s.%u.*", pref_prefix, if_id),
	 -- examples:
	 --  ntopng.profiles_counters.ifid_0
	 --  ntopng.serialized_host_pools.ifid_0
	 string.format("ntopng.*ifid_%u", if_id),
	 -- examples:
	 --  ntopng.serialized_macs.ifid_0__52:54:00:3B:CB:B3
	 --  ntopng.serialized_hosts.ifid_0__192.168.2.131@0
	 string.format("*.ifid_%u_*", if_id),
	 -- examples:
	 --  ntopng.cache.engaged_alerts_cache_ifid_4_5mins
	 --  ntopng.cache.engaged_alerts_cache_ifid_4_min
	 string.format("ntopng.*_ifid_%u_*", if_id),
	 -- examples:
	 -- ntopng.prefs.ifid_0.custom_nDPI_proto_categories
	 -- ntopng.prefs.ifid_0.is_traffic_mirrored
	 string.format("*.ifid_%u.*", if_id),
	 -- examples:
	 --  ntopng.prefs.iface_2.packet_drops_alert
	 --  ntopng.prefs.iface_3.scaling_factor
	 string.format("%s.iface_%u.*", pref_prefix, if_id),
	 -- examples:
	 --  ntopng.prefs.enp1s0f0.dump_sampling_rate
	 --  ntopng.prefs.enp1s0f0.dump_all_traffic
	 string.format("%s.%s.*", pref_prefix, if_name),
	 -- examples:
	 --  ntopng.prefs.enp2s0f0_not_idle
	 string.format("%s.%s_*", pref_prefix, if_name),
      }

      for _, pattern in pairs(keys_patterns) do
	 local matching_keys = ntop.getKeysCache(pattern)

	 for matching_key, _ in pairs(matching_keys or {}) do
	    if not dry_run then
	       ntop.delCache(matching_key)
	    end
	 end
      end
   end

   return {status = status}
end

-- ################################################################

local function delete_interfaces_data(interfaces_list)
   local status = "OK"
   local data_dir = ntop.getDirs()["workingdir"]

   for if_id, if_name in pairs(interfaces_list) do
      local if_dir = os_utils.fixPath(string.format("%s/%u/", data_dir, if_id))

      if not dry_run then
	 if not ts_utils.delete("" --[[ all schemas ]], {ifid=if_id}) then
	    status = "ERR_TS_DELETE"
	    break
	 end

	 -- Delete additional data
	 if ntop.exists(if_dir) and not ntop.rmdir(if_dir) then
	    status = "ERR_UNABLE_TO_DELETE_DIR"
	    break
	 end
      end
   end

   return {status = status}
end

-- ################################################################

local function delete_interfaces_influx_data(interfaces_list)
   local status = "OK"
   -- TODO
   return {status = status}
end

-- ################################################################

local function delete_interfaces_db_flows(interfaces_list)
   local db_utils = require "db_utils"
   local status = "OK"
   local prefs = ntop.getPrefs()

   for if_id, if_name in pairs(interfaces_list) do
      -- this deletes MySQL
      if prefs.is_dump_flows_to_mysql_enabled == true and not dry_run then
	 db_utils.harverstExpiredMySQLFlows(if_id, os.time() + 86400 --[[ go 1d in the future to make sure everything is deleted --]])
      end
      -- TODO: add delete for nIndex
   end

   return {status = status}
end

-- ################################################################

local function delete_interfaces_ids(interfaces_list)
   local status = "OK"

   for if_id, if_name in pairs(interfaces_list) do
      -- delete the interface from the all interfaces hash
      -- this will cause the id to be re-used
      if not dry_run then
	 ntop.delHashCache(ALL_INTERFACES_HASH_KEYS, if_name)
	 ntop.delHashCache(ALL_INTERFACES_HASH_KEYS, if_id)
      end
   end

   return {status = status}
end

-- ################################################################

local function list_interfaces(inactive_interfaces_only)
   local res = {}
   local active_interfaces = interface.getIfNames()
   local all_interfaces = ntop.getHashAllCache(ALL_INTERFACES_HASH_KEYS)

   for k, v in pairs(all_interfaces) do
      if tonumber(k) ~= nil then
	 -- assumes this in an interface integer id
	 -- this check is necessary as function Utils::ifname2id
	 -- inserts in the same hash table both the ids and the interface
	 -- names. So for example interface eno1 with id 20 has two entries in the
	 -- hash table, namely eno1: 20 and 20: eno1
	 goto continue
      end

      local if_name = k
      local if_id = v

      if inactive_interfaces_only and active_interfaces[if_id] then
	 -- the interface is active
	 goto continue
      end

      -- add the interface to the list of inactive interfaces
      res[if_id] = if_name
      ::continue::
   end

   return res
end

-- ################################################################

function delete_data_utils.list_inactive_interfaces()
   return list_interfaces(true --[[ inactive interfaces only --]])
end

-- ################################################################

-- no need to make it global yet
local function list_all_interfaces()
   return list_interfaces(false --[[ all interfaces, active and inactive --]])
end

-- ################################################################

local function delete_interfaces_from_list(interfaces_list)
   local if_dt = delete_interfaces_data(interfaces_list)
   local if_rk = delete_interfaces_redis_keys(interfaces_list)
   local if_db = delete_interfaces_db_flows(interfaces_list)

   -- last step is to also free the ids that can thus be re-used
   -- if everything was OK.
   local if_in   
   if if_dt["status"] == "OK" and if_rk["status"] == "OK" and if_db["status"] == "OK" then
      if_in = delete_interfaces_ids(interfaces_list)
   end

   return {delete_if_data = if_dt, delete_if_redis_keys = if_rk, delete_if_db = if_db, delete_if_ids = if_in}
end

-- ################################################################

function delete_data_utils.delete_inactive_interfaces()
   local inactive_if_list = delete_data_utils.list_inactive_interfaces()

   return delete_interfaces_from_list(inactive_if_list)
end

-- ################################################################

function delete_data_utils.delete_all_interfaces_data()
   -- Deleting all interfaces can be a risky operation as it includes active interfaces.
   -- Currently we are using this only in boot.lua (that is, before interfaces registration)
   -- and only in nEdge. Use it carefully as also the interface ids are recycled.

   if not ntop.isnEdge() then
      return
   end

   local if_list = list_all_interfaces()

   return delete_interfaces_from_list(if_list)
end

-- ################################################################

return delete_data_utils


