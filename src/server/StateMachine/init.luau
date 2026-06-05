--!nonstrict
--!nolint
-- @date : 06/04/2026

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- TYPES
local Types = require(ReplicatedStorage.Shared.Types)

local StateMachine = {}
StateMachine.__index = StateMachine

--- Creates a new StateMachine instance.
--- @class StateMachine
--- @param StartIn State The State object the StateMachine starts in.
function StateMachine.new(StartIn: Types.State)
	StartIn.Priority = 100

	local self = setmetatable({
		CurrentState = nil, -- The current state
		LastState = nil, -- The state that was just left.
		Queue = { StartIn }, -- Priority sorted queue.
	}, StateMachine)

	return self
end

--- Adds a state to the StateMachine queue.
--- Passes the StateMachine object to the target State.
--- @param Target State The state object to add to the queue.
function StateMachine:Transition(Target: Types.State)
	Target.Priority = math.clamp(Target.Priority, 1, 99)

	Target.StateMachine = self

	for Index, NextState in ipairs(self.Queue) do
		if Target.Priority < NextState.Priority then
			table.insert(self.Queue, Index, Target)

			return
		end
	end

	table.insert(self.Queue, #self.Queue, Target)
end

--- Clear the StateMachine's queue.
--- @usage When a player needs to be forced idle.
function StateMachine:Clear()
	local IdleState = self.Queue[#self.Queue]
	table.clear(self.Queue)
	table.insert(self.Queue, IdleState)
end

--- Ticks the StateMachine.
--- Moves through states in the queue.
--- @param dt number DeltaTime returned by RunService.Heartbeat
function StateMachine:Update(dt: number)
	local NextState = self.Queue[1]
	if not NextState then
		return
	end

	if self.CurrentState ~= NextState then
		if self.CurrentState then
			self.LastState = self.CurrentState
			self.CurrentState:OnExit()
		end
		self.CurrentState = NextState
		self.CurrentState:OnEnter()
	end

	if not self.CurrentState.Update then
		warn("[StateMachine] Critical error. Corrupted state object.")
		table.remove(self.Queue, 1)
		return
	end

	self.CurrentState:Update(dt)
	self.CurrentState.Elapsed += dt

	if self.CurrentState.Duration and self.CurrentState.Elapsed >= self.CurrentState.Duration then
		table.remove(self.Queue, 1)
	end
end

return StateMachine
