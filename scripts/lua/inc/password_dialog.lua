
print [[

 <style type='text/css'>
.largegroup {
    width:500px
}
</style>
<div id="password_dialog" class="modal fade" tabindex="-1" role="dialog" aria-labelledby="password_dialog_label" aria-hidden="true">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header">
  <button type="button" class="close" data-dismiss="modal" aria-hidden="true"><i class="fa fa-times"></i></button>
  <h3 id="password_dialog_label">Manage User <span id="password_dialog_title"></span></h3>
</div>

<div class="modal-body">

  <div class="tabbable"> <!-- Only required for left/right tabs -->
  <ul class="nav nav-tabs" role="tablist" id="edit-user-container">
    <li class="active"><a href="#change-password-dialog" role="tab" data-toggle="tab"> Password </a></li>
]]

local captive_portal_user = false
if is_captive_portal_active and _GET["captive_portal_users"] ~= nil then
   captive_portal_user = true
end

if(user_group=="administrator" and not captive_portal_user) then
   print[[<li><a href="#change-prefs-dialog" role="tab" data-toggle="tab"> Preferences </a></li>]]
end
   print[[
  </ul>
  <div class="tab-content">
  <div class="tab-pane active" id="change-password-dialog">

  <div id="password_alert_placeholder"></div>

<script>
  password_alert = function() {}
  password_alert.error   = function(message) { $('#password_alert_placeholder').html('<div class="alert alert-danger"><button type="button" class="close" data-dismiss="alert">x</button>' + message + '</div>');  }
  password_alert.success = function(message) { $('#password_alert_placeholder').html('<div class="alert alert-success"><button type="button" class="close" data-dismiss="alert">x</button>' + message + '</div>'); }
</script>

  <form data-toggle="validator" id="form_password_reset" class="form-inline" method="post" action="]] print(ntop.getHttpPrefix()) print[[/lua/admin/password_reset.lua">
]]
print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
print [[
    <input id="password_dialog_username" type="hidden" name="username" value="" />

<div class="control-group">
   ]]

local user_group = ntop.getUserGroup()
local col_md_size = "6"

print('<br><div class="row">')

if(user_group ~= "administrator") then
   col_md_size = "4"
print [[
  <div class='form-group col-md-]] print(col_md_size) print[[ has-feedback'>
      <label for="" class="control-label">Old Password</label>
      <div class="input-group"><span class="input-group-addon"><i class="fa fa-lock"></i></span>
        <input id="old_password_input" type="password" name="old_password" value="" class="form-control" required>
      </div>
  </div>
   ]]
end

print [[
  <div class='form-group has-feedback col-md-]] print(col_md_size) print[['>
      <label for="" class="control-label">New Password</label>
      <div class="input-group"><span class="input-group-addon"><i class="fa fa-lock"></i></span>
        <input id="new_password_input" type="password" name="new_password" value="" class="form-control" pattern="^[\w\$\\!\/\(\)=\?\^\*@_\-\u0000-\u00ff]{1,}" required>
      </div>
  </div>

  <div class='form-group has-feedback col-md-]] print(col_md_size) print[['>
      <label for="" class="control-label">Confirm New Password</label>
      <div class="input-group"><span class="input-group-addon"><i class="fa fa-lock"></i></span>
        <input id="confirm_new_password_input" type="password" name="confirm_new_password" value="" class="form-control" pattern="^[\w\$\\!\/\(\)=\?\^\*@_\-\u0000-\u00ff]{1,}" required>
      </div>
  </div>
</div>

<div><small>Allowed characters are ISO 8895-1 (latin1) upper and lower case letters, numbers and special symbols.  </small></div>

<br>

<div class="row">
    <div class="form-group col-md-12 has-feedback">
      <button id="password_reset_submit" class="btn btn-primary btn-block">Change User Password</button>
    </div>
</div>

</form>
</div> <!-- closes div "change-password-dialog" -->
]]

if(user_group=="administrator") then

print [[
</div>
<div class="tab-pane" id="change-prefs-dialog">

  <form data-toggle="validator" id="form_pref_change" class="form-inline" method="post" action="]] print(ntop.getHttpPrefix()) print[[/lua/admin/change_user_prefs.lua">]]
print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
print [[
  <input id="pref_dialog_username" type="hidden" name="username" value="" />

<br>

<div class="row">
  <div class='col-md-6 form-group has-feedback'>
      <label class="input-label">User Role</label>
      <div class="input-group" style="width:100%;">
        <select id="host_role_select" name="host_role" class="form-control">
          <option value="unprivileged">Non Privileged User</option>
          <option value="administrator">Administrator</option>
        </select>
      </div>
  </div>

  <div class='col-md-6 form-group has-feedback'>
      <label class="form-label">Allowed Interface</label>
      <div class="input-group" style="width:100%;">
        <select name="allowed_interface" id="allowed_interface" class="form-control">
          <option value="">Any Interface</option>
]]
for _, interface_name in pairsByValues(interface.getIfNames(), asc) do
   -- io.write(interface_name.."\n")
   print('<option value="'..getInterfaceId(interface_name)..'"> '..interface_name..'</option>')
