return {
	Name = "wipe",
	Aliases = {},
	Description = "Wipes a player's profile data and kicks them.",
	Group = "Data",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "The player to wipe.",
		},
	},
}
