--!nonstrict
-- @author : BakedAleska
-- @date : 02/21/2026

-- CONSTANTS
const DEFAULT_FADE_TIME = 0.1

const TRACK_PROPERTIES = {
	Looped = true,
	Priority = true,
	TimePosition = true,
	Length = true,
}

-- SERVICES
const ContentProvider = game:GetService("ContentProvider")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Networker = require(ReplicatedStorage.Shared.Networker)

-- VARIABLES
const Player = Players.LocalPlayer

--> Declare
local Animations = {}

--[[
-- A per-key local animation playing list and queue.
-- Allows multiple concurrent animations by name/group.
--]]
const Playing: { [string]: AnimationTrack } = {}
const Queued: { [string]: AnimationTrack } = {}

export type Properties = { Looped: boolean?, Group: string?, FadeTime: number?, Speed: number?, Priority: Enum.AnimationPriority? }

function Animations.PlayAnimation(Character: Model, Name: string, Properties: Properties?)
	local Animation
	if string.match(Name, "^rbxassetid://") or string.match(Name, "^%d+$") then
		const TempAnim = Instance.new("Animation")
		TempAnim.AnimationId = string.match(Name, "^%d+$") and ("rbxassetid://" .. Name) or Name
		TempAnim.Name = Name
		Animation = TempAnim
	else
		Animation = ReplicatedStorage.Assets.Animations:FindFirstChild(Name, true)
		if not Animation then
			warn(string.format("[Animations] No such animation: %s", Name))
			return
		end
	end

	const Humanoid = Character:FindFirstChildOfClass("Humanoid")
	assert(Humanoid, "[Animations] No humanoid for character: " .. Character.Name)

	const Animator = Humanoid:FindFirstChildOfClass("Animator")
	assert(Animator, "[Animations] No Animator found.")

	const Track = Animator:LoadAnimation(Animation) :: AnimationTrack
	const FadeTime = (Properties and Properties.FadeTime) or DEFAULT_FADE_TIME

	if Properties then
		if Properties.Group then
			Track:SetAttribute("Group", Properties.Group)
		end

		for Property, Value in pairs(Properties) do
			if Property == "Speed" then
				Track:AdjustSpeed(Value)
			elseif TRACK_PROPERTIES[Property] then
				Track[Property] = Value
			end
		end
	end

	const LOOPED = Track.Looped
	const LOCAL = Character == Player.Character
	const Key = (Properties and Properties.Group) or Name

	if LOCAL then
		const Existing = Playing[Key]
		if Existing and Existing ~= Track then
			if Existing.Looped and not LOOPED then
				Queued[Key] = Existing
			end
			if LOOPED then
				Queued[Key] = nil
			end
			Existing:Stop(FadeTime)
		end

		Playing[Key] = Track
	end

	Track:Play(FadeTime)

	if not LOOPED then
		const TrackRef = Track
		TrackRef.Stopped:Once(function()
			if not LOCAL then
				return
			end
			if Playing[Key] ~= TrackRef then
				return
			end

			Playing[Key] = nil

			if Queued[Key] then
				const Resume = Queued[Key]
				Queued[Key] = nil
				Playing[Key] = Resume
				Resume:Play(DEFAULT_FADE_TIME)
			end
		end)
	end
end

function Animations.StopAnimation(Character: Model, Name: string, FadeTime: number?)
	FadeTime = FadeTime or DEFAULT_FADE_TIME

	const LOCAL = Character == Player.Character

	if LOCAL then
		for Key, Track in pairs(Playing) do
			if Track and (Track.Name == Name or Track:GetAttribute("Group") == Name) then
				Track:Stop(FadeTime)
				Playing[Key] = nil
			end
		end

		for Key, Track in pairs(Queued) do
			if Track and (Track.Name == Name or Track:GetAttribute("Group") == Name) then
				Track:Stop(FadeTime)
				Queued[Key] = nil
			end
		end
	else
		const Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if not Humanoid then
			return
		end

		const Animator = Humanoid:FindFirstChildOfClass("Animator")
		if not Animator then
			return
		end

		const Tracks = Animator:GetPlayingAnimationTracks()
		if #Tracks == 0 then
			return
		end

		for _, Track in ipairs(Tracks) do
			Track:Stop(FadeTime)
		end
	end
end

function Animations.ModifyAnimation(Character: Model, Name: string, Key: string, Value: any)
	const LOCAL = Character == Player.Character

	if LOCAL then
		const Apply = function(Track)
			if not Track then
				return
			end
			if Track.Name ~= Name and Track:GetAttribute("Group") ~= Name then
				return
			end

			if Key == "Speed" then
				Track:AdjustSpeed(Value)
			elseif TRACK_PROPERTIES[Key] then
				Track[Key] = Value
			end
		end

		for _, Track in pairs(Playing) do
			Apply(Track)
		end
		for _, Track in pairs(Queued) do
			Apply(Track)
		end
	else
		const Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if not Humanoid then
			return
		end

		const Animator = Humanoid:FindFirstChildOfClass("Animator")
		if not Animator then
			return
		end

		for _, Track in ipairs(Animator:GetPlayingAnimationTracks()) do
			if Track.Name == Name or Track:GetAttribute("Group") == Name then
				if Key == "Speed" then
					Track:AdjustSpeed(Value)
				elseif TRACK_PROPERTIES[Key] then
					Track[Key] = Value
				end
			end
		end
	end
end

function Animations.CancelAnimations(Character: Model, FadeTime: number?)
	FadeTime = FadeTime or DEFAULT_FADE_TIME

	const LOCAL = Character == Player.Character

	if LOCAL then
		for Key, Track in pairs(Playing) do
			if Track then
				Track:Stop(FadeTime)
			end
			Playing[Key] = nil
		end

		for Key, Track in pairs(Queued) do
			if Track then
				Track:Stop(FadeTime)
			end
			Queued[Key] = nil
		end
	else
		const Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if not Humanoid then
			return
		end

		const Animator = Humanoid:FindFirstChildOfClass("Animator")
		if not Animator then
			return
		end

		for _, Track in ipairs(Animator:GetPlayingAnimationTracks()) do
			Track:Stop(FadeTime)
		end
	end
end

function Animations.Listen()
	const Queue = {}
	for _, Animation in ipairs(ReplicatedStorage.Assets.Animations:GetDescendants()) do
		if Animation:IsA("Animation") then
			table.insert(Queue, Animation)
		end
	end
	if #Queue > 0 then
		ContentProvider:PreloadAsync(Queue)
	end

	Networker.Connect("playAnimation", function(Character: Model, Name: string, Properties)
		Animations.PlayAnimation(Character, Name, Properties)
	end)

	Networker.Connect("stopAnimation", function(Character: Model, Name: string, FadeTime: number?)
		Animations.StopAnimation(Character, Name, FadeTime)
	end)

	Networker.Connect("modifyAnimation", function(Character: Model, Name, Key, Value)
		Animations.ModifyAnimation(Character, Name, Key, Value)
	end)

	Networker.Connect("cancelAnimations", function(Character: Model, FadeTime: number?)
		Animations.CancelAnimations(Character, FadeTime)
	end)
end

return Animations
