local action = require("ranger.action")

return {
	-- The command name ranger defined.
	command = "Ranger",
	-- Set to true to enable editing directory with ranger by default.
	hijack_netrw = false,
	-- Default command to open directory buffer with "Ranger".
	open_cmd = "edit",
	-- The pattern defining the files to be hidden. Runtime behavior can be
	-- toggled by `action.toggle_hidden`.
	ignore_patterns = { "^%..*" },
	-- The width of the preview panel. If smaller than 1, will be multipled by the window width.
	preview_panel_width = 0.3,
	-- Set to false to disable preview by default. Runtime behavior can be can
	-- be toggled by `action.preview.toggle`.
	preview_default_on = true,
	-- Rifle configuration path.
	rifle_path = vim.fn.stdpath("data") .. "/rifle.conf",
	-- Whether to enable devicon.
	enable_devicon = true,
	-- Define the highlights. Currently not used.
	highlights = {},
	-- Define the entry highlights. Only the listed keys are valid. See
	-- `nvim_set_hl` for valid value definition.
	node_highlights = {
		RangerHeader = { ctermfg = "yellow", fg = "#ffff00" },
		RangerSelected = { ctermfg = "yellow", fg = "#ffff00" },
		RangerCut = { ctermfg = "grey", fg = "#808080" },
		RangerCopied = { ctermfg = 13, fg = "#ff00ff" },
		RangerDir = { ctermfg = 26, fg = "#00afff" },
		RangerFile = { ctermfg = "white", fg = "#ffffff" },
		RangerLink = { ctermfg = 51, fg = "#00ffff" },
		RangerExe = { ctermfg = 22, fg = "#005f00" },
	},
	mappings = {
		-- To unmap predefined keys, set them to false. To add new mappings, set
		-- a key to a lua function. For e.g., to unmap `h` and add a mapping hh:
		--  h = false,
		--  hh = function() end
		n = {
			h = action.goto_parent,
			l = action.open,
			L = action.set_cwd,
			t = require("libp.functional").bind(action.open, "tabedit"),
			a = action.ask,
			za = action.toggle_expand,
			zh = action.toggle_hidden,
			v = action.transfer.toggle_select,
			dd = action.transfer.cut_current,
			d = action.transfer.cut_selected,
			y = action.transfer.copy_selected,
			yy = action.transfer.copy_current,
			p = action.transfer.paste,
			D = action.trash.trash_selected,
			DD = action.trash.trash_current,
			u = action.trash.restore_last,
			i = action.rename,
			o = action.create_entries,
			P = action.preview.toggle,
			S = action.sort,
			["/"] = action.search,
		},
		v = {
			v = action.transfer.toggle_select,
		},
	},
}
