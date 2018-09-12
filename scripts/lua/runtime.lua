--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local ts_utils = require("ts_utils")

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "about"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

info = ntop.getInfo()
print("<hr /><h2>"..info["product"].." "..i18n("about.runtime_status").."</h2>")

print("<table class=\"table table-bordered table-striped\">\n")
if(info["pro.systemid"] and (info["pro.systemid"] ~= "")) then
   print("<tr><th nowrap>"..i18n("about.system_id").."</th><td>".. info["pro.systemid"].."</td></tr>\n")
end

local system_host_stats = ntop.systemHostStat()

if system_host_stats["cpu_load"] ~= nil then
   print("<tr><th nowrap>"..i18n("about.cpu_load").."</th><td><span id='cpu-load-pct'>...</span></td></tr>\n")
end
if system_host_stats["mem_total"] ~= nil then
   print("<tr><th nowrap>"..i18n("about.ram_memory").."</th><td><span id='ram-used'></span></td></tr>\n")
end

vers = string.split(info["version.git"], ":")
if((vers ~= nil) and (vers[2] ~= nil)) then
   ntopng_git_url = "<A HREF=\"https://github.com/ntop/ntopng/commit/".. vers[2] .."\">"..info["version"].."</A>"
else
   ntopng_git_url = info["version"]
end

print("<tr><th nowrap>"..i18n("about.version").."</th><td>"..ntopng_git_url.." - ")

printntopngRelease(info)

print("<tr><th nowrap>"..i18n("about.platform").."</th><td>"..info["platform"].." - "..info["bits"] .." bit</td></tr>\n")
if(info.pid ~= nil) then
   print("<tr><th nowrap>PID (Process ID)</th><td>"..info.pid.."</td></tr>\n")
end
if ts_utils.getDriverName() == "influxdb" then
   print("<tr><th nowrap>".. i18n("prefs.influxdb_storage_title") .."</th><td><img id=\"influxdb-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"influxdb-info-text\"></span></td></tr>\n")
   print[[<script>
$(function() {
   $.get("]] print(ntop.getHttpPrefix()) print[[/lua/get_influxdb_info.lua", function(info) {
      $("#influxdb-info-load").hide();
      $("#influxdb-info-text").html(bytesToVolume(info.db_bytes) + " ");
   }).fail(function() {
      $("#influxdb-info-load").hide();
   });
});
</script>
]]
end
print("<tr><th nowrap>"..i18n("about.startup_line").."</th><td>".. info["product"] .." "..info["command_line"].."</td></tr>\n")
print("<tr><th nowrap>"..i18n("about.last_log").."</th><td><code>\n")

for i=1,32 do
    msg = ntop.listIndexCache("ntopng.trace", i)
    if(msg ~= nil) then
        print(msg.."<br>\n")	
    end			
end

print("</code></td></tr>\n")


print("</table>\n")


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
