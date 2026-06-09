local ServerStorage = game:GetService("ServerStorage")
return {
	["Katana"] = {
		ActiveC0 = CFrame.new(0, -1, 0),
		PassiveC0 = CFrame.new(-1.25, -0.7, -1.75) * CFrame.Angles(math.rad(15), math.rad(180), 0),
		InactiveC0 = CFrame.new(-1.25, -0.8, -1.75) * CFrame.Angles(math.rad(15), 0, 0),
		WeaponModel = ServerStorage.Assets.Weapons.Katana,
		SheatheModel = ServerStorage.Assets.Weapons.Sheathes.LeatherSheathe,
		Description = "A loyal blade.",
	},
}
