local States = {}
States.__index = States

local TableUtil = path to sleitnick's tableutil
local Maid = path to quentys's maid

-- Private Methods
function States.new(reducer)
	assert(reducer,"A reducer must be provided to the state manager on creation")

	local this = setmetatable({
		__states = {},
		__action_binds = {},
		__action_cleanups = {},
		__index = 0,
		__reducer = reducer,
		state = nil,
		Maid = Maid.new()
	}, States)

	return this
end

function States:__set_state(newState)
	if newState == self.state then
		return
	end

	local oldState = self.state

	-- Clear old connections
	self.Maid:DoCleaning()
	self.state = newState

	local cleanupTask = self.__action_cleanups[newState]
	local actionStart = self.__action_binds[newState]
	local defaultStart = self.__default_bind

	if cleanupTask then
		coroutine.wrap(function()
			cleanupTask(self, newState, oldState)
		end)()
	end

	if actionStart then
		actionStart(self, newState, oldState)
	end

	if defaultStart then
		coroutine.wrap(function()
			defaultStart(self, newState, oldState)
		end)()
	end

	self.Maid:DoCleaning()
end

-- Reducers
States.Reducers = {
	And = function(_,states)
		local value = true

		for _,newValue in pairs(states) do
			value = value and newValue
		end

		return value
	end,

	Or = function(_,states)
		local value

		for _,newValue in pairs(states) do
			value = value or newValue
		end

		return value
	end,

	Last = function(_,_,value)
		return value
	end
}

States.Reducers.Any = States.Reducers.Or
States.Reducers.All = States.Reducers.And

-- Public Methods
function States:Push(value,port)
	port = port or "DEFAULT_PORT"

	self.__states[port] = value

	local newState = self.__reducer(self,self.__states,value)
	self:__set_state(newState)
end

--- Runs a function when state is commenced
function States:Connect(stateValue,func)
	if not func then
		self.__default_bind = stateValue
	else
		self.__action_binds[stateValue] = func
	end

	return self
end

--- Runs function when state terminates
function States:BindMaid(stateValue,func)
	assert(func,"Cannot bind nil function!")
	self.__action_cleanups[stateValue] = func
	return self
end

function States:Clone()
	return TableUtil.Copy(self)
end

return States
