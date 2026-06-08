--!nonstrict
-- @date 05/29/2026
-- @author BakedAleska

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- PACKAGES
local Replica = require(ReplicatedStorage.Packages.replica)

-- CONSTANTS
const PLAYER_TOKEN = Replica.Token("PlayerData")

--- Per-player replica manager.
--- Responsible for creating, managing, and destroying a player's Replica.
--- @class Replicator
local Replicator = {}
Replicator.__index = Replicator

--- Creates a Replica for the given player with the provided initial data.
--- Subscribes the player as soon as Replica reports them ready.
--- @param Player Player -- The Roblox Player instance.
--- @param Format { [string]: any } -- The initial replicated data table.
--- @return Replicator
function Replicator.new(Player: Player, Format: { [string]: any })
	local PlayerReplica = Replica.New({
		Token = PLAYER_TOKEN,
		Tags = {
			UserId = Player.UserId,
		},
		Data = Format,
	})

	local self = setmetatable({
		_Player = Player,
		_Replica = PlayerReplica,
		_Ready = nil,
	}, Replicator)

	if Replica.ReadyPlayers[Player] then
		PlayerReplica:Subscribe(Player)
	else
		self._Ready = Replica.NewReadyPlayer:Connect(function(ReadyPlayer)
			if ReadyPlayer ~= Player then
				return
			end

			PlayerReplica:Subscribe(Player)

			self._Ready:Disconnect()
			self._Ready = nil
		end)
	end

	return self
end

--- Sets a value at the given path in the replicated data.
--- Path is an array of string keys, e.g. `{ "Stats", "Health", "Current" }`.
--- No-ops if the replica has already been destroyed.
--- @param Path { string } -- Key path into the replica's Data table.
--- @param Value any -- The value to write.
function Replicator:Set(Path: { string }, Value: any)
	if not self._Replica:IsActive() then
		return
	end

	self._Replica:Set(Path, Value)
end

--- Destroys the replica and cleans up all subscriptions.
function Replicator:Destroy()
	if self._Ready then
		self._Ready:Disconnect()
		self._Ready = nil
	end

	if self._Replica:IsActive() then
		self._Replica:Destroy()
	end
end

return Replicator
