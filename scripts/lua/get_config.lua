--
-- (C) 2013-18 - ntop.org
--

local prefs = ntop.getPrefs()
local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local os_utils = require "os_utils"

require "lua_utils"

local json = require("dkjson")

local function send_error(error_type)
   local msg = i18n("error")
   if error_type == "not_granted" then
     msg = i18n("conf_backup.not_granted")
   elseif error_type == "tar_not_found" then
     msg = i18n("conf_backup.tar_not_counf")
   end

   sendHTTPContentTypeHeader('application/json')
   print(json.encode({error = msg}))
end

local function starts_with(str, start_str)
   return string.sub(str, 1, string.len(start_str)) == start_str
end

if not isAdministrator() then
  send_error("not_granted")
else

  if ntop.isWindows() then

    sendHTTPContentTypeHeader('application/json', 'attachment; filename="runtimeprefs.json"')

    local runtimeprefs_path = os_utils.fixPath(dirs.workingdir.."/runtimeprefs.json")
    local runtimeprefs = io.open(runtimeprefs_path, "r")
    
    print(runtimeprefs:read "*a") 

  else -- Unix

    -- -- Old way (single json)
    -- sendHTTPContentTypeHeader('application/json', 'attachment; filename="runtimeprefs.json"')
    -- local config_backup = {}
    -- if not isEmptyString(prefs.config_file) then
    --   local ntopng_conf = io.open(prefs.config_file, "r")  
    --   if ntopng_conf ~= nil then
    --     config_backup[prefs.config_file] = (ntopng_conf:read "*a")
    --   end
    -- end
    -- print(json.encode(config_backup or {}))

    local bin_tar = "/bin/tar"
    if not ntop.exists(bin_tar) then
      bin_tar = "/usr/bin/tar"
    end
    if not ntop.exists(bin_tar) then
      send_error("tar_not_found")
    else

      local config_files = ""

      local ntopng_conf_dir = "/etc/ntopng"
      if ntop.exists(ntopng_conf_dir) then
        config_files = config_files .. " " .. ntopng_conf_dir
      end

      local license_path = "/etc/ntopng.license"
      if ntop.isnEdge() then
        license_path = "/etc/nedge.license"
      end
      if ntop.exists(license_path) then
        config_files = config_files .. " " .. license_path
      end

      if not isEmptyString(prefs.config_file) then
        if ntop.exists(prefs.config_file) and not starts_with(prefs.config_file, ntopng_conf_dir) then
          config_files = config_files .. " " .. prefs.config_file
        end
      end

      local runtimeprefs_path = os_utils.fixPath(dirs.workingdir.."/runtimeprefs.json")
      if ntop.exists(runtimeprefs_path) and not starts_with(runtimeprefs_path, ntopng_conf_dir) then
        config_files = config_files .. " " .. runtimeprefs_path
      end

      if ntop.isnEdge() then
        local system_config_path = os_utils.fixPath(dirs.workingdir.."/system.config")
        if ntop.exists(system_config_path) and not starts_with(system_config_path, ntopng_conf_dir) then
          config_files = config_files .. " " .. system_config_path
        end
      end

      if not isEmptyString(prefs.ndpi_proto_file) then
        if ntop.exists(prefs.ndpi_proto_file) and not starts_with(prefs.ndpi_proto_file, ntopng_conf_dir) then
          config_files = config_files .. " " .. prefs.ndpi_proto_file
        end
      end

      local tar_file = "ntopng_conf_backup.tar.gz"
      if ntop.isnEdge() then
        tar_file = "nedge_conf_backup.tar.gz"
      end

      sendHTTPContentTypeHeader('application/x-tar-gz', 'attachment; filename="' .. tar_file .. '"')

      local cmd = bin_tar .. " czP " .. config_files 

      -- Note: we are using os.execute / ntop.dumpBinaryFile as io.popen / print 
      -- cannot be used for dumping binary files directly to the connection

      local tmp = os.tmpname()
      os.execute(cmd .. " > " .. tmp)
      ntop.dumpBinaryFile(tmp)
      os.remove(tmp)

    end
  end
end

