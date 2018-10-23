--
-- (C) 2014-18 - ntop.org
--

local dirs = ntop.getDirs()
require "lua_utils"
require "prefs_utils"
local json = require("dkjson")

prefs = ntop.getPrefs()

local n2disk_ctl = "/usr/local/bin/n2diskctl"
local ntopng_config_tool = "/usr/bin/ntopng-utils-manage-config"
local n2disk_ctl_cmd = "sudo "..n2disk_ctl
local extraction_queue_key = "ntopng.traffic_recording.extraction_queue"
local extraction_stop_queue_key = "ntopng.traffic_recording.extraction_stop_queue"
local extraction_seqnum_key = "ntopng.traffic_recording.extraction_seqnum"
local extraction_jobs_key = "ntopng.traffic_recording.extraction_jobs"

local recording_utils = {}

recording_utils.default_disk_space = 10*1024

-- #################################

local function executeWithOuput(c)
  local f = assert(io.popen(c, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  return s
end

function recording_utils.isSupportedZMQInterface(ifid)
  local ifname = getInterfaceName(ifid)
  -- localhost in collectore mode is accepted
  local zmq_prefix_any = "tcp://*"
  local zmq_prefix_loh = "tcp://127.0.0.1"
  if (ifname:sub(1, #zmq_prefix_any) == zmq_prefix_any or
      ifname:sub(1, #zmq_prefix_loh) == zmq_prefix_loh) and
      ifname:sub(-1) == "c" then
    return true
  end
  return false
end

local function getZMQPort(addr)
  local values = split(addr, ':')
  if #values == 3 then
    local port = split(values[3], 'c')
    return port[1]
  end
  return nil
end

function recording_utils.getZMQProbeAddr(ifid)
  local port = getZMQPort(getInterfaceName(ifid))
  if port == nil then
    port = "5556"
  end
  return "tcp://127.0.0.1:"..port
end

function recording_utils.isSupportedZMQInterface(ifid)
  local ifname = getInterfaceName(ifid)
  local zmq_prefix = "tcp://"
  if ifname:sub(1, #zmq_prefix) == zmq_prefix and ifname:sub(-1) == "c" then
    return true
  end
  return false
end

function recording_utils.isSupportedInterface(ifid)
  if interface.isPacketInterface() or 
     recording_utils.isSupportedZMQInterface(ifid) then
    return true
  end
  return false
end

function recording_utils.isAvailable()
  if isAdministrator() and
     not ntop.isWindows() and
     not ntop.isnEdge() and
     ntop.exists(ntopng_config_tool) and 
     ntop.exists(n2disk_ctl) then
    return true
  end
  return false
end

function recording_utils.isZC(ifname)
  local proc_info = io.open("/proc/net/pf_ring/dev/"..ifname.."/info", "r")
  if proc_info ~= nil then
    local info = proc_info:read "*a"
    proc_info:close()
    if string.match(info, "ZC") then
      return true
    end
  end
  -- return true -- DEBUG
  return false
end

local function getInUseExtInterfaces(current_ifid)
  local inuse_ext_interfaces = {}
  local ntopng_interfaces = interface.getIfNames()
  for other_ifid,other_ifname in pairs(ntopng_interfaces) do
    if other_ifid ~= current_ifid then
      local enabled = ntop.getCache('ntopng.prefs.ifid_'..other_ifid..'.traffic_recording.enabled')
      if not isEmptyString(enabled) and enabled == "true" then
        local other_ext_ifname = ntop.getCache('ntopng.prefs.ifid_'..other_ifid..'.traffic_recording.ext_ifname')
        if not isEmptyString(other_ext_ifname) then
          inuse_ext_interfaces[other_ext_ifname] = true
        end
      end
    end
  end
  return inuse_ext_interfaces
end

function recording_utils.getExtInterfaces(ifid)
  local ext_interfaces = {}
  local all_interfaces = ntop.listInterfaces()
  local ntopng_interfaces = swapKeysValues(interface.getIfNames()) 
  local inuse_ext_interfaces = getInUseExtInterfaces(ifid)
 
  for ifname,_ in pairs(all_interfaces) do
    if ntopng_interfaces[ifname] == nil and -- not in use as packet interface by ntopng 
       inuse_ext_interfaces[ifname] == nil and -- not in use by other zmq interfaces
       recording_utils.isZC(ifname) then -- is ZC
      ext_interfaces[ifname] = {
        ifdesc = 'zc:'..ifname,
        is_zc = is_zc
      }
    end
  end

  return ext_interfaces
end

local function nextFreeCore(num_cores, busy_cores, start)
  local busy_map = swapKeysValues(busy_cores) 
  for i=start,num_cores-1 do
    if busy_map[i] == nil then
      return i
    end
  end
  return start
end

local function memInfo()
  local mem_info = {}
  for line in io.lines("/proc/meminfo") do 
    local values = split(line, ':')
    mem_info[values[1]] = trimString(values[2])
  end
  return mem_info
end

local function dirname(s)
  s = s:gsub('/$', '')
  local s, n = s:gsub('/[^/]*$', '')
  if n == 1 then
    return ternary(string.len(s) > 0, s, "/")
  else 
    return '.' 
  end
end

function recording_utils.storageInfo()
  local storage_info = {
    path = dirs.pcapdir, dev = "", mount = "",
    total = 0, used = 0, avail = 0, used_perc = 0,
  }
  local root_path = storage_info.path
  while not ntop.isdir(root_path) and string.len(root_path) > 1 do
    root_path = dirname(root_path) 
  end
  local line = executeWithOuput("df "..root_path.." 2>/dev/null|tail -n1")
  line = line:gsub('%s+', ' ')
  local values = split(line, ' ')
  if #values >= 6 then
    storage_info.dev = values[1]
    storage_info.total = tonumber(values[2])/1024
    storage_info.used = tonumber(values[3])/1024
    storage_info.avail = tonumber(values[4])/1024
    storage_info.used_perc = values[5]
    storage_info.mount = values[6]
  end
  return storage_info
end

function recording_utils.getPcapPath(ifid)
  local storage_path = dirs.pcapdir
  return storage_path.."/"..ifid.."/pcap"
end

function recording_utils.getTimelinePath(ifid)
  local storage_path = dirs.pcapdir
  return storage_path.."/"..ifid.."/timeline"
end

local function getPcapFileDir(job_id, ifid)
  local storage_path = dirs.pcapdir
  return storage_path.."/"..ifid.."/extr_pcap/"..job_id
end

local function getPcapFilePath(job_id, ifid, file_id)
  local dir_path = getPcapFileDir(job_id, ifid)
  return dir_path.."/"..file_id..".pcap"
end

local function getN2diskInterfaceName(ifid)
  if interface.isPacketInterface() then
    return getInterfaceName(ifid)
  else
    return ntop.getCache('ntopng.prefs.ifid_'..ifid..'.traffic_recording.ext_ifname')
  end
end

function recording_utils.createConfig(ifid, params)
  local ifname = getN2diskInterfaceName(ifid)

  if interface.isPacketInterface() then
    full_ifname = ifname
  else
    if recording_utils.isZC(ifname) then
      -- full_ifname = ifname -- DEBUG
      full_ifname = "zc:"..ifname
    else
      full_ifname = ifname
    end
  end

  if isEmptyString(ifname) then
    return false
  end

  local conf_dir = dirs.workingdir.."/n2disk"
  local filename = conf_dir.."/n2disk-"..ifname..".conf"
  local storage_path = dirs.pcapdir

  if isEmptyString(storage_path) then
    return false
  end

  local defaults = {
    buffer_size = 1024,       -- Buffer size (MB)
    max_file_size = 256,      -- Max file length (MB)
    max_file_duration = 60,   -- Max file duration (sec)
    max_disk_space = recording_utils.default_disk_space, -- Max disk space (MB)
    snaplen = 1536,           -- Capture length
    writer_core = 0,          -- Writer thread affinity
    reader_core = 1,          -- Reader thread affinity
    indexer_cores = { 2 },    -- Indexer threads affinity
    -- Optional parameters
    -- zmq_endpoint = "tcp://*:5556" -- ZMQ endpoint for stats/flows
  }

  local ifspeed = (interface.getMaxIfSpeed(ifname) or 1000)

  -- Reading system memory info

  local mem_info = memInfo()
  local mem_total_mb = math.floor(tonumber(split(mem_info['MemTotal'], ' ')[1])/1024)

  -- Computing file and buffer size

  if ifspeed > 10000 then -- 40/100G
    defaults.max_file_size = 4*1024
  elseif ifspeed > 1000 then -- 10G
    defaults.max_file_size = 1*1024
  end
  defaults.buffer_size = 4*defaults.max_file_size

  local min_sys_mem = 1024 -- 1G reserved for system
  local min_n2disk_buffer_size = 128 -- min memory for n2disk to work
  local total_n2disk_mem = defaults.buffer_size + (defaults.buffer_size/2) -- pcap + index buffer
  if mem_total_mb < total_n2disk_mem + min_sys_mem then
    local min_total_n2disk_mem = min_n2disk_buffer_size + (min_n2disk_buffer_size/2)
    local min_total_mem = min_sys_mem + min_total_n2disk_mem
    if mem_total_mb < min_total_mem then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Not enough memory available ("..mem_total_mb.."MB total, min required is "..min_total_mem.."MB)") 
      return false
    end
    defaults.buffer_size = (mem_total_mb - min_sys_mem) / 2 -- leave some room for index memory and other processes
    defaults.max_file_size = math.floor(defaults.buffer_size/4)
  end

  -- Computing core affinity

  local indexing_threads = 1 -- 1G
  if ifspeed > 10000 then    -- 40/100G
    indexing_threads = 4
  elseif ifspeed > 1000 then -- 10G
    indexing_threads = 2
  end
  local n2disk_threads = indexing_threads + 2

  local cores = tonumber(executeWithOuput("nproc"))

  local ntopng_affinity = split(prefs.cpu_affinity, ',')
  local busy_cores = {}
  if cores - (#ntopng_affinity) >= n2disk_threads then
    -- enough cores to isolate all threads, skipping ntopng threads
    busy_cores = ntopng_affinity
  end

  local first_core = 0

  defaults.writer_core = nextFreeCore(cores, busy_cores, first_core)
  table.insert(busy_cores, defaults.writer_core)
  first_core = (defaults.writer_core + 1) % cores

  defaults.reader_core = nextFreeCore(cores, busy_cores, first_core)
  table.insert(busy_cores, defaults.reader_core)
  first_core = (defaults.reader_core + 1) % cores

  defaults.indexer_cores = {}
  for i=1,indexing_threads do
    local indexer_core = nextFreeCore(cores, busy_cores, first_core)
    table.insert(defaults.indexer_cores, indexer_core)
    table.insert(busy_cores, indexer_core)
    first_core = (indexer_core + 1) % cores
  end 

  local config = table.merge(defaults, params)

  -- Writing configuration file

  local ret = ntop.mkdir(conf_dir)

  if not ret then
    return false
  end

  local f = io.open(filename, "w")

  if not f then
    return false
  end

  local pcap_path = recording_utils.getPcapPath(ifid)
  local timeline_path = recording_utils.getTimelinePath(ifid)

  f:write("--interface="..full_ifname.."\n")
  f:write("--dump-directory="..pcap_path.."\n")
  f:write("--index\n")
  f:write("--timeline-dir="..timeline_path.."\n")
  f:write("--buffer-len="..config.buffer_size.."\n")
  f:write("--max-file-len="..config.max_file_size.."\n")
  f:write("--max-file-duration="..config.max_file_duration.."\n")
  f:write("--disk-limit="..config.max_disk_space.."\n")
  f:write("--snaplen="..config.snaplen.."\n")
  f:write("--writer-cpu-affinity="..config.writer_core.."\n")
  f:write("--reader-cpu-affinity="..config.reader_core.."\n")
  f:write("--compressor-cpu-affinity=")
  for i, v in ipairs(config.indexer_cores) do
    f:write(v..ternary(i == #config.indexer_cores, "", ","))
  end
  f:write("\n")
  f:write("--index-on-compressor-threads\n")
  if not isEmptyString(prefs.user) then
    f:write("-u="..prefs.user.."\n");
  else
    f:write("--dont-change-user\n");
  end
  if config.zmq_endpoint ~= nil then
    f:write("--zmq="..config.zmq_endpoint.."\n")
    f:write("--zmq-probe-mode\n")
    f:write("--zmq-export-flows\n")
  end
  -- Ignored by systemd, required by init.d
  f:write("--daemon\n")
  f:write("-P=/var/run/n2disk-"..ifname..".pid\n")

  f:close()

  return true
end

function recording_utils.isEnabled(ifid)
  if recording_utils.isAvailable() then
    local record_traffic = ntop.getCache('ntopng.prefs.ifid_'..ifid..'.traffic_recording.enabled')
    if record_traffic == "true" then
      return true
    end
  end
  return false
end

function recording_utils.isActive(ifid)
  local ifname = getN2diskInterfaceName(ifid)
  local check_cmd = n2disk_ctl_cmd.." is-active "..ifname
  local is_active = executeWithOuput(check_cmd)
  return ternary(string.match(is_active, "^active"), true, false)
end

function recording_utils.restart(ifid)
  local ifname = getN2diskInterfaceName(ifid)
  os.execute(n2disk_ctl_cmd.." enable "..ifname)
  os.execute(n2disk_ctl_cmd.." restart "..ifname)
end

function recording_utils.stop(ifid)
  local ifname = getN2diskInterfaceName(ifid)
  os.execute(n2disk_ctl_cmd.." stop "..ifname)
  os.execute(n2disk_ctl_cmd.." disable "..ifname)
end

function recording_utils.log(ifid, rows)
  local ifname = getN2diskInterfaceName(ifid)
  local log = executeWithOuput(n2disk_ctl_cmd.." log "..ifname.."|tail -n"..rows)
  return log
end

function recording_utils.stats(ifid)
  local ifname = getN2diskInterfaceName(ifid)
  local stats = {}
  local proc_stats = executeWithOuput(n2disk_ctl_cmd.." stats "..ifname)
  local lines = split(proc_stats, "\n")
  for i = 1, #lines do
    local pair = split(lines[i], ": ")
    if pair[1] ~= nil and pair[2] ~= nil then
      stats[pair[1]] = trimString(pair[2])
    end
  end
  return stats
end

function recording_utils.setLicense(key)
  os.execute(n2disk_ctl_cmd.." set-license "..key)
end

function recording_utils.getJobFiles(id)
  local job_json = ntop.getHashCache(extraction_jobs_key, id)
  local files = {}
  if not isEmptyString(job_json) then
    local job = json.decode(job_json)
    local file_id = 1
    local file = getPcapFilePath(job.id, job.ifid, file_id)
    while ntop.exists(file) do
      table.insert(files, file)
      file_id = file_id + 1
      file = getPcapFilePath(job.id, job.ifid, file_id) 
    end
  end
  return files
end

function recording_utils.deleteJob(job_id)
  local job_json = ntop.getHashCache(extraction_jobs_key, job_id)
  if not isEmptyString(job_json) then
    ntop.delHashCache(extraction_jobs_key, tostring(job_id))
    local job = json.decode(job_json)
    local dir_path = getPcapFileDir(job.id, job.ifid)
    ntop.rmdir(dir_path)
  end
end

function recording_utils.extractionJobsInfo(ifid)
  local job_ids = ntop.getHashKeysCache(extraction_jobs_key) or {}
  local jobs_info = { total = 0, ready = 0 }

  for id,_ in pairs(job_ids) do
    local job_json = ntop.getHashCache(extraction_jobs_key, id)
    local job = json.decode(job_json)
    if ifid == nil or job.ifid == ifid then
      if job.status == "completed" or job.status == "failed" then
        jobs_info.ready = jobs_info.ready + 1
      end
      jobs_info.total = jobs_info.total + 1
    end
  end

  return jobs_info
end

function recording_utils.getExtractionJobs(ifid)
  local jobs = {}
  local job_ids = ntop.getHashKeysCache(extraction_jobs_key) or {}

  for id,_ in pairs(job_ids) do
    local job_json = ntop.getHashCache(extraction_jobs_key, id)
    local job = json.decode(job_json)
    if ifid == nil or job.ifid == ifid then
      jobs[tonumber(id)] = json.decode(job_json)
    end
  end

  return jobs
end

-- Stop an extraction
function recording_utils.stopJob(job_id)
  ntop.rpushCache(extraction_stop_queue_key, job_id)
end

-- Schedule an extraction
-- Note: 'params' should contain 'time_from', 'time_to', 'filter'
-- 'time_*' format is epoch (number)
-- 'filter' format is BPF
function recording_utils.scheduleExtraction(ifid, params)

  if params.time_from == nil or params.time_to == nil then
    return nil
  end
  if params.filter == nil then
    params.filter = ""
  end

  local id = ntop.incrCache(extraction_seqnum_key)

  local job = {
    id = id,
    ifid = tonumber(ifid),
    time = os.time(),
    status = 'waiting',
    time_from = tonumber(params.time_from),
    time_to = tonumber(params.time_to),
    filter = params.filter,
  }

  ntop.setHashCache(extraction_jobs_key, job.id, json.encode(job))

  ntop.rpushCache(extraction_queue_key, tostring(job.id))
  
  local job_info = { id = job.id }
  return job_info
end

local function setJobAsCompleted()
  local datapath_extractions = ntop.getExtractionStatus()
  for id,status in pairs(datapath_extractions) do
    local job_json = ntop.getHashCache(extraction_jobs_key, id)
    if not isEmptyString(job_json) then
      local job = json.decode(job_json)
      if job.status == "processing" then
        if status.status == 0 then
          job.status = "completed"
        else
          job.status = "failed"
          job.error_code = status.status
        end
        job.extracted_pkts = status.extracted_pkts
        job.extracted_bytes = status.extracted_bytes
        ntop.setHashCache(extraction_jobs_key, job.id, json.encode(job)) 
      end
    end
  end
end

function recording_utils.checkExtractionJobs()

  -- stop extractions for stopped jobs, if any
  if ntop.isExtractionRunning() then
    local id = ntop.lpopCache(extraction_stop_queue_key)
    if not isEmptyString(id) then
      local job_json = ntop.getHashCache(extraction_jobs_key, id)
      if not isEmptyString(job_json) then
        local job = json.decode(job_json)

        ntop.stopExtraction(job.id)

        job.status = 'stopped'
        ntop.setHashCache(extraction_jobs_key, job.id, json.encode(job))
      end
    end
  end

  if not ntop.isExtractionRunning() then
    -- set the previous job as completed, if any
    setJobAsCompleted()

    -- run a new extraction job
    local id = ntop.lpopCache(extraction_queue_key)
    if not isEmptyString(id) then

      local job_json = ntop.getHashCache(extraction_jobs_key, id)
      if not isEmptyString(job_json) then
        local job = json.decode(job_json)

        ntop.runExtraction(job.id, tonumber(job.ifid), tonumber(job.time_from), tonumber(job.time_to), job.filter)

        job.status = 'processing'
        ntop.setHashCache(extraction_jobs_key, job.id, json.encode(job))
      end
    end
  end
end

-- #################################

return recording_utils

