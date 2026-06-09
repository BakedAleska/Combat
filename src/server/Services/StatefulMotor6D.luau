--!nonstrict

-- SERVICES
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- IMPORT
local Types = require(ReplicatedStorage.Shared.Types)

--- @class StatefulMotor6D
--- Allows the creation of "Stateful" Motor6Ds.
--- Enables relationships between 2 Motor6Ds, mostly for the purpose of equipping and unequipping anything more easily.

--- @prop Motor6DRegistry { [string]: { Passive: Motor6D, Active: Motor6D } }
--- @within StatefulMotor6D
--- Registry of all related Motor6D groups on the entity, keyed by GroupId.

local StatefulMotor6D = {}

--- Creates a standalone Motor6D connecting `Part0` to `Handle`, parented to `Part0`.
--- @param Part0 BasePart -- The part that owns and drives the Motor6D (e.g. a character limb).
--- @param Handle BasePart -- The part to connect to via Part1 (e.g. a weapon handle).
--- @param Properties {}? -- A table of additional Motor6D properties to apply on creation.
--- @return Motor6D
function StatefulMotor6D.Create(Part0: BasePart, Handle: BasePart, Properties: {}?)
	local Motor6D = Instance.new("Motor6D")
	Motor6D.Part0 = Part0
	Motor6D.Part1 = Handle
	Motor6D.Enabled = false
	Motor6D.Name = "StatefulMotor6D"
	Motor6D.Parent = Part0

	if Properties then
		for Property, Value in pairs(Properties) do
			print("[StatefulMotor6D] property assigned:", Property, Value)
			if Motor6D[Property] then
				Motor6D[Property] = Value
			end
		end
	end

	return Motor6D
end

--- Relates a Passive and Active Motor6D under a shared `GroupId` on the given `Entity`.
--- Tags are applied for Studio visibility. The relationship is stored in `Entity.Motor6DRegistry`.
--- @param Entity Types.Entity -- The entity that owns the registry.
--- @param GroupId string -- A unique identifier for this motor group.
--- @param Passive Motor6D -- The motor used in the passive (unequipped/idle) state.
--- @param Active Motor6D -- The motor used in the active (equipped/in-use) state.
function StatefulMotor6D.Relate(Entity: Types.Entity, GroupId: string, Passive: Motor6D, Active: Motor6D)
	CollectionService:AddTag(Passive, "StatefulMotor6D")
	CollectionService:AddTag(Active, "StatefulMotor6D")
	Entity["Motor6DRegistry"][GroupId] = { ["Passive"] = Passive, ["Active"] = Active }
end

--- Reads the relationship of a Motor6D from the given `Entity`'s registry.
--- Returns the full group entry and the role of the given motor (`"Passive"` or `"Active"`).
--- @param Entity Types.Entity -- The entity whose registry to search.
--- @param Motor6D Motor6D -- The Motor6D to look up.
--- @return { Passive: Motor6D, Active: Motor6D }?, string?
function StatefulMotor6D.ReadRelationship(Entity: Types.Entity, Motor6D: Motor6D)
	local registry = Entity["Motor6DRegistry"]
	for _, Group in pairs(registry) do
		if Group.Passive == Motor6D then
			return Group, "Passive"
		elseif Group.Active == Motor6D then
			return Group, "Active"
		end
	end
	return nil, nil
end

--- Switches the enabled state between the Passive and Active motors in a group.
--- `"Active"` can be qualified as an equip; `"Passive"` can be qualified as an unequip.
--- @param Entity Types.Entity -- The entity whose registry to update.
--- @param GroupId string -- The group to switch.
--- @param State string -- `"Active"` or `"Passive"`.
function StatefulMotor6D.Switch(Entity: Types.Entity, GroupId: string, State: "Active" | "Passive")
	local Group = Entity["Motor6DRegistry"][GroupId]
	if not Group then
		warn(`StatefulMotor6D.Switch: No group found for GroupId "{GroupId}"`)
		return
	end
	Group.Active.Enabled = State == "Active"
	Group.Passive.Enabled = State == "Passive"
end

--- Safely destroys a Motor6D, removes its tags, and cleans up its relationship from the `Entity` registry.
--- Also destroys the counterpart motor in the same group.
--- @param Entity Types.Entity -- The entity whose registry to clean up.
--- @param Motor6D Motor6D -- The Motor6D to destroy.
function StatefulMotor6D.Destroy(Entity: Types.Entity, Motor6D: Motor6D)
	local Group, Role = StatefulMotor6D.ReadRelationship(Entity, Motor6D)

	if Group then
		local tags = CollectionService:GetTags(Motor6D)
		for _, tag in ipairs(tags) do
			if tag ~= "PassiveMotor6D" and tag ~= "ActiveMotor6D" then
				local GroupId = tag
				local counterpart = Role == "Passive" and Group.Active or Group.Passive
				if counterpart and counterpart.Parent then
					CollectionService:RemoveTag(counterpart, GroupId)
					CollectionService:RemoveTag(counterpart, Role == "Passive" and "ActiveMotor6D" or "PassiveMotor6D")
					counterpart:Destroy()
				end
				Entity["Motor6DRegistry"][GroupId] = nil
				break
			end
		end
	end

	CollectionService:RemoveTag(Motor6D, "PassiveMotor6D")
	CollectionService:RemoveTag(Motor6D, "ActiveMotor6D")
	Motor6D:Destroy()
end

--- Destroys all Motor6Ds tagged with `"StatefulMotor6D"` that are descendants of `instance`.
--- Also clears the `Motor6DRegistry` if the instance has one.
--- @param Instance Instance -- The root instance to clean up motors under.
function StatefulMotor6D.Cleanup(Instance: Instance)
	for _, motor in ipairs(CollectionService:GetTagged("StatefulMotor6D")) do
		if motor:IsDescendantOf(Instance) then
			motor:Destroy()
		end
	end
	local ok, registry = pcall(function()
		return (Instance :: any)["Motor6DRegistry"]
	end)
	if ok and registry then
		table.clear(registry)
	end
end

return StatefulMotor6D
