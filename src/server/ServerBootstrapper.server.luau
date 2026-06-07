-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- IMPORT
local Entity = require(ServerScriptService.Server.Classes.Entity)
local PlayerController = require(ServerScriptService.Server.Classes.PlayerController)
local StateMachine = require(ServerScriptService.Server.Classes.StateMachine)
local Idle = require(ServerScriptService.Server.Classes.StateMachine.States.Idle)
local Registry = require(ServerScriptService.Server.Services.Registry)

Players.PlayerAdded:Connect(function(Player: Player)
	local PlayerEntity = Entity.new(Player)
	PlayerEntity["PlayerController"] = PlayerController.new(Player)

	PlayerEntity["StateMachine"] = StateMachine.new(Idle.new())
	PlayerEntity["StateMachine"].Entity = PlayerEntity
	PlayerEntity["StateMachine"].Player = Player
	PlayerEntity["StateMachine"].Character = Player.Character
	PlayerEntity["StateMachine"].Humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
		or nil
	PlayerEntity["StateMachine"] = PlayerEntity["StateMachine"]

	PlayerEntity["_Heartbeat"] = RunService.Heartbeat:Connect(
		function(dt: number) -- Auto cleaned up on Entity destruction.
			PlayerEntity["StateMachine"]:Update(dt)
		end
	)

	Player.CharacterAdded:Connect(function(Character: Model)
		PlayerEntity["StateMachine"].Character = Character
		PlayerEntity["StateMachine"].Humanoid = Character:FindFirstChildOfClass("Humanoid")
		PlayerEntity["PlayerController"]:OnCharacterAdded(Character)
	end)
end)

Players.PlayerRemoving:Connect(function(Player: Player)
	local PlayerEntity = Registry.Get(Player.UserId)
	assert(PlayerEntity, "[ServerBootstrapper] Critical error. Leaving player has no such entity.")

	PlayerEntity:Destroy()
end)
