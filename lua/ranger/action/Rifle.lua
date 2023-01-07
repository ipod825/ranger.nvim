local M = require("libp.datatype.Class"):EXTEND()
local fs = require("libp.fs")
local constants = require("ranger.constants")
local vimfn = require("libp.utils.vimfn")
local List = require("libp.datatype.List")
local osfn = require("libp.utils.osfn")
local iter = require("libp.iter")
local a = require("plenary.async")

function M.Rule(fn, ...)
	local args = { ... }
	return function()
		fn(unpack(args))
	end
end

local Rule = require("libp.datatype.Class"):EXTEND()

function Rule:init(...)
	self.args = { ... }
end

M.rules = {}

M.has = Rule:EXTEND({
	__call = function(this)
		return osfn.is_in_path(this.args[1])
	end,
})

M.ext = Rule:EXTEND({
	__call = function(this, fname)
		return vim.endswith(fname, "." .. this.args[1])
	end,
})

M.isdir = Rule:EXTEND({
	__call = function(_, fname)
		return fs.is_directory(fname)
	end,
})

function M:init(config_file)
	vim.validate({ config_file = { config_file, "s" } })
	if not fs.is_readable(config_file) then
		local _, err = fs.copy(constants.default_rifle_conf, config_file)
		if err then
			vimfn.info(("Fail to copy rifle config: %s"):format(err))
			return
		end
	end

	self.rules = List()
	local i = 0
	for line in io.lines(config_file) do
		i = i + 1
		line = vim.trim(line:gsub("#.*", ""))
		if #line > 0 then
			local sp = vim.split(line, "=")
			if #sp ~= 2 then
				Vim.ErrorMsg(
					('invalid rule: rifle.conf line %d. There should be one and only one "=" for each line'):format(
						i + 1
					)
				)
			end

			local tests = List()
			for test in iter.values(vim.split(sp[1], ",")) do
				local test_sp = List(vim.split(test, " ")):filter(function(e)
					return #e > 0
				end)
				tests:append(M[test_sp[1]](unpack(vim.list_slice(test_sp, 2))))
			end

			local command = vim.trim(sp[2])
			-- Simple case, user specify only the command. For sophisicated
			-- command like bash -c "command %s" user should add '%s' themselves
			if not command:match("%%s") then
				command = command .. ' "%s"'
			end

			self.rules:append({ tests, command })
		end
	end
end

function M:decide_open_cmd(path)
	for rule in iter.values(self.rules) do
		local succ = true
		local tests, command = unpack(rule)
		for test in iter.values(tests) do
			if not test(path) then
				succ = false
				break
			end
			if succ then
				return command:format(path)
			end
		end
	end
end

function M:list_available_cmd(path)
	local res = List()
	for rule in iter.values(self.rules) do
		local succ = true
		local tests, command = unpack(rule)
		for test in iter.values(tests) do
			if not test(path) then
				succ = false
				break
			end
		end
		if succ then
			res:append(command)
		end
	end
	return res
end

return M
