local M = require("libp.ui.Buffer"):EXTEND()
local ui = require("libp.ui")
local Node = require("ranger.Node")
local List = require("libp.datatype.List")
local Watcher = require("libp.fs.Watcher")
local vimfn = require("libp.utils.vimfn")
local path = require("libp.path")
local fs = require("libp.fs")
local a = require("plenary.async")

function M.open_or_new(buf_opts)
	return ui.Buffer.open_or_new(buf_opts, M)
end

function M.get_or_new(buf_opts)
	return ui.Buffer.get_or_new(buf_opts, M)
end

function M.get_current_buffer()
	return ui.Buffer.get_current_buffer()
end

function M.define_buf_win_enter_autocmd()
	vim.api.nvim_create_autocmd("BufWinEnter", {
		pattern = "ranger://*",
		callback = function()
			vim.wo.scrolloff = 0
			vim.wo.sidescrolloff = 0
			vim.wo.wrap = false
			vim.wo.spell = false
			vim.wo.cursorline = false
			vim.wo.foldcolumn = "0"
			vim.wo.foldenable = false
			vim.foldmethod = "manual"
			vim.list = false
		end,
	})
end

function M.open(dir_name, opts)
	opts = vim.tbl_deep_extend("force", require("ranger.default_config"), opts or {})
	if #dir_name > 1 and vim.endswith(dir_name, "/") then
		dir_name = dir_name:sub(1, #dir_name - 1)
	end
	local buf_opts = {
		-- TODO(smwang): abspath, expand home
		filename = "ranger://" .. dir_name,
		open_cmd = opts.open_cmd,
		buf_enter_reload = false,
		content = {},
		bo = {
			filetype = "ranger",
			bufhidden = "hide",
			buftype = "nofile",
			swapfile = false,
			buflisted = false,
		},
	}

	local buffer, new
	if #buf_opts.open_cmd == 0 then
		buffer, new = M.get_or_new(buf_opts)
		local grid = ui.Grid()
		grid:add_row({ focusable = true }):fill_window(ui.Window(buffer, { focus_on_open = true }))
		grid:show()
	else
		buffer, new = M.open_or_new(buf_opts)
	end

	if new then
		buffer:config_new(dir_name)
		buffer:set_mappings(opts.mappings)
	end
	return buffer
end

function M:add_dir_node_children(node)
	assert(node.type == "directory")
	node:extend_children(List(fs.list_dir(node.abspath)):map(function(e)
		e.abspath = path.join(node.abspath, e.name)
		return Node(e)
	end))
	node:sort()
end

function M:build_nodes(directory)
	local root = Node({ type = "directory", abspath = directory })
	root:add_child(Node({ type = "header", name = directory }))
	self:add_dir_node_children(root)
	return root
end

function M:reload()
	if not self.root then
		return
	end
	self:SUPER():reload()
	self:clear_hl(1, -1)
	self.root:flatten_children():for_each(function(node, row)
		self:set_row_hl(row, node.highlight)
	end)
end

function M:redraw()
	local editable_width = vimfn.editable_width(0)
	self.content = self.root:flatten_children():map(function(e)
		local res = (" "):rep(e.level * 2) .. e.name
		res = res .. (" "):rep(math.max(0, editable_width - vim.fn.strwidth(res)))
		return res
	end)
	self:reload()
end

function M:build_nodes_and_reload()
	self.root = self:build_nodes(self.directory)
	self:redraw()
end

function M:nodes(ind)
	vim.validate({ ind = { ind, "n", true } })
	local res = self.root:flatten_children(ind)
	return res
end

function M:set_row_hl(row, hl)
	local node = self:nodes(row)
	if node then
		hl = hl or node.highlight
		if vimfn.current_row() == row then
			self:set_hl(hl .. "Sel", row)
		else
			self:set_hl(hl, row)
		end
	end
end

function M:config_new(dir_name)
	self.cur_row = 1
	self.directory = dir_name
	self:build_nodes_and_reload()

	local bid = self.id
	Watcher(dir_name, function(watcher)
		if not vim.api.nvim_buf_is_valid(bid) then
			watcher:stop()
		else
			a.void(function()
				self:build_nodes_and_reload()
			end)()
		end
	end)

	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = self.id,
		callback = function()
			local new_row = vimfn.current_row()
			self:clear_hl(self.cur_row)
			-- TODO(smwang): Workaround on bug of clear_highlight
			-- https://github.com/neovim/neovim/issues/19511
			self:set_row_hl(self.cur_row - 1)
			self:set_row_hl(self.cur_row)
			self:set_row_hl(new_row)
			self.cur_row = new_row
		end,
	})
end

return M
