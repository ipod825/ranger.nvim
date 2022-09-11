local M = {}
local ui = require("libp.ui")
local utils = require("ranger.action.utils")
local VIter = require("libp.datatype.VIter")
local KVIter = require("libp.datatype.KVIter")
local bind = require("libp.functional").bind
local vimfn = require("libp.utils.vimfn")
local functional = require("libp.functional")

function M.draw_search_buffer(buffer, search_buffer, substr)
	substr = substr or ""

	local nodes = buffer.root:flatten_children()
	if buffer._reanger_search == substr then
		return
	end
	buffer._reanger_search = substr

	local ignore_case = (vim.o.smartcase and not substr:match("%u")) or vim.o.ignorecase

	local find
	if ignore_case then
		substr = ("(%s)"):format(substr:lower())
		find = function(name)
			return name:lower():find(substr)
		end
	else
		substr = ("(%s)"):format(substr)
		find = function(name)
			return name:find(substr)
		end
	end

	local filtered_nodes = nodes:filter(function(n)
		return find(n.name)
	end)

	search_buffer:set_content_and_reload(filtered_nodes:map(function(e)
		return e.name
	end))

	search_buffer:reload_highlight(VIter(filtered_nodes):mapkv(function(row, n)
		local beg, ends = find(n.name)
		return row, { { n.highlight, row }, { "IncSearch", row, beg, ends } }
	end))
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
	functional.debounce({
		body = function()
			local pattern = cmdline:get_content()
			if pattern then
				M.draw_search_buffer(buffer, search_buffer, pattern)
				local search_window_row = vimfn.getrow(search_window.id)
				search_res = search_buffer:get_line(search_window_row)
			end
			return pattern
		end,
		wait_ms = 20,
	})

	local confirmed_search_res = cmdline:confirm()
	search_window:close()
	vim.cmd("stopinsert")

	if confirmed_search_res then
		for i, node in KVIter(buffer:nodes()) do
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
