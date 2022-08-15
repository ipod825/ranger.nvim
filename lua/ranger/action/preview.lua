local M = {}
local utils = require("ranger.action.utils")
local Buffer = require("ranger.Buffer")
local vimfn = require("libp.utils.vimfn")
local ui = require("libp.ui")
local itt = require("libp.datatype.itertools")
local mime = require("libp.mime")
local a = require("plenary.async")

function M.close_all_preview_windows_in_current_tabpage()
	for w in itt.values(vim.api.nvim_tabpage_list_wins(0)) do
		if vimfn.win_get_var(w, "ranger_preview") then
			vim.api.nvim_win_close(w, true)
		end
	end
end

function M.preview()
	local buffer, node = utils.get_cur_buffer_and_node()
	local ori_row = vimfn.current_row()
	a.void(function()
		a.util.sleep(30)
		if vimfn.current_row() ~= ori_row then
			return
		end
		local preview_buffer
		if node.type == "header" then
			M.close_all_preview_windows_in_current_tabpage()
			return
		elseif node.type == "directory" then
			preview_buffer = Buffer.open(node.abspath, { open_cmd = "preview" })
		elseif node.type == "file" then
			local mime_str = mime.info(node.abspath)
			if mime_str:match("text") then
				preview_buffer = ui.FilePreviewBuffer(node.abspath)
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
			local grid = ui.Grid({ relative = "win" })
			local row = grid:add_row()
			row:add_column({ width = 40 })
			row:add_column():fill_window(
				ui.BorderedWindow(
					preview_buffer,
					{ wo = { wrap = true }, w = { ranger_preview = true } },
					{ border = { nil, nil, nil, nil, nil, nil, nil, "│" } }
				)
			)
			-- Not sure why BufEnter is even triggered. But that leads to ranger
			-- Buffer's CursorMoved handler to be called twice.
			local ori_eventignore = vim.o.eventignore
			vim.opt.eventignore:append("BufEnter")
			grid:show()
			vim.o.eventignore = ori_eventignore
		end
	end)()
end

return setmetatable(M, {
	__call = function()
		return M.preview()
	end,
})
