--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "alert_utils"

alerts_api = require("alerts_api")

local do_trace      = true
local config_alerts = nil
local ifname        = nil

-- The function below ia called once (#pragma once)
function setup(str_granularity)
   print("alert.lua:setup("..str_granularity..") called\n")
   ifname = interface.setActiveInterfaceId(tonumber(interface.getId()))
   config_alerts = getHostsConfiguredAlertThresholds(ifname, str_granularity)
end

-- #################################################################

local function cached_val_key(metric_name, granularity)
   return string.format("%s:%s", metric_name, granularity)
end

-- #################################################################

local function delta_val(metric_name, granularity, curr_val)
   local key = cached_val_key(metric_name, granularity)

   -- Read cached value and purify it
   local prev_val = host.getCachedAlertValue(key)
   prev_val = tonumber(prev_val) or 0

   -- Save the value for the next round
   host.setCachedAlertValue(key, tostring(curr_val))

   -- Compute the delta
   return curr_val - prev_val
end

-- #################################################################

local function application_bytes(info, application_name)
   local curr_val = 0

   if info["ndpi"] and info["ndpi"][application_name] then
      curr_val = info["ndpi"][application_name]["bytes.sent"] + info["ndpi"][application_name]["bytes.rcvd"]
   end

   return curr_val
end

-- #################################################################

function active(metric_name, info, granularity)
   return delta_val(metric_name, granularity, info["total_activity_time"])
end

-- #################################################################

function bytes(metric_name, info, granularity)
   return delta_val(metric_name, granularity, info["bytes.sent"] + info["bytes.rcvd"])
end

-- #################################################################

function packets(metric_name, info, granularity)
   return delta_val(metric_name, granularity, info["packets.sent"] + info["packets.rcvd"])
end

-- #################################################################

function flows(metric_name, info, granularity)
   return delta_val(metric_name, granularity, info["total_flows.as_client"] + info["total_flows.as_server"])
end

-- #################################################################

function idle(metric_name, info, granularity)
   return delta_val(metric_name, granularity, os.time() - info["seen.last"])
end

-- #################################################################

function dns(metric_name, info, granularity)
   return delta_val(metric_name, granularity, application_bytes(info, "DNS"))
end

-- #################################################################

function p2p(metric_name, info, granularity)
   local tot_p2p = application_bytes(info, "eDonkey") + application_bytes(info, "BitTorrent") + application_bytes(info, "Skype")

   return delta_val(metric_name, granularity, tot_p2p)
end

-- #################################################################

function throughput(metric_name, info, granularity)
   local duration = granularity2sec(granularity)

   return delta_val(metric_name, granularity, info["bytes.sent"] + info["bytes.rcvd"]) * 8 / duration
end

-- #################################################################

-- The function below is called once per host
local function checkHostAlertsThreshold(host_key, host_info, granularity, rules)
   if(do_trace) then print("checkHostAlertsThreshold()\n") end

   for function_name,params in pairs(rules) do
      -- IMPORTANT: do not use "local" with the variables below
      --            as they need to be accessible by the evaluated function
      threshold_value    = params["edge"]
      alert_key_name     = params["key"]
      threshold_operator = params["operator"]
      metric_name        = params["metric"]
      threshold_gran     = granularity
      h_info             = host_info

      print("[Alert @ "..granularity.."] ".. host_key .." ["..function_name.."]\n")

      if(true) then
	 -- This is where magic happens: load() evaluates the string
	 local what = 'return('..function_name..'(metric_name, h_info, threshold_gran))'
	 -- tprint(what)
	 local func, err = load(what)

	 if func then
	    local ok, value = pcall(func)

	    if ok then
	       local alarmed = false
	       local host_alert = alerts_api:newAlert({ entity = "host", type = "threshold_cross", severity = "error" })

	       if(do_trace) then print("Execution OK. value: "..tostring(value)..", operator: "..threshold_operator..", threshold: "..threshold_value.."]\n") end

	       threshold_value = tonumber(threshold_value)

	       if(threshold_operator == "lt") then
		  if(value < threshold_value) then alarmed = true end
	       else
		  if(value > threshold_value) then alarmed = true end
	       end

	       if(alarmed) then
		  print("Trigger alert [value: "..tostring(value).."]\n")

		  -- IMPORTANT: uncommenting the line below break all
		  -- host_alert:trigger(host_key, "Host "..host_key.." crossed threshold "..metric_name)
		  host.storeTriggeredAlert(alert_key_name..":"..granularity)
	       else
		  print("DON'T trigger alert [value: "..tostring(value).."]\n")
		  -- host_alert:release(host_key)
		  host.releaseTriggeredAlert(alert_key_name..":"..granularity)
	       end
	    else
	       if(do_trace) then print("Execution error:  "..tostring(rc).."\n") end
	    end
	 else
	    print("Compilation error:", err)
	 end
      end

      print("=============\n")
   end
end

-- #################################################################

-- The function below is called once per host
function checkHostAlerts(granularity)
   local info       = host.getFullInfo()
   local host_key   = info.ip.."@"..info.vlan
   local host_alert = config_alerts[host_key]

   if(do_trace) then print("checkHostAlerts()\n") end

   -- specific host alerts
   if((host_alert ~= nil) and (table.len(host_alert) > 0)) then
      checkHostAlertsThreshold(host_key, info, granularity, host_alert)
   end

   -- generic host alerts
   host_alert = config_alerts["local_hosts"]
   if((host_alert ~= nil) and (table.len(host_alert) > 0)) then
      checkHostAlertsThreshold(host_key, info, granularity, host_alert)
   end
end
