local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cmdr = require(ReplicatedStorage.Packages.cmdr)

const WHITELIST = { 5106100492, 32084843 }

const DEFAULT_COMMANDS = { help = true, kick = true, clear = true }

Cmdr:RegisterTypesIn(script.Types)

Cmdr:RegisterDefaultCommands(function(Cmd)
	return DEFAULT_COMMANDS[Cmd.Name] == true
end)
Cmdr:RegisterCommandsIn(script.Commands)

Cmdr.Registry:RegisterHook("BeforeRun", function(context)
	local Executor = context.Executor
	if not Executor then
		return nil
	end

	for _, UserId in ipairs(WHITELIST) do
		if Executor.UserId == UserId then
			return nil
		end
	end

	return "You don't have permission to run commands."
end)
