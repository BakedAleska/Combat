--!strict
-- @author : Claude

return function(Parent: { [string]: any }, Add: { [string]: any }?)
	local Base: { [string]: any } = Add or {}

	local Child: { [string]: any } = {}
	Child.__index = Child
	setmetatable(Child, Parent)

	function Child.new(Props: { [string]: any }?)
		local Safe = typeof(Props) == "table" and Props or {}
		local Merged = table.clone(Base)
		for Key, Value in pairs(Safe) do
			Merged[Key] = Value
		end
		local Inst = Parent.new(Merged)
		return setmetatable(Inst, Child)
	end

	return Child
end
