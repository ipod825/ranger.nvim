local M = {}
local ui = require("libp.ui")
local utils = require("ranger.action.utils")
local fs = require("libp.fs")
local uv = vim.loop
local vimfn = require("libp.utils.vimfn")

local Order = { ASCENDING = 1, DESCENDING = 2 }

function M.open_menu()
	local metric = ui.Menu({
		title = "Sort by",
		content = {
			"default",
			"name",
			"size",
			"mtime",
			"ctime",
			"atime",
		},
	}):select()
	if not metric then
		return
	end

	local order
	if metric ~= "default" then
		order = ui.Menu({
			title = "Order",
			content = {
				"Ascending: small to large / early to late",
				"Dscending: large to small / late to early ",
			},
			select_map = {
				Order.ASCENDING,
				Order.DESCENDING,
			},
		}):select()
	end
	M.sort(metric, order)
end

function M.sort(metric, order)
	local buffer = utils.get_cur_buffer_and_node()
	if metric == "default" then
		buffer:add_right_display("sort", nil)
		buffer:set_sort_fn(nil)
	else
		local get_metric
		if metric == "name" then
			get_metric = function(node)
				return node.name
			end
		elseif metric == "size" then
			get_metric = function(node)
				if not node.size then
					if node.type == "directory" then
						local handle, _ = uv.fs_scandir(node.abspath)
						local count = 0
						while uv.fs_scandir_next(handle) do
							count = count + 1
						end
						node.size = count
					else
						local stat, err = uv.fs_stat(node.abspath)
						if err then
							vimfn.warn("Error loading stats: " .. node.abspath)
							return 0
						end
						node.size = stat.size
					end
				end
				return node.size
			end
		else
			get_metric = function(node)
				if not node[metric] then
					local stat, err = uv.fs_stat(node.abspath)
					if err then
						vimfn.warn("Error loading stats: " .. node.abspath)
						return 0
					end
					node[metric] = stat[metric].sec + stat[metric].nsec / 1000000000
				end
				return node[metric]
			end
		end

		if metric ~= "name" and metric ~= "default" then
			buffer:add_right_display("sort", function(node)
				if node.type == "header" then
					return ""
				end
				return " " .. get_metric(node)
			end)
		end

		buffer:set_sort_fn(order == Order.ASCENDING and function(a, b)
			return get_metric(a) < get_metric(b)
		end or function(a, b)
			return get_metric(a) > get_metric(b)
		end)
	end
	buffer:rebuild_nodes()
	buffer:draw()
end

return setmetatable(M, {
	__call = function()
		return M.open_menu()
	end,
})
