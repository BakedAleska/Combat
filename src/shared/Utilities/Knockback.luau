--!nonstrict
-- @author : BakedAleska
-- @date : 05/31/2026
--
-- Unified knockback. The VISUAL motion runs on the owning CLIENT (it moves the
-- character every RenderStepped frame — smoothest), while the SERVER runs a headless
-- prediction of the SAME trajectory to validate the client's landing report and to
-- hold an authoritative fallback if the client never reports.
--
-- Both sides share one set of constants, one curve table, one integration step
-- (Advance) and one bounce-landing search (ComputeBounceLanding), so the physics can
-- only ever be tuned in one place.

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

const SERVER = RunService:IsServer()

-- IMPORTS
local Registry = require(ReplicatedStorage.Shared.Services.Registry)
local Events = ReplicatedStorage.Shared.Events
local janitor = require(ReplicatedStorage.Packages.janitor)
-- Client-only visual helper; never required on the server.
local Animations = if SERVER then nil else require(ReplicatedStorage.Shared.Utilities.Animations)

-- CONSTANTS
const WALL_MARGIN = 0.1
const CHARACTER_HIP_HEIGHT = 3

const SMALL_DISTANCE = 16
const SMALL_DURATION = 0.345

const LARGE_DISTANCE = 24
const LARGE_DURATION = 0.5

const SPLATTER_DURATION = 0.6
const BOUNCE_DURATION = 0.55
const BOUNCE_DIST = 10
const ARC_HEIGHT = 5

const SIM_DT = 1 / 60
const REPORT_TIMEOUT = 0.3
const POSITION_TOLERANCE = 12

const Debug = false

-- TYPES
export type curve = "Linear" | "Log"
export type options = {
	Curve: curve?,
	Distance: number?,
	Duration: number?,
}
export type Result = {
	ExpectedPos: Vector3,
	ExpectedCFrame: CFrame,
	FallbackThread: thread,
}

const CURVES = {
	Linear = function(T: number): number
		return T
	end,
	Log = function(T: number): number
		return math.log(1 + 9 * T) / math.log(10)
	end,
}

-- Per-type presets (distance, duration, default curve). Shared by the client driver
-- and the server prediction so "small"/"large" mean the same thing on both sides.
const PRESETS = {
	small = { Distance = SMALL_DISTANCE, Duration = SMALL_DURATION, Curve = "Log" },
	large = { Distance = LARGE_DISTANCE, Duration = LARGE_DURATION, Curve = "Linear" },
}

local Knockback = {}

--======================================================================
-- SHARED CORE
--======================================================================

local function ExcludeParams(Character: Model): RaycastParams
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Character }
	return Params
end

local function Horizontalize(Direction: Vector3): Vector3
	local Horizontal = Vector3.new(Direction.X, 0, Direction.Z)
	return if Horizontal.Magnitude > 1e-6 then Horizontal.Unit else Vector3.new(0, 0, -1)
end

local function SnapToGround(Pos: Vector3, Character: Model): Vector3
	local Hit = Workspace:Raycast(
		Vector3.new(Pos.X, Pos.Y + 5, Pos.Z),
		Vector3.new(0, -(CHARACTER_HIP_HEIGHT + 55), 0),
		ExcludeParams(Character)
	)
	if Hit then
		return Vector3.new(Pos.X, Hit.Position.Y + CHARACTER_HIP_HEIGHT, Pos.Z)
	end
	return Pos
end

export type hit = {
	Normal: Vector3, -- surface normal of the thing struck
	Point: Vector3, -- raw world contact point
	Safe: Vector3, -- position to place the root at (margin-backed off the surface)
	Correct: Vector3, -- depth-corrected centre position (used by server prediction)
}

