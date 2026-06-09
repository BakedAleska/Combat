--- Tilts the character body based on lateral and backward movement.
--- Only active while shift lock is enabled.
--- At above-default walk speed the strafe angle snaps fully to 90 degrees.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local Player = Players.LocalPlayer

local DEFAULT_WALK_SPEED = 16
local MAX_STRAFE_ANGLE = math.rad(40)
local MAX_LEAN_ANGLE = math.rad(20)
local LERP_SPEED = 10
local MIN_SPEED = 0.5

local CurrentAngle = 0
local CurrentLean = 0
local RootJointDefaultC0: CFrame? = nil

--- Resets tilt state and caches the RootJoint default C0 for the new character.
--- @param Character Model
local function SetupCharacter(Character: Model)
	CurrentAngle = 0
	CurrentLean = 0
	RootJointDefaultC0 = nil

	local Hrp = Character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not Hrp then return end

	local RootJoint = Hrp:WaitForChild("RootJoint", 5) :: Motor6D?
	if RootJoint and RootJoint:IsA("Motor6D") then
		RootJointDefaultC0 = RootJoint.C0
	end
end

Player.CharacterAdded:Connect(SetupCharacter)
if Player.Character then
	task.spawn(SetupCharacter, Player.Character)
end

--- Each frame, projects velocity onto the right and look vectors to derive
--- strafe and backward tilt angles when shift lock is active, then applies
--- them as a combined rotation offset on the RootJoint C0.
--- Smoothly returns to neutral when shift lock is off.
RunService.RenderStepped:Connect(function(Dt)
	local Character = Player.Character
	if not Character or not RootJointDefaultC0 then return end

	local Hrp = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not Hrp then return end

	local RootJoint = Hrp:FindFirstChild("RootJoint") :: Motor6D?
	if not RootJoint then return end

	local Alpha = math.min(LERP_SPEED * Dt, 1)

	if UserGameSettings.RotationType ~= Enum.RotationType.CameraRelative then
		CurrentAngle += (0 - CurrentAngle) * Alpha
		CurrentLean += (0 - CurrentLean) * Alpha
		RootJoint.C0 = RootJointDefaultC0 * CFrame.Angles(-CurrentLean, 0, -CurrentAngle)
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local WalkSpeed = Humanoid and Humanoid.WalkSpeed or DEFAULT_WALK_SPEED

	local Velocity = Hrp.AssemblyLinearVelocity
	local StrafeSpeed = Velocity:Dot(Hrp.CFrame.RightVector)
	local ForwardSpeed = Velocity:Dot(Hrp.CFrame.LookVector)

	local TargetAngle = 0
	if math.abs(StrafeSpeed) > MIN_SPEED then
		if WalkSpeed > DEFAULT_WALK_SPEED then
			TargetAngle = math.sign(StrafeSpeed) * math.rad(90)
		else
			local T = math.clamp(StrafeSpeed / WalkSpeed, -1, 1)
			TargetAngle = T * MAX_STRAFE_ANGLE
		end
	end

	local TargetLean = 0
	if ForwardSpeed < -MIN_SPEED then
		local SpeedNorm = math.min(WalkSpeed, DEFAULT_WALK_SPEED)
		local T = math.clamp(-ForwardSpeed / SpeedNorm, 0, 1)
		TargetLean = T * MAX_LEAN_ANGLE
	end

	CurrentAngle += (TargetAngle - CurrentAngle) * Alpha
	CurrentLean += (TargetLean - CurrentLean) * Alpha
	RootJoint.C0 = RootJointDefaultC0 * CFrame.Angles(-CurrentLean, 0, -CurrentAngle)
end)