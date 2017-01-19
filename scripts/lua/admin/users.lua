--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

if(haveAdminPrivileges()) then
   interface.select(ifname)

   ifstats = interface.getStats()
   is_bridge_iface = (ifstats["bridge.device_a"] ~= nil) and (ifstats["bridge.device_b"] ~= nil)
   is_captive_portal_enabled = ntop.getPrefs()["is_captive_portal_enabled"]

   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
   
   active_page = "admin"
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   
   dofile(dirs.installdir .. "/scripts/lua/inc/users.lua")
   dofile(dirs.installdir .. "/scripts/lua/inc/password_dialog.lua")
   dofile(dirs.installdir .. "/scripts/lua/inc/add_user_dialog.lua")
   dofile(dirs.installdir .. "/scripts/lua/inc/delete_user_dialog.lua")
   
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
end
