local M = {}
local utils = require("ranger.action.utils")
local Buffer = require("ranger.Buffer")
local vimfn = require("libp.utils.vimfn")
local ui = require("libp.ui")
local iter = require("libp.iter")
local mime = require("libp.mime")
local a = require("plenary.async")
local functional = require("libp.functional")
local Ueberzug = require("libp.integration.Ueberzug")
local uv = require("libp.fs.uv")

local panel_width
local preview_width
local is_previewing

function M.setup(opts)
	local columns = vim.o.columns
	panel_width = opts.preview_panel_width > 1 and opts.preview_panel_width
		or math.floor(columns * opts.preview_panel_width)
	preview_width = columns - panel_width
	is_previewing = opts.preview_default_on
	if is_previewing then
		Buffer.set_init_win_width(panel_width)
	end
end

function M.close_all_preview_windows_in_current_tabpage()
	for w in iter.values(vim.api.nvim_tabpage_list_wins(0)) do
		if vimfn.win_get_var(w, "ranger_previewer") then
			vim.api.nvim_win_close(w, true)
		end
	end
end

function M.close_all_invalid_preview_windows_in_current_tabpage()
	for w in iter.values(vim.api.nvim_tabpage_list_wins(0)) do
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
		buffer:set_win_width_maybe_redraw(vim.o.columns)
	end

	if is_previewing then
		Buffer.set_init_win_width(panel_width)
	else
		Buffer.set_init_win_width(vim.o.columns)
	end
end

function M.preview()
	if not is_previewing then
		return
	end
	local previewer_win = vim.api.nvim_get_current_win()
	if vimfn.win_get_var(previewer_win, "ranger_previewer") then
		return
	end

	local previewer_buffer, node = utils.get_cur_buffer_and_node()
	local ori_row = vimfn.getrow()
	previewer_buffer:set_win_width_maybe_redraw(panel_width)
	a.void(function()
		a.util.sleep(30)
		if vimfn.getrow() ~= ori_row then
			return
		end
		local previewee_buffer
		local post_previewee_window_open = functional.nop
		if node.type == "header" then
			previewee_buffer = ui.Buffer()
		elseif node.type == "directory" then
			previewee_buffer = Buffer.open(node.abspath, { open_cmd = "caller", win_width = preview_width })
		elseif node.type == "file" or node.type == "link" then
			local path = node.type == "link" and uv.fs_readlink(node.abspath) or node.abspath
			local mime_str = mime.info(path)
			if mime_str:match("text") or mime_str:match("x-empty") then
				previewee_buffer = ui.FileBuffer(node.abspath)
				-- TODO(With FileBuffer in the buffadd path, this can cause treesitter textobj problem.)
				-- if vim.version().minor <= 7 then
				-- 	vim.filetype.match(node.abspath, previewee_buffer.id)
				-- else
				-- 	local ft = vim.filetype.match({ filename = node.abspath }) or ""
				-- 	vim.api.nvim_buf_set_option(previewee_buffer.id, "filetype", ft)
				-- end
			elseif mime_str:match("image/") or mime_str:match("video/") or mime_str:match("application/pdf") then
				previewee_buffer = ui.Buffer()
				post_previewee_window_open = function(win_id)
					if
						not Ueberzug({ win_id = win_id, kill_on_win_close = { win_id, previewer_win } }):add({
							x = panel_width,
							y = vimfn.tabline_end_pos() - 1,
							path = path,
							width = preview_width,
							height = vim.api.nvim_win_get_height(0),
							scaler = "contain",
						})
					then
						previewee_buffer:set_content_and_reload({ mime_str })
					end
					if vim.api.nvim_win_is_valid(win_id) then
						vim.api.nvim_win_set_option(win_id, "cursorline", false)
					end
				end
			else
				previewee_buffer = ui.Buffer({ content = { mime_str } })
			end
		end

		if previewee_buffer and vim.api.nvim_get_current_buf() == previewer_buffer.id and vimfn.getrow() == ori_row then
			M.close_all_preview_windows_in_current_tabpage()

			vim.cmd(("noautocmd rightbelow vert %d vsplit"):format(preview_width))
			local previewee_win = vim.api.nvim_get_current_win()
			-- Ranger buffer renders wrongly if there's any gutter. These window
			-- options are only set on first time entering the window (after the
			-- buffer is shown). We thus manually set them here.
			if node.type == "directory" then
				vim.api.nvim_win_set_option(previewee_win, "wrap", false)
				vim.api.nvim_win_set_option(previewee_win, "number", false)
				vim.api.nvim_win_set_option(previewee_win, "relativenumber", false)
			end
			vim.api.nvim_win_set_buf(previewee_win, previewee_buffer.id)
			vim.api.nvim_win_set_var(previewee_win, "ranger_previewer", previewer_win)

			local ori_eventignore = vim.o.eventignore
			vim.opt.eventignore:append("all")
			vim.api.nvim_set_current_win(previewer_win)
			vim.o.eventignore = ori_eventignore
			post_previewee_window_open(previewee_win)
		end
	end)()
end

return setmetatable(M, {
	__call = function()
		return M.preview()
	end,
})
