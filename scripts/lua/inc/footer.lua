--
-- (C) 2013-16 - ntop.org
--

require "os"

print [[
      <div id="footer"> <hr>
   ]]

ntop_version_check()

info = ntop.getInfo(true)

print [[
	<div class="container-fluid">
	<div class="row">
	<div class="col-xs-6 col-sm-4">]]
print(info["product"])

iface_id = interface.name2id(ifname)

interface.select(ifname)
_ifstats = interface.getStats()

if(info["version.enterprise_edition"]) then
   print(" Enterprise")
elseif(info["pro.release"]) then
   print(" Pro [Small Business Edition]")
else
   print(" Community")
end

if(info["version.embedded_edition"] == true) then
   print("/Embedded")
end

print(" v."..info["version"])

print("</br>User ")
print('<a href="'..ntop.getHttpPrefix()..'/lua/admin/users.lua"><span class="label label-primary">'.._SESSION["user"].. '</span></a> Interface <a href="'..ntop.getHttpPrefix()..'/lua/if_stats.lua"><span class="label label-primary">')

alias = getInterfaceNameAlias(ifname)

if((alias ~= nil) and (alias ~= ifname)) then
   print(alias)
else
   print(_ifstats.name)
end

print('</span></a>')

if(info["pro.systemid"] and (info["pro.systemid"] ~= "")) then
   local do_show = false

   print('<br><A HREF='..ntop.getHttpPrefix()..'/lua/about.lua> <span class="badge badge-warning">')
   if(info["pro.release"]) then
      if(info["pro.demo_ends_at"] ~= nil) then
	 local rest = info["pro.demo_ends_at"] - os.time()
	 if(rest > 0) then
	    print(' License expires in '.. secondsToTime(rest) ..'')
	 end
      end
   else
      print('Upgrade to Professional version')
      do_show = true
   end
   print('</span></A>')

   if(do_show) then
      print('<br><iframe src="https://ghbtns.com/github-btn.html?user=ntop&repo=ntopng&type=watch&count=true" allowtransparency="true" frameborder="0" scrolling="0" width="110" height="20"></iframe>')
   end
end




print [[</font>

</div> <!-- End column 1 -->
	<div class="col-xs-4 v col-sm-4">
	<div class="row">
	 <div class="col-xs-6 col-sm-6">
]]

