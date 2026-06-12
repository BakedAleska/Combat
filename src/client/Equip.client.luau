-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- IMPORTS
const Networker = require(ReplicatedStorage.Shared.Networker)

UserInputService.InputBegan:Connect(function(Input: InputObject, GameProcessed: boolean)
	if GameProcessed then
		return
	end
	if Input.KeyCode == Enum.KeyCode.C then
		Networker.Fire("Equip")
	end
end)
