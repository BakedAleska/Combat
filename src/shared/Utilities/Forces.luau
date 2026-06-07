--!nonstrict
-- @author : BakedAleska
-- @date : 02/22/2026

-- SERVICES
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- IMPORT
local Events = ReplicatedStorage.Shared.Events
local janitor = require(ReplicatedStorage.Packages.janitor)

-- VARIABLES
local Janitor = janitor.new()

-- CONSTANTS
const DEFAULT_MAX_AXES_FORCE = Vector3.new(50000, 50000, 50000)
const VELOCITY_ATTACHMENT_NAME = "VelocityAttachment"

--> Declare
local Forces = {}

local function MakeAttachment(Parent: Instance): Attachment
	local Attachment = Instance.new("Attachment")
	Attachment.Parent = Parent
	return Attachment
end

local function Normalize(Vector: Vector3): Vector3
	local XZ = Vector3.new(Vector.X, 0, Vector.Z)
	local Magnitude = XZ.Magnitude
	return (Magnitude > 1e-6) and (XZ / Magnitude) or Vector3.zero
end

function Forces.LinearVelocity(RootPart: BasePart, Velocity: Vector3, Duration: number, Max: Vector3?)
	local Attachment = MakeAttachment(RootPart)
	Attachment.Name = VELOCITY_ATTACHMENT_NAME

	local LV = Instance.new("LinearVelocity")
	LV.VectorVelocity = Velocity
	LV.Attachment0 = Attachment
	LV.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	LV.RelativeTo = Enum.ActuatorRelativeTo.World
	LV.MaxAxesForce = Max or DEFAULT_MAX_AXES_FORCE
	LV.Parent = Attachment

	Debris:AddItem(Attachment, Duration)
end

function Forces.AdaptiveLinearVelocity(
	RootPart: BasePart,
	Velocity: Vector3,
	Duration: number,
	Direction: string,
	Max: Vector3?
)
	local Attachment = MakeAttachment(RootPart)
	Attachment.Name = VELOCITY_ATTACHMENT_NAME

	local LV = Instance.new("LinearVelocity")
	LV.Attachment0 = Attachment
	LV.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	LV.RelativeTo = Enum.ActuatorRelativeTo.World
	LV.MaxAxesForce = Max or DEFAULT_MAX_AXES_FORCE
	LV.Parent = Attachment

	local Elapsed = 0
	local Connection: RBXScriptConnection?

	local function Cleanup()
		if Connection then
			Connection:Disconnect()
			Connection = nil
		end
		if Attachment.Parent then
			Attachment:Destroy()
		end
	end

	Connection = RunService.Heartbeat:Connect(function(dt)
		if not RootPart or not RootPart.Parent then
			Cleanup()
			return
		end
		Elapsed += dt
		if Elapsed >= Duration then
			Cleanup()
			return
		end

		local Forward = Normalize(RootPart.CFrame.LookVector)
		local Right = Normalize(RootPart.CFrame.RightVector)
		local Dir = if Direction == "Back" or Direction == "Backward"
			then -Forward
			elseif Direction == "Right" then Right
			elseif Direction == "Left" then -Right
			else Forward

		local HSpeed = Vector3.new(Velocity.X, 0, Velocity.Z).Magnitude
		LV.VectorVelocity = (Dir == Vector3.zero) and Vector3.zero or (Dir * HSpeed + Vector3.new(0, Velocity.Y, 0))
	end)

	Janitor:Add(Connection, "Disconnect")
end

function Forces.AssemblyLinearVelocity(RootPart: BasePart, Velocity: Vector3)
	RootPart.AssemblyLinearVelocity = Velocity
end

function Forces.DestroyForces(RootPart: BasePart)
	Janitor:Cleanup()
	RootPart.AssemblyLinearVelocity = Vector3.zero

	for _, Desc in ipairs(RootPart:GetChildren()) do
		if
			(Desc:IsA("Attachment") and Desc.Name == VELOCITY_ATTACHMENT_NAME)
			or Desc:IsA("LinearVelocity")
			or Desc:IsA("VectorForce")
		then
			Desc:Destroy()
		end
	end
end

function Forces.Listen()
	Events.applyLinearVelocity.OnServerEvent:Connect(function(Character, Velocity, Duration, Max)
		local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if Root then
			Forces.LinearVelocity(Root, Velocity, Duration, Max)
		end
	end)

	Events.applyAdaptiveLinearVelocity.OnServerEvent:Connect(function(Character, Velocity, Duration, Direction, Max)
		local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if Root then
			Forces.AdaptiveLinearVelocity(Root, Velocity, Duration, Direction, Max)
		end
	end)

	Events.applyAssemblyLinearVelocity.OnServerEvent:Connect(function(Character, Velocity)
		local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if Root then
			Forces.AssemblyLinearVelocity(Root, Velocity)
		end
	end)

	Events.destroyForces.OnServerEvent:Connect(function(Character)
		local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if Root then
			Forces.DestroyForces(Root)
		end
	end)
end

return Forces