end
print[[
        </select>
    </div>
  </div>
</div>

<br>

<div class="row">
    <div class="form-group col-md-12 has-feedback">
      <label class="control-label">Allowed Networks</label>
      <div class="input-group"><span class="input-group-addon"><span class="glyphicon glyphicon-tasks"></span></span>
        <input id="networks_input" type="text" name="networks" value="" class="form-control" required>
      </div>
      <small>Comma separated list of networks this user can view. Example: 192.168.1.0/24,172.16.0.0/16</small>
    </div>
</div>

<br>

<div class="row">
    <div class="form-group col-md-12 has-feedback">
      <button id="pref_change" class="btn btn-primary btn-block">Change User Preferences</button>
    </div>
</div>

<br>

  </form>
</div> <!-- closes div "change-prefs-dialog" -->
]]
end

print [[<script>
  function isValid(str) { /* return /^[\w%]+$/.test(str); */ return true; }
  function isValidPassword(str) { return /^[\w\$\\!\/\(\)=\?\^\*@_\-^\u0000-\u00ff]{1,}$/.test(str); }

  var frmpassreset = $('#form_password_reset');
  frmpassreset.submit(function () {
    if(!isValidPassword($("#new_password_input").val())) {
      password_alert.error("Password contains invalid chars. Please use valid ISO8895-1 (latin1) letters and numbers."); return(false);
    }
    if($("#new_password_input").val().length < 5) {
      password_alert.error("Password too short (< 5 characters)"); return(false);
    }
    if($("#new_password_input").val() != $("#confirm_new_password_input").val()) {
      password_alert.error("Passwords don't match"); return(false);
    }

    // escape characters to send out valid latin-1 encoded characters
    $('#old_password_input').val(escape($('#old_password_input').val()))
    $('#new_password_input').val(escape($('#new_password_input').val()))
    $('#confirm_new_password_input').val(escape($('#confirm_new_password_input').val()))

    $.ajax({
      type: frmpassreset.attr('method'),
      url: frmpassreset.attr('action'),
      data: frmpassreset.serialize(),
      success: function (data) {

        var response = jQuery.parseJSON(data);
        if(response.result == 0) {
          password_alert.success(response.message);
   	  // window.location.href = 'users.lua';
          window.location.href = window.location.href;

       } else
          password_alert.error(response.message);
    ]]

if(user_group ~= "administrator") then
   print('$("old_password_input").text("");\n');
end

print [[
        $("new_password_input").text("");
        $("confirm_new_password_input").text("");
      }
    });
    return false;
  });

  var frmprefchange = $('#form_pref_change');

  frmprefchange.submit(function () {
  var ok = true;

  if($("#networks_input").val().length == 0) {
     password_alert.error("Network list not specified");
     ok = false;
  } else {
     var arrayOfStrings = $("#networks_input").val().split(",");

     for (var i=0; i < arrayOfStrings.length; i++) {
	if(!is_network_mask(arrayOfStrings[i])) {
	   password_alert.error("Invalid network list specified ("+arrayOfStrings[i]+")");
	   ok = false;
	}
     }
  }

  if(ok) {
    $.ajax({
      type: frmprefchange.attr('method'),
      url: frmprefchange.attr('action'),
      data: frmprefchange.serialize(),
      success: function (response) {
        if(response.result == 0) {
          password_alert.success(response.message);
          window.location.href= window.location.href;
       } else
          password_alert.error(response.message);
      }
    });
   }

    return false;   
   });
</script>

</div> <!-- closes "tab-content" -->
</div> <!-- closes "tabbable" -->
</div> <!-- modal-body -->

<script>

function reset_pwd_dialog(user) {
      $.getJSON(']] print(ntop.getHttpPrefix()) print[[/lua/admin/get_user_info.lua?user='+user, function(data) {
      $('#password_dialog_title').text(data.username);
      $('#password_dialog_username').val(data.username);
      $('#pref_dialog_username').val(data.username);
      $('#old_password_input').val('');
      $('#new_password_input').val('');
      $('#confirm_password_input').val('');
      $('#host_role_select option[value = '+data.group+']').attr('selected','selected');
      $('#networks_input').val(data.allowed_nets);
      $('#allowed_interface option').filter(function () {
        return $(this).html().trim() == data.allowed_ifname;
      }).attr('selected','selected');
      // $('#allowed_interface option[value = "'+data.allowed_ifname+'"]').attr('selected','selected');
      $('#form_pref_change').show();
      $('#pref_part_separator').show();
      $('#password_alert_placeholder').html('');
      $('#add_user_alert_placeholder').html('');
    });

      return(true);
}

/*
$('#password_reset_submit').click(function() {
  $('#form_password_reset').submit();
});
*/
</script>

</div>
</div>
</div>
</div> <!-- password_dialog -->

			    ]]

