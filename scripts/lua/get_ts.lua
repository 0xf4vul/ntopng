--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local nv_graph_utils

if ntop.isPro() then
  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
  nv_graph_utils = require "nv_graph_utils"
end

require "lua_utils"
require "graph_utils"
local ts_utils = require("ts_utils")
local json = require("dkjson")

local schema_id = _GET["ts_schema"]
local query = _GET["ts_query"]
local tstart = tonumber(_GET["epoch_begin"]) or (os.time() - 3600)
local tend = tonumber(_GET["epoch_end"]) or os.time()
local compare_backward = _GET["ts_compare"]

local options = {
  max_num_points = tonumber(_GET["limit"]),
}

-- convert the query into fields
local tags = tsQueryToTags(_GET["ts_query"])

if tags.ifid then
  interface.select(tags.ifid)
end

sendHTTPHeader('application/json')

local function performQuery(tstart, tend, keep_total)
  local res

  if starts(schema_id, "top:") then
    local schema_id = split(schema_id, "top:")[2]

    res = ts_utils.queryTopk(schema_id, tags, tstart, tend, options)
  else
    res = ts_utils.query(schema_id, tags, tstart, tend, options)

    if(not keep_total) and (res) and (res.additional_series) then
      -- no need for total serie in normal queries
      res.additional_series.total = nil
    end
  end

  return res
end

local res

if starts(schema_id, "custom:") and ntop.isPro() then
  res = performCustomQuery(schema_id, tags, tstart, tend, options)
  compare_backward = nil
else
  res = performQuery(tstart, tend)
end

if res == nil then
  print("[]")
  return
end

if not isEmptyString(compare_backward) and compare_backward ~= "1Y" then
  local backward_sec = getZoomDuration(compare_backward)
  local tstart_cmp = tstart - backward_sec
  local tend_cmp = tend - backward_sec
  local res_cmp = performQuery(tstart_cmp, tend_cmp, true)

  if res_cmp and res_cmp.additional_series and res_cmp.additional_series.total then
    res.additional_series = res.additional_series or {}
    res.additional_series[compare_backward.. " " ..i18n("details.ago")] = res_cmp.additional_series.total
  end
end

-- TODO make a script parameter?
local extend_labels = true

if extend_labels and ntop.isPro() then
  extendLabels(res)
end

print(json.encode(res))
