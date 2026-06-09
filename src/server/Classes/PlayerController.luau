--!strict

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- IMPORT
local Replicator = require(ReplicatedStorage.Shared.Services.Replicator)
local Weapons = require(ServerScriptService.Server.Configurations.Weapons)
local ProfileService = require(ServerScriptService.Server.Services.ProfileService)

--- @class PlayerController
--- Manages initial player / character loads.
--- Ensures smooth data and character handling.
local PlayerController = {}
PlayerController.__index = PlayerController

--- Creates a new PlayerController and begins loading the player's profile and character.
--- @param Player Player
--- @return PlayerController
function PlayerController.new(Player: Player)
	local self = setmetatable({
		Player = Player,
		Character = nil :: Model?,
		Humanoid = nil :: Humanoid?,
		_Replicator = nil :: any,
		_Profile = nil :: any,
	}, PlayerController)

	Player.CharacterAdded:Connect(function(Character: Model)
		self:OnCharacterAdded(Character)
	end)

	-- Load profile first, then spawn character so data is available immediately
	task.spawn(function()
		ProfileService.Load(Player)
		self._Profile = ProfileService.Get(Player)
		local WeaponNames = {}
		for Name in pairs(Weapons) do
			table.insert(WeaponNames, Name)
		end
		self._Replicator = Replicator.new(Player, {
			Weapons = WeaponNames,
		})
		if Player.Parent then
			if Player.Character then
				self:OnCharacterAdded(Player.Character)
			else
				Player:LoadCharacterAsync()
			end
		end
	end)

	return self
end

--- Called when the character spawns. Sets up game-specific character state.
--- @param Character Model
function PlayerController:OnCharacterAdded(Character: Model)
	self.Character = Character
	self.Humanoid = Character:FindFirstChildOfClass("Humanoid")

	local Humanoid = self.Humanoid
	if Humanoid then
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	end

	local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if Root then
		local GroundAttachment = Instance.new("Attachment")
		GroundAttachment.Name = "GroundAttachment"
		GroundAttachment.CFrame = CFrame.new(0, -2.85, 0)
		GroundAttachment.Parent = Root
	end

	--TODO: Enforce no accessories
	--TODO: Apply custom outfit

	if self._Profile and self._Profile.Data["Weapon"] then
		ProfileService.GiveWeapon(self.Player, self._Profile.Data["Weapon"])
	end
end

--- Ends the player's profile session and cleans up the controller.
--- @return boolean
function PlayerController:Destroy(): boolean
	local Ok, Err = pcall(function()
		if self.Player then
			ProfileService.Unload(self.Player)
		end
		if self.Character then
			self.Character:Destroy()
		end
	end)

	if not Ok then
		warn("[PlayerController] Failed to destroy:", Err)
	end

	self.Player = nil :: any
	self.Character = nil :: any
	self.Humanoid = nil :: any
	self._Profile = nil :: any

	return Ok
end

return PlayerController
