local M = {
	utils = require("ranger.action.utils"),
	transfer = require("ranger.action.transfer"),
}
local Buffer = require("ranger.Buffer")
local vimfn = require("libp.utils.vimfn")
local path = require("libp.path")

function M.toggle_expand()
	local buffer, node = M.utils.get_cur_buffer_and_node()
	if node.type ~= "directory" then
		return
	end

	if node.is_expanded then
		node:remove_all_children()
		node.is_expanded = false
	else
		buffer:add_dir_node_children(node)
		node.is_expanded = true
	end
	buffer:redraw()
end

function M.goto_parent()
	local buffer, _ = M.utils.get_cur_buffer_and_node()
	if path.dirname(buffer.directory) == buffer.directory then
		return
	end
	local new_buffer = Buffer.open(path.dirname(buffer.directory), { open_cmd = "edit" })
	local target_name = path.basename(buffer.directory)
	for i, new_node in ipairs(new_buffer:nodes()) do
		if new_node.name == target_name then
			if vim.api.nvim_get_current_buf() == new_buffer.id then
				vimfn.setrow(i)
			end
			break
		end
	end
end

function M.open(open_cmd)
	vim.validate({ open_cmd = { open_cmd, "s", true } })
	open_cmd = open_cmd or "edit"
	local buffer, node = M.utils.get_cur_buffer_and_node()
	if node.type == "directory" then
		Buffer.open(path.join(buffer.directory, node.name), { open_cmd = open_cmd })
	else
		vim.cmd(("%s %s"):format(open_cmd, node.abspath))
	end
end

return M
