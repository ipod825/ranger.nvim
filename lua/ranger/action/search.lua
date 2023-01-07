local M = {}
local ui = require("libp.ui")
local utils = require("ranger.action.utils")
local List = require("libp.datatype.List")
local iter = require("libp.iter")
local bind = require("libp.functional").bind
local vimfn = require("libp.utils.vimfn")
local functional = require("libp.functional")

function M.draw_search_buffer(buffer, search_buffer, pattern)
	pattern = pattern or ""

	local nodes = buffer.root:flatten_children()
	local re_pattern = vim.regex(pattern)
	local find = function(name)
		local beg, ends = re_pattern:match_str(name)
		if beg then
			return beg + 1, ends
		end
	end

	local filtered_nodes = nodes:filter(function(n)
		return find(n.name)
	end)

	search_buffer:set_content_and_reload(
		filtered_nodes:map(function(e)
			return e.name
		end),
		{
			content_highlight_fn = function()
				local res = List()

				for row, n in iter.KV(filtered_nodes) do
					local beg, ends = find(n.name)
					res:append({ hl_group = n.highlight, line = row - 1 })
					if beg then
						table.insert(
							res,
							{ hl_group = "IncSearch", line = row - 1, col_start = beg - 1, col_end = ends }
						)
					end
				end
				return res
			end,
		}
	)
end

function M.move(search_window, direction)
	vimfn.setrow(vimfn.getrow(search_window.id) + direction, search_window.id)
end

function M.start()
	local buffer = utils.get_cur_buffer_and_node()
	local search_buffer = ui.Buffer()

	local search_window =
		ui.Window(search_buffer, { wo = { winhighlight = "Normal:Normal", cursorline = true }, focus_on_open = true })

	search_window:open({
		relative = "win",
		row = 0,
		col = 0,
		width = vim.api.nvim_win_get_width(0),
		height = vim.api.nvim_win_get_height(0),
		focusable = true,
	})

	local cmdline = ui.CmdLine({
		hint = "/",
		mappings = {
			i = {
				["<c-k>"] = bind(M.move, search_window, -1),
				["<c-j>"] = bind(M.move, search_window, 1),
				["<up>"] = bind(M.move, search_window, -1),
				["<down>"] = bind(M.move, search_window, 1),
			},
		},
	})

	local search_res
	local last_pattern
	functional.debounce({
		body = function()
			local pattern = cmdline:get_content()
			if pattern ~= last_pattern then
				M.draw_search_buffer(buffer, search_buffer, pattern)
				local search_window_row = vimfn.getrow(search_window.id)
				search_res = vimfn.buf_get_line({ buffer = search_buffer.id, row = search_window_row - 1 })
			end
			return pattern
		end,
		wait_ms = 20,
	})

	local confirmed_search_res = cmdline:confirm()
	search_window:close()
	vim.cmd("stopinsert")

	if confirmed_search_res then
		for i, node in iter.KV(buffer:nodes()) do
			if node.name == search_res then
				vimfn.setrow(i)
				break
			end
		end
	end
end

return setmetatable(M, {
	__call = function()
		return M.start()
	end,
})
