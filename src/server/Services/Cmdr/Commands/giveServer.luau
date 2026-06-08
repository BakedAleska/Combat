return function(Context, Target)
	local Executor = Context.Executor
	Target.Character:PivotTo(Executor.Character:GetPivot())
	return "Brought " .. Target.Name
end
