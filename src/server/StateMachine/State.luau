--!nonstrict
-- @date : 06/04/2026

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- IMPORT
local Types = require(ReplicatedStorage.Shared.Types)

local State = {}
State.__index = State

--- Creates a new State instance
--- @class State
--- @param Props table? Optional table of properties to override or add properties.
function State.new(Props: {}?)
	local self = setmetatable({
		Name = nil,
		Priority = 99, -- Any priority less than 1 or greater than 99 is invalid and will be ignored.
		Elapsed = 0,
		Duration = nil,
	}, State)
	if type(Props) == "table" then
		for Key, Value in pairs(Props) do
			self[Key] = Value
		end
	end
	return self :: Types.State
end

--- Called by the StateMachine when entering a state.
function State:OnEnter() end

--- Called by the StateMachine when exiting a state.
function State:OnExit() end

--- Called each frame by the StateMachine.
function State:Update(dt: number) end

return State
