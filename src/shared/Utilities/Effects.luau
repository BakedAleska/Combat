--!nocheck
-- @author : BakedAleska
-- @date : 02/23/2026

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- IMPORTS
local Events = ReplicatedStorage.Shared.Events

export type Properties = {
	Enabled: boolean?,
	EmitCount: number?,
	Janitor: Instance?,
	InheritColor: boolean?,
}

local Effects = {}

function Effects.Emit(Effect: string, Adornee: BasePart | Attachment, Properties: Properties?)
	local Container = ReplicatedStorage.Shared.Assets.Effects:FindFirstChild(Effect, true)
	if not Container then
		warn(string.format("[Effects] No such effect: %s", Effect))
		return
	end

	local Emitters = if Container:IsA("Folder") then Container:GetChildren() else { Container }

	for _, Emitter in ipairs(Emitters) do
		if not Emitter:IsA("ParticleEmitter") then
			continue
		end

		local Clone = Emitter:Clone()
		local Attachment: Attachment?

		if not Adornee:IsA("Attachment") then
			Attachment = Instance.new("Attachment")
			Attachment.Parent = Adornee
			Clone.Parent = Attachment
		else
			Clone.Parent = Adornee
		end

		if Properties and Properties.Janitor then
			Properties.Janitor.Destroying:Once(function()
				if Clone then
					Clone:Destroy()
				end
				if Attachment then
					Attachment:Destroy()
				end
			end)
		end

		if Properties and Properties.Enabled then
			Clone.Enabled = true
		end

		if Properties and Properties.InheritColor then
			local Ancestor = Adornee
			while Ancestor and not Ancestor:IsA("Model") do
				Ancestor = Ancestor.Parent
			end

			local Params = RaycastParams.new()
			if Ancestor then
				Params.FilterDescendantsInstances = { Ancestor }
			end
			Params.FilterType = Enum.RaycastFilterType.Exclude
			Params.IgnoreWater = true

			local Position = if Adornee:IsA("Attachment") then Adornee.WorldPosition else Adornee.Position
			local Result = Workspace:Raycast(Position, Vector3.new(0, -10, 0), Params)
			if Result and Result.Instance:IsA("BasePart") then
				Clone.Color = ColorSequence.new(Result.Instance.Color)
			end
		end

		local Attribute = Clone:GetAttribute("EmitCount")
		local EmitCount = (Properties and Properties.EmitCount) or (typeof(Attribute) == "number" and Attribute) or 1
		Clone:Emit(EmitCount)

		if not (Properties and Properties.Janitor) then
			local Lifetime = typeof(Emitter.Lifetime) == "number" and Emitter.Lifetime
				or (Emitter.Lifetime :: NumberRange).Max
			Debris:AddItem(Clone, Lifetime + 1)
			if Attachment then
				Debris:AddItem(Attachment, Lifetime + 1)
			end
		end
	end
end

function Effects.Invoke(Effect: string, Adornee: BasePart | Attachment, Arguments: {}?)
	local Module = ReplicatedStorage.Shared.Assets.Effects:FindFirstChild(Effect, true)
	if not Module or not Module:IsA("ModuleScript") then
		warn(string.format("[Effects] No module found: %s", Effect))
		return
	end

	local Ok, Err = pcall(function()
		local Fn = require(Module)
		if typeof(Fn) == "function" then
			Fn(Adornee, Arguments)
		end
	end)

	if not Ok then
		warn(string.format("[Effects] Invoke error for %s: %s", Effect, Err))
	end
end

local function Adorn(Character, Adornee: (BasePart | Attachment)?): (BasePart | Attachment)?
	if Adornee then
		return Adornee
	end

	return Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Effects.Listen()
	Events.emitEffect.OnClientEvent:Connect(
		function(Character: Model, Effect: string, Adornee: (BasePart | Attachment)?, Properties: Properties?)
			local Target = Adorn(Character, Adornee)
			if not Target then
				return
			end
			Effects.Emit(Effect, Target, Properties)
		end
	)

	Events.invokeEffect.OnClientEvent:Connect(
		function(Character: Model, Effect: string, Adornee: (BasePart | Attachment)?, Arguments: {}?)
			local Target = Adorn(Character, Adornee)
			if not Target then
				return
			end
			Effects.Invoke(Effect, Target, Arguments)
		end
	)
end

return Effects
