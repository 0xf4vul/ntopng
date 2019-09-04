--
-- (C) 2019 - ntop.org
--
-- MUD - Manufacturer Usage Description
-- https://tools.ietf.org/id/draft-ietf-opsawg-mud-22.html
--
-- Information stored varies based on the host classification and connection
-- type:
--
-- <General Purpose Host>
--  - Local: <l4_proto, peer_ip, peer_port>
--  - Remote: <l4_proto, l7_proto, fp_type, host_fp>
-- <Special Purpose Host>
--  - Local: <l4_proto, peer_ip, peer_port>
--  - Remote: <l4_proto, l7_proto, fp_type, host_fp, peer_fp, peer_key>
--
-- Items marked with the NTOP_MUD comment are part of the ntop MUD proposal
--

local mud_utils = {}

-- ###########################################

-- @brief Possibly extract fingerprint information for host/peers
-- @return a table {fp_id, host_fp, peer_fp} where fp_id is one of {"", "JA3", "HASSH"}
local function getFingerprints(info, is_client)
   local ja3_cli_hash = info["protos.ssl.ja3.client_hash"]
   local ja3_srv_hash = info["protos.ssl.ja3.server_hash"]

   if(ja3_cli_hash or ja3_srv_hash) then
      if(is_client) then
         return {"JA3", ja3_cli_hash or "", ja3_srv_hash or ""}
      else
         return {"JA3", ja3_srv_hash or "", ja3_cli_hash or ""}
      end
   end

   local hassh_cli_hash = info["protos.ssh.hassh.client_hash"]
   local hassh_srv_hash = info["protos.ssh.hassh.server_hash"]

   if(hassh_cli_hash or hassh_srv_hash) then
      if(is_client) then
         return {"HASSH", hassh_cli_hash or "", hassh_srv_hash or ""}
      else
         return {"HASSH", hassh_srv_hash or "", hassh_cli_hash or ""}
      end
   end

   return {"", "", ""}
end

-- ###########################################

local function local_mud_encode(info, peer_ip, peer_port, is_client)
   return(string.format("%s|%s|%u", info["proto.l4"], peer_ip, peer_port))
end

local function local_mud_decode(value)
   local v = string.split(value, "|")

   return({
      l4proto = v[1],
      peer_ip = v[2],
      peer_port = v[3],
   })
end

-- ###########################################

local function remote_minimal_mud_encode(info, peer_key, peer_port, is_client)
   local l7proto = interface.getnDPIProtoName(info["proto.ndpi_id"])
   local fingerprints = getFingerprints(info, is_client)

   return(string.format("%s|%s|%s|%s", info["proto.l4"], l7proto,
      fingerprints[1], fingerprints[2]))
end

local function remote_minimal_mud_decode(value)
   local v = string.split(value, "|")

   return({
      l4proto = v[1],
      l7proto = v[2],
      fingerprint_type = v[3],
      host_fingerprint = v[4],
   })
end

-- ###########################################

local function remote_full_mud_encode(info, peer_ip, peer_port, is_client)
   local l7proto = interface.getnDPIProtoName(info["proto.ndpi_id"])
   local fingerprints = getFingerprints(info, is_client)

   -- TODO: this can take time, maybe postpone?
   local peer_key = resolveAddress({host = peer_ip})

   return(string.format("%s|%s|%s|%s|%s|%s", info["proto.l4"], l7proto,
      fingerprints[1], fingerprints[2], fingerprints[3], peer_key))
end

local function remote_full_mud_decode(value)
   local v = string.split(value, "|")

   return({
      l4proto = v[1],
      l7proto = v[2],
      fingerprint_type = v[3],
      host_fingerprint = v[4],
      peer_fingerprint = v[5],
      peer_key = v[6],
   })
end

-- ###########################################

mud_utils.mud_types = {
   -- A local MUD describe local-local communications
   ["local"] = {
      redis_key = "ntopng.mud.ifid_%d.local._%s_.%s",
      encode = local_mud_encode,
      decode = local_mud_decode,
   },
   -- A remote_minimal MUD describes local-remote communications and
   -- keeps minimal information about remote peers
   ["remote_minimal"] = {
      redis_key = "ntopng.mud.ifid_%d.remote_minimal._%s_.%s",
      encode = remote_minimal_mud_encode,
      decode = remote_minimal_mud_decode,
   },
   -- A remote_full MUD describes local-remote communications and
   -- keeps complete information about remote peers
   ["remote_full"] = {
      redis_key = "ntopng.mud.ifid_%d.remote_full._%s_.%s",
      encode = remote_full_mud_encode,
      decode = remote_full_mud_decode,
   },
}

