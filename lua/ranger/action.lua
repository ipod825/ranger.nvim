local M = {}
local Buffer = require("ranger.Buffer")
local vimfn = require("libp.utils.vimfn")
local path = require("libp.path")
local Set = require("libp.datatype.Set")

function M.get_cur_buffer_and_node()
	local buffer = Buffer.get_current_buffer()
	assert(buffer)
	local cur_row = vimfn.current_row()
	return buffer, buffer:nodes(cur_row)
end

function M.toggle_expand()
	local buffer, node = M.get_cur_buffer_and_node()
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
	local buffer, _ = M.get_cur_buffer_and_node()
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
	local buffer, node = M.get_cur_buffer_and_node()
	if node.type == "directory" then
		Buffer.open(path.join(buffer.directory, node.name), { open_cmd = open_cmd })
	else
		vim.cmd(("%s %s"):format(open_cmd, node.abspath))
	end
end

function M.toggle_select()
	local buffer, node = M.get_cur_buffer_and_node()
	local global = require("ranger.global")
	global.managed_buffers = global.managed_buffers or Set()
	Set.add(global.managed_buffers, buffer)
	buffer.selected_nodes = buffer.selected_nodes or Set()
	if Set.has(buffer.selected_nodes, node) then
		Set.remove(buffer.selected_nodes, node)
		node:unset_temporary_hl()
	else
		Set.add(buffer.selected_nodes, node)
		node:set_temporary_hl("RangerSelected")
	end
	buffer:clear_hl(vimfn.current_row())
	buffer:set_row_hl(vimfn.current_row())
end

function M.cut_selected_path()
	local global = require("ranger.global")
	global.managed_buffers = global.managed_buffers or Set()
	for buffer in Set.values(global.managed_buffers) do
		if vim.api.nvim_buf_is_valid(buffer.id) then
			buffer.cut_nodes = buffer.cut_nodes or Set()
			for node in Set.values(buffer.selected_nodes) do
				Set.remove(buffer.selected_nodes, node)
				Set.add(buffer.cut_nodes, node)
				node:set_temporary_hl("RangerCut")
			end
			buffer:redraw()
		end
	end
end

function M.copy_selected_path()
	require("libp.log").warn("copy_selected_path")
	local global = require("ranger.global")
	global.managed_buffers = global.managed_buffers or Set()
	for buffer in Set.values(global.managed_buffers) do
		if vim.api.nvim_buf_is_valid(buffer.id) then
			buffer.copied_nodes = buffer.copied_nodes or Set()
			for node in Set.values(buffer.selected_nodes) do
				Set.remove(buffer.selected_nodes, node)
				Set.add(buffer.copied_nodes, node)
				node:set_temporary_hl("RangerCopied")
			end
			buffer:redraw()
		end
	end
end

function M.cut_node()
	local buffer, node = M.get_cur_buffer_and_node()
	local global = require("ranger.global")
	global.managed_buffers = global.managed_buffers or Set()
	Set.add(global.managed_buffers, buffer)
	buffer.cut_nodes = buffer.cut_nodes or Set()
	Set.add(buffer.cut_nodes, node)
	node:set_temporary_hl("RangerCut")
	buffer:clear_hl(vimfn.current_row())
	buffer:set_row_hl(vimfn.current_row())
end

return M
