local M = require("libp.datatype.Class"):EXTEND()
local Set = require("libp.datatype.Set")
local functional = require("libp.functional")

function M:init(states_and_controls)
	self.fallback_controller = nil
	self.controllers = {}
	self.all_controllers = {}
	for state, control in pairs(states_and_controls) do
		local controller
		if control.is_fallback_state then
			assert(not self.fallback_state, "Can set only one fallback state")
			controller = { nodes = Set(), set = control.set or functional.nop }
			self.fallback_state = state
			self.fallback_controller = controller
		else
			controller = { nodes = Set(), set = control.set or functional.nop }
			self.controllers[state] = controller
		end
		self.all_controllers[state] = controller
	end
	assert(self.fallback_controller, "Must set one fallback state")
end

function M:is(node, state)
	if state == self.fallback_state then
		if Set.has(self.fallback_controller.nodes, node) then
			return true
		end
		for _, controller in pairs(self.controllers) do
			if Set.has(controller.nodes, node) then
				return false
			end
		end
		return true
	else
		return Set.has(self.controllers[state].nodes, node)
	end
end

function M:set(node, state, ...)
	for _, controller in pairs(self.all_controllers) do
		Set.remove(controller.nodes, node)
	end
	Set.add(self.all_controllers[state].nodes, node)
	self.all_controllers[state].set(node, ...)
end

function M:get(state)
	return self.all_controllers[state].nodes
end

function M:clear()
	for _, controller in pairs(self.controllers) do
		for node in Set.values(controller.nodes) do
			self.fallback_controller.set(node)
		end
	end
	for _, controller in pairs(self.all_controllers) do
		controller.nodes = Set()
	end
end

return M
