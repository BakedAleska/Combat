--!nonstrict
-- @author : Claude

return function(Target: { [string]: any }, Props: { [string]: any })
	for Key, Value in Props do
		Target[Key] = Value
	end
end
