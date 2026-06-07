--!nonstrict

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- IMPORT
local Cooldowns = require(ServerScriptService.Server.Configurations.Cooldowns)
local Types = require(ReplicatedStorage.Shared.Types)

local CooldownHandler = {}

function CooldownHandler.Add(Entity: Types.Entity, Key: string, Duration: number?): boolean
	if not Entity.Cooldowns then
		Entity.Cooldowns = {}
	end

	if Entity.Cooldowns[Key] then
		return false
	end

	local CooldownDuration = Duration or Cooldowns[Key] or nil

	if not CooldownDuration then
		warn(`[CooldownHandler] No such duration found for key: {Key} ... defaulting to 1.`)
		CooldownDuration = 1
	end

	Entity.Cooldowns[Key] = true

	task.delay(CooldownDuration, function()
		if Entity.Cooldowns then
			Entity.Cooldowns[Key] = nil
		end
	end)

	return true
end

function CooldownHandler.Has(Entity: Types.Entity, Key: string): boolean
	return Entity.Cooldowns and Entity.Cooldowns[Key] == true
end

function CooldownHandler.Remove(Entity: Types.Entity, Key: string): boolean
	if not Entity.Cooldowns or not Entity.Cooldowns[Key] then
		return false
	end

	Entity.Cooldowns[Key] = nil
	return true
end

return CooldownHandler
