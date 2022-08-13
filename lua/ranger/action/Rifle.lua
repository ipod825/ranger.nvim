local M = require("libp.datatype.Class"):EXTEND()
local fs = require("libp.fs")
local constants = require("ranger.constants")
local vimfn = require("libp.utils.vimfn")
local List = require("libp.datatype.List")
local osfn = require("libp.utils.osfn")
local itt = require("libp.datatype.itertools")
local a = require("plenary.async")

function M.Rule(fn, ...)
	local args = { ... }
	return function()
		fn(unpack(args))
	end
end

M.rules = {}
function M.register_rule(rule_name, fn)
	M.rules[rule_name] = fn
end

function M.has(name)
	return osfn.is_in_path(name)
end

function M.isdir(name)
	return fs.is_directory(name)
end

function M.ext(extension, name)
	return vim.endswith(name, "." .. extension)
end

function M:init(config_file)
	vim.validate({ config_file = { config_file, "s" } })
	if not fs.is_readable(config_file) then
		local _, err = fs.copy(constants.default_rifle_conf, config_file)
		if err then
			vimfn.info(("Fail to copy rifle config: %s"):format(err))
			return
		end
	end

	self.rules = {}
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

			local conditions, command = sp[1], sp[2]
			-- Simple case, user specify only the command. For sophisicated
			-- command like bash -c "command %s" user should add '%s' themselves
			if not command:match("%%s") then
				command = command .. ' "%s"'
			end

			local condition_fns = List(vim.split(conditions, ",")):map(function(condition_str)
				local condition_sp = List(vim.split(condition_str, " ")):filter(function(e)
					return #e > 0
				end)
				return function(path)
					return M[condition_sp[1]](unpack(vim.list_slice(condition_sp, 2, #condition_sp)), path)
				end
			end)
			table.insert(self.rules, {
				condition = function(path)
					for condition_fn in itt.values(condition_fns) do
						if not condition_fn(path) then
							return false
						end
						return true
					end
				end,
				command = command,
			})
		end
	end
end

function M:decide_open_cmd(path)
	for _, rule in ipairs(self.rules) do
		if rule.condition(path) then
			return rule.command
		end
	end
end

function M:list_available_cmd(path)
	local res = {}
	for _, rule in ipairs(self.rules) do
		if rule.condition(path) then
			table.insert(res, rule.command)
		end
	end
	return res
end

return M
