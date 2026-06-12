--!nonstrict

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- IMPORTS
local Janitor = require(ReplicatedStorage.Packages.janitor)
local Networker = require(ReplicatedStorage.Shared.Networker)
local Weapons = require(ServerScriptService.Server.Configurations.Weapons)
local ProfileService = require(ServerScriptService.Server.Services.ProfileService)
local Registry = require(ServerScriptService.Server.Services.Registry)
local StatefulMotor6D = require(ServerScriptService.Server.Services.StatefulMotor6D)

--- @class Weapon
--- Manages equip/unequip state and animations for a player's active weapon.
local Weapon = {}
Weapon.__index = Weapon

--- @param Player Player
--- @return Weapon
function Weapon.new(Player: Player)
	local self = setmetatable({
		Player = Player,
		GroupId = nil :: string?,
		_Equipped = false :: boolean,
		_Janitor = Janitor.new(),
	}, Weapon)

	self._Janitor:Add(Networker.Connect("Equip", function(SenderPlayer: Player)
		if SenderPlayer ~= self.Player then
			return
		end
		if not self.GroupId then
			return
		end
		if self._Equipped then
			self:Unequip()
		else
			self:Equip()
		end
	end), "Disconnect")

	return self
end

--- Called on each character spawn to attach the weapon model and reset equip state.
--- @param GroupId string
function Weapon:OnCharacterAdded(GroupId: string)
	self.GroupId = GroupId
	self._Equipped = false

	const Entity = Registry.Get(self.Player.UserId)
	if not Entity then
		return
	end

	const HeldMotor, SheathedMotor = ProfileService.GiveWeapon(self.Player, GroupId)
	if HeldMotor and SheathedMotor then
		if not Entity["Motor6DRegistry"] then
			Entity["Motor6DRegistry"] = {}
		end
		StatefulMotor6D.Relate(Entity, GroupId, SheathedMotor, HeldMotor)
	end
end

function Weapon:Equip()
	self._Equipped = true

	const Character = self.Player.Character
	if not Character then
		return
	end

	const WeaponConfig = Weapons[self.GroupId]
	if not WeaponConfig then
		return
	end

	const EquipAnim = WeaponConfig.EquipAnimation
	const UnequipAnim = WeaponConfig.UnequipAnimation

	if UnequipAnim and UnequipAnim ~= "" then
		Networker.Fire("stopAnimation", self.Player, Character, UnequipAnim)
	end
	if EquipAnim and EquipAnim ~= "" then
		Networker.Fire("playAnimation", self.Player, Character, EquipAnim)
	end

	const GroupId = self.GroupId
	task.delay(0.3, function()
		if not self._Equipped or self.GroupId ~= GroupId then
			return
		end
		const Entity = Registry.Get(self.Player.UserId)
		if Entity then
			StatefulMotor6D.Switch(Entity, GroupId, "Active")
		end
	end)

	const IdleAnim = WeaponConfig.IdleAnimation
	if IdleAnim and IdleAnim ~= "" then
		Networker.Fire("playAnimation", self.Player, Character, IdleAnim, {
			Looped = true,
			Group = "Idle",
			Priority = Enum.AnimationPriority.Idle,
		})
	end
end

function Weapon:Unequip()
	self._Equipped = false

	const Character = self.Player.Character
	if not Character then
		return
	end

	const WeaponConfig = Weapons[self.GroupId]
	if not WeaponConfig then
		return
	end

	const Entity = Registry.Get(self.Player.UserId)
	if not Entity then
		return
	end

	StatefulMotor6D.Switch(Entity, self.GroupId, "Passive")

	const EquipAnim = WeaponConfig.EquipAnimation
	const UnequipAnim = WeaponConfig.UnequipAnimation

	if EquipAnim and EquipAnim ~= "" then
		Networker.Fire("stopAnimation", self.Player, Character, EquipAnim)
	end
	Networker.Fire("stopAnimation", self.Player, Character, "Idle")
	if UnequipAnim and UnequipAnim ~= "" then
		Networker.Fire("playAnimation", self.Player, Character, UnequipAnim)
	end
end

function Weapon:Destroy()
	self._Janitor:Destroy()
	self.Player = nil :: any
	self.GroupId = nil :: any
	self._Janitor = nil :: any
	self._Equipped = nil :: any
end

return Weapon
