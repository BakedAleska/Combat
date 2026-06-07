--!nonstrict
--!nolint
-- @date : 06/04/2026

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- TYPES
local Propogate = require(ServerScriptService.Server.Functions.Propogate)
local goodsignal = require(ReplicatedStorage.Packages.goodsignal)
local Types = require(ReplicatedStorage.Shared.Types)

--- @class StateMachine
local StateMachine = {}
StateMachine.__index = StateMachine

--- @prop _Queue table
--- @readonly
--- @within StateMachine
--- The StateMachine queue. Used to iterate States.

--- @prop CurrentState State
--- @within StateMachine
--- The State object which is being actively ticked.

--- @prop LastState State
--- @within StateMachine
--- The last State object the StateMachine was ticking.

--- @prop StateChanged Signal
--- @within StateMachine
--- @external Signal https://github.com/stravant/goodsignal
--- A goodsignal object; OldStateName, NewStateName parameters. Fires on state change.

--- Creates a new StateMachine instance.
--- @param StartIn State -- The default State object; used as a fallback and on startup.
--- @return StateMachine
function StateMachine.new(StartIn: Types.State)
	StartIn.Priority = 100

	local self = setmetatable({
		CurrentState = nil, -- The current state
		LastState = nil, -- The state that was just left.
		_Queue = { StartIn }, -- Priority sorted queue.

		StateChanged = goodsignal.new() :: Types.Signal<Types.State, Types.State>,
	}, StateMachine)

	-- Initialize states.
	for _, State in ipairs(script.States:GetChildren()) do
		require(State)
	end

	return self
end

--- Adds a state to the StateMachine queue.
--- Passes the StateMachine object to the target State.
--- @param Target State -- The state object to add to the queue.
function StateMachine:Transition(Target: Types.State)
	Target.Priority = math.clamp(Target.Priority, 1, 99)

	local TargetName = Target.Name
	if self.CurrentState == Target or (TargetName and self.CurrentState and self.CurrentState.Name == TargetName) then
		return false
	end

	for _, NextState in ipairs(self._Queue) do
		if NextState == Target or (TargetName and NextState.Name == TargetName) then
			return false
		end
	end

	Propogate(Target, {
		["StateMachine"] = self,
		["Humanoid"] = self.Humanoid,
		["Character"] = self.Character,
		["Entity"] = self.Entity,
	})

	Target.StateMachine = self

	for Index, NextState in ipairs(self._Queue) do
		if Target.Priority < NextState.Priority then
			table.insert(self._Queue, Index, Target)

			return true
		end
	end

	table.insert(self._Queue, #self._Queue, Target)
	return true
end

--- Clear the StateMachine's queue.
--- Used when a player needs to be forced idle.
function StateMachine:Clear()
	local IdleState = self._Queue[#self._Queue]
	table.clear(self._Queue)
	table.insert(self._Queue, IdleState)
end

--- Ticks the StateMachine.
--- Moves through states in the queue.
--- @param dt number -- DeltaTime returned by RunService.Heartbeat
function StateMachine:Update(dt: number)
	local NextState = self._Queue[1]
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
		table.remove(self._Queue, 1)
		return
	end

	self.CurrentState:Update(dt)
	self.CurrentState.Elapsed += dt

	if self.CurrentState.Duration and self.CurrentState.Elapsed >= self.CurrentState.Duration then
		table.remove(self._Queue, 1)
	end

	self.StateChanged:Fire(
		(self.LastState and self.LastState.Name) or nil,
		(self.CurrentState and self.CurrentState.Name) or nil
	)
end

--- Destroy the StateMachine.
--- Cleans up queued state objects and clears internal references.
--- @return boolean -- Whether destruction completed without errors.
function StateMachine:Destroy(): boolean
	local Success = true

	if self.CurrentState and type(self.CurrentState.OnExit) == "function" then
		local Ok, Err = pcall(self.CurrentState.OnExit, self.CurrentState)
		if not Ok then
			warn("[StateMachine] Failed to exit current state during destroy:", Err)
			Success = false
		end
	end

	for _, State in ipairs(self._Queue) do
		if type(State) == "table" and type(State.Destroy) == "function" then
			local Ok, Err = pcall(State.Destroy, State)
			if not Ok then
				warn("[StateMachine] Failed to destroy queued state:", Err)
				Success = false
			end
		end
	end

	table.clear(self._Queue)
	self.CurrentState = nil
	self.LastState = nil

	if self.StateChanged and type(self.StateChanged.Destroy) == "function" then
		local Ok, Err = pcall(self.StateChanged.Destroy, self.StateChanged)
		if not Ok then
			warn("[StateMachine] Failed to destroy StateChanged signal:", Err)
			Success = false
		end
	end

	return Success
end

return StateMachine