-- ###########################################

local function getMudRedisKey(mud_type, ifid, host_key, is_client)
   return(string.format(mud_type.redis_key, ifid, host_key, ternary(is_client, "out", "in")))
end

-- ###########################################

local function handleHostMUD(ifid, info, is_local_connection, is_general_purpose, is_client)
   local l4proto = info["proto.l4"]
   local mud_type
   local host_ip, peer_ip, peer_port

   -- Only support TCP and UDP
   if((l4proto ~= "TCP") and (l4proto ~= "UDP")) then
      return
   end

   if(is_local_connection) then
      mud_type = mud_utils.mud_types["local"]
   elseif(is_general_purpose) then
      mud_type = mud_utils.mud_types["remote_minimal"]
   else
      mud_type = mud_utils.mud_types["remote_full"]
   end

   if is_client then
      host_ip = info["cli.ip"]
      peer_ip = info["srv.ip"]
      peer_port = info["srv.port"]
   else
      host_ip = info["srv.ip"]
      peer_ip = info["cli.ip"]
      peer_port = info["cli.port"]
   end

   -- TODO use MAC address key is this is in LBD
   local mud_key = getMudRedisKey(mud_type, ifid, host_ip, is_client)
   local conn_key = mud_type.encode(info, peer_ip, peer_port, is_client)

   -- Register the connection
   -- TODO add check for disabled recording
   ntop.setMembersCache(mud_key, conn_key)
end

-- ###########################################

-- @brief Possibly generate MUD entries for the flow hosts
-- @param info flow information as returned by Flow::lua
-- @notes This function is called with a LuaC flow context set
function mud_utils.handleFlow(info)
   local ifid = interface.getId()
   local cli_recording = mud_utils.getHostMUDRecordingPref(ifid, info["cli.ip"])
   local srv_recording = mud_utils.getHostMUDRecordingPref(ifid, info["srv.ip"])
   local is_local_connection = flow.isLocal()

   if(cli_recording ~= "disabled") then
      handleHostMUD(ifid, info, is_local_connection, (cli_recording == "general_purpose"), true --[[client]])
   end
   if(srv_recording ~= "disabled") then
      handleHostMUD(ifid, info, is_local_connection, (srv_recording == "general_purpose"), false --[[server]])
   end
end

-- ###########################################

local function getAclMatches(conn, mud_direction)
   -- TODO support IPv6/MAC
   local peer_key = conn.peer_ip or conn.peer_key
   local matches = {}

   matches["ipv4"] = {
      ["protocol"] = string.lower(conn.l4proto),
   }

   if isIPv4(peer_key or "") then
      matches["ipv4"]["destination-ipv4-network"] = string.format("%s/32", peer_key)
   else
      matches["ipv4"]["ietf-acldns:dst-dnsname"] = peer_key
   end

   if(conn.peer_port ~= nil) then
      matches["destination-port"] = {
         ["operator"] = "eq",
         ["port"] = conn.peer_port,
      }
   end

   if(conn.l7proto ~= nil) then
      -- NTOP_MUD
      matches["ndpi_l7"] = {
         ["application"] = string.lower(conn.l7proto),
      }
   end

   if(not isEmptyString(conn.fingerprint_type)) then
      if(conn.fingerprint_type == "JA3") then
         if(not isEmptyString(conn.host_fingerprint)) then
            -- NTOP_MUD
            matches["JA3"] = matches["JA3"] or {}
            matches["JA3"]["source_fingerprint"] = conn.host_fingerprint
         end
         if(not isEmptyString(conn.peer_fingerprint)) then
            -- NTOP_MUD
            matches["JA3"] = matches["JA3"] or {}
            matches["JA3"]["destination_fingerprint"] = conn.peer_fingerprint
         end
      elseif(conn.fingerprint_type == "HASSH") then
         if(not isEmptyString(conn.host_fingerprint)) then
            -- NTOP_MUD
            matches["HASSH"] = matches["HASSH"] or {}
            matches["HASSH"]["source_fingerprint"] = conn.host_fingerprint
         end
         if(not isEmptyString(conn.peer_fingerprint)) then
            -- NTOP_MUD
            matches["HASSH"] = matches["HASSH"] or {}
            matches["HASSH"]["destination_fingerprint"] = conn.peer_fingerprint
         end
      end
   end

   return(matches)
