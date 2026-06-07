--!strict
-- @author : BakedAleska
-- @date : 04/16/2026

local RunService = game:GetService("RunService")

local Registry = {}

local Store: { [string | number]: any } = {}

local Boundary: string = if RunService:IsServer() then "Server" else "Client"

local function Keyed(Key: any): string | number
	local KeyType = typeof(Key)
	assert(KeyType == "string" or KeyType == "number", "[Registry] Key must be a non-empty string or a number.")

	if KeyType == "string" then
		assert(#Key > 0, "[Registry] Key must be a non-empty string.")
	end

	return Key :: string | number
end

function Registry.Register(Key: any, Object: any): ()
	local K = Keyed(Key)
	if Store[K] ~= nil then
		error(`[Registry][{Boundary}] Key "{tostring(K)}" is already registered.`, 2)
	end
	Store[K] = Object
end

function Registry.Get(Key: any): any?
	local K = Keyed(Key)
	return Store[K]
end

function Registry.Remove(Key: any): ()
	local K = Keyed(Key)
	Store[K] = nil
end

function Registry.List(): { string | number }
	local Keys: { string | number } = {}
	for K in Store do
		table.insert(Keys, K)
	end
	table.sort(Keys, function(a, b)
		if type(a) == type(b) then
			return a < b
		end
		return tostring(a) < tostring(b)
	end)
	return table.freeze(Keys)
end

return table.freeze(Registry)
