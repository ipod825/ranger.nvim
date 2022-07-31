local M = {
	utils = require("ranger.action.utils"),
	transfer = require("ranger.action.transfer"),
	trash = require("ranger.action.trash"),
}
local Buffer = require("ranger.Buffer")
local vimfn = require("libp.utils.vimfn")
local path = require("libp.path")
local Stack = require("libp.datatype.Stack")
local a = require("plenary.async")

function M.toggle_expand()
	local buffer, node = M.utils.get_cur_buffer_and_node()
	buffer:toggle_expand_node(node)
end

function M.goto_parent()
	local buffer = M.utils.get_cur_buffer_and_node()
	if path.dirname(buffer.directory) == buffer.directory then
		return
	end
	local new_buffer, new = Buffer.open(path.dirname(buffer.directory), { open_cmd = "edit" })
	if new then
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
end

function M.open(open_cmd)
	vim.validate({ open_cmd = { open_cmd, "s", true } })
	open_cmd = open_cmd or "edit"
	local _, node = M.utils.get_cur_buffer_and_node()
	if node.type == "header" then
		return
	elseif node.type == "directory" then
		Buffer.open(node.abspath, { open_cmd = open_cmd })
	else
		vim.cmd(("%s %s"):format(open_cmd, node.abspath))
	end
end

function M.rename()
	local buffer = M.utils.get_cur_buffer_and_node()
	buffer:edit({
		get_items = function()
			local res = {}
			local lines = vim.api.nvim_buf_get_lines(buffer.id, 0, -1, true)
			local nodes = buffer.root:flatten_children()
			assert(#nodes == #lines)

			local stack = Stack({ buffer.directory })
			local level_stack = Stack({})
			for i = 1, #nodes do
				if nodes[i].type ~= "header" then
					local cur_level = nodes[i].level
					while not level_stack:empty() and level_stack:top() >= cur_level do
						stack:pop()
						level_stack:pop()
					end

					stack:push(vim.trim(lines[i]))
					level_stack:push(nodes[i].level)
					res[cur_level] = res[cur_level] or {}
					table.insert(res[cur_level], path.join(unpack(stack)))
				end
			end
			return res
		end,
		update = function(ori_items, new_items)
			require("libp.log").warn(ori_items)
			require("libp.log").warn(new_items)
			buffer:disable_fs_event_watcher()
			for level = 0, #new_items do
				for _, ori_item in ipairs(ori_items[level]) do
					require("libp.log").warn(ori_item, ori_item .. "copy")
					a.uv.fs_rename(ori_item, ori_item .. "copy")
				end

				for i, new_item in ipairs(new_items[level]) do
					require("libp.log").warn(ori_items[level][i] .. "copy", new_item)
					a.uv.fs_rename(ori_items[level][i] .. "copy", new_item)
				end
			end
			buffer:enable_fs_event_watcher()
			buffer:rebuild_nodes()
			buffer:draw()
		end,
	})
end

return M
