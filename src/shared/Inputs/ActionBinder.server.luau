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
		local function FireInputState(State: string)
			local RemoteEvent = RemoteEvents[InputAction.Name]
			if not RemoteEvent then
				warn(`[ActionBinder] No such remote event for action {InputAction.Name}`)
				return
			end

			local ClientInfo = {
				State = State,
				KeysPressed = {},
				MouseLocation = Vector2.new(Mouse.X / Mouse.ViewSizeX, Mouse.Y / Mouse.ViewSizeY),
			} :: Types.ClientInfo

			for _, InputObject in pairs(UserInputService:GetKeysPressed()) do
				table.insert(ClientInfo.KeysPressed, InputObject.KeyCode)
			end

			RemoteEvent:FireServer(ClientInfo)
		end

		InputAction.Pressed:Connect(function()
			FireInputState("Pressed")
		end)

		InputAction.Released:Connect(function()
			FireInputState("Released")
		end)
	end
end
