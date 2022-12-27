local M = {}
local utils = require("ranger.action.utils")
local transfer = require("ranger.action.transfer")
local pathfn = require("libp.utils.pathfn")
local Stack = require("libp.datatype.Stack")
local vimfn = require("libp.utils.vimfn")
local a = require("plenary.async")
local fs = require("libp.fs")
local uv = require("libp.fs.uv")
local List = require("libp.datatype.List")

local trash_dir = pathfn.join(vim.fn.stdpath("cache"), "ranger_trash")

vim.api.nvim_create_autocmd("VimEnter", {
	group = vim.api.nvim_create_augroup("ranger_trash_vimenter", {}),
	callback = function()
		a.void(function()
			if fs.is_directory(trash_dir) then
				local _, err = fs.rmdir(trash_dir)
				if err then
					vimfn.error(err)
				end
			end
			fs.mkdir(trash_dir)
		end)()
	end,
})

M._history = Stack()

local function cross_device_rename(src, dst)
	local _, err = uv.fs_rename(src, dst)
	if err then
		_, err = fs.copy(src, dst)
		if err then
			return nil, err
		end
		_, err = fs.rm(src)
		if err then
			return nil, err
		end
	end
	return true
end

function M._trash_single(file_path)
	local trash_path
	local basename = pathfn.basename(file_path)
	repeat
		trash_path = ("%s/%s%s"):format(trash_dir, basename, pathfn.randomAlphaNumerical(10))
	until not fs.is_readable(trash_path)

	local _, err = cross_device_rename(file_path, trash_path)
	if err then
		vimfn.error(err)
		return
	end

	M._history:push({ file_path, trash_path })
end

function M._add_history_separation()
	M._history:push({})
end

function M.trash_current()
	local buffer, node = utils.get_cur_buffer_and_node()
	if node.type == "header" then
		return
	end

	M._add_history_separation()
	M._trash_single(node.abspath)
	buffer:rebuild_nodes()
	buffer:draw()
end

function M.trash_selected()
	local trashed_paths = List()
	for buffer, controller, node in transfer.selected_nodes() do
		if node then
			trashed_paths:append(node.abspath)
			transfer.unselect_node(node, controller)
		else
			buffer:disable_fs_event_watcher()

			M._add_history_separation()
			a.util.join(trashed_paths:map(function(e)
				return a.wrap(function(cb)
					M._trash_single(e)
					cb()
				end, 1)
			end))

			buffer:enable_fs_event_watcher()
			buffer:rebuild_nodes()
			buffer:draw()
		end
	end
end

function M.restore_last()
	local path_tuples = List()
	local path_tuple

	while true do
		path_tuple = M._history:pop()
		if not path_tuple or #path_tuple == 0 then
			break
		end
		path_tuples:append(path_tuple)
	end

	local buffer = utils.get_cur_buffer_and_node()
	buffer:disable_fs_event_watcher()

	a.util.join(path_tuples:map(function(e)
		return a.wrap(function(cb)
			local ori_path, trash_path = unpack(e)
			if not fs.is_directory(pathfn.dirname(ori_path)) then
				vim.fn.mkdir(pathfn.dirname(ori_path), "p")
			end
			cross_device_rename(trash_path, ori_path)
			cb()
		end, 1)
	end))

	buffer:enable_fs_event_watcher()
	buffer:rebuild_nodes()
	buffer:draw()
end

return M
