return function(registry)
	return registry:RegisterType("kind", registry.Cmdr.Util.MakeEnumType("kind", { "Weapon" }))
end
