local M = {}
local reflection = require("libp.debug.reflection")
local pathfn = require("libp.utils.pathfn")

M.config_dir = pathfn.join(reflection.script_dir(), "..", "..", "config")
M.default_rifle_conf = pathfn.join(M.config_dir, "rifle.conf")

return M
