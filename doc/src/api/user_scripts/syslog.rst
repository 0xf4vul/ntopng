Syslog Scripts
##############

Syslog scripts are used to handle syslog events and ingest data, including alerts,
from external sources (alerts from Intrusion Detection Systems is an example).

Scripts Location
----------------

Syslog scripts are located under `/usr/share/ntopng/scripts/callbacks/syslog` and
should use the source name (e.g. application name) with the `.lua` extension as
file name. In fact messages demultiplexing is implemented by using the source name 
for matching the script name. For example, log messages coming from `suricata` will 
be delivered to the `/usr/share/ntopng/scripts/callbacks/syslog/suricata.lua` script.

Script API
----------

A syslog module shoule implement the below functions:

 - `setup` (optional) which is called once to initialize the module.
 - `teardown` (optional) which is called once to terminate the module.
 - `handleEvent` which is called for each log message received from Suricata.

Script Example
--------------

Here is a sample script `suricata.lua` processing alerts from Suricata, exported
to syslog in JSON format.

.. code:: lua

   local dirs = ntop.getDirs()
   package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
   require "lua_utils"
   local json = require ("dkjson")
   
   local syslog_module = {}
   
   -- The function below is called once to initialize the script
   function syslog_module.setup()
      return true
   end
   
   -- The function below is called for each log message received from Suricata
   function syslog_module.handleEvent(message)
      local alert = json.decode(message)
      tprint(alert)
   end 
   
   -- The function below is called once to terminate the script
   function syslog_module.teardown()
      return true
   end
   
   return syslog_module


