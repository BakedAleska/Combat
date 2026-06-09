--!strict

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- IMPORTS
local StatefulMotor6D = require(script.Parent.StatefulMotor6D)
local Data = require(ServerScriptService.Server.Configurations.Data)
local Weapons = require(ServerScriptService.Server.Configurations.Weapons)
local ProfileStore = require(ServerScriptService.ServerPackages.profilestore)

--- @class ProfileService
--- Manages player profiles via ProfileStore.
--- Handles session lifetime (load, unload) and live data mutation.
--- Player lifecycle connections (PlayerAdded, PlayerRemoving) are the
--- responsibility of the caller — typically PlayerController.

--- @prop Profiles { [number]: any }
--- @within ProfileService
--- Map of UserId to loaded profile. A missing key means the profile is not yet loaded or has been released.

local ProfileService = {}
ProfileService.Profiles = {} :: { [number]: any }

local PlayerStore = ProfileStore.New(RunService:IsStudio() and "Trial" or "Live", Data)

--- Loads and starts a profile session for the given player.
--- Yields until the session is established or cancelled.
--- Kicks the player on failure or if the session ends unexpectedly.
--- Should be called from `PlayerController.new` inside a `task.spawn`.
--- @param Player Player
function ProfileService.Load(Player: Player)
	local Profile = PlayerStore:StartSessionAsync("Player_" .. Player.UserId, {
		Cancel = function()
			return Player.Parent ~= Players
		end,
	})
	if Profile then
		Profile:AddUserId(Player.UserId)
		Profile:Reconcile()
		Profile.OnSessionEnd:Connect(function()
			ProfileService.Profiles[Player.UserId] = nil
			Player:Kick("Fatal data error. Please rejoin.")
		end)
		if Player.Parent == Players then
			ProfileService.Profiles[Player.UserId] = Profile
		else
			Profile:EndSession()
		end
	else
		Player:Kick("Fatal data error. Please rejoin.")
	end
end

--- Ends the active profile session for the given player and flushes data to the store.
--- Should be called from `PlayerController:Destroy`.
--- No-ops if the player has no loaded profile.
--- @param Player Player
function ProfileService.Unload(Player: Player)
	local Profile = ProfileService.Profiles[Player.UserId]
	if Profile then
		Profile:EndSession()
	end
end

--- Returns the loaded profile for the given player.
--- Returns `nil` if the profile has not yet finished loading or has been released.
--- @param Player Player
--- @return any?
function ProfileService.Get(Player: Player): any?
	return ProfileService.Profiles[Player.UserId]
end

--- Yields the calling thread until the player's profile is loaded or they leave.
--- Returns the profile on success, or `nil` if the player left before it loaded.
--- @param Player Player
--- @yields
--- @return any?
function ProfileService.WaitForProfile(Player: Player): any?
	while Player.Parent == Players and not ProfileService.Profiles[Player.UserId] do
		task.wait()
	end
	return ProfileService.Profiles[Player.UserId]
end

--- Writes a single field into the player's live profile data.
--- No-ops silently if the profile is not loaded.
--- @param Player Player
--- @param Key string -- The data key to write.
--- @param Value any -- The value to assign.
function ProfileService.Set(Player: Player, Key: string, Value: any)
	local Profile = ProfileService.Profiles[Player.UserId]
	if Profile then
		Profile.Data[Key] = Value
	end
end

--- Resets all profile data fields to their defaults from the Data config,
--- removes any keys not present in the config, and kicks the player.
--- No-ops if the player has no loaded profile.
--- @param Player Player
function ProfileService.Wipe(Player: Player)
	local Profile = ProfileService.Profiles[Player.UserId]
	if not Profile then
		return
	end
	for Key, Default in pairs(Data) do
		Profile.Data[Key] = Default
	end
	for Key in pairs(Profile.Data) do
		if Data[Key] == nil then
			Profile.Data[Key] = nil
		end
	end
	Player:Kick("Data wiped.")
end

function ProfileService.GiveWeapon(Player: Player, Value: string)
	if not Weapons[Value] then
		return warn("[ProfileService] No such weapon:", Value)
	end

	local Profile = ProfileService.Profiles[Player.UserId]
	assert(Profile, "[ProfileService] Player has no such valid profile.")

	local WeaponConfiguration = Weapons[Value]

	local Character = Player.Character :: Model
	assert(Character, "[ProfileService] Invalid character.")

	local RightArm = Character:FindFirstChild("Right Arm") :: BasePart
	local Torso = Character:FindFirstChild("Torso") :: BasePart

	StatefulMotor6D.Cleanup(Character)

	local WeaponModel = WeaponConfiguration.WeaponModel:Clone()
	WeaponModel.Parent = Character

	local SheatheModel = WeaponConfiguration.SheatheModel:Clone()
	SheatheModel.Parent = Character

	local Handle = WeaponModel:FindFirstChild("Handle") :: BasePart
	assert(Handle, "[ProfileService] WeaponModel has no such valid handle.")

	-- Hand
	local ActiveMotor6D = StatefulMotor6D.Create(
		RightArm,
		Handle,
		{ ["C0"] = WeaponConfiguration.ActiveC0, ["Name"] = "RightHandMotor6D" }
	)

	-- Hip / Back
	local PassiveMotor6D =
		StatefulMotor6D.Create(Torso, Handle, { ["C0"] = WeaponConfiguration.PassiveC0, ["Name"] = "TorsoMotor6D" })

	-- Sheathe
	local InactiveMotor6D = StatefulMotor6D.Create(
		Torso,
		SheatheModel.PrimaryPart,
		{ ["C0"] = WeaponConfiguration.InactiveC0, ["Name"] = "InactiveMotor6D" }
	)

	ActiveMotor6D.Enabled = false
	PassiveMotor6D.Enabled = true
	InactiveMotor6D.Enabled = true

	Profile.Data["Weapon"] = Value
end

return ProfileService
