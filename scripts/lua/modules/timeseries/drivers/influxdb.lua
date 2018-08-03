--
-- (C) 2018 - ntop.org
--

local driver = {}

local ts_common = require("ts_common")

local json = require("dkjson")
require("ntop_utils")

--
-- Sample query:
--    select * from "iface:ndpi" where ifid='0' and protocol='SSL'
--
-- See also callback_utils.uploadTSdata
--

local INFLUX_QUERY_TIMEMOUT_SEC = 5
local MIN_INFLUXDB_SUPPORTED_VERSION = "1.6.0"

-- ##############################################

function driver:new(options)
  local obj = {
    url = options.url,
    db = options.db,
  }

  setmetatable(obj, self)
  self.__index = self

  return obj
end

-- ##############################################

function driver:append(schema, timestamp, tags, metrics)
  local tags_string = table.tconcat(tags, "=", ",")
  local metrics_string = table.tconcat(metrics, "=", ",")

  -- E.g. iface:ndpi_categories,category=Network,ifid=0 bytes=371707
  -- NB: time format is in nanoseconds UTC
  local api_line = schema.name .. "," .. tags_string .. " " .. metrics_string .. " " .. timestamp .. "000000000\n"

  return ntop.appendInfluxDB(api_line)
end

-- ##############################################

