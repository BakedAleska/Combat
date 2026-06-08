-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- IMPORTS
local CharacterController = require(script.Parent.CharacterController)
local Animations = require(ReplicatedStorage.Shared.Utilities.Animations)
local Effects = require(ReplicatedStorage.Shared.Utilities.Effects)
local Forces = require(ReplicatedStorage.Shared.Utilities.Forces)
local Replica = require(ReplicatedStorage.Packages.replica)
local Replicated = require(ReplicatedStorage.Shared.Services.Replicator.Replicated)

local Player = Players.LocalPlayer

Player.CharacterAdded:Connect(CharacterController.OnCharacterAdded)

if Player.Character then
	CharacterController.OnCharacterAdded(Player.Character)
end

-- INITIALIZE
Animations.Listen()
Effects.Listen()
Forces.Listen()

-- REPLICA
Replica.RequestData()
Replica.OnNew("PlayerData", function(Replica)
	if Replica.Tags.UserId ~= Player.UserId then
		return
	end

	Replicated._Set(Replica.Data)

	Replica.Maid:Add(function()
		Replicated.Clear()
	end)
end)
