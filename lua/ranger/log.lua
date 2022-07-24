local global = require("ranger.global")

global.logger = global.logger or require("libp.debug.logger")({ log_file = "ranger.log" })

return global.logger
