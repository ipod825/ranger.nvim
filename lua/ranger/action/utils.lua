local M = {}
local Buffer = require("ranger.Buffer")
local vimfn = require("libp.utils.vimfn")

function M.get_cur_buffer_and_node()
	local buffer = Buffer.get_current_buffer()
	assert(buffer)
	local cur_row = vimfn.getrow()
	return buffer, buffer:nodes(cur_row)
end

return M
