local M = require("libp.ui.Buffer"):EXTEND()
local ui = require("libp.ui")
local Node = require("ranger.Node")
local Watcher = require("libp.fs.Watcher")
local vimfn = require("libp.utils.vimfn")
local path = require("libp.path")
local Set = require("libp.datatype.Set")
local fs = require("libp.fs")
local itt = require("libp.datatype.itertools")
local abbrev = require("ranger.abbrev")
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

function M.set_win_options()
	vim.wo.scrolloff = 0
	vim.wo.sidescrolloff = 0
	vim.wo.wrap = false
	vim.wo.spell = false
	vim.wo.cursorline = false
	vim.wo.foldcolumn = "0"
	vim.wo.foldenable = false
	vim.foldmethod = "manual"
	vim.list = false
end

function M.define_buf_win_enter_autocmd()
	vim.api.nvim_create_autocmd("BufWinEnter", {
		pattern = "ranger://*",
		callback = function()
			M.set_win_options()
			vim.cmd("lcd " .. M.get_current_buffer().directory:gsub(" ", "\\ "))
		end,
	})
end

local init_win_width = vimfn.editable_width(0)
function M.set_init_win_width(width)
	init_win_width = width
end

function M:set_win_width_maybe_redraw(win_width)
	if self.win_width ~= win_width then
		self.win_width = win_width
		self:draw()
	end
end

function M.open(dir_name, opts)
	opts = vim.tbl_deep_extend("force", require("ranger.default_config"), opts or {})
	local ori_dir_name = dir_name

	dir_name = dir_name:gsub("^~", os.getenv("HOME"))
	if not vim.startswith(dir_name, path.path_sep) then
		local rel_dir_name = path.join(vim.fn.getcwd(), dir_name)
		if vim.fn.isdirectory(rel_dir_name) == 1 then
			dir_name = rel_dir_name
		end
	end

	if vim.fn.isdirectory(dir_name) ~= 1 then
		vim.notify(("%s is not a directory"):format(ori_dir_name), vim.log.levels.WARN)
		return
	end

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
	if buf_opts.open_cmd == "preview" then
		-- Caller will render itself.
		buffer, new = M.get_or_new(buf_opts)
	elseif #buf_opts.open_cmd == 0 then
		buffer, new = M.get_or_new(buf_opts)
		local grid = ui.Grid()
		grid:add_row({ focusable = true }):fill_window(ui.Window(buffer, { focus_on_open = true }))
		grid:show()
		M.set_win_options()
	else
		local ori_buf = vim.api.nvim_get_current_buf()
		buffer, new = M.open_or_new(buf_opts)
		M.set_win_options()
		-- Wipe the temporary buffer created by netrw.
		if new and vim.api.nvim_buf_get_name(ori_buf) == dir_name then
			vim.cmd("bwipe " .. ori_buf)
		end
	end

	if new then
		opts.win_width = opts.win_width or init_win_width
		buffer:_config_new(dir_name, opts)
		buffer:set_mappings(opts.mappings)
	else
		opts.win_width = opts.win_width or vimfn.editable_width(0)
		buffer:set_win_width_maybe_redraw(opts.win_width)
	end
	return buffer, new
end

function M:_add_dir_node_children(node, abspath)
	abspath = abspath or node.abspath

	local entries, err = fs.list_dir(abspath):map(function(e)
		e.abspath = path.join(abspath, e.name)
		return Node(e)
	end)
	if err then
		vimfn.warn(err)
		return
	end

	node:extend_children(entries)

	for _, child in ipairs(node:flatten_children()) do
		-- Recursively add children to expanded nodes.
		if Set.has(self.expanded_abspaths, child.abspath) then
			self:_add_dir_node_children(child)
		end
	end

	node:sort()
end

function M:build_nodes(directory)
	local root = Node()
	root:add_child(Node({ type = "header", name = directory }))
	self:_add_dir_node_children(root, directory)

	return root
end

function M:reload()
	if not self.root then
		return
	end
	self:SUPER():reload()
	self:clear_hl(1, -1)

	local total_lines = vim.api.nvim_buf_line_count(self.id)
	self.cur_row = math.min(self.cur_row, total_lines)
	for row in itt.range(total_lines) do
		self:set_row_hl(row, self.cur_row)
	end
end

-- Set content and highlight assuming the nodes (from which the content were
-- based on) were built.
function M:draw()
	self.content = self.root:flatten_children():map(function(e)
		if e.type == "header" then
			return abbrev.path((" "):rep(e.level * 2) .. e.name, self.win_width)
		else
			return abbrev.name((" "):rep(e.level * 2) .. e.name, self.win_width)
		end
	end)
	self:reload()
end

function M:rebuild_nodes()
	self.root = self:build_nodes(self.directory)
end

function M:nodes(ind)
	vim.validate({ ind = { ind, "n", true } })
	local res = self.root:flatten_children(ind)
	return res
end

-- If the current buffer (self.id) is not in focus, `cur_vim_row` must be passed
-- in as otherwise the wrong row (the row of whatever buffer is in focus now)
-- might be used for highlighting the selected row of self.
function M:set_row_hl(row, cur_vim_row)
	local node = self:nodes(row)
	cur_vim_row = cur_vim_row or vimfn.current_row()
	if node then
		local hl = node.highlight
		if cur_vim_row == row then
			self:set_hl(hl .. "Sel", row)
		else
			self:set_hl(hl, row)
		end
	end
end

function M:disable_fs_event_watcher()
	self._watch_fs_event = false
end

function M:enable_fs_event_watcher()
	self._watch_fs_event = true
end

function M:toggle_expand_node(node)
	if node.type ~= "directory" then
		return
	end

	if not Set.has(self.expanded_abspaths, node.abspath) then
		Set.add(self.expanded_abspaths, node.abspath)
		self:_add_fs_event_watcher(node.abspath)
		self:_add_dir_node_children(node)
	else
		for _, n in ipairs(node:flatten_children()) do
			if Set.has(self.expanded_abspaths, n.abspath) then
				Set.remove(self.expanded_abspaths, n.abspath)
				self:_remove_rebuild_fs_watcher(n.abspath)
			end
		end
		node:remove_all_children()
	end
	self:draw()
end

function M:_add_fs_event_watcher(directory)
	self._build_and_draw_watchers = self._build_and_draw_watchers or {}

	assert(self._build_and_draw_watchers[directory] == nil)
	if self._build_and_draw_watchers[directory] then
		return
	end

	local bid = self.id
	self._build_and_draw_watchers[directory] = Watcher(directory, function(watcher)
		if not vim.api.nvim_buf_is_valid(bid) then
			watcher:stop()
		else
			if self._watch_fs_event then
				a.void(function()
					self:rebuild_nodes()
					self:draw()
				end)()
			end
		end
	end)
end

function M:_remove_rebuild_fs_watcher(directory)
	local watcher = self._build_and_draw_watchers[directory]
	watcher:stop()
	self._build_and_draw_watchers[directory] = nil
end

function M:_config_new(dir_name, opts)
	self.win_width = opts.win_width
	self.cur_row = 1
	self.directory = dir_name
	self.expanded_abspaths = Set()
	self:_add_fs_event_watcher(self.directory)
	self:enable_fs_event_watcher()
	self:rebuild_nodes()
	self:draw()

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

			require("ranger.action").preview()
		end,
	})
end

return M
