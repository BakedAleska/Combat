--!nonstrict
-- @date 06/07/2026
-- @author BakedAleska

--- Client-side read facade for the player's replicated data.
--- Populated automatically when the PlayerData replica arrives.
--- @class Replicated
local Replicated = {}

local Data: { [string]: any }? = nil

--- Returns the local player's replicated data, or a specific key if provided.
--- @within Replicated
--- @param Key string?
--- @return any?
function Replicated.Get(Key: string?): any?
	if not Data then
		return
	end

	if Key ~= nil and Data[Key] then
		return Data[Key]
	end

	return Data
end

--- Sets the local replicated data reference.
--- Internal — called by the replica bootstrap in ClientBootstrapper.
--- @within Replicated
--- @param NewData { [string]: any }
function Replicated._Set(NewData: { [string]: any })
	Data = NewData
end

--- Clears the local replicated data reference.
--- Internal — called on replica destruction.
--- @within Replicated
function Replicated.Clear()
	Data = nil
end

return Replicated
