return function(Registry)
	local Replicated = require(game:GetService("ReplicatedStorage").Shared.Services.Replicator.Replicated)

	Registry:RegisterType("weapon", {
		Transform = function(Text)
			return Text
		end,

		Validate = function(Text)
			local Weapons = Replicated.Get("Weapons")
			if not Weapons then
				return false, "Weapon data not yet available."
			end
			for _, Name in ipairs(Weapons) do
				if Name == Text then
					return true
				end
			end
			return false, string.format("'%s' is not a valid weapon.", Text)
		end,

		Autocomplete = function()
			local Weapons = Replicated.Get("Weapons")
			if not Weapons then
				return {}
			end
			local Suggestions = {}
			for _, Name in ipairs(Weapons) do
				table.insert(Suggestions, Name)
			end
			return Suggestions
		end,
	})
end
