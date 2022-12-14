local M = require("libp.datatype.Class"):EXTEND()
local List = require("libp.datatype.List")
local iter = require("libp.iter")
local args = require("libp.args")

function M.cmp(a, b)
	if a.sorting_order ~= b.sorting_order then
		return (a.sorting_order < b.sorting_order)
	end
end

local SortingOrder = { header = 0, directory = 1, file = 2, link = 2 }
M.HighlightGroup = { directory = "RangerDir", file = "RangerFile", link = "RangerLink", header = "RangerHeader" }

function M:init(opts)
	opts = opts or {}
	vim.validate({
		name = { opts.name, "s", true },
		link = { opts.abspath, "s", true },
		type = { opts.type, "s", true },
		abspath = { opts.abspath, "s", true },
		level = { opts.level, "n", true },
	})
	self.type = opts.type
	self.name = opts.name
	self.link = opts.link
	self.abspath = opts.abspath
	self.level = opts.level or -1
	self.sorting_order = self.type and SortingOrder[self.type]
	self.highlight = self.type and M.HighlightGroup[self.type]
	self.children = List()
	self._flatten_children = nil
end

function M:set_temporary_hl(hl)
	if not self.ori_hl then
		self.ori_hl = self.highlight
	end
	self.highlight = hl
end

function M:unset_temporary_hl()
	assert(self.ori_hl)
	self.highlight, self.ori_hl = self.ori_hl, nil
end

function M:mark_flatten_children_dirty()
	-- Recursively invalidate _flatten_children
	local root = self
	-- Checks root._flatten_children just to avoid unnecessary computation for
	-- repeated call to mark_flatten_children_dirty.
	while root and root._flatten_children do
		root._flatten_children = nil
		root = root.parent
	end
end

function M:add_child(child)
	self:extend_children(List({ child }))
end

function M:extend_children(new_children)
	for c in iter.values(new_children) do
		c.parent = self
		c.level = self.level + 1
	end
	self.children:extend(new_children)
	self:mark_flatten_children_dirty()
end

function M:remove_all_children()
	for _, c in ipairs(self.children) do
		c:remove_all_children()
		c.invalid = true
	end
	self.children = List()
	self:mark_flatten_children_dirty()
end

function M:sort(cmp)
	vim.validate({ cmp = { cmp, "f", true } })
	local composite_cmp = cmp and function(a, b)
		return args.get_default_lazy(M.cmp(a, b), cmp, a, b)
	end or M.cmp

	for _, child in ipairs(self.children) do
		child:sort(composite_cmp)
	end
	self.children:sort(composite_cmp)
	self:mark_flatten_children_dirty()
end

-- todo flatten_children_with_self
function M:_flatten_children_inner()
	if not self._flatten_children then
		self._flatten_children = List({ self })
		for _, child in ipairs(self.children) do
			self._flatten_children:extend(child:_flatten_children_inner())
		end
	end
	return self._flatten_children
end

function M:flatten_children(ind)
	vim.validate({ ind = { ind, "n", true } })
	if not self._flatten_children then
		self._flatten_children = List()
		for _, child in ipairs(self.children) do
			self._flatten_children:extend(child:_flatten_children_inner())
		end
	end

	if ind then
		return self._flatten_children[ind]
	else
		return self._flatten_children
	end
end

return M
