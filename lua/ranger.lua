local M = {}
local a = require("plenary.async")
local default_config = require("ranger.default_config")
local Buffer = require("ranger.Buffer")

function M.setup(opts)
	opts = vim.tbl_deep_extend("force", default_config, opts or {})

	vim.validate({
		command = { opts.command, "s", true },
	})

	require("ranger.action").setup(opts)
	M.define_command(opts)
	M.define_highlights(opts.highlights)
	Buffer.define_buf_win_enter_autocmd()
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("ranger_define_highlight", {}),
		callback = function()
			M.define_highlights(opts.highlights)
		end,
	})
end

function M.define_highlights(highlights)
	for group, color in pairs(highlights) do
		vim.api.nvim_set_hl(0, group, color)
		vim.api.nvim_set_hl(0, group .. "Sel", vim.tbl_extend("force", color, { fg = "black", bg = color.fg }))
	end
end

function M.define_command(opts)
	vim.validate({ command = { opts.command, "s" } })

	local execute = function(args)
		a.void(function()
			Buffer.open(args.args)
		end)()
	end

	vim.api.nvim_create_user_command(opts.command, execute, {
		nargs = 1,
		complete = "dir",
	})
end

return M
