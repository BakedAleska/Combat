--!nonstrict
-- @date : 06/08/2026

-- Weak keys allow owners to be garbage collected when no longer referenced.
local Registry: any = setmetatable({}, { __mode = "k" })

--- Calls `Fn` exactly once per `Owner`/`Key` pair for the lifetime of `Owner`.
--- Safe to call every frame; subsequent calls with the same pair are no-ops.
--- @param Owner table The object scoping this once-call (e.g. a state instance).
--- @param Key any Unique identifier within `Owner`'s scope. Must be non-nil.
--- @param Fn () -> () The function to invoke on the first call.
return function(Owner: any, Key: any, Fn: () -> ())
	assert(type(Owner) == "table", "[Once] Owner must be a table.")
	assert(Key ~= nil, "[Once] Key must be non-nil.")
	assert(type(Fn) == "function", "[Once] Fn must be a function.")

	local Set = Registry[Owner]
	if not Set then
		Set = {}
		Registry[Owner] = Set
	end

	if Set[Key] then
		return
	end

	Set[Key] = true
	Fn()
end
