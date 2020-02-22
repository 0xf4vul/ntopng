--
-- (C) 2020 - ntop.org
--
-- This file contains the user_script constats

local periodic_activities_utils = {}
local ts_utils = require "ts_utils_core"

-- ###########################################

periodic_activities_utils.periodic_activities = {
   -- Script -> max_duration sec
   ["stats_update.lua"]      = { periodicity = 5,     },
   ["ht_state_update.lua"]   = { periodicity = 5,     },
   ["minute.lua"]            = { periodicity = 60,    },
   ["5min.lua"]              = { periodicity = 300,   },
   ["hourly.lua"]            = { periodicity = 3600,  },
   ["daily.lua"]             = { periodicity = 86400, },
   ["housekeeping.lua"]      = { periodicity = 3,     },
   ["discover.lua"]          = { periodicity = 5,     },
   ["timeseries.lua"]        = { periodicity = 5,     },
   ["second.lua"]            = { periodicity = 1,     },
}

-- ###########################################

periodic_activities_utils.periodic_activity_issues = {
   ["not_executed"] =
      {
	 i18n_title = "internals.script_not_executed",
	 i18n_descr = "internals.script_not_executed_descr"
      },
   ["is_slow"] =
      {
	 i18n_title = "internals.script_deadline_exceeded",
	 i18n_descr = "internals.script_deadline_exceeded_descr",
      },
   ["rrd_slow"] =
      {
	 i18n_title = "internals.slow_rrd_writes",
	 i18n_descr = "internals.slow_rrd_writes_descr"
      }
}

if ts_utils.getDriverName() ~= "rrd" then
   -- No rrd issues when driver is not RRD
   periodic_activities_utils.periodic_activity_issues["rrd_slow"] = nil
end

-- ###########################################

-- ###########################################

-- Returns true when at least one of the interfaces (system interface included)
-- has issues with one of its periodic activities
local function stats_have_degraded_performance(stats)
   for ps_name, ps_stats in pairs(stats) do
      -- The activity is slow if it has been executing for too long,
      -- if it has been waiting in the queue for too long (no available threads)
      -- of if the RRD writes are slow
      if ps_stats["is_slow"] or ps_stats["not_excecuted"] or ps_stats["rrd_slow"] then
	 return true
      end
   end
end

-- ###########################################

-- Check if any of the executing periodic activities is slow and showing
-- degraded performance
function periodic_activities_utils.have_degraded_performance()
   local cur_ifid = tostring(interface.getId())
   local res = false

   local available_interfaces = interface.getIfNames()
   -- Add the system interface id
   available_interfaces[getSystemInterfaceId()] = getSystemInterfaceName()

   for _, iface in pairs(available_interfaces) do
      interface.select(iface)

      if stats_have_degraded_performance(interface.getPeriodicActivitiesStats()) then
	 res = true
	 break
      end
   end

   -- Restore the original id and return
   interface.select(cur_ifid)

   return res
end

-- ###########################################

return periodic_activities_utils
