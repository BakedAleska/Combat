--!strict

-- SERVICES
local StarterPlayer = game:GetService("StarterPlayer")

-- CONSTANTS
const DEFAULT_WALK_SPEED = StarterPlayer.CharacterWalkSpeed

--- @class WalkSpeedUtils
--- Utility service for reading and modifying a Humanoid's walk speed.
--- Speed changes are driven by a keyed modifier table on the Entity,
--- allowing multiple systems to add and remove speed changes independently without stomping each other.
local WalkSpeedUtils = {}

--- Sets the Humanoid's WalkSpeed to the specified value.
--- @param Humanoid Humanoid -- The humanoid to be affected.
--- @param Value number -- The new WalkSpeed value.
--- @return boolean -- Whether or not the given character's WalkSpeed changed.
function WalkSpeedUtils:Set(Humanoid: Humanoid, Value: number): boolean
	assert(Humanoid.Parent, "[WalkSpeedUtils] Humanoid has no such valid parent.")

	local OldValue = Humanoid.WalkSpeed
	if OldValue ~= Value then
		Humanoid.WalkSpeed = Value

		return true
	end

	return false
end

--- Sets the Humanoid's WalkSpeed back to default.
--- @param Humanoid Humanoid -- The humanoid to be affected
function WalkSpeedUtils:Default(Humanoid: Humanoid)
	self:Set(Humanoid, DEFAULT_WALK_SPEED)
end

--- Calculate total walk speed from modifiers.
--- @param Entity Entity -- The entity to calculate speed for.
--- @within WalkSpeedUtils
--- @return number -- The total calculated walk speed.
local function GetTotalSpeed(Entity)
	local TotalSpeed = DEFAULT_WALK_SPEED

	if type(Entity.WalkSpeedModifiers) == "table" then
		for _, Modifier in pairs(Entity.WalkSpeedModifiers) do
			TotalSpeed += Modifier
		end
	end

	return TotalSpeed
end

--- Add a speed modifier to the entity and apply it.
--- @param Entity Entity -- The entity to add the modifier to.
--- @param Key string -- The unique key for this modifier.
--- @param Value number -- The modifier value (added to base speed).
function WalkSpeedUtils:AddSpeedModifier(Entity, Key: string, Value: number)
	assert(type(Entity) == "table", "[WalkSpeedUtils] Entity must be a table.")
	assert(type(Key) == "string" and #Key > 0, "[WalkSpeedUtils] Key must be a non-empty string.")
	assert(type(Value) == "number", "[WalkSpeedUtils] Value must be a number.")

	if not Entity.WalkSpeedModifiers then
		Entity.WalkSpeedModifiers = {}
	end

	Entity.WalkSpeedModifiers[Key] = Value

	local Humanoid = Entity.PlayerController and Entity.PlayerController.Humanoid
	if Humanoid then
		self:Set(Humanoid, GetTotalSpeed(Entity))
	end
end

--- Remove a speed modifier from the entity and recalculate speed.
--- @param Entity Entity -- The entity to remove the modifier from.
--- @param Key string -- The unique key of the modifier to remove.
function WalkSpeedUtils:RemoveSpeedModifier(Entity, Key: string)
	assert(type(Entity) == "table", "[WalkSpeedUtils] Entity must be a table.")
	assert(type(Key) == "string" and #Key > 0, "[WalkSpeedUtils] Key must be a non-empty string.")

	if Entity.WalkSpeedModifiers then
		Entity.WalkSpeedModifiers[Key] = nil
	end

	local Humanoid = Entity.PlayerController and Entity.PlayerController.Humanoid
	if Humanoid then
		self:Set(Humanoid, GetTotalSpeed(Entity))
	end
end

return WalkSpeedUtils
