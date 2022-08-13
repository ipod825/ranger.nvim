local M = {}
local reflection = require("libp.debug.reflection")
local path = require("libp.path")

M.config_dir = path.join(reflection.script_dir(), "..", "..", "config")
M.default_rifle_conf = path.join(M.config_dir, "rifle.conf")

return M
