local M = {}
local elipsis_note = "…"

function M.abbrev_name(name, width)
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
			abbrev_name = name
		end
		return ("%s%s"):format(abbrev_name, ext)
	end

	return name
end

return setmetatable(M, {
	["__call"] = function(_, ...)
		return M.abbrev_name(...)
	end,
})
