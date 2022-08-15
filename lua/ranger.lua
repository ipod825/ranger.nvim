local M = {}
local a = require("plenary.async")
local default_config = require("ranger.default_config")
local fs = require("libp.fs")
local Buffer = require("ranger.Buffer")

function M.setup(opts)
	opts = vim.tbl_deep_extend("force", default_config, opts or {})

	vim.validate({
		command = { opts.command, "s", true },
	})

	if opts.hijack_netrw then
		vim.g.loaded_netrw = 1
		vim.g.loaded_netrwPlugin = 1

		vim.api.nvim_create_autocmd("BufEnter", {
			pattern = "*",
			group = vim.api.nvim_create_augroup("ranger_hijack_netrw", {}),
			callback = function(args)
				if fs.is_directory(args.file) then
					a.void(function()
						local ori_buf = vim.api.nvim_get_current_buf()
						local _, new = Buffer.open(args.file)
						if new and vim.api.nvim_buf_get_name(ori_buf) == args.file then
							vim.cmd("bwipe " .. ori_buf)
						end
					end)()
				end
			end,
		})
	end

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
		if group == "RangerHeader" then
			vim.api.nvim_set_hl(0, group .. "Sel", color)
		else
			vim.api.nvim_set_hl(0, group .. "Sel", vim.tbl_extend("force", color, { fg = "black", bg = color.fg }))
		end
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
