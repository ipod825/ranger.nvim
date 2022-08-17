local M = {}
local utils = require("ranger.action.utils")
local Buffer = require("ranger.Buffer")
local vimfn = require("libp.utils.vimfn")
local ui = require("libp.ui")
local itt = require("libp.datatype.itertools")
local mime = require("libp.mime")
local Set = require("libp.datatype.Set")
local a = require("plenary.async")

local panel_width
local preview_width
local is_previewing
local floating_preview

function M.setup(opts)
	local editable_width = vimfn.editable_width(0)
	floating_preview = opts.floating_preview
	panel_width = opts.preview_panel_width > 1 and opts.preview_panel_width
		or math.floor(editable_width * opts.preview_panel_width)
	-- -1 for border
	preview_width = editable_width - panel_width - 1
	is_previewing = opts.preview_default_on
	if is_previewing then
		Buffer.set_init_win_width(panel_width)
	end
end

function M.close_all_preview_windows_in_current_tabpage()
	for w in itt.values(vim.api.nvim_tabpage_list_wins(0)) do
		if vimfn.win_get_var(w, "ranger_previewer") then
			vim.api.nvim_win_close(w, true)
		end
	end
end

function M.close_all_invalid_preview_windows_in_current_tabpage()
	for w in itt.values(vim.api.nvim_tabpage_list_wins(0)) do
		local ranger_previewer = vimfn.win_get_var(w, "ranger_previewer")
		if ranger_previewer and not vim.api.nvim_win_is_valid(ranger_previewer) then
			vim.api.nvim_win_close(w, true)
		end
	end
end

function M.toggle()
	is_previewing = not is_previewing
	local buffer = utils.get_cur_buffer_and_node()
	if is_previewing then
		M.preview()
	else
		M.close_all_preview_windows_in_current_tabpage()
		buffer:set_win_width_maybe_redraw(vimfn.editable_width(0))
	end
end

function M.preview()
	if not is_previewing then
		return
	end
	local cur_win = vim.api.nvim_get_current_win()
	if vimfn.win_get_var(cur_win, "ranger_previewer") then
		return
	end

	local buffer, node = utils.get_cur_buffer_and_node()
	local ori_row = vimfn.current_row()
	buffer:set_win_width_maybe_redraw(panel_width)
	a.void(function()
		a.util.sleep(30)
		if vimfn.current_row() ~= ori_row then
			return
		end
		local preview_buffer
		if node.type == "header" then
			preview_buffer = ui.Buffer()
		elseif node.type == "directory" then
			preview_buffer = Buffer.open(node.abspath, { open_cmd = "preview", win_width = preview_width })
		elseif node.type == "file" then
			local mime_str = mime.info(node.abspath)
			if mime_str:match("text") or mime_str:match("x-empty") then
				preview_buffer = ui.FileBuffer(node.abspath)
				-- TODO(remove version check when nvim version stable)
				if vim.version().minor <= 7 then
					vim.filetype.match(node.abspath, preview_buffer.id)
				else
					local ft = vim.filetype.match({ filename = node.abspath }) or ""
					vim.api.nvim_buf_set_option(preview_buffer.id, "filetype", ft)
				end
			else
				preview_buffer = ui.Buffer({ content = { mime_str } })
			end
		end

		if preview_buffer and vim.api.nvim_get_current_buf() == buffer.id and vimfn.current_row() == ori_row then
			M.close_all_preview_windows_in_current_tabpage()

			if floating_preview then
				local grid = ui.Grid({ relative = "win", focusable = true, noautocmd = true })
				local row = grid:add_row()
				row:add_column({ width = panel_width })
				row:add_column():fill_window(
					ui.BorderedWindow(
						preview_buffer,
						{ wo = { wrap = true }, w = { ranger_previewer = cur_win } },
						{
							highlight = "RangerFloatingPreviewBorder",
							border = { nil, nil, nil, nil, nil, nil, nil, "│" },
						}
					)
				)
				grid:show()
			else
				vim.cmd(("noautocmd rightbelow vert %d vsplit"):format(preview_width))
				local preview_win = vim.api.nvim_get_current_win()
				vim.api.nvim_win_set_buf(preview_win, preview_buffer.id)
				vim.api.nvim_win_set_var(preview_win, "ranger_previewer", cur_win)

				local ori_eventignore = vim.o.eventignore
				vim.opt.eventignore:append("all")
				vim.api.nvim_set_current_win(cur_win)
				vim.o.eventignore = ori_eventignore
			end
		end
	end)()
end

return setmetatable(M, {
	__call = function()
		return M.preview()
	end,
})
