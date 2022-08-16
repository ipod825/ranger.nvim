local M = {}
local elipsis_note = "…"
local vimfn = require("libp.utils.vimfn")
local VIter = require("libp.datatype.VIter")
local functional = require("libp.functional")
local List = require("libp.datatype.List")
local itt = require("libp.datatype.itertools")

local function bisect_trunc(s, w)
	if #s == 0 then
		return s
	end

	local chars = List(vimfn.str_to_char(s))
	local length = VIter(chars)
		:map(function(v)
			return vim.fn.strwidth(v)
		end)
		:fold(0, functional.binary_op.add)
		:collect()
	local bytes = VIter(chars)
		:map(function(v)
			return #v
		end)
		:fold(0, functional.binary_op.add)
		:collect()

	if w < length[1] then
		return elipsis_note:rep(w)
	end
	local left = 1
	local right = #length
	local middle
	while left < right do
		middle = left + math.floor((right - left) / 2) + 1
		if length[middle] == w then
			return s:sub(1, bytes[middle])
		elseif length[middle] > w then
			right = middle - 1
		else
			left = middle
		end
	end
	-- No substring of s is of exactly width w, pad left spaces with elipsis_note
	return s:sub(1, bytes[left]) .. elipsis_note:rep(w - length[left])
end

function M.name(name, width)
	local sz = vim.fn.strwidth(name)
	if width >= sz then
		return name .. (" "):rep(width - sz)
	else
		local ext_beg = name:find("%.[^%.]-$")
		local ext
		if ext_beg then
			name, ext = name:sub(1, ext_beg - 1), elipsis_note .. name:sub(ext_beg)
			sz = vim.fn.strwidth(name)
		else
			ext = elipsis_note
		end

		local abbrev_name
		if sz == #name then
			abbrev_name = name:sub(1, width - vim.fn.strwidth(ext))
		else
			abbrev_name = bisect_trunc(name, width - vim.fn.strwidth(ext))
		end
		return ("%s%s"):format(abbrev_name, ext)
	end

	return name
end

local home = ("^%s"):format(os.getenv("HOME"))
function M.path(path, width)
	path = path:gsub(home, "~")
	if #path <= width then
		return path
	end

	local sp = vim.split(path, "/")
	local szm1 = #sp - 1
	local total = 2 * szm1 + #sp[#sp]
	for i in itt.range(szm1, 1, -1) do
		if total + #sp[i] - 1 > width then
			for j in itt.range(i) do
				sp[j] = sp[j]:sub(1, 1)
			end
			return require("libp.path").join_array(sp)
		else
			total = total + #sp[i] - 1
		end
	end
end

return M
