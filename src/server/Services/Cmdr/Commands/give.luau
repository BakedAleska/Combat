local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Kinds = require(ReplicatedStorage.Shared.Configurations.Kinds)

return {
	Name = "give",
	Aliases = {},
	Description = "Give something to a player.",
	Group = "Data",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "The player to give it to.",
		},
		{
			Type = "kind",
			Name = "Kind",
			Description = "What to give.",
		},
		function(Context)
			local Arg = Context:GetArgument(2)
			local Kind = Arg and Arg:GetValue()
			local Descriptor = Kind and Kinds[Kind]
			if Descriptor then
				return Descriptor.Argument
			end
			return {
				Type = "string",
				Name = "Value",
				Description = "Choose a valid kind first.",
			}
		end,
	},
}