if interface.isPcapDumpInterface() == false then
   key = 'ntopng.prefs.'..ifname..'.speed'
   maxSpeed = ntop.getCache(key)
   -- io.write(maxSpeed)
   if((maxSpeed == "") or (maxSpeed == nil)) then
      -- if the speed in not custom we try to read the speed from the interface
      -- and, as a final resort, we use 1Gbps
      if tonumber(_ifstats.speed) ~= nil then
	 maxSpeed = tonumber(_ifstats.speed) * 1e6
      else
	 maxSpeed = 1000000000 -- 1 Gbit
      end
   else
      -- use the user-specified custom value for the speed
      maxSpeed = tonumber(maxSpeed)*1000000
   end
   addGauge('networkload', ntop.getHttpPrefix()..'/lua/set_if_prefs.lua', 100, 100, 50)
   print [[ <div class="text-center" title="All traffic detected by NTOP: Local2Local, Remote2Local, Local2Remote" id="gauge_text_allTraffic"></div> ]]

   print [[
	</div>
	<div>]]
   print [[  <a href="]]
   print (ntop.getHttpPrefix())
   print [[/lua/if_stats.lua">
	    <table style="border-collapse:collapse; !important">
	    <tr><td title="Local to Remote Traffic"><i class="fa fa-cloud-upload"></i>&nbsp;</td><td class="network-load-chart-local2remote">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</td><td class="text-right" id="chart-local2remote-text"></td></tr>
	    <tr><td title="Remote to Local Traffic"><i class="fa fa-cloud-download"></i>&nbsp;</td><td class="network-load-chart-remote2local">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</td><td class="text-right" id="chart-remote2local-text"></td></tr>
	    </table>
	    </div>
	    <div class="col-xs-6 col-sm-4">
	    </a>
]]

end -- closes interface.isPcapDumpInterface() == false 

print [[
      </div>
    </div>
  </div><!-- End column 2 -->
  <!-- Optional: clear the XS cols if their content doesn't match in height -->
  <div class="clearfix visible-xs"></div>
  <div class="col-xs-6 col-sm-4">
    <div id="network-load">
  </div> <!-- End column 3 -->
</div>
</div>]]


print[[<script>
// Updating charts.
]]

print('var is_historical = false;')
print [[

var updatingChart_local2remote = $(".network-load-chart-local2remote").peity("line", { width: 64, max: null });
var updatingChart_remote2local = $(".network-load-chart-remote2local").peity("line", { width: 64, max: null, fill: "lightgreen"});

var prev_bytes   = 0;
var prev_packets = 0;
var prev_local   = 0;
var prev_remote  = 0;
var prev_epoch   = 0;

function addCommas(nStr) {
  nStr += '';
  var x = nStr.split('.');
  var x1 = x[0];
  var x2 = x.length > 1 ? '.' + x[1] : '';
  var rgx = /(\d+)(\d{3})/;
  while (rgx.test(x1)) {
    x1 = x1.replace(rgx, '$1' + ',' + '$2');
  }
  return x1 + x2;
}

function formatPackets(n) {
  return(addCommas(n)+" Pkts");
}

function bytesToVolume(bytes) {
  var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  if (bytes == 0) return '0 Bytes';
  var i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
  return (bytes / Math.pow(1024, i)).toFixed(2) + ' ' + sizes[i];
};

function bytesToVolumeAndLabel(bytes) {
  var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  if (bytes == 0) return '0 Bytes';
  var i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
  return [ (bytes / Math.pow(1024, i)).toFixed(2), sizes[i] ];
};

function bitsToSize(bits, factor) {
  var sizes = ['bps', 'Kbps', 'Mbps', 'Gbps', 'Tbps'];
  if (bits == 0) return '0 bps';
  var i = parseInt(Math.floor(Math.log(bits) / Math.log(1024)));
  if (i == 0) return bits + ' ' + sizes[i];
  return (bits / Math.pow(factor, i)).toFixed(2) + ' ' + sizes[i];
};

function bytesToSize(bytes) {
  return(bytesToSize(bytes*8));
}

function secondsToTime(seconds) {
   if(seconds < 1) {
      return("< 1 sec")
   }

   var days = Math.floor(seconds / 86400)
   var hours =  Math.floor((seconds / 3600) - (days * 24))
   var minutes = Math.floor((seconds / 60) - (days * 1440) - (hours * 60))
   var sec = seconds % 60
   var msg = "", msg_array = []

   if(days > 0) {
      years = Math.floor(days/365)

      if(years > 0) {
	 days = days % 365

	 msg = years + " year"
	 if(years > 1) {
	    msg += "s"
	 }

         msg_array.push(msg)
         msg = ""
      }
      msg = days + " day"
      if(days > 1) { msg += "s" }
      msg_array.push(msg)
      msg = ""
   }

   if(hours > 0) {
      msg = hours + " hour";
      if(hours > 1) { msg +=  "s" }
      msg_array.push(msg)
      msg = ""
   }

   if(minutes > 0) {
      msg_array.push(minutes + " min")
   }

   if(sec > 0) {
      msg_array.push(sec + " sec")
   }

   return msg_array.join(", ")
}

Date.prototype.format = function(format) { //author: meizz
  var o = {
     "M+" : this.getMonth()+1, //month
     "d+" : this.getDate(),    //day
     "h+" : this.getHours(),   //hour
     "m+" : this.getMinutes(), //minute
     "s+" : this.getSeconds(), //second
     "q+" : Math.floor((this.getMonth()+3)/3),  //quarter
     "S" : this.getMilliseconds() //millisecond
  }

  if(/(y+)/.test(format)) format=format.replace(RegExp.$1,
						(this.getFullYear()+"").substr(4 - RegExp.$1.length));
  for(var k in o)if(new RegExp("("+ k +")").test(format))
    format = format.replace(RegExp.$1,
			    RegExp.$1.length==1 ? o[k] :
			    ("00"+ o[k]).substr((""+ o[k]).length));
  return format;
}


function epoch2Seen(epoch) {
  /* 08/01/13 15:12:37 [18 min, 13 sec ago] */
  var d = new Date(epoch*1000);
  var tdiff = Math.floor(((new Date()).getTime()/1000)-epoch);

  return(d.format("dd/MM/yyyy hh:mm:ss")+" ["+secondsToTime(tdiff)+" ago]");
}

var footerRefresh = function() {
    $.ajax({
      type: 'GET',
	  url: ']]
print (ntop.getHttpPrefix())
print [[/lua/network_load.lua',
	  data: { },
	  /* error: function(content) { alert("JSON Error (session expired?): logging out"); window.location.replace("]]
print (ntop.getHttpPrefix())
print [[/lua/logout.lua");  }, */
	  success: function(rsp) {
    
	  try {

	    if (prev_bytes > 0) {
	      if (rsp.packets < prev_packets) {
	        prev_bytes   = rsp.bytes;
	        prev_packets = rsp.packets;
	        prev_local   = rsp.local2remote;
	        prev_remote  = rsp.remote2local;
	      }

              var values = updatingChart_local2remote.text().split(",")
	      var values1 = updatingChart_remote2local.text().split(",")
	      var bytes_diff   = Math.max(rsp.bytes-prev_bytes, 0);
	      var packets_diff = Math.max(rsp.packets-prev_packets, 0);
	      var local_diff   = Math.max(rsp.local2remote-prev_local, 0);
	      var remote_diff  = Math.max(rsp.remote2local-prev_remote, 0);
	      var epoch_diff   = Math.max(rsp.epoch - prev_epoch, 0);

	      if(epoch_diff > 0) {
		if(bytes_diff > 0) {
		   var v = local_diff-remote_diff;
		   var v_label;

		  values.shift();
		  values.push(local_diff);
		  updatingChart_local2remote.text(values.join(",")).change();
		  values1.shift();
		  values1.push(-remote_diff);
		  updatingChart_remote2local.text(values1.join(",")).change();
		}

		var pps = Math.floor(packets_diff / epoch_diff);
		var bps = Math.round((bytes_diff*8) / epoch_diff );
		var bps_local2remote = Math.round((local_diff*8) / epoch_diff);
		var bps_remote2local = Math.round((remote_diff*8) / epoch_diff);

		/* don't use the remote_{b,p}ps values to update the gauge
                if(rsp.remote_pps != 0)  { pps = Math.max(rsp.remote_pps, 0); }
                if(rsp.remote_bps != 0)  { bps = Math.max(rsp.remote_bps, 0); }
		*/
]]

   if interface.isPcapDumpInterface() == false then
      print[[

		$('#gauge_text_allTraffic').html(bitsToSize(bps, 1000) + " [" + addCommas(pps) + " pps]");
		$('#chart-local2remote-text').html("&nbsp;"+bitsToSize(bps_local2remote, 1000));
		$('#chart-remote2local-text').html("&nbsp;"+bitsToSize(bps_remote2local, 1000));
		var v = Math.round(Math.min((bps*100)/]] print(maxSpeed) print[[, 100));
		$('#networkload').css("width", v+"%")
		$('#networkload').html(v+"%");

	    } else {
	      /* $('#network-load').html("[No traffic (yet)]"); */
	    }

]]

   end

print[[
	      } /* closes if (prev_bytes > 0) */
		var msg = "&nbsp;<i class=\"fa fa-clock-o\"></i> <small>"+rsp.localtime+" | Uptime: "+rsp.uptime+"</small><br>";

		if(rsp.alerts > 0 || rsp.engaged_alerts > 0) {
		   msg += "&nbsp;<a href=]]
print (ntop.getHttpPrefix())
print [[/lua/show_alerts.lua><i class=\"fa fa-warning\" style=\"color: #B94A48;\"></i>"

		   if(rsp.engaged_alerts > 0) {
		      msg += "&nbsp;<span class=\"label label-danger\">"+addCommas(rsp.engaged_alerts)+" Engaged Alert";
		      if(rsp.engaged_alerts > 1) msg += "s";
                      msg += "</span>";
		   }

                   if(rsp.alerts > 0) {
		     msg += "&nbsp;<span class=\"label label-danger\">"+addCommas(rsp.alerts)+" Alert";
		     if(rsp.alerts > 1) msg += "s";
		     msg += "</span>";
		}

                   msg += "</A>&nbsp;"
                }

		var alarm_threshold_low = 60;  /* 60% */
		var alarm_threshold_high = 90; /* 90% */
		var alert = 0;    
            
            msg += "<a href=]]
print (ntop.getHttpPrefix())
print [[/lua/hosts_stats.lua>";
		if(rsp.hosts_pctg < alarm_threshold_low) {
		  msg += "<span class=\"label label-default\">";
		} else if(rsp.hosts_pctg < alarm_threshold_high) {
		  alert = 1;
		  msg += "<span class=\"label label-warning\">";
		} else {
		  alert = 1;
		  msg += "<span class=\"label label-danger\">";
		}

		msg += addCommas(rsp.num_hosts)+" Hosts</span></a> ";

            msg += "<a href=]]
print (ntop.getHttpPrefix())
print [[/lua/mac_stats.lua>";
		  msg += "<span class=\"label label-default\">";
		msg += addCommas(rsp.num_devices)+" Devices</span></a> ";

    msg += "<a href=]]
print (ntop.getHttpPrefix())
print [[/lua/flows_stats.lua>";
		if(rsp.flows_pctg < alarm_threshold_low) {
		  msg += "<span class=\"label label-default\">";
		} else if(rsp.flows_pctg < alarm_threshold_high) {
		   alert = 1;
		  msg += "<span class=\"label label-warning\">";
		} else {
		   alert = 1;
		  msg += "<span class=\"label label-danger\">";
		}

		msg += addCommas(rsp.num_flows)+" Flows </span> </a>";

		if(rsp.flow_export_drops > 0) {
		   msg += "&nbsp;<a href=]]
print (ntop.getHttpPrefix())
print [[/lua/if_stats.lua><i class=\"fa fa-warning\" style=\"color: #B94A48;\"></i> <span class=\"label label-danger\">"+addCommas(rsp.flow_export_drops)+" Dropped flow";
		   if(rsp.flow_export_drops > 1) msg += "s";

		   msg += "</span></A> ";
		}

		$('#network-load').html(msg);


		if(alert) {
		   $('#toomany').html("<div class='alert alert-warning'><h4>Warning</h4>You have too many hosts/flows for your ntopng configuration and this will lead to packet drops and high CPU load. Please restart ntopng increasing -x and -X.</div>");
		}

	    prev_bytes   = rsp.bytes;
	    prev_packets = rsp.packets;
            prev_local   = rsp.local2remote;
            prev_remote  = rsp.remote2local;
	    prev_epoch   = rsp.epoch;

	  } catch(e) {
	     console.log(e);
	     /* alert("JSON Error (session expired?): logging out"); window.location.replace("]]
print (ntop.getHttpPrefix())
print [[/lua/logout.lua");  */
	  }
	}
      });
}

footerRefresh();  /* call immediately to give the UI a more responsive look */
setInterval(footerRefresh, 3000);  /* re-schedule every three seconds */

//Enable tooltip without a fixer placement
$(document).ready(function () { $("[rel='tooltip']").tooltip(); });
$(document).ready(function () { $("a").tooltip({ 'selector': ''});});
$(document).ready(function () { $("i").tooltip({ 'selector': ''});});

//Automatically open dropdown-menu
$(document).ready(function(){
    $('ul.nav li.dropdown').hover(function() {
      $(this).find('.dropdown-menu').stop(true, true).delay(150).fadeIn(100);
    }, function() {
      $(this).find('.dropdown-menu').stop(true, true).delay(150).fadeOut(100);
    });
});

// hide the possibly shown alerts icon in the header
]]
if ntop.getPrefs().are_alerts_enabled == false then
   print("$('#alerts-li').hide();")
else
   print("$('#alerts-li').show();")
end
print[[
</script>

    </div> <!-- / header main container -->

  </body>
</html> ]]
