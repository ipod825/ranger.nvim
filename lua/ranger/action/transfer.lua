local M = {}
local utils = require("ranger.action.utils")
local vimfn = require("libp.utils.vimfn")
local Set = require("libp.datatype.Set")
local path = require("libp.path")
local a = require("plenary.async")
local uv = require("libp.fs.uv")
local fs = require("libp.fs")
local NodeStateController = require("ranger.NodeStateController")

local State = { NORMAL = 1, SELECTED = 2, CUT = 3, COPIED = 4 }
local transfer_controller_key = {}
local managed_buffers = {
	[State.SELECTED] = Set(),
	[State.CUT] = Set(),
	[State.COPIED] = Set(),
}

local function build_state_controller()
	return NodeStateController({
		[State.NORMAL] = {
			is_fallback_state = true,
			set = function(node)
				node:unset_temporary_hl("RangerSelected")
			end,
		},
		[State.SELECTED] = {
			set = function(node)
				node:set_temporary_hl("RangerSelected")
			end,
		},
		[State.CUT] = {
			set = function(node)
				node:set_temporary_hl("RangerCut")
			end,
		},
		[State.COPIED] = {
			set = function(node)
				node:set_temporary_hl("RangerCopied")
			end,
		},
	})
end

local function maybe_recycle_managed_buffers(buffer, state)
	if not vim.api.nvim_buf_is_valid(buffer.id) or Set.empty(buffer[transfer_controller_key]:get(state)) then
		Set.remove(managed_buffers[state], buffer)
		return
	end
	return buffer[transfer_controller_key]
end

local function add_managed_buffer(buffer, state)
	Set.add(managed_buffers[state], buffer)
	buffer[transfer_controller_key] = buffer[transfer_controller_key] or build_state_controller()
	return buffer[transfer_controller_key]
end

function M.toggle_select()
	local buffer = utils.get_cur_buffer_and_node()
	local controller = add_managed_buffer(buffer, State.SELECTED)

	local b, e = vimfn.visual_rows()
	for i = b, e do
		local node = buffer:nodes(i)
		if node.type ~= "header" then
			if controller:is(node, State.SELECTED) then
				controller:set(node, State.NORMAL)
			elseif controller:is(node, State.NORMAL) then
				controller:set(node, State.SELECTED)
			end
		end
	end
	maybe_recycle_managed_buffers(buffer, State.SELECTED)

	buffer:draw()
	vimfn.ensure_exit_visual_mode()
end

function M._nodes_of_state(state)
	return coroutine.wrap(function()
		for buffer in Set.values(managed_buffers[state]) do
			local controller = maybe_recycle_managed_buffers(buffer, state)
			if controller then
				for node in Set.values(controller:get(state)) do
					if not node.invalid then
						coroutine.yield(buffer, controller, node)
					end
				end
				coroutine.yield(buffer)
			end
		end
	end)
end

function M.selected_nodes()
	return M._nodes_of_state(State.SELECTED)
end

function M.cut_nodes()
	return M._nodes_of_state(State.CUT)
end

function M.copied_nodes()
	return M._nodes_of_state(State.COPIED)
end

function M.unselect_node(node, controller)
	controller:set(node, State.NORMAL)
end

function M.cut_selected()
	for buffer, controller, node in M.selected_nodes() do
		if node then
			controller:set(node, State.CUT)
		else
			add_managed_buffer(buffer, State.CUT)
			buffer:draw()
		end
		maybe_recycle_managed_buffers(buffer, State.SELECTED)
	end
end

function M.copy_selected()
	for buffer, controller, node in M.selected_nodes() do
		if node then
			controller:set(node, State.COPIED)
		else
			add_managed_buffer(buffer, State.COPY)
			buffer:draw()
		end
		maybe_recycle_managed_buffers(buffer, State.SELECTED)
	end
end

function M.cut_current()
	local buffer, node = utils.get_cur_buffer_and_node()
	if node.type == "header" then
		return
	end
	local controller = add_managed_buffer(buffer, State.CUT)
	if controller:is(node, State.NORMAL) or controller:is(node, State.SELECTED) then
		controller:set(node, State.CUT)
	end
	buffer:draw()
end

function M.copy_current()
	local buffer, node = utils.get_cur_buffer_and_node()
	if node.type == "header" then
		return
	end
	local controller = add_managed_buffer(buffer, State.COPIED)
	if controller:is(node, State.NORMAL) or controller:is(node, State.SELECTED) then
		controller:set(node, State.COPIED)
	end
	buffer:draw()
end

function M.paste()
	local cur_buffer = utils.get_cur_buffer_and_node()
	cur_buffer:disable_fs_event_watcher()

	local errors = {}
	local dest_dir = vim.fn.getcwd()
	for buffer, controller, node in M.copied_nodes() do
		if node then
			local _, err = fs.copy(node.abspath, path.join(dest_dir, node.name), { excl = true, ficlone = true })
			a.util.scheduler()
			if err then
				table.insert(errors, err)
			end
			controller:set(node, State.NORMAL)
		else
			maybe_recycle_managed_buffers(buffer, State.COPIED)
			if buffer ~= cur_buffer then
				buffer:draw()
			end
		end
	end

	for buffer, controller, node in M.cut_nodes() do
		buffer:disable_fs_event_watcher()
		if node then
			local _, err = uv.fs_rename(node.abspath, path.join(dest_dir, node.name))
			a.util.scheduler()
			if err then
				table.insert(errors, err)
			end
			controller:set(node, State.NORMAL)
		else
			maybe_recycle_managed_buffers(buffer, State.CUT)
			if buffer ~= cur_buffer then
				buffer:rebuild_nodes()
				buffer:draw()
				buffer:enable_fs_event_watcher()
			end
		end
	end

	cur_buffer:enable_fs_event_watcher()
	cur_buffer:rebuild_nodes()
	cur_buffer:draw()
	if #errors > 0 then
		vim.notify(table.concat(errors, "\n"), vim.log.levels.WARN)
	end
end

return M
