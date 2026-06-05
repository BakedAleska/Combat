--!nonstrict
-- @date : 06/04/2026

-- SERIVCES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- IMPORT
local Types = require(ReplicatedStorage.Shared.Types)

-- TABLES
local RemoteEvents = {}

-- VARIABLES
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

-- Cache RemoteEvents
for _, RemoteEvent in ipairs(ReplicatedStorage.Shared.Events:GetChildren()) do
	if RemoteEvent:IsA("RemoteEvent") then
		RemoteEvents[RemoteEvent.Name] = RemoteEvent
	end
end

for _, InputAction in ipairs(script.Parent:GetDescendants()) do
	if InputAction:IsA("InputAction") then
		InputAction.Pressed:Connect(function()
			local RemoteEvent = RemoteEvents[InputAction.Name]
			if RemoteEvent then
				local ClientInfo = {
					KeysPressed = {},
					MouseLocation = Vector2.new(Mouse.X / Mouse.ViewSizeX, Mouse.Y / Mouse.ViewSizeY),
				} :: Types.ClientInfo
				for _, InputObject in pairs(UserInputService:GetKeysPressed()) do
					table.insert(ClientInfo.KeysPressed, InputObject.KeyCode)
				end

				RemoteEvent:FireServer(ClientInfo)
			else
				warn(`[ActionBinder] No such remote event for action {InputAction.Name}`)
			end
		end)
	end
end
