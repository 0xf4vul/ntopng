--
-- (C) 2014-15-15 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

local page = _GET["page"]

if(page == nil) then page = "username_processes" end
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local user_key    = _GET["username"]
local host_info    = url2hostinfo(_GET)
local uid         = _GET["uid"]
local application = _GET["application"]
local name
local ifstats = interface.getStats()
local refresh_rate

local have_nedge = ntop.isnEdge()
if have_nedge then
   refresh_rate = 5
else
   refresh_rate = getInterfaceRefreshRate(ifstats["id"])
end

if(user_key == nil) then
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> "..i18n("user_info.missing_user_name_message").."</div>")
else
   if host_info and host_info["host"] then
      name = getResolvedAddress(hostkey2hostinfo(host_info["host"]))
      if (name == nil) then
	 name = host_info["host"]
      end
   end
   print [[
            <nav class="navbar navbar-default" role="navigation">
              <div class="navbar-collapse collapse">
      <ul class="nav navbar-nav">
	    <li><a href="#">]]

   if host_info then
      print(string.format("%s: %s", i18n("host_details.host"), name))
   end

   print [[ <i class="fa fa-linux fa-lg"></i> ]] print(user_key)

   print [[  </a></li>]]


   if(page == "username_processes") then active=' class="active"' else active = "" end
   print('<li'..active..'><a href="?username='.. user_key..'&uid='..uid)
   if host_info then
      print('&'..hostinfo2url(host_info))
   end
   print('&page=username_processes">'..i18n("user_info.processes")..'</a></li>\n')

   if(page == "username_ndpi") then active=' class="active"' else active = "" end
   print('<li'..active..'><a href="?username='.. user_key..'&uid='..uid)
   if host_info then
      print('&'..hostinfo2url(host_info))
   end
   print('&page=username_ndpi">'..i18n("protocols")..'</a></li>\n')

   if(page == "flows") then active=' class="active"' else active = "" end
   print('<li'..active..'><a href="?username='.. user_key..'&uid='..uid)
   if host_info then
      print('&'..hostinfo2url(host_info))
   end
   print('&page=flows">'..i18n("flows")..'</a></li>\n')


   print('</ul>\n\t</div>\n\t\t</nav>\n')

   if(page == "username_processes") then
      print [[
    <table class="table table-bordered table-striped">
      <tr><th class="text-left">
      ]] print(i18n("user_info.processes_overview")) print[[
        <td><div class="pie-chart" id="topProcesses"></div></td>
      
      </th>
    </tr>]]

      print [[
      </table>
<script type='text/javascript'>
window.onload=function() {
   var refresh = ]] print(refresh_rate..'') print[[000 /* ms */;
		    do_pie("#topProcesses", ']]
      print (ntop.getHttpPrefix())
      print [[/lua/get_username_data.lua', { uid: "]] print(uid) print [[", username_data: "processes" ]] 
      if (host_info ~= nil) then print(", "..hostinfo2json(host_info)) end
      print [[
 }, "", refresh);
}
</script>
]]

   elseif(page == "username_ndpi") then

      print [[

  <table class="table table-bordered table-striped">
    <tr>
      <th class="text-left" colspan=2>]] print(i18n("ndpi_page.overview", {what = i18n("ndpi_page.application_protocol")})) print[[</th>
      <td>
        <div class="pie-chart" id="topApplicationProtocols"></div>
      </td>
      <td colspan=2>
        <div class="pie-chart" id="topApplicationBreeds"></div>
      </td>
    </tr>
    <tr>
      <th class="text-left" colspan=2>]] print(i18n("ndpi_page.overview", {what = i18n("ndpi_page.application_protocol_category")})) print[[</th>
      <td colspan=2>
        <div class="pie-chart" id="topApplicationCategories"></div>
      </td>
    </tr>
  </table>

        <script type='text/javascript'>
               var refresh = ]] print(refresh_rate..'') print[[000 /* ms */;
	       window.onload=function() {]]

      print[[ do_pie("#topApplicationProtocols", ']]
      print (ntop.getHttpPrefix())
      print [[/lua/get_username_data.lua', { uid: "]] print(uid) print [[", username_data: "applications" ]] 
      if (host_info ~= nil) then print(", "..hostinfo2json(host_info)) end
      print [[ }, "", refresh); ]]

      print[[ do_pie("#topApplicationCategories", ']]
      print (ntop.getHttpPrefix())
      print [[/lua/get_username_data.lua', { uid: "]] print(uid) print [[", username_data: "categories" ]] 
      if (host_info ~= nil) then print(", "..hostinfo2json(host_info)) end
      print [[ }, "", refresh); ]]

      print[[do_pie("#topApplicationBreeds", ']]
      print [[/lua/get_username_data.lua', { uid: "]] print(uid) print [[", username_data: "breeds" ]] 
      if (host_info ~= nil) then print(", "..hostinfo2json(host_info)) end
      print [[ }, "", refresh);]]

      print[[
				}

	    </script>
]]

   elseif page == "flows" then
      print [[
      <div id="table-flows"></div>
	 <script>
   var url_update = "]]
      print (ntop.getHttpPrefix())
      print [[/lua/get_flows_data.lua?uid=]] print(uid)
      if host_info then
	 print ('&'..hostinfo2url(host_info))
      end
      print ('";')

      ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/flows_stats_id.inc")

      local show_vlan
      if ifstats.vlan then show_vlan = true else show_vlan = false end
      -- Set the host table option
      if show_vlan then print ('flow_rows_option["vlan"] = true;\n') end

      local active_flows_msg = i18n("flows_page.active_flows",{filter=""})
      if not interface.isPacketInterface() then
	 active_flows_msg = i18n("flows_page.recently_active_flows",{filter=""})
      elseif interface.isPcapDumpInterface() then
	 active_flows_msg = i18n("flows")
      end

      local dt_buttons = ''
      -- TODO: add application filter, etc.
      dt_buttons = "["..dt_buttons.."]"

      print [[
  flow_rows_option["type"] = 'host';
	 $("#table-flows").datatable({
         url: url_update,
         buttons: ]] print(dt_buttons) print[[,
         rowCallback: function ( row ) { return flow_table_setID(row); },
         tableCallback: function()  { $("#dt-bottom-details > .pull-left > p").first().append('. ]]
      print(i18n('flows_page.idle_flows_not_listed'))
      print[['); },
         showPagination: true,
	       ]]

      print('title: "'..active_flows_msg..'",')

      -- Set the preference table
      local preference = tablePreferences("rows_number", _GET["perPage"])
      if preference ~= "" then
	 print ('perPage: '..preference.. ",\n")
      end

      print ('sort: [ ["' .. getDefaultTableSort("flows") ..'","' .. getDefaultTableSortOrder("flows").. '"] ],\n')

      print [[
	        columns: [
           {
        title: "Key",
         field: "key",
         hidden: true
         },
			     {
			     title: "",
				 field: "column_key",
	 	             css: {
			        textAlign: 'center'
			     }
				 },
			     {
                             title: "]] print(i18n("application")) print[[",
				 field: "column_ndpi",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("flows_page.l4_proto")) print[[",
				 field: "column_proto_l4",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			     }
				 },]]

      if show_vlan then

	 if ifstats.vlan then
	    print('{ title: "'..i18n("vlan")..'",\n')
	 end


	 print [[
         field: "column_vlan",
         sortable: true,
                 css: {
              textAlign: 'center'
           }

         },
]]
      end
      print [[
			     {
			     title: "]] print(i18n("client")) print[[",
				 field: "column_client",
				 sortable: true,
				 },
			     {
			     title: "]] print(i18n("server")) print[[",
				 field: "column_server",
				 sortable: true,
				 },
			     {
                             title: "]] print(i18n("duration")) print[[",
				 field: "column_duration",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			       }
			       },
			     {
                             title: "]] print(i18n("breakdown")) print[[",
				 field: "column_breakdown",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			       }
			       },
			     {
			     title: "]] print(i18n("flows_page.actual_throughput")) print[[",
				 field: "column_thpt",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			     }
				 },
			     {
                             title: "]] print(i18n("flows_page.total_bytes")) print[[",
				 field: "column_bytes",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			     }

				 }
			     ,{
                             title: "]] print(i18n("info")) print[[",
				 field: "column_info",
				 sortable: true,
	 	             css: {
			        textAlign: 'left'
			     }
				 }
			     ]
	       });
]]

      if have_nedge then
	 printBlockFlowJs()
      end

      print[[
       </script>

   ]]

   end
end



dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
