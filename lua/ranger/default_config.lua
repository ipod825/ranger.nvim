local action = require("ranger.action")

return {
	-- The command name ranger defined.
	command = "Ranger",
	-- open_cmd = "edit",
	open_cmd = "Tabdrop",
	highlights = {
		RangerHeader = { ctermfg = "yellow", fg = "#ffff00" },
		RangerSelected = { ctermfg = "yellow", fg = "#ffff00" },
		RangerCut = { ctermfg = "grey", fg = "#808080" },
		RangerCopied = { ctermfg = 13, fg = "#ff00ff" },
		RangerDir = { ctermfg = 26, fg = "#005fd7" },
		RangerFile = { ctermfg = "white", fg = "#ffffff" },
		RangerLink = { ctermfg = 51, fg = "#00ffff" },
		RangerExe = { ctermfg = 22, fg = "#005f00" },
	},
	mappings = {
		n = {
			h = action.goto_parent,
			l = action.open,
			za = action.toggle_expand,
			v = action.transfer.toggle_select,
			dd = action.transfer.cut_current,
			d = action.transfer.cut_selected,
			y = action.transfer.copy_selected,
			yy = action.transfer.copy_current,
			p = action.transfer.paste,
			x = action.trash.trash_selected,
			xx = action.trash.trash_current,
			u = action.trash.restore_last,
			i = action.rename,
		},
		v = {
			v = action.transfer.toggle_select,
		},
	},
}
