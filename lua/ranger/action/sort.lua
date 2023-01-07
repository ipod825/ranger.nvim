local M = {}
local ui = require("libp.ui")
local utils = require("ranger.action.utils")
local uv = vim.loop
local vimfn = require("libp.utils.vimfn")
local iter = require("libp.iter")

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
		short_key_map = { "d", "n", "s", "m", "c", "a" },
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
			short_key_map = { "a", "d" },
			select_map = {
				Order.ASCENDING,
				Order.DESCENDING,
			},
		}):select()
	end
	M.sort(metric, order)
end

local file_sz_display_wid = 6
local function size_str(st_size)
	local res = tonumber(st_size)
	for u in iter.values({ "B", "K", "M", "G", "T", "P" }) do
		if res < 1024 then
			res = tostring(res):sub(1, file_sz_display_wid - 2):gsub("%.$", "")
			return ("%s%s %s"):format((" "):rep(file_sz_display_wid - #res - 2), res, u)
		else
			res = res / 1024
		end
	end
	return ("?"):rep(file_sz_display_wid)
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
					node[metric] = stat[metric].sec
				end
				return node[metric]
			end
		end

		if metric == "size" then
			buffer:add_right_display("sort", function(node)
				if node.type == "header" then
					return ""
				end
				return " " .. (node.type == "directory" and get_metric(node) or size_str(get_metric(node)))
			end)
		elseif metric:match("time$") then
			buffer:add_right_display("sort", function(node)
				if node.type == "header" then
					return ""
				end
				return " " .. os.date("!%m/%d/%y %H:%M:%S", math.floor(get_metric(node)))
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
