--
-- (C) 2019-20 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path
local ts_utils = require "ts_utils_core"
require "ts_5sec"
local system_utils = require "system_utils"
local ts_dump = require "ts_5sec_dump_utils"
local when = os.time()

-- ########################################################

system_utils.compute_cpu_states()
ts_dump.dump_cpu_states(interface.getId(), when, system_utils.get_cpu_states())

-- ########################################################

