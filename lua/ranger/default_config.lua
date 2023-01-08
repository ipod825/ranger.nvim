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
			h = { action.goto_parent, desc = "Change to parent directory" },
			l = { action.open, desc = "Change directory/open file under cursor" },
			L = { action.set_cwd, desc = "Change window-local pwd to the directory of the entry under cursor" },
			t = { require("libp.functional").bind(action.open, "tabedit"), desc = "Open file in new tab" },
			T = { action.open_tab_bg, desc = "Open file in new tab without switching to it" },
			a = { action.ask, desc = "Open file with with menu to select the application" },
			za = { action.toggle_expand, desc = "Toggle expand current directory under cursor" },
			zh = { action.toggle_hidden, desc = "Toggle Show hidden files" },
			v = { action.transfer.toggle_select, desc = "Toggle select the current entry for further copy/cut" },
			dd = { action.transfer.cut_current, desc = "Cut the current entry" },
			d = { action.transfer.cut_selected, desc = "Cut all picked entries" },
			y = { action.transfer.copy_selected, desc = "Copy all selected entries" },
			yy = { action.transfer.copy_current, desc = "Copy the current entry" },
			p = { action.transfer.paste, desc = "Paste all cut/copied entries" },
			D = { action.trash.trash_selected, desc = "Delete all picked entries" },
			DD = { action.trash.trash_current, desc = "Delete the current entry" },
			u = { action.trash.restore_last, desc = "Undo last delete" },
			i = { action.rename, desc = "Enter edit mode to rename file/directory names" },
			o = { action.create_entries, desc = "Create new directory/file with menu" },
			P = { action.preview.toggle, desc = "Toggle enter preview mode" },
			S = { action.sort, desc = "Sort content in current directory with menu" },
			["/"] = { action.search, desc = "Search for word in the current directory buffer" },
		},
		v = {
			v = action.transfer.toggle_select,
		},
	},
}
