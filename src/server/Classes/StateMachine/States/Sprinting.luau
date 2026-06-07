-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- IMPORT
local Types = require(ReplicatedStorage.Shared.Types)
local State = require(script.Parent.Parent.State)
local Extend = require(ServerScriptService.Server.Functions.Extend)
local Registry = require(ServerScriptService.Server.Services.Registry)
local WalkSpeedUtils = require(ServerScriptService.Server.Services.WalkSpeedUtils)

local Sprinting = Extend(State, { ["Name"] = "Sprinting", Priority = 10 })
local SPRINT_SPEED = 34

function Sprinting:OnEnter()
	local Humanoid = self.StateMachine and self.StateMachine.Humanoid
	if not Humanoid then
		return
	end

	self._Humanoid = Humanoid
	self._Last = nil
	WalkSpeedUtils:Set(Humanoid, SPRINT_SPEED)

	ReplicatedStorage.Shared.Events.playAnimation:FireAllClients(self.StateMachine.Character, "Sprint")
end

function Sprinting:Update()
	local Humanoid = self._Humanoid or (self.StateMachine and self.StateMachine.Humanoid)
	if not Humanoid then
		return
	end

	-- Slow down animation when midair
	local New = Humanoid.FloorMaterial == Enum.Material.Air and 0.25 or 1

	if self._Last ~= New then
		self._Last = New
		ReplicatedStorage.Shared.Events.modifyAnimation:FireAllClients(
			self.StateMachine.Character,
			"Sprint",
			"Speed",
			New
		)
	end
end

function Sprinting:OnExit()
	local Humanoid = self._Humanoid or (self.StateMachine and self.StateMachine.Humanoid)
	if not Humanoid then
		return
	end

	WalkSpeedUtils:Default(Humanoid)
	ReplicatedStorage.Shared.Events.stopAnimation:FireAllClients(self.StateMachine.Character, "Sprint", 0.25)
end

ReplicatedStorage.Shared.Events.Sprint.OnServerEvent:Connect(function(Player: Player, ClientInfo: Types.ClientInfo)
	local Entity = Registry.Get(Player.UserId)
	assert(Entity, "[Sprinting] Invalid entity.")

	if ClientInfo.State == "Pressed" then
		Entity.StateMachine:Transition(Sprinting.new())
	elseif ClientInfo.State == "Released" then
		Entity.StateMachine:Clear()
	end
end)

return Sprinting
