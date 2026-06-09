-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- IMPORT
local Types = require(ReplicatedStorage.Shared.Types)
local State = require(script.Parent.Parent.State)
local Sprinting = require(script.Parent.Sprinting)
local Extend = require(ServerScriptService.Server.Functions.Extend)
local CooldownHandler = require(ServerScriptService.Server.Services.CooldownHandler)
local Registry = require(ServerScriptService.Server.Services.Registry)
local Networker = require(ReplicatedStorage.Shared.Networker)

local Dashing = Extend(State, { ["Name"] = "Dashing", Priority = 9 })

function Dashing:OnEnter()
	Networker.Fire("playAnimation", self.Character, self._Direction .. "Dash", { Looped = false })

	Networker.Fire("applyAdaptiveLinearVelocity", self.Character, Vector3.new(58, 0, 0), self.Duration, self._Direction)

	--TODO(sound): Dash

	if self.StateMachine.LastState.Name == "Sprinting" then
		local WasLongSprint = self.StateMachine.LastState._LongSprintActive
		self.StateMachine:Transition(Sprinting.new({ _LongSprintActive = WasLongSprint }))
	end
end

function Dashing:OnExit()
	CooldownHandler.Add(self.Entity, "Dash")
end

Networker.Connect("Dash", function(Player: Player, ClientInfo: Types.ClientInfo)
	if ClientInfo.State ~= "Pressed" then
		return
	end

	local Entity = Registry.Get(Player.UserId)
	assert(Entity, "[Sprinting] Invalid entity.")

	if CooldownHandler.Has(Entity, "Dash") then
		return
	end

	local Direction = "Forward"

	for Index = #ClientInfo.KeysPressed, 1, -1 do
		local KeyCode = ClientInfo.KeysPressed[Index]
		if KeyCode == Enum.KeyCode.W then
			Direction = "Forward"
			break
		elseif KeyCode == Enum.KeyCode.S then
			Direction = "Backward"
			break
		elseif KeyCode == Enum.KeyCode.A then
			Direction = "Left"
			break
		elseif KeyCode == Enum.KeyCode.D then
			Direction = "Right"
			break
		end
	end

	Entity.StateMachine:Transition(Dashing.new({ ["_Direction"] = Direction, Duration = 0.22 }))
end)

return Dashing