local function influx_query(full_url)
  local res = ntop.httpGet(full_url, "", "", INFLUX_QUERY_TIMEMOUT_SEC, true)

  if not res then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Invalid response for query: " .. full_url)
    return nil
  end

  if res.RESPONSE_CODE ~= 200 then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad response code[" .. res.RESPONSE_CODE .. "]: " .. (res.CONTENT or ""))
    return nil
  end

  if res.CONTENT == nil then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing content")
    return nil
  end

  local jres = json.decode(res.CONTENT)

  if (not jres) or (not jres.results) or (not #jres.results) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Invalid JSON reply[" .. res.CONTENT_LEN .. " bytes]: " .. string.sub(res.CONTENT, 1, 50))
    return nil
  end

  if not jres.results[1].series then
    -- no results fount
    return nil
  end

  return jres.results[1]
end

-- ##############################################

local function influx2Series(schema, tstart, tend, tags, options, data, time_step)
  local data_type = schema.options.metrics_type
  local series = {}

  -- Create the columns
  for i=2, #data.columns do
    series[i-1] = {label=data.columns[i], data={}}
  end

  -- Time tracking to fill the missing points
  local first_t = data.values[1][1]
  local prev_t = tstart + ((first_t - tstart) % time_step)

  local series_idx = 1
  --tprint(time_step .. ") " .. tstart .. " vs " .. first_t .. " - " .. prev_t)

  -- Convert the data
  for idx, values in ipairs(data.values) do
    local cur_t = data.values[idx][1]

    if (idx == 1) and (data_type ~= ts_common.metrics.counter) then
      -- skip first point when no derivative is performed as an issue with GROUP BY
      goto continue
    end

    -- Fill the missing points
    while((cur_t - prev_t) > time_step) do
      for _, serie in pairs(series) do
        serie.data[series_idx] = options.fill_value
      end

      --tprint("FILL [" .. series_idx .."] " .. cur_t .. " vs " .. prev_t)
      series_idx = series_idx + 1
      prev_t = prev_t + time_step
    end

    if #values > 1 then
      for i=2, #values do
        local val = values[i]

        if val < options.min_value then
          val = options.min_value
        elseif val > options.max_value then
          val = options.max_value
        end

        series[i-1].data[series_idx] = val
      end

      series_idx = series_idx + 1
      prev_t = prev_t + time_step
    end

    ::continue::
  end

   -- Fill the missing points at the end
  while((tend - prev_t) > time_step) do
    for _, serie in pairs(series) do
      serie.data[series_idx] = options.fill_value
    end

    series_idx = series_idx + 1
    prev_t = prev_t + time_step
  end

  local count = series_idx - 1

  return series, count
end

-- TEST function for influx2Series with real data
-- This dataset reproduces the error fixed in:
--  12c8fc315654c1a0e7bf82f089ee47d45a98fc07 - Fix occasional series ponts differences in InfluxDB
local function test_influx2Series()
  local schema = {
    options = {
      step = 300,
      metrics_type = "counter",
    }
  }

  local options = {
    fill_value = 0,
    min_value = 0,
    max_value = math.huge,
  }
  local tstart = 1532009616
  local tend = 1532091600
  local tags = {}
  local time_step = 600 -- sampling taking place

  local data1 = {
    statement_id = 0,
    series = {
      {
        name = "host:ndpi",
        columns = {
          "time", "bytes_sent", "bytes_rcvd"
        },
        values = {
          {1532010000, 7.1333333333333, 199.05166666667},
          {1532010600, 11, 205.45166666667},
          {1532011200, 9.4366666666667, 198.38833333333},
          {1532011800, 0, 0},
          {1532012400, 0, 0},
          {1532013000, 9.5633333333333, 198.87833333333},
          {1532013600, 0, 0},
          {1532081400, -0.54522123893805, -12.366224188791},
          {1532082000, 0, 0},
          {1532082600, 0, 0},
          {1532083200, 7.5833333333333, 200.805},
          {1532083800, 0, 0},
          {1532086800, 1.8586666666667, 39.729},
          {1532087400, 0, 0},
          {1532088000, 0, 0},
          {1532088600, 0, 0},
          {1532089200, 0, 0},
          {1532089800, 4.6116666666667, 99.195},
          {1532090400, 4.6116666666667, 99.195},
          {1532091000, 0, 0},
          {1532091600, 0, 0},
        },
      }
    },
  }

  local data2 = {
    statement_id = 0,
    series = {
      {
        name = "host:ndpi",
        columns = {
          "time", "bytes_sent", "bytes_rcvd"
        },
        values = {
          {1532086800, -0.18549180327869, -5.7308606557377},
          {1532087400, 4.9166666666667, 5.66},
          {1532088000, 7.14, 8.0383333333333},
          {1532088600, 6.0525, 6.9458333333333},
          {1532089200, 8.1358333333333, 9.5725},
          {1532089800, 7.8566666666667, 9.0508333333333},
          {1532090400, 9.4025, 23.83},
          {1532091000, 7.1975, 8.2333333333333},
          {1532091600, 4.475, 5.5808333333333},
        },
      }
    },
  }

  local data1_series, data1_count = influx2Series(schema, tstart, tend, tags, options, data1.series[1], time_step)
  local data2_series, data2_count = influx2Series(schema, tstart, tend, tags, options, data2.series[1], time_step)

  -- Number of points must be the same
  if(not(data1_count == data2_count)) then
    io.write("test_influx2Series ASSERTION FAILED: data1_count == data2_count\n")
    return false
  end

  -- No initial gaps
  if(not(data1_series[1].data[1] == 7.1333333333333)) then
    io.write("test_influx2Series ASSERTION FAILED: data1_series[1].data[1] == 7.1333333333333\n")
    return false
  end

  io.write("test_influx2Series OK\n")
  return true
end

 --##############################################

local function getTotalSerieQuery(schema, tstart, tend, tags, time_step, data_type)
  --[[
  SELECT NON_NEGATIVE_DERIVATIVE(total_serie) AS total_serie FROM               // derivate the serie, if necessary
    (SELECT MEAN("total_serie") AS "total_serie" FROM                           // sample the total serie points, if necessary
      (SELECT SUM("value") AS "total_serie" FROM                                // sum all the series together
        (SELECT (bytes_sent + bytes_rcvd) AS "value" FROM "host:ndpi"           // possibly sum multiple metrics within same serie
          WHERE host='192.168.43.18' AND ifid='2'
          AND time >= 1531916170000000000 AND time <= 1532002570000000000)
        GROUP BY time(300s))
      GROUP BY time(600s))
  ]]
  local query = 'SELECT SUM("value") AS "total_serie" FROM ' ..
    '(SELECT (' .. table.concat(schema._metrics, " + ") ..') AS "value" FROM "'.. schema.name ..'" WHERE ' ..
    table.tconcat(tags, "=", " AND ", nil, "'") .. ' AND time >= ' .. tstart .. '000000000 AND time <= ' .. tend .. '000000000)'..
    ' GROUP BY time('.. schema.options.step ..'s)'

  if time_step and (schema.options.step ~= time_step) then
    -- sample the points
    query = 'SELECT MEAN("total_serie") AS "total_serie" FROM ('.. query ..') GROUP BY time('.. time_step ..'s)'
  end

  if data_type == ts_common.metrics.counter then
    query = "SELECT NON_NEGATIVE_DERIVATIVE(total_serie) AS total_serie FROM (" .. query .. ")"
  end

  return query
end

-- ##############################################

local function makeTotalSerie(schema, tstart, tend, tags, options, url, time_step, db)
  local data_type = schema.options.metrics_type
  local query = getTotalSerieQuery(schema, tstart, tend, tags, time_step, data_type)

  local full_url = url .. "/query?db=".. db .."&epoch=s&q=" .. urlencode(query)
  local data = influx_query(full_url)

  if not data then
    return nil
  end

  data = data.series[1]

  local series, count = influx2Series(schema, tstart, tend, tags, options, data, time_step)
  return series[1].data
end

-- ##############################################

-- NOTE: mean / percentile values are calculated manually because of an issue with
-- empty points in the queries https://github.com/influxdata/influxdb/issues/6967
local function calcStats(schema, tstart, tend, tags, url, total_serie, time_step, db)
  local stats = ts_common.calculateStatistics(total_serie, time_step, tend - tstart, schema.options.metrics_type)

  if time_step ~= schema.options.step then
    -- NOTE: the total must be manually extracted from influx when sampling occurs
    local data_type = schema.options.metrics_type
    local query = getTotalSerieQuery(schema, tstart, tend, tags, nil --[[ important: no sampling ]], data_type)
    query = 'SELECT SUM("total_serie") * ' .. schema.options.step ..' FROM (' .. query .. ')'

    local full_url = url .. "/query?db=".. db .."&epoch=s&q=" .. urlencode(query)
    local data = influx_query(full_url)

    if (data and data.series and data.series[1] and data.series[1].values[1]) then
      local data_stats = data.series[1].values[1]
      local total = data_stats[2]

      if stats.total then
        -- only overwrite it if previously set
        stats.total = total
      end

      stats.average = total / (tend - tstart)
    end
  end

  return stats
end

-- ##############################################

function calculateSampledTimeStep(schema, tstart, tend, options)
  local estimed_num_points = math.ceil((tend - tstart) / schema.options.step)
  local time_step = schema.options.step

  if estimed_num_points > options.max_num_points then
    -- downsample
    local num_samples = math.ceil(estimed_num_points / options.max_num_points)
    time_step = num_samples * schema.options.step
  end

  return time_step
end

-- ##############################################

function driver:query(schema, tstart, tend, tags, options)
  local metrics = {}
  local time_step = calculateSampledTimeStep(schema, tstart, tend, options)
  local data_type = schema.options.metrics_type

  for i, metric in ipairs(schema._metrics) do
    -- NOTE: why we need to device by time_step ? is MEAN+GROUP BY TIME bugged?
    if data_type == ts_common.metrics.counter then
      metrics[i] = "(DERIVATIVE(MEAN(\"" .. metric .. "\")) / ".. time_step ..") as " .. metric
    else
      metrics[i] = "MEAN(\"".. metric .."\") as " .. metric
    end
  end

  -- NOTE: GROUP BY TIME and FILL do not work well together! Additional zeroes produce non-existent derivative values
  -- Will perform fill manually below
  --[[
  SELECT (DERIVATIVE(MEAN("bytes")) / 60) as bytes
    FROM "iface:ndpi" WHERE protocol='SSL' AND ifid='2'
    AND time >= 1531991910000000000 AND time <= 1532002710000000000
    GROUP BY TIME(60s)
  ]]
  local query = 'SELECT '.. table.concat(metrics, ",") ..' FROM "' .. schema.name .. '" WHERE ' ..
      table.tconcat(tags, "=", " AND ", nil, "'") .. " AND time >= " .. tstart .. "000000000 AND time <= " .. tend .. "000000000" ..
      " GROUP BY TIME(".. time_step .."s)"

  local url = self.url
  local full_url = url .. "/query?db=".. self.db .."&epoch=s&q=" .. urlencode(query)
  local data = influx_query(full_url)

  if not data then
    return nil
  end

  local series, count = influx2Series(schema, tstart, tend, tags, options, data.series[1], time_step)
  local total_serie = makeTotalSerie(schema, tstart, tend, tags, options, url, time_step, self.db)
  local stats = nil

  if options.calculate_stats then
    stats = calcStats(schema, tstart, tend, tags, url, total_serie, time_step, self.db)
  end

  local rv = {
    start = tstart,
    step = time_step,
    count = count,
    series = series,
    statistics = stats,
    additional_series = {
      total = total_serie,
    },
  }

  return rv
end

-- ##############################################

function driver:flush()
  return true
end

-- ##############################################

function driver:listSeries(schema, tags_filter, wildcard_tags, start_time)
  -- NOTE: time based query not currently supported on show tags/series, using select
  -- https://github.com/influxdata/influxdb/issues/5668
  --[[
  SELECT * FROM "iface:ndpi_categories"
    WHERE ifid='2' AND time >= 1531981349000000000
    GROUP BY category
    LIMIT 1
  ]]
  local query = 'SELECT * FROM "' .. schema.name .. '" WHERE ' ..
      table.tconcat(tags_filter, "=", " AND ", nil, "'") ..
      " AND time >= " .. start_time .. "000000000" ..
      ternary(not table.empty(wildcard_tags), " GROUP BY " .. table.concat(wildcard_tags, ","), "") ..
      " LIMIT 1"

  local url = self.url
  local full_url = url .. "/query?db=".. self.db .."&q=" .. urlencode(query)
  local data = influx_query(full_url)

  if not data then
    return nil
  end

  if table.empty(data.series) then
    return {}
  end

  if table.empty(wildcard_tags) then
    -- Simple "exists" check
    if not table.empty(data.series[1].values) then
      return tags_filter
    else
      return {}
    end
  end

  local res = {}

  for _, serie in pairs(data.series) do
    for _, value in pairs(serie.values) do
      local tags = {}

      for i=2, #value do
        local tag = serie.columns[i]

        -- exclude metrics
        if schema.tags[tag] ~= nil then
          tags[tag] = value[i]
        end
      end

      for key, val in pairs(serie.tags) do
        tags[key] = val
      end

      res[#res + 1] = tags
    end
  end

  return res
end

-- ##############################################

function driver:topk(schema, tags, tstart, tend, options, top_tags)
  if #top_tags ~= 1 then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "InfluxDB driver expects exactly one top tag, " .. #top_tags .. " found")
    return nil
  end

  local top_tag = top_tags[1]

  --[[
  SELECT TOP("value", "protocol", 10) FROM                                      // select top 10 protocols
    (SELECT protocol, (bytes_sent + bytes_rcvd) AS "value"                      // possibly sum multiple metrics within same serie
      FROM "host:ndpi" WHERE host='192.168.43.18' AND ifid='2'
      AND time >= 1531986825000000000 AND time <= 1531994776000000000)
  ]]
  local query = 'SELECT TOP("value", "'.. top_tag ..'", '.. options.top ..') FROM (SELECT '.. top_tag ..
      ', (' .. table.concat(schema._metrics, " + ") ..') AS "value" FROM "'.. schema.name ..'" WHERE '..
      table.tconcat(tags, "=", " AND ", nil, "'") .. ' AND time >= '.. tstart ..'000000000 AND time <= '.. tend ..'000000000)'
  local url = self.url
  local full_url = url .. "/query?db=".. self.db .."&epoch=s&q=" .. urlencode(query)

  local data = influx_query(full_url)

  if not data then
    return nil
  end

  if table.empty(data.series) then
    return {}
  end

  data = data.series[1]

  local res = {}

  for idx, value in pairs(data.values) do
    -- top value
    res[idx] = value[2]
  end

  local sorted = {}

  for idx in pairsByValues(res, rev) do
    local value = data.values[idx]

    sorted[#sorted + 1] = {
      tags = table.merge(tags, {[top_tag] = value[3]}),
      value = value[2],
    }
  end

  local time_step = calculateSampledTimeStep(schema, tstart, tend, options)
  local total_serie = makeTotalSerie(schema, tstart, tend, tags, options, url, time_step, self.db)
  local stats = nil

  if options.calculate_stats then
    stats = calcStats(schema, tstart, tend, tags, url, total_serie, time_step, self.db)
  end

  return {
    topk = sorted,
    statistics = stats,
     additional_series = {
      total = total_serie,
    },
  }
end

-- ##############################################

local function isCompatibleVersion(version)
  local parts = split(version, "%.")
  local required = split(MIN_INFLUXDB_SUPPORTED_VERSION, "%.")

  return (parts[1] == required[1]) -- major
    and (tonumber(parts[2]) ~= nil)
    and (tonumber(required[2]) ~= nil)
    and (tonumber(parts[2]) >= tonumber(required[2])) -- minor
end

function driver.init(dbname, url, days_retention, verbose)
  -- Check version
  if verbose then traceError(TRACE_NORMAL, TRACE_CONSOLE, "Contacting influxdb at " .. url .. " ...") end

  local res = ntop.httpGet(url .. "/ping", "", "", INFLUX_QUERY_TIMEMOUT_SEC, true)
  if res == nil then
    local err = i18n("prefs.could_not_contact_influxdb")

    traceError(TRACE_ERROR, TRACE_CONSOLE, err)
    return false, err
  end

  local content = res.CONTENT or ""
  local version = string.match(content, "\nX%-Influxdb%-Version: ([%d|%.]+)")

  if not version or not isCompatibleVersion(version) then
    local err = i18n("prefs.incompatible_influxdb_version",
      {required=MIN_INFLUXDB_SUPPORTED_VERSION, found=version})

    traceError(TRACE_ERROR, TRACE_CONSOLE, err)
    return false, err
  end

  -- Create database
  if verbose then traceError(TRACE_NORMAL, TRACE_CONSOLE, "Creating database " .. dbname .. " ...") end
  local query = "CREATE DATABASE \"" .. dbname .. "\""

  local res = ntop.postHTTPform("", "", url .. "/query", "q=" .. query)
  if not res then
    local err = i18n("prefs.influxdb_create_error", {db=dbname})

    traceError(TRACE_ERROR, TRACE_CONSOLE, err)
    return false, err
  end

  -- Set retention
  if verbose then traceError(TRACE_NORMAL, TRACE_CONSOLE, "Setting retention for " .. dbname .. " ...") end
  local query = "ALTER RETENTION POLICY autogen ON \"".. dbname .."\" DURATION ".. days_retention .."d"

  local res = ntop.postHTTPform("", "", url .. "/query", "q=" .. query)
  if not res then
    local err = i18n("prefs.influxdb_retention_error", {db=dbname})

    traceError(TRACE_ERROR, TRACE_CONSOLE, err)
    return false, err
  end

  return true, i18n("prefs.successfully_connected_influxdb", {db=dbname, version=version})
end

-- ##############################################

return driver