-- A single integration step of the flight. Returns the hit info (or nil if the step
-- was clean) and the resolved position to advance to. Identical on client and server;
-- the client drives it per RenderStepped frame, the server per fixed SIM_DT.
local function Advance(
	Pos: Vector3,
	Horizontal: Vector3,
	DH: number,
	Params: RaycastParams,
	HalfDepth: number
): (hit?, Vector3)
	local Desired = Pos + Horizontal * DH

	if DH > 1e-4 then
		local WallHit = Workspace:Raycast(Pos, Horizontal * (DH + WALL_MARGIN), Params)
		if WallHit then
			local Safe = Vector3.new(
				WallHit.Position.X - Horizontal.X * WALL_MARGIN,
				Desired.Y,
				WallHit.Position.Z - Horizontal.Z * WALL_MARGIN
			)
			local N = WallHit.Normal.Unit
			local Correct = Safe - N * ((Safe - WallHit.Position):Dot(N) - HalfDepth)
			return { Normal = N, Point = WallHit.Position, Safe = Safe, Correct = Correct }, Safe
		end
	end

	local GroundHit = Workspace:Raycast(
		Vector3.new(Desired.X, Desired.Y + 2, Desired.Z),
		Vector3.new(0, -(CHARACTER_HIP_HEIGHT + 3), 0),
		Params
	)
	if GroundHit then
		local FloorY = GroundHit.Position.Y + CHARACTER_HIP_HEIGHT
		if Desired.Y < FloorY then
			Desired = Vector3.new(Desired.X, FloorY, Desired.Z)
			if -GroundHit.Normal:Dot(Horizontal) > 0.3 then
				local N = GroundHit.Normal.Unit
				local Correct = Desired - N * ((Desired - GroundHit.Position):Dot(N) - HalfDepth)
				return { Normal = N, Point = GroundHit.Position, Safe = Desired, Correct = Correct }, Desired
			end
		end
	end

	return nil, Desired
end

