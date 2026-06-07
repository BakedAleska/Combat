--!nonstrict
-- @date : 06/04/2026

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- IMPORT
local Types = require(ReplicatedStorage.Shared.Types)

--- @class State
local State = {}
State.__index = State

--- @prop Duration number
--- @within State
--- The total duration of the State. A value of 0 is used for a State that will never be exited.

--- @prop Elapsed number
--- @within State
--- The amount of time the State has been ticked for.

--- @prop Name string
--- @within State
--- The name of the State object.

--- @prop Priority number
--- @within State
--- The priority of the State. Describes the point in the queue at which the State object will be placed. Clamped (1-99)

--- Creates a new State instance
--- @param Props table? -- Optional table used to override or add properties when extending.
--- @return State
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
--- @param dt number The delta time returned by RunService.Heartbeat.
function State:Update(dt: number) end

--- Destory a given state
function State:Destroy() end

return State
