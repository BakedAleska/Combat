local ServerStorage = game:GetService("ServerStorage")
return {
	["Katana"] = {
		Held = { C0 = CFrame.new(0, -1, 0), Parent = "Right Arm" },
		Sheathed = {
			C0 = CFrame.new(-1.1, -0.5, -2) * CFrame.Angles(math.rad(20), math.rad(180), 0),
			Parent = "Torso",
		},
		Sheathe = {
			C0 = CFrame.new(-1.1, -1.6, 1.27) * CFrame.Angles(math.rad(20), math.rad(180), 0),
			Parent = "Torso",
		},
		WeaponModel = ServerStorage.Assets.Weapons.Katana,
		SheatheModel = ServerStorage.Assets.Weapons.Sheathes.MediumSheathe,
		AttackAnimations = {},
		IdleAnimation = "rbxassetid://133946831099209",
		EquipAnimation = "rbxassetid://110597343189770",
		UnequipAnimation = "",
		Description = "A loyal blade.",
		Type = "Medium",
	},
}
