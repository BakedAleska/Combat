--!strict
-- @author : BakedAleska
-- @date : 02/23/2026

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Shared.Networker)

local require = require

const EffectsFolder = ReplicatedStorage.Assets.Effects
const InvokeFolder = ReplicatedStorage.Shared.Effects

export type Properties = {
	Enabled: boolean?,
	EmitCount: number?,
	Janitor: Instance?,
	InheritColor: boolean?,
}

local function ResolveAdornee(Adornee: Instance?): (BasePart | Attachment)?
	if not Adornee then
		return nil
	end

	local Current: Instance? = Adornee
	while Current do
		if Current:IsA("Attachment") then
			return Current :: Attachment
		end
		if Current:IsA("BasePart") then
			return Current :: BasePart
		end
		Current = Current.Parent
	end

	warn(string.format("[Effects] Could not resolve adornee from: %s (%s)", Adornee.Name, Adornee.ClassName))
	return nil
end

local function GetOrCreateAttachment(Adornee: BasePart | Attachment): (Attachment, boolean)
	if Adornee:IsA("Attachment") then
		return Adornee, false
	end
	local Att = Instance.new("Attachment")
	Att.Parent = Adornee
	return Att, true
end

local function GetGroundColor(Adornee: BasePart | Attachment): Color3?
	local Position = if Adornee:IsA("Attachment") then Adornee.WorldPosition else Adornee.Position

	local Ancestor: Instance? = Adornee
	while Ancestor and not Ancestor:IsA("Model") do
		Ancestor = Ancestor.Parent
	end

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.IgnoreWater = true
	if Ancestor then
		Params.FilterDescendantsInstances = { Ancestor }
	end

	local Result = Workspace:Raycast(Position, Vector3.new(0, -10, 0), Params)
	if Result and Result.Instance:IsA("BasePart") then
		return Result.Instance.Color
	end

	return nil
end

local function TrackCleanup(Clone: ParticleEmitter, Attachment: Attachment?, Janitor: Instance?, Lifetime: number)
	if Janitor then
		Janitor.Destroying:Once(function()
			if Clone and Clone.Parent then
				Clone:Destroy()
			end
			if Attachment and Attachment.Parent then
				Attachment:Destroy()
			end
		end)
	else
		Debris:AddItem(Clone, Lifetime + 1)
		if Attachment then
			Debris:AddItem(Attachment, Lifetime + 1)
		end
	end
end

local Effects = {}

function Effects.Emit(Effect: string, Adornee: BasePart | Attachment, Properties: Properties?)
	local Container = EffectsFolder:FindFirstChild(Effect, true)
	if not Container then
		warn(string.format("[Effects] No such effect: %s", Effect))
		return
	end

	local Emitters: { Instance } = if Container:IsA("Folder") then Container:GetChildren() else { Container }

	for _, Emitter in ipairs(Emitters) do
		if not Emitter:IsA("ParticleEmitter") then
			continue
		end

		local Att, IsNew = GetOrCreateAttachment(Adornee)
		local Clone = Emitter:Clone()
		Clone.Parent = Att

		-- Color
		if Properties and Properties.InheritColor then
			local GroundColor = GetGroundColor(Adornee)
			if GroundColor then
				Clone.Color = ColorSequence.new(GroundColor)
			end
		end

		-- Enabled state (defaults off; explicit true turns it on)
		Clone.Enabled = Properties ~= nil and Properties.Enabled == true

		-- Lifetime for Debris fallback
		local RawLifetime = Emitter.Lifetime
		local Lifetime = if typeof(RawLifetime) == "number" then RawLifetime else (RawLifetime :: NumberRange).Max

		-- Cleanup
		TrackCleanup(Clone, if IsNew then Att else nil, Properties and Properties.Janitor, Lifetime)

		-- Emit
		local Attribute = Clone:GetAttribute("EmitCount")
		local EmitCount = (Properties and Properties.EmitCount) or (typeof(Attribute) == "number" and Attribute) or 1
		Clone:Emit(EmitCount)
	end
end

function Effects.Invoke(Effect: string, ...: any)
	local Module = InvokeFolder:FindFirstChild(Effect, true)
	if not Module or not Module:IsA("ModuleScript") then
		warn(string.format("[Effects] No module found: %s", Effect))
		return
	end

	local Args = { ... }

	local Ok, Err = pcall(function()
		local Fn = require(Module)
		if typeof(Fn) == "function" then
			Fn(table.unpack(Args))
		end
	end)

	if not Ok then
		warn(string.format("[Effects] Invoke error for %s: %s", Effect, tostring(Err)))
	end
end

function Effects.Listen()
	Networker.Connect("emitEffect", function(Adornee: Instance?, Effect: string, Properties: Properties?): ()
		local Target = ResolveAdornee(Adornee)
		if not Target then
			warn("[Effects] Missing or unresolvable adornee for emitEffect.")
			return
		end
		Effects.Emit(Effect, Target, Properties)
	end)

	Networker.Connect("invokeEffect", function(Effect: string, ...: any): ()
		Effects.Invoke(Effect, ...)
	end)
end

return Effects
