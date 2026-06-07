--!nonstrict

--- @class PlayerController
local PlayerController = {}
PlayerController.__index = PlayerController

--- Create a new PlayerController, necessary to spawn a character properly.
--- @param Player Player -- The player associated with the PlayerController object.
--- @return PlayerController
function PlayerController.new(Player: Player)
	local self = setmetatable({
		Player = Player,
		Character = Player.Character,
		Humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") or nil,
	}, PlayerController)

	if Player.Character then
		self.Character = Player.Character
	else
		Player:LoadCharacterAsync()
	end

	return self
end

--- Called on character added to do game specific things.
--- @param Character Model -- The character added.
function PlayerController:OnCharacterAdded(Character: Model)
	self.Character = Character
	self.Humanoid = Character:FindFirstChildOfClass("Humanoid")

	--TODO: Enforce no accesories
	--TODO: Add custom outfit
	--TODO: Equip weapons and accesories
end

--- Clean up this PlayerController.
--- @return boolean -- Whether destroy completed without errors.
function PlayerController:Destroy(): boolean
	local Success = true

	if self.Character and type(self.Character.Destroy) == "function" then
		local Ok, Err = pcall(self.Character.Destroy, self.Character)
		if not Ok then
			warn("[PlayerController] Failed to destroy character:", Err)
			Success = false
		end
	end

	self.Player = nil
	self.Character = nil
	self.Humanoid = nil

	return Success
end

return PlayerController
