-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- IMPORT
local Networker = require(ReplicatedStorage.Shared.Networker)
local Types = require(ReplicatedStorage.Shared.Types)
local State = require(script.Parent.Parent.State)
local Extend = require(ServerScriptService.Server.Functions.Extend)
local CooldownHandler = require(ServerScriptService.Server.Services.CooldownHandler)
local Registry = require(ServerScriptService.Server.Services.Registry)
local WalkSpeedUtils = require(ServerScriptService.Server.Services.WalkSpeedUtils)

local function SetCharacterVisiblity(Character: Model, Visible: boolean)
	local Target = if not Visible then 1 else 0
	for _, Desc in Character:GetDescendants() do
		if Desc:IsA("BasePart") then
			if Desc.Name == "HumanoidRootPart" or Desc.Name == "Collide" or Desc:HasTag("Effect") then
				continue
			end
			if Desc.Name == "Handle" and Desc.Parent and Desc.Parent:IsA("Model") then
				continue
			end
			Desc.Transparency = Target
		elseif Desc:IsA("Decal") then
			Desc.Transparency = Target
		end
	end
end

local Flashstepping = Extend(State, { ["Name"] = "Flashstepping", ["Priority"] = 9 })

function Flashstepping:OnEnter()
	SetCharacterVisiblity(self.Character, false)
	local RootPart = self.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if RootPart then
		Networker.Fire("emitEffect", RootPart, "Shunpo")
		Networker.Fire("emitEffect", RootPart:FindFirstChild("GroundAttachment"), "GroundWind")
		Networker.Fire("invokeEffect", "Shadow", self.Character, self.Duration)
	else
		warn("[Flashstepping] Missing HumanoidRootPart for effect emit.")
	end

	-- TODO(sound): Flashstep

	WalkSpeedUtils:Set(self.Humanoid, 72)
end

function Flashstepping:OnExit()
	SetCharacterVisiblity(self.Character, true)
	WalkSpeedUtils:Default(self.Humanoid)

	CooldownHandler.Add(self.Entity, "Flashstep")

	local RootPart = self.Character:FindFirstChild("HumanoidRootPart") :: BasePart?

	Networker.Fire("emitEffect", RootPart, "Shunpo")
	Networker.Fire("emitEffect", RootPart:FindFirstChild("GroundAttachment"), "GroundWind")
end

Networker.Connect("Flashstep", function(Player: Player, ClientInfo: Types.ClientInfo)
	if ClientInfo.State ~= "Pressed" then
		return
	end

	local Entity = Registry.Get(Player.UserId)
	assert(Entity, "[Sprinting] Invalid entity.")

	if CooldownHandler.Has(Entity, "Flashstep") then
		return
	end

	Entity.StateMachine:Transition(Flashstepping.new({ Duration = 0.33 }))
end)

return Flashstepping