end

-- ###########################################

function mud_utils.getHostMUD(host_key)
   local ifid = interface.getId()
   local is_general_purpose = (mud_utils.getHostMUDRecordingPref(ifid, host_key) == "general_purpose")
   local ifid = interface.getId()
   local mud = {}

   -- TODO IPv6/MAC support
   local mud_host_from = "from-ipv4-"..host_key
   local mud_host_to = "to-ipv4-"..host_key

   -- https://tools.ietf.org/html/rfc8520
   mud["ietf-mud:mud"] = {
      ["mud-version"] = 1,
      -- TODO replace link with ntopng host link (NOTE: *MUST* use HTTPS)
      ["mud-url"] = "https://mud.ntop.org/"..host_key,
      ["last-update"] = os.date("%Y-%m-%dT%H:%M:%S"),
      ["cache-validity"] = 48,
      ["is-supported"] = true,
      ["systeminfo"] = "MUD file for host "..host_key,
      ["from-device-policy"] = {
         ["access-lists"] = {
            ["name"] = mud_host_from
         }
      },
      ["to-device-policy"] = {
         ["access-lists"] = {
            ["access-list"] = {
               ["name"] = mud_host_to
            }
         },
      },
      ["ietf-access-control-list:access-lists"] = {
          ["acl"] = {}
      }
   }

   -- Populate ACL
   local mud_acls = mud["ietf-mud:mud"]["ietf-access-control-list:access-lists"]["acl"]
   local local_mud_type = mud_utils.mud_types["local"]
   local remote_mud_type = ternary(is_general_purpose, mud_utils.mud_types["remote_minimal"], mud_utils.mud_types["remote_full"])

   local directions = {
      {
         mud_direction = "from-device",
         host = mud_host_from,
         local_key = getMudRedisKey(local_mud_type, ifid, host_key, true),
         remote_key = getMudRedisKey(remote_mud_type, ifid, host_key, true),
         id = 0,
      }, {
         mud_direction = "to-device",
         host = mud_host_to,
         local_key = getMudRedisKey(local_mud_type, ifid, host_key, false),
         remote_key = getMudRedisKey(remote_mud_type, ifid, host_key, false),
         id = 1,
      }
   }

   for _, direction in pairs(directions) do
      local direction_aces = {}
      local acl_id = 0

      local local_remote = {
         {
            mud_type = local_mud_type,
            redis_key = direction.local_key,
         }, {
            redis_key = direction.remote_key,
            mud_type = remote_mud_type,
         }
      }

      -- Imposing order to retain acl_id -> rule mapping
      for _, lr in ipairs(local_remote) do
         local mud_type = lr.mud_type

         for _, serialized in pairsByKeys(ntop.getMembersCache(lr.redis_key) or {}) do
            local connection = mud_type.decode(serialized)
            connection.host_key = host_key

            local acl = {
               ["name"] = string.format("%s-%u", direction.host, acl_id),
               ["matches"] = getAclMatches(connection, direction.mud_direction),
               ["actions"] = {
                  ["forwarding"] = "accept",
               }
            }

            acl_id = acl_id + 1
            direction_aces[acl_id] = acl
         end
      end

      -- TODO support IPv6
      mud_acls[#mud_acls + 1] = {
         name = direction.host,
         type = "ipv4-acl-type",
         aces = direction_aces,
      }
   end

   return(mud)
end

-- ###########################################

local function getHostMUDRecordingKey(ifid, host_key)
   return(string.format("ntopng.prefs.iface_%d.mud.recording.%s", ifid, host_key))
end

function mud_utils.getHostMUDRecordingPref(ifid, host_key)
   local rv = ntop.getPref(getHostMUDRecordingKey(ifid, host_key))

   if(not isEmptyString(rv)) then
      return(rv)
   end

   return("disabled")
end

function mud_utils.setHostMUDRecordingPref(ifid, host_key, val)
   ntop.setPref(getHostMUDRecordingKey(ifid, host_key), val)
end

-- ###########################################

function mud_utils.hasRecordedMUD(ifid, host_key)
   local pattern = string.format("ntopng.mud.ifid_%d.*._%s_*", ifid, host_key)
   return(table.len(ntop.getKeysCache(pattern)) > 0)
end

-- ###########################################

return mud_utils
