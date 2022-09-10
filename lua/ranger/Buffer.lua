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
local List = require("libp.datatype.List")
local VIter = require("libp.datatype.VIter")
local KVIter = require("libp.datatype.KVIter")
local OrderedDict = require("libp.datatype.OrderedDict")
local uv = require("libp.fs.uv")
local a = require("plenary.async")

local open_opts
function M.setup(opts)
	open_opts = opts
end

function M:_on_open_focused()
	vimfn.set_cwd(self.directory)
	if not self._ever_open_focused then
		self._ever_open_focused = true
		-- Puts the cursor on the row after the header.
		vimfn.setrow(2)
		-- TODO(smwang): The API has bugs that sets the global values
		-- vim.api.nvim_win_set_option(0, "scrolloff", 0)
		-- vim.api.nvim_win_set_option(0, "sidescrolloff", 0)
		-- vim.api.nvim_win_set_option(0, "wrap", false)
		-- vim.api.nvim_win_set_option(0, "spell", false)
		-- vim.api.nvim_win_set_option(0, "cursorline", false)
		-- vim.api.nvim_win_set_option(0, "foldcolumn", "0")
		-- vim.api.nvim_win_set_option(0, "foldenable", false)
		-- vim.api.nvim_win_set_option(0, "foldmethod", "manual")
		-- vim.api.nvim_win_set_option(0, "list", false)
		vim.cmd("setlocal scrolloff=0")
		vim.cmd("setlocal sidescrolloff=0")
		vim.cmd("setlocal nowrap")
		vim.cmd("setlocal nospell")
		vim.cmd("setlocal nocursorline")
		vim.cmd("setlocal foldcolumn=0")
		vim.cmd("setlocal nofoldenable")
		vim.cmd("setlocal foldmethod=manual")
		vim.cmd("setlocal nolist")
	end
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
	opts = vim.tbl_deep_extend("force", open_opts, opts or {})
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
		filename = "ranger://" .. dir_name,
		open_cmd = opts.open_cmd,
		buf_enter_reload = false,
		content = false,
		bo = {
			filetype = "ranger",
			bufhidden = "hide",
			buftype = "nofile",
			swapfile = false,
			buflisted = false,
		},
	}

	local buffer, new
	if buf_opts.open_cmd == "caller" then
		-- Caller will render itself.
		buffer, new = M:get_or_new(buf_opts)
	else
		buffer, new = M:open_or_new(buf_opts)
	end

	if new then
		opts.win_width = opts.win_width or init_win_width
		buffer:_config_new(dir_name, opts)
		buffer:set_mappings(opts.mappings)
	else
		opts.win_width = opts.win_width or vimfn.editable_width(0)
		buffer:set_win_width_maybe_redraw(opts.win_width)
	end

	if buffer:is_focused() then
		buffer:_on_open_focused()
	end

	return buffer, new
end

function M:_add_dir_node_children(node, abspath)
	abspath = abspath or node.abspath

	local entries, err = fs.list_dir(abspath)
	if err then
		vimfn.warn(err)
		return
	end

	entries = VIter(entries)
		:filter(function(e)
			for pattern in itt.values(self.ignore_patterns) do
				if e.name:match(pattern) then
					return false
				end
			end
			return true
		end)
		:map(function(e)
			e.abspath = path.join(abspath, e.name)
			e.link = e.type == "link" and uv.fs_readlink(e.abspath)
			return Node(e)
		end)
		:collect()

	node:extend_children(entries)

	for _, child in ipairs(node:flatten_children()) do
		-- Recursively add children to expanded nodes.
		if Set.has(self.expanded_abspaths, child.abspath) then
			self:_add_dir_node_children(child)
		end
	end

	node:sort(self._sort_fn)
end

function M:build_nodes(directory)
	local root = Node()
	root:add_child(Node({ type = "header", name = directory }))
	self:_add_dir_node_children(root, directory)

	return root
end

-- Called by parent (ui.Buffer:reload) to set highlight after reload.
function M:reload_highlight()
	self:clear_hl(1, -1)
	for row, node in KVIter(self.root:flatten_children()) do
		self:set_hl(node.highlight, row)
	end

	if not self:is_editing() then
		self.cur_row = math.min(self.cur_row, vim.api.nvim_buf_line_count(self.id))
		self:set_selected_row_hl(self.cur_row)
	end
end

function M:add_right_display(key, fn)
	self._right_display = self._right_display or OrderedDict()
	self._right_display[key] = fn
end

function M:add_left_display(fn)
	self._left_display = self._left_display or List()
	self._left_display:append(fn)
end

-- Set content and highlight assuming the nodes (which the content were based
-- on) were built.
function M:draw(plain)
	local content
	if plain then
		content = self.root:flatten_children():map(function(e)
			return e.name
		end)
	else
		content = self.root:flatten_children():map(function(e)
			local res

			local width = self.win_width - 1
			local right

			if self._right_display then
				right = ""
				for fn in OrderedDict.values(self._right_display) do
					right = right .. fn(e)
				end
				width = width - vim.fn.strwidth(right)
			end

			if e.type == "header" then
				res = abbrev.path((" "):rep(e.level * 2) .. e.name, width)
			else
				local name = e.type == "link" and ("%s -> %s"):format(e.name, e.link) or e.name
				res = abbrev.name((" "):rep(e.level * 2) .. name, width)
			end

			if right then
				res = res .. right
			end

			return res
		end)
	end

	self:set_content_and_reload(content)
end

function M:rebuild_nodes()
	self.root = self:build_nodes(self.directory)
end

function M:nodes(ind)
	vim.validate({ ind = { ind, "n", true } })
	local res = self.root:flatten_children(ind)
	return res
end

function M:set_sort_fn(fn)
	self._sort_fn = fn or function(first, second)
		return first.name < second.name
	end
end

function M:set_unselected_row_hl(row)
	-- TODO(smwang): Ideally we don't need this check (caller should guarantee
	-- that). But in CursorMoved handler there's a workaround that pass in 0 or
	-- -1.
	if row < 1 then
		return
	end
	self:set_hl(self:nodes(row).highlight, row)
end

function M:set_selected_row_hl(row)
	self:set_hl(self:nodes(row).highlight .. "Sel", row)
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
	self.ignore_patterns = vim.deepcopy(opts.ignore_patterns)
	self.cur_row = 1
	self.directory = dir_name
	self.expanded_abspaths = Set()
	self:set_sort_fn()
	self:_add_fs_event_watcher(self.directory)
	self:enable_fs_event_watcher()
	self:rebuild_nodes()
	self:draw()

	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = self.id,
		callback = function()
			if self:is_editing() then
				return
			end
			local new_row = vimfn.getrow()
			self:clear_hl(self.cur_row)
			-- TODO(smwang): Workaround on bug of clear_highlight
			-- https://github.com/neovim/neovim/issues/19511
			self:set_unselected_row_hl(self.cur_row - 1)
			self:set_unselected_row_hl(self.cur_row)
			self:set_selected_row_hl(new_row)
			self.cur_row = new_row

			require("ranger.action").preview()
		end,
	})

	vim.api.nvim_create_autocmd("BufEnter", {
		buffer = self.id,
		callback = function()
			vimfn.set_cwd(self.directory)
		end,
	})
end

return M
