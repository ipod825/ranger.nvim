local M = {}
local utils = require("ranger.action.utils")
local vimfn = require("libp.utils.vimfn")
local Set = require("libp.datatype.Set")

local managed_buffers = Set()

function M.toggle_select()
	local buffer, _ = utils.get_cur_buffer_and_node()
	Set.add(managed_buffers, buffer)
	buffer.selected_nodes = buffer.selected_nodes or Set()
	local b, e = vimfn.visual_rows()

	for i = b, e do
		local node = buffer:nodes(i)
		if Set.has(buffer.selected_nodes, node) then
			Set.remove(buffer.selected_nodes, node)
			node:unset_temporary_hl()
		else
			Set.add(buffer.selected_nodes, node)
			node:set_temporary_hl("RangerSelected")
		end
	end
	buffer:redraw()
	vimfn.ensure_exit_visual_mode()
end

function M.cut_selected()
	for buffer in Set.values(managed_buffers) do
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

function M.copy_selected()
	for buffer in Set.values(managed_buffers) do
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

function M.cut_current()
	local buffer, node = utils.get_cur_buffer_and_node()
	Set.add(managed_buffers, buffer)
	buffer.cut_nodes = buffer.cut_nodes or Set()
	Set.add(buffer.cut_nodes, node)
	node:set_temporary_hl("RangerCut")
	buffer:redraw()
end

return M
