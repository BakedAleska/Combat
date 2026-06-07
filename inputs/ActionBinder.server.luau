--!nonstrict
-- @date : 06/04/2026

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- IMPORT
local Types = require(ReplicatedStorage.Shared.Types)
local Networker = require(ReplicatedStorage.Shared.Networker)

-- VARIABLES
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

for _, InputAction in ipairs(script.Parent:GetDescendants()) do
	if InputAction:IsA("InputAction") then
		local function FireInputState(State: string)
			local ClientInfo = {
				State = State,
				KeysPressed = {},
				MouseLocation = Vector2.new(Mouse.X / Mouse.ViewSizeX, Mouse.Y / Mouse.ViewSizeY),
			} :: Types.ClientInfo

			for _, InputObject in pairs(UserInputService:GetKeysPressed()) do
				table.insert(ClientInfo.KeysPressed, InputObject.KeyCode)
			end

			Networker.Fire(InputAction.Name, ClientInfo)
		end

		InputAction.Pressed:Connect(function()
			FireInputState("Pressed")
		end)

		InputAction.Released:Connect(function()
			FireInputState("Released")
		end)
	end
end
