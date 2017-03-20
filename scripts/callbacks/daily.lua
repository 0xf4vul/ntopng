--
-- (C) 2013-17 - ntop.org
--


dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"
require "blacklist_utils"
local callback_utils = require "callback_utils"

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
   require("daily")
end

-- Delete JSON files older than a 30 days
-- TODO: make 30 configurable
harvestJSONTopTalkers(30)

local verbose = ntop.verboseTrace()
local ifnames = interface.getIfNames()

-- Scan "day" alerts
callback_utils.foreachInterface(ifnames, verbose, function(ifname, ifstats)
   scanAlerts("day", ifname)
end)

local delete_keys = true

begin = os.clock()
t = os.time()-86400

if((_GET ~= nil) and (_GET["verbose"] ~= nil)) then
   verbose = true
   t = t + 86400
end

if(verbose) then sendHTTPHeader('text/plain') end

when = os.date("%y%m%d", t)

mysql_retention = ntop.getCache("ntopng.prefs.mysql_retention")
if((mysql_retention == nil) or (mysql_retention == "")) then mysql_retention = "7" end
mysql_retention = os.time() - 86400*tonumber(mysql_retention)

minute_top_talkers_retention = ntop.getCache("ntopng.prefs.minute_top_talkers_retention")
if((minute_top_talkers_retention == nil) or (minute_top_talkers_retention == "")) then minute_top_talkers_retention = "365" end

callback_utils.foreachInterface(ifnames, verbose, function(_ifname, ifstats)
   interface_id = getInterfaceId(_ifname)

   ntop.deleteMinuteStatsOlderThan(interface_id, tonumber(minute_top_talkers_retention))

   callback_utils.harverstExpiredMySQLFlows(_ifname, mysql_retention, verbose)

   hosts_stats = interface.getHostsInfo(false --[[ don't show details --]])
   hosts_stats = hosts_stats["hosts"]

   for key, value in pairs(hosts_stats) do
      interface.resetPeriodicStats(key, value["vlan"])
   end

   if(interface.getInterfaceDumpDiskPolicy() == true) then
      ntop.deleteDumpFiles(interface_id)
   end
end)

loadHostBlackList()
