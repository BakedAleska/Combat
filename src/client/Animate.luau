--!nonstrict
-- @date : 06/12/2026

-- CONSTANTS
const FADE = 0.1
const FALL_FADE = 0.3
const JUMP_TO_FALL_DELAY = 0.3

const IDLE_ID = "rbxassetid://180435571"
const WALK_ID = "rbxassetid://124950136614851"
const JUMP_ID = "rbxassetid://125750702"
const FALL_ID = "rbxassetid://180436148"
const CLIMB_ID = "rbxassetid://180436334"
const SIT_ID = "rbxassetid://178130996"

local Animate = {}

function Animate.Init(Character: Model)
	-- Disable any existing default Animate script, and guard against it arriving late
	local function DisableDefaultAnimate(Child: Instance)
		if Child.Name == "Animate" and Child:IsA("LocalScript") then
			Child.Enabled = false
		end
	end

	for _, Child in ipairs(Character:GetChildren()) do
		DisableDefaultAnimate(Child)
	end
	Character.ChildAdded:Connect(DisableDefaultAnimate)

	const Humanoid = Character:WaitForChild("Humanoid") :: Humanoid

	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then
		Animator = Instance.new("Animator")
		Animator.Parent = Humanoid
	end

	-- Clear leftover tracks from a prior life
	for _, Track in ipairs(Animator:GetPlayingAnimationTracks()) do
		Track:Stop(0)
		Track:Destroy()
	end

	local function Load(Id: string): AnimationTrack
		const Anim = Instance.new("Animation")
		Anim.AnimationId = Id
		const Track = Animator:LoadAnimation(Anim)
		Track.Priority = Enum.AnimationPriority.Core
		return Track
	end

	const IdleTrack = Load(IDLE_ID)
	const WalkTrack = Load(WALK_ID)
	const JumpTrack = Load(JUMP_ID)
	const FallTrack = Load(FALL_ID)
	const ClimbTrack = Load(CLIMB_ID)
	const SitTrack = Load(SIT_ID)

	WalkTrack.Priority = Enum.AnimationPriority.Movement

	local CurrentTrack: AnimationTrack? = nil

	local function Play(Track: AnimationTrack, FadeTime: number?)
		if Track == CurrentTrack then
			return
		end
		if CurrentTrack then
			CurrentTrack:Stop(FadeTime or FADE)
		end
		CurrentTrack = Track
		Track:Play(FadeTime or FADE)
	end

	local RecentlyJumped = false

	Humanoid.Running:Connect(function(Speed)
		if Speed / Character:GetScale() > 0.01 then
			Play(WalkTrack, FADE)
		else
			Play(IdleTrack, FADE)
		end
	end)

	Humanoid.Jumping:Connect(function()
		RecentlyJumped = true
		Play(JumpTrack, FADE)
		task.delay(JUMP_TO_FALL_DELAY, function()
			RecentlyJumped = false
			if Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
				Play(FallTrack, FALL_FADE)
			end
		end)
	end)

	Humanoid.FreeFalling:Connect(function()
		if not RecentlyJumped then
			Play(FallTrack, FALL_FADE)
		end
	end)

	Humanoid.Climbing:Connect(function(Speed)
		Play(ClimbTrack, FADE)
		ClimbTrack:AdjustSpeed(Speed / Character:GetScale() / 12)
	end)

	Humanoid.Seated:Connect(function(IsSeated)
		if IsSeated then
			Play(SitTrack, 0.5)
		end
	end)

	Play(IdleTrack, 0)
end

return Animate