-- After a wall/ground splat, search for where the victim lands once bounced off.
-- Returns the landing position (used by both sides) and the bezier mid control point
-- (used only by the client's visual arc; the server ignores it).
local function ComputeBounceLanding(
	HitPos: Vector3,
	BounceDir: Vector3,
	SurfaceNormal: Vector3,
	Character: Model
): (Vector3, Vector3)
	local IsCeiling = SurfaceNormal.Y <= -0.7

	local SearchOrigin = if IsCeiling
		then Vector3.new(HitPos.X + BounceDir.X * BOUNCE_DIST, HitPos.Y, HitPos.Z + BounceDir.Z * BOUNCE_DIST)
		else Vector3.new(HitPos.X + BounceDir.X * BOUNCE_DIST, HitPos.Y + 5, HitPos.Z + BounceDir.Z * BOUNCE_DIST)

	local GroundSearch =
		Workspace:Raycast(SearchOrigin, Vector3.new(0, -(CHARACTER_HIP_HEIGHT + 50), 0), ExcludeParams(Character))
	local LandY = GroundSearch and (GroundSearch.Position.Y + CHARACTER_HIP_HEIGHT)
		or (if IsCeiling then HitPos.Y - 10 else HitPos.Y)

	local LandPos = Vector3.new(SearchOrigin.X, LandY, SearchOrigin.Z)

	local ArcMid = if IsCeiling
		then Vector3.new(SearchOrigin.X, HitPos.Y, SearchOrigin.Z)
		else Vector3.new(
			(HitPos.X + LandPos.X) / 2,
			math.max(HitPos.Y, LandPos.Y) + ARC_HEIGHT,
			(HitPos.Z + LandPos.Z) / 2
		)

	return LandPos, ArcMid
end

--======================================================================
-- SERVER — headless prediction + landing validation
--======================================================================

-- Walks the whole flight at a fixed timestep to find the first hit (or a clean end).
-- Returns (hitTime, position, hitNormal?). Mirrors the client's per-frame walk.
local function Simulate(
	StartPos: Vector3,
	Horizontal: Vector3,
	CurveFn: (number) -> number,
	Distance: number,
	Duration: number,
	HalfDepth: number,
	Character: Model
): (number, Vector3, Vector3?)
	local Params = ExcludeParams(Character)
	local Pos = StartPos
	local PrevFactor = 0
	local Elapsed = 0

	while Elapsed < Duration do
		Elapsed = math.min(Elapsed + SIM_DT, Duration)
		local Factor = CurveFn(Elapsed / Duration)
		local DH = (Factor - PrevFactor) * Distance
		PrevFactor = Factor

		local Contact, NextPos = Advance(Pos, Horizontal, DH, Params, HalfDepth)
		if Contact then
			return Elapsed, Contact.Correct, Contact.Normal
		end
		Pos = NextPos
	end

	return Duration, Pos, nil
end

local function ExitKnockback(Character: Model)
	local Entity = Registry.Get(Character.Name)
	if Entity and Entity.StateMachine and Entity.StateMachine:Is("Knockedback") then
		Entity.StateMachine:Exit(true)
	end
end

-- Predicts where a knockback will end so the Knockedback state can validate the
-- client's report against it and fall back to it on timeout. Server-only.
function Knockback.Predict(Character: Model, Direction: Vector3, Type: "small" | "large", Options: options?): Result?
	local RootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not RootPart then
		return nil
	end

	local Preset = PRESETS[Type] or PRESETS.small
	local Distance = Preset.Distance
	local Duration = Preset.Duration
	local CurveFn = CURVES[(Options and Options.Curve) or Preset.Curve] or CURVES[Preset.Curve]
	local HalfDepth = RootPart.Size.Z / 2

	local StartPos = RootPart.Position
	local Horizontal = Horizontalize(Direction)

	local HitTime, HitPos, HitNormal = Simulate(StartPos, Horizontal, CurveFn, Distance, Duration, HalfDepth, Character)

	local TotalTime: number
	local FinalPos: Vector3

	if HitNormal then
		local LandPos = ComputeBounceLanding(HitPos, -Horizontal, HitNormal, Character)
		FinalPos = LandPos
		TotalTime = HitTime + SPLATTER_DURATION + BOUNCE_DURATION
	else
		FinalPos = SnapToGround(HitPos, Character)
		TotalTime = Duration
	end

	local FinalCFrame = CFrame.new(FinalPos, FinalPos - Horizontal)

	if Debug then
		print(
			string.format(
				"[Knockback] %s on %s | %s | finalPos=(%.2f, %.2f, %.2f) | totalTime=%.2fs",
				Type,
				Character.Name,
				if HitNormal then "wall→bounce" else "clean flight",
				FinalPos.X,
				FinalPos.Y,
				FinalPos.Z,
				TotalTime
			)
		)
	end

	local FallbackThread = task.delay(TotalTime + REPORT_TIMEOUT, function()
		if not Character.Parent then
			return
		end
		local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if Root then
			Root.CFrame = FinalCFrame
		end
		local Entity = Registry.Get(Character.Name)
		if Entity and Entity.StateMachine and Entity.StateMachine:Is("Knockedback") then
			Entity.StateMachine.Current.FallbackThread = nil
			Entity.StateMachine:Exit(true)
		end
	end)

	return {
		ExpectedPos = FinalPos,
		ExpectedCFrame = FinalCFrame,
		FallbackThread = FallbackThread,
	}
end

-- Only the character's owning client may report its own landing; NPCs may be reported
-- by any client. Reports for characters not in Knockedback are silently dropped.
local function OnKnockbackLanded(Player: Player, Character: Model, ReportedCFrame: CFrame)
	if not Character or not Character:IsDescendantOf(Workspace) then
		return
	end

	local Owner = Players:GetPlayerFromCharacter(Character)
	if Owner and Owner ~= Player then
		return
	end

	local Entity = Registry.Get(Character.Name)
	if not Entity or not Entity.StateMachine:Is("Knockedback") then
		return
	end

	local KBState = Entity.StateMachine.Current

	if KBState.FallbackThread then
		task.cancel(KBState.FallbackThread)
		KBState.FallbackThread = nil
	end

	local RootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not RootPart then
		ExitKnockback(Character)
		return
	end

	local Delta = (ReportedCFrame.Position - KBState.ExpectedPos).Magnitude

	-- Trust the client's reported landing when it's within tolerance of the prediction;
	-- otherwise snap to the server's own predicted landing.
	local Trusted = Delta <= POSITION_TOLERANCE
	local Source = if Trusted then ReportedCFrame else KBState.ExpectedCFrame
	local Snapped = SnapToGround(Source.Position, Character)
	RootPart.CFrame = CFrame.fromMatrix(Snapped, Source.RightVector, Source.UpVector)

	if Debug then
		print(
			string.format(
				"[Knockback] Report from %s | delta=%.2f | %s",
				Player.Name,
				Delta,
				if Trusted then "trusted client" else "fallback to prediction"
			)
		)
	end

	ExitKnockback(Character)
end

--======================================================================
-- CLIENT — visual driver (owns the actual motion)
--======================================================================

local Janitors: { [Model]: any } = {}

local function GetJanitor(Character: Model)
	local J = Janitors[Character]
	if not J then
		J = janitor.new()
		Janitors[Character] = J
	end
	return J
end

local function Restore(Humanoid: Humanoid, RootPart: BasePart)
	local Ground = Workspace:Raycast(
		RootPart.Position + Vector3.new(0, 1, 0),
		Vector3.new(0, -3, 0),
		ExcludeParams(Humanoid.Parent :: Model)
	)
	Humanoid:ChangeState(if Ground then Enum.HumanoidStateType.Running else Enum.HumanoidStateType.Freefall)
end

local function Cancel(Character: Model)
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local RootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?

	if RootPart then
		RootPart.AssemblyLinearVelocity = Vector3.zero
		RootPart.AssemblyAngularVelocity = Vector3.zero
	end

	if Humanoid then
		Humanoid.AutoRotate = true
		if RootPart then
			Restore(Humanoid, RootPart)
		end
	end

	-- Nil before Cleanup so re-entrant Cancel calls within Cleanup are no-ops.
	local J = Janitors[Character]
	if J then
		Janitors[Character] = nil
		J:Cleanup()
	end

	if RootPart and RootPart.Parent then
		Events.KnockbackLanded:FireServer(Character, RootPart.CFrame)
	end
end

local function BounceOffWall(Character: Model, WallPos: Vector3, BounceDir: Vector3, SurfaceNormal: Vector3)
	local J = GetJanitor(Character)
	local RootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not RootPart then
		return
	end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid") :: Humanoid?

	Animations.PlayAnimation(Character, "WallBounce", { FadeTime = 0.25, Looped = false })

	if Humanoid then
		Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end

	local LandPos, ArcMid = ComputeBounceLanding(WallPos, BounceDir, SurfaceNormal, Character)

	local Elapsed = 0
	local BounceRot = CFrame.new(Vector3.zero, BounceDir)

	J:Add(function()
		if RootPart.Parent then
			RootPart.Anchored = false
		end
	end, true)

	J:Add(RunService.RenderStepped:Connect(function(Dt: number)
		if not RootPart.Parent then
			Cancel(Character)
			return
		end

		Elapsed = math.min(Elapsed + Dt, BOUNCE_DURATION)
		local T = Elapsed / BOUNCE_DURATION
		local U = 1 - T

		-- Quadratic bezier: B(t) = (1-t)²·P0 + 2(1-t)t·P1 + t²·P2
		local Pos = U * U * WallPos + 2 * U * T * ArcMid + T * T * LandPos

		RootPart.AssemblyLinearVelocity = Vector3.zero
		RootPart.AssemblyAngularVelocity = Vector3.zero
		RootPart.CFrame = CFrame.new(Pos) * BounceRot

		if Elapsed >= BOUNCE_DURATION then
			Cancel(Character)
		end
	end))
end

local function Hit(HitNormal: Vector3, Horizontal: Vector3, Character: Model, HitPoint: Vector3)
	local J = GetJanitor(Character)
	J:Cleanup()

	local RootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not RootPart then
		return
	end

	RootPart.AssemblyLinearVelocity = Vector3.zero
	RootPart.AssemblyAngularVelocity = Vector3.zero

	local SurfaceNormal = HitNormal.Unit
	local BounceDir = -Horizontal
	local HalfDepth = RootPart.Size.Z / 2

	local ActualDist = (RootPart.Position - HitPoint):Dot(SurfaceNormal)
	local CorrectPosition = RootPart.Position - SurfaceNormal * (ActualDist - HalfDepth)

	local AlignedCFrame: CFrame
	if math.abs(SurfaceNormal.Y) < 0.7 then
		local FlatNormal = Vector3.new(SurfaceNormal.X, 0, SurfaceNormal.Z)
		local FaceDir = if FlatNormal.Magnitude > 1e-6 then FlatNormal.Unit else BounceDir
		AlignedCFrame = CFrame.new(CorrectPosition, CorrectPosition + FaceDir)
	elseif SurfaceNormal.Y >= 0.7 then
		local HeadDir = Horizontal - Horizontal:Dot(SurfaceNormal) * SurfaceNormal
		if HeadDir.Magnitude < 1e-6 then
			local Perp = SurfaceNormal:Cross(Vector3.new(0, 1, 0))
			HeadDir = if Perp.Magnitude > 1e-6 then Perp.Unit else Vector3.new(1, 0, 0)
		else
			HeadDir = HeadDir.Unit
		end
		local BackVec = -SurfaceNormal
		local RightVec = HeadDir:Cross(BackVec).Unit
		AlignedCFrame = CFrame.fromMatrix(CorrectPosition, RightVec, HeadDir, BackVec)
	else
		AlignedCFrame = CFrame.new(CorrectPosition, CorrectPosition + BounceDir) * CFrame.Angles(-math.pi / 2, 0, 0)
	end

	RootPart.Anchored = true
	RootPart.CFrame = AlignedCFrame

	J:Add(RunService.RenderStepped:Connect(function()
		if not RootPart.Parent then
			Cancel(Character)
			return
		end
		RootPart.AssemblyLinearVelocity = Vector3.zero
		RootPart.AssemblyAngularVelocity = Vector3.zero
		RootPart.CFrame = AlignedCFrame
	end))

	local Released = false

	Animations.CancelAnimations(Character)
	Animations.PlayAnimation(Character, "WallSplatter", { Looped = false })

	local SplatterThread = task.delay(SPLATTER_DURATION, function()
		Released = true
		J:Cleanup()
		if not RootPart.Parent then
			return
		end
		BounceOffWall(Character, CorrectPosition, BounceDir, SurfaceNormal)
	end)

	J:Add(function()
		if Released then
			return
		end
		Released = true
		if coroutine.status(SplatterThread) ~= "dead" then
			task.cancel(SplatterThread)
		end
		if RootPart.Parent then
			RootPart.Anchored = false
		end
	end, true)
end

-- Drives the visual flight on the owning client, moving the root every frame along
-- the same trajectory the server predicted, and reporting the landing back.
local function Do(Character: Model, Direction: Vector3, Options: options, StartPos: Vector3?)
	local J = GetJanitor(Character)
	J:Cleanup()

	local Humanoid = Character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	local RootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?

	if not RootPart or not Humanoid or not Character.Parent then
		return
	end

	RootPart.AssemblyLinearVelocity = Vector3.zero
	RootPart.AssemblyAngularVelocity = Vector3.zero
	Humanoid.AutoRotate = false

	local CurveFn = CURVES[Options.Curve or "Linear"] or CURVES.Linear
	local Distance = Options.Distance or 10
	local Duration = Options.Duration or 0.25
	local HalfDepth = RootPart.Size.Z / 2

	local Horizontal = Horizontalize(Direction)
	local Rot = CFrame.new(Vector3.zero, -Horizontal)
	local Params = ExcludeParams(Character)

	-- Snap to the server's authoritative start so both simulations share an origin.
	local Pos = StartPos or RootPart.Position
	if StartPos then
		RootPart.CFrame = CFrame.new(StartPos) * Rot
	end

	local PrevFactor = 0
	local Elapsed = 0

	Animations.PlayAnimation(
		Character,
		if Distance <= SMALL_DISTANCE then "KnockbackShort" else "KnockbackLong",
		{ Looped = false }
	)

	Humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	J:Add(RunService.RenderStepped:Connect(function(Dt: number)
		if not RootPart or not RootPart.Parent then
			Cancel(Character)
			return
		end

		Elapsed = math.min(Elapsed + Dt, Duration)
		local Factor = CurveFn(Elapsed / Duration)
		local DH = (Factor - PrevFactor) * Distance
		PrevFactor = Factor

		local Contact, NextPos = Advance(Pos, Horizontal, DH, Params, HalfDepth)

		Pos = NextPos
		RootPart.AssemblyLinearVelocity = Vector3.zero
		RootPart.AssemblyAngularVelocity = Vector3.zero
		RootPart.CFrame = CFrame.new(Pos) * Rot

		if Contact then
			Hit(Contact.Normal, Horizontal, Character, Contact.Point)
			return
		end

		if Elapsed >= Duration then
			Cancel(Character)
		end
	end))
end

function Knockback.knockbackSmall(Character: Model, Direction: Vector3, Options: options?, StartPos: Vector3?)
	Do(Character, Direction, {
		Curve = (Options and Options.Curve) or PRESETS.small.Curve,
		Distance = (Options and Options.Distance) or PRESETS.small.Distance,
		Duration = (Options and Options.Duration) or PRESETS.small.Duration,
	}, StartPos)
end

function Knockback.knockbackLarge(Character: Model, Direction: Vector3, Options: options?, StartPos: Vector3?)
	Do(Character, Direction, {
		Curve = (Options and Options.Curve) or PRESETS.large.Curve,
		Distance = (Options and Options.Distance) or PRESETS.large.Distance,
		Duration = (Options and Options.Duration) or PRESETS.large.Duration,
	}, StartPos)
end

--======================================================================
-- WIRING
--======================================================================

-- Server: listen for landing reports. Client: listen for knockback commands and run
-- the visual. Call once per boundary (ServerBootstrapper / ClientBootstrapper).
function Knockback.Listen()
	if SERVER then
		Events.KnockbackLanded.OnServerEvent:Connect(function(Player: Player, Character: Model, ReportedCFrame: CFrame)
			OnKnockbackLanded(Player, Character, ReportedCFrame)
		end)
	else
		Events.knockbackSmall.OnClientEvent:Connect(
			function(Character: Model, Direction: Vector3, Options: options?, StartPos: Vector3?)
				Knockback.knockbackSmall(Character, Direction, Options, StartPos)
			end
		)
		Events.knockbackLarge.OnClientEvent:Connect(
			function(Character: Model, Direction: Vector3, Options: options?, StartPos: Vector3?)
				Knockback.knockbackLarge(Character, Direction, Options, StartPos)
			end
		)
	end
end

return Knockback
