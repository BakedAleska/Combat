-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- IMPORT
local Entity = require(ServerScriptService.Server.Classes.Entity)
local PlayerController = require(ServerScriptService.Server.Classes.PlayerController)
local StateMachine = require(ServerScriptService.Server.Classes.StateMachine)
local Idle = require(ServerScriptService.Server.Classes.StateMachine.States.Idle)
local Propogate = require(ServerScriptService.Server.Functions.Propogate)
local Registry = require(ServerScriptService.Server.Services.Registry)
local Networker = require(ReplicatedStorage.Shared.Networker)

Networker.Event("playAnimation")
Networker.Event("stopAnimation")
Networker.Event("modifyAnimation")
Networker.Event("cancelAnimations")
Networker.Event("applyLinearVelocity")
Networker.Event("applyAdaptiveLinearVelocity")
Networker.Event("applyAssemblyLinearVelocity")
Networker.Event("destroyForces")
Networker.Event("emitEffect")
Networker.Event("invokeEffect")
Networker.Event("Dash")
Networker.Event("Sprint")

Players.PlayerAdded:Connect(function(Player: Player)
	local PlayerEntity = Entity.new(Player)
	PlayerEntity["PlayerController"] = PlayerController.new(Player)
	PlayerEntity["StateMachine"] = StateMachine.new(Idle.new())
	Propogate(PlayerEntity["StateMachine"], {
		Entity = PlayerEntity,
		Character = Player.Character,
		Humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") or nil,
	})
	PlayerEntity["_Heartbeat"] = RunService.Heartbeat:Connect(function(dt: number)
		PlayerEntity["StateMachine"]:Update(dt)
	end)
	Player.CharacterAdded:Connect(function(Character: Model)
		Propogate(PlayerEntity["StateMachine"], {
			Character = Character,
			Humanoid = Character:FindFirstChildOfClass("Humanoid"),
		})
		PlayerEntity["PlayerController"]:OnCharacterAdded(Character)
	end)
end)

Players.PlayerRemoving:Connect(function(Player: Player)
	local PlayerEntity = Registry.Get(Player.UserId)
	assert(PlayerEntity, "[ServerBootstrapper] Critical error. Leaving player has no such entity.")
	PlayerEntity:Destroy()
end)
