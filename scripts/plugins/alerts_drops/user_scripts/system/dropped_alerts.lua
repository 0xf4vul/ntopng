--
-- (C) 2019-20 - ntop.org
--

local user_scripts = require("user_scripts")
local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

local script = {
  -- Script category
  category = user_scripts.script_categories.internals,

  -- This script is only for alerts generation
  is_alert = true,

  -- See below
  hooks = {},

  gui = {
    i18n_title = "alerts_dashboard.alert_drops",
    i18n_description = "alerts_dashboard.alert_drops_description",
  },
}

-- #################################################################

function script.hooks.min(params)
  local available_interfaces = interface.getIfNames()

  for _, iface in pairs(available_interfaces) do
    interface.select(iface)

    local new_dropped_alerts = interface.checkDroppedAlerts()

    local alert_type = {
      alert_type = alert_consts.alert_types.alert_dropped_alerts,
      alert_granularity = alert_consts.alerts_granularities.min,
      alert_severity = alert_consts.alert_severities.error,
      alert_type_params = {
        ifid = interface.getId(),
        num_dropped = new_dropped_alerts,
      }
    }

    -- Note: required for the trigger/release below
    interface.select(getSystemInterfaceId())

    if(new_dropped_alerts > 0) then
      alerts_api.trigger(params.alert_entity, alert_type, nil, params.cur_alerts)
    else
      alerts_api.release(params.alert_entity, alert_type, nil, params.cur_alerts)
    end
  end
end

-- #################################################################

return script
