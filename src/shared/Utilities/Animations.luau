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
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Shared.Networker)

-- VARIABLES
local Player = Players.LocalPlayer

--> Declare
local Animations = {}

--[[
-- A per-key local animation playing list and queue.
-- Allows multiple concurrent animations by name/group.
--]]
local Playing: { [string]: AnimationTrack } = {}
local Queued: { [string]: AnimationTrack } = {}

export type Properties = { Looped: boolean?, Group: string?, FadeTime: number?, Speed: number? }

function Animations.PlayAnimation(Character: Model, Name: string, Properties: Properties?)
	local Animation = ReplicatedStorage.Assets.Animations:FindFirstChild(Name, true)
	if not Animation then
		warn(string.format("[Animations] No such animation: %s", Name))
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	assert(Humanoid, "[Animations] No humanoid for character: " .. Character.Name)

	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	assert(Animator, "[Animations] No Animator found.")

	local Track = Animator:LoadAnimation(Animation) :: AnimationTrack
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
	local Key = (Properties and Properties.Group) or Name

	if LOCAL then
		local Existing = Playing[Key]
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
		local track = Track
		track.Stopped:Once(function()
			if not LOCAL then
				return
			end
			if Playing[Key] ~= track then
				return
			end

			Playing[Key] = nil

			if Queued[Key] then
				local resume = Queued[Key]
				Queued[Key] = nil
				Playing[Key] = resume
				resume:Play(DEFAULT_FADE_TIME)
			end
		end)
	end
end

function Animations.StopAnimation(Character: Model, Name: string, FadeTime: number?)
	FadeTime = FadeTime or DEFAULT_FADE_TIME

	local LOCAL = Character == Player.Character

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
		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if not Humanoid then
			return
		end

		local Animator = Humanoid:FindFirstChildOfClass("Animator")
		if not Animator then
			return
		end

		local Tracks = Animator:GetPlayingAnimationTracks()
		if #Tracks == 0 then
			return
		end

		for _, Track in ipairs(Tracks) do
			Track:Stop(FadeTime)
		end
	end
end

function Animations.ModifyAnimation(Character: Model, Name: string, Key: string, Value: any)
	local LOCAL = Character == Player.Character

	if LOCAL then
		local function apply(track)
			if not track then
				return
			end
			if track.Name ~= Name and track:GetAttribute("Group") ~= Name then
				return
			end

			if Key == "Speed" then
				track:AdjustSpeed(Value)
			elseif TRACK_PROPERTIES[Key] then
				track[Key] = Value
			end
		end

		for _, Track in pairs(Playing) do
			apply(Track)
		end
		for _, Track in pairs(Queued) do
			apply(Track)
		end
	else
		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if not Humanoid then
			return
		end

		local Animator = Humanoid:FindFirstChildOfClass("Animator")
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

	local LOCAL = Character == Player.Character

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
		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if not Humanoid then
			return
		end

		local Animator = Humanoid:FindFirstChildOfClass("Animator")
		if not Animator then
			return
		end

		for _, Track in ipairs(Animator:GetPlayingAnimationTracks()) do
			Track:Stop(FadeTime)
		end
	end
end

function Animations.Listen()
	local Queue = {}
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
