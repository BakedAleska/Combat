--!nonstrict
-- Holds data

-- SERVICES
local ServerScriptService = game:GetService("ServerScriptService")

-- IMPORT
local Registry = require(ServerScriptService.Server.Services.Registry)

--- @class Entity
--- Data container associated with a player or NPC in the game world.
--- Holds all runtime state for an entity: stun, modifiers, controllers, and any other attached services.
--- Registered to the Registry on creation for retrieval by key (UserId for players, Instance for NPCs).
local Entity = {}
Entity.__index = Entity

--- Returns a table of data, meant to be associated with player or NPC entities.
--- E.G.: Holds "Stun" value to keep track of stun,
--- E.G.: Holds "WalkSpeedModifier" table so the WalkSpeedUtils service can modify the entity accordingly.
--- @param RegistryKey Instance? -- Allows optional retrieval through Registry.
--- @return Entity
function Entity.new(RegistryKey: Instance?)
	local self = setmetatable({}, Entity)

	if RegistryKey then
		if RegistryKey:IsA("Player") then
			Registry.Register(RegistryKey.UserId, self)
		else
			Registry.Register(RegistryKey, self)
		end
	else
		warn(
			"[Entity] Entities should be created with a RegistryKey Instance. Expect difficulties when retrieving data."
		)
	end

	return self
end

--- Clean up an entity. Destroy all classes, objects, instances, etc stored in the entity.
--- @return boolean -- Whether the destroy method met a snag or not.
function Entity:Destroy(): boolean
	local Success = true
	local Visited = {}

	local function GetMethod(Value, MethodName)
		local Ok, Method = pcall(function()
			return Value[MethodName]
		end)
		if Ok and type(Method) == "function" then
			return Method
		end
		return nil
	end

	local function Cleanup(Value, IsRoot)
		local Type = type(Value)

		if Type == "table" then
			if Visited[Value] then
				return
			end
			Visited[Value] = true
		end

		if (Type == "table" or Type == "userdata") and not IsRoot then
			local DestroyMethod = GetMethod(Value, "Destroy")
			local DisconnectMethod = GetMethod(Value, "Disconnect")

			if DestroyMethod then
				local Ok, Err = pcall(DestroyMethod, Value)
				if not Ok then
					warn("[Entity] Failed to destroy child value:", Err)
					Success = false
				end
			elseif DisconnectMethod then
				local Ok, Err = pcall(DisconnectMethod, Value)
				if not Ok then
					warn("[Entity] Failed to disconnect child value:", Err)
					Success = false
				end
			end
		end

		if Type == "table" then
			for Key, Child in pairs(Value) do
				Cleanup(Key)
				Cleanup(Child)
				Value[Key] = nil
			end
			setmetatable(Value, nil)
		end
	end

	Cleanup(self, true)

	return Success
end

return Entity
