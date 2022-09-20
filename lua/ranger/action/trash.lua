local M = {}
local utils = require("ranger.action.utils")
local transfer = require("ranger.action.transfer")
local pathfn = require("libp.utils.pathfn")
local Set = require("libp.datatype.Set")
local Job = require("libp.Job")

local gio_available = vim.fn.executable("gio")
if gio_available then
	Job({ cmd = "gio trash --empty" }):start()
end

local trash_cmd = function(abspath)
	return gio_available and ('gio trash "%s"'):format(abspath) or ('rm "%s"'):format(abspath)
end

M._history = {}

function M.trash_current()
	local buffer, node = utils.get_cur_buffer_and_node()
	local code = Job({ cmd = trash_cmd(node.abspath) }):start()
	if code == 0 then
		table.insert(M._history, { node.abspath })
	end
	buffer:rebuild_nodes()
	buffer:draw()
end

function M.trash_selected()
	local cmds = {}
	local trashed_paths = {}
	for buffer, controller, node in transfer.selected_nodes() do
		if node then
			table.insert(cmds, trash_cmd(node.abspath))
			table.insert(trashed_paths, node.abspath)
			transfer.unselect_node(node, controller)
		else
			buffer:disable_fs_event_watcher()
			local codes = Job.start_all(cmds)
			local new_history = {}
			for i, code in ipairs(codes) do
				if code[1] == 0 then
					table.insert(new_history, trashed_paths[i])
				end
			end
			if #new_history > 0 then
				table.insert(M._history, new_history)
			end
			trashed_paths = {}
			buffer:enable_fs_event_watcher()
			buffer:rebuild_nodes()
			buffer:draw()
		end
	end
end

function M.restore_last()
	if not gio_available then
		vim.notify("Command gio not found!", vim.log.levels.WARN)
		return
	end
	local restore_paths = table.remove(M._history, #M._history)
	if not restore_paths then
		return
	end
	restore_paths = Set(restore_paths)

	local lines = Job({ cmd = { "gio", "trash", "--list" } }):stdoutput()
	local file_version = {}
	for abspath in Set.values(restore_paths) do
		file_version[abspath] = 1
	end

	for _, line in ipairs(lines) do
		local gio_file, ori_path = unpack(vim.split(line, "\t"))
		if Set.has(restore_paths, ori_path) then
			local version = tonumber(gio_file:find_pattern("(%d*)$")) or 1
			file_version[ori_path] = math.max(file_version[ori_path], version)
		end
	end

	local cmds = {}
	for abspath in Set.values(restore_paths) do
		if file_version[abspath] == 1 then
			table.insert(cmds, { "gio", "trash", "--restore", "trash:///" .. pathfn.basename(abspath) })
		else
			table.insert(cmds, {
				"gio",
				"trash",
				"--restore",
				("trash:///%s.%d"):format(pathfn.basename(abspath), file_version[abspath]),
			})
		end
	end
	local buffer = utils.get_cur_buffer_and_node()
	buffer:enable_fs_event_watcher()
	Job.start_all(cmds)
	buffer:enable_fs_event_watcher()
	buffer:rebuild_nodes()
	buffer:draw()
end

return M
