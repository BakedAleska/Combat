--!strict
-- @author BakedAleska
-- @date 05/31/2026

-- SERVICES
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- CONSTANTS
const SERVER = RunService:IsServer()
const DEFAULT_RATE_LIMIT = 60 -- max calls per window per player
const RATE_WINDOW = 1 -- seconds per window

-- VARIABLES
local Events = script.Events :: Folder
local Functions = script.Functions :: Folder

-- TYPES
type Callback = (...any) -> any
type Connection = RBXScriptConnection | RemoteFunction

type RateLimitConfig = {
	MaxCalls: number,
	Window: number,
}

type RateLimitEntry = {
	Count: number,
	WindowStart: number,
}

-- Rate limit state: [eventName][userId] = RateLimitEntry
local RateLimitData: { [string]: { [number]: RateLimitEntry } } = {}
local RateLimitConfigs: { [string]: RateLimitConfig } = {}

-- ─────────────────────────────────────────────
-- PRIVATE HELPERS
-- ─────────────────────────────────────────────

-- Returns a RemoteEvent by name, creating it if it doesn't exist yet.
-- On the server the remote is created under the Events folder.
-- On the client waits up to 10 seconds for the server to create it.
local function _Event(Name: string): RemoteEvent
	if SERVER then
		local Existing = Events:FindFirstChild(Name)
		if Existing and Existing:IsA("RemoteEvent") then
			return Existing :: RemoteEvent
		end
		local New = Instance.new("RemoteEvent")
		New.Name = Name
		New.Parent = Events
		return New
	else
		local Found = Events:WaitForChild(Name, 10)
		assert(Found and Found:IsA("RemoteEvent"), "[Networker] Event timed out or not found: " .. Name)
		return Found :: RemoteEvent
	end
end

-- Returns a RemoteFunction by name, creating it if it doesn't exist yet.
-- On the server the remote is created under the Functions folder.
-- On the client waits up to 10 seconds for the server to create it.
local function _Function(Name: string): RemoteFunction
	if SERVER then
		local Existing = Functions:FindFirstChild(Name)
		if Existing and Existing:IsA("RemoteFunction") then
			return Existing :: RemoteFunction
		end
		local New = Instance.new("RemoteFunction")
		New.Name = Name
		New.Parent = Functions
		return New
	else
		local Found = Functions:WaitForChild(Name, 10)
		assert(Found and Found:IsA("RemoteFunction"), "[Networker] Function timed out or not found: " .. Name)
		return Found :: RemoteFunction
	end
end

-- Returns true if the player is within their rate limit for the given event.
-- Called server-side only before processing an incoming client request.
local function _CheckRateLimit(Name: string, Player: Player): boolean
	const Config = RateLimitConfigs[Name] or { MaxCalls = DEFAULT_RATE_LIMIT, Window = RATE_WINDOW }
	const UserId = Player.UserId
	const Now = os.clock()

	if not RateLimitData[Name] then
		RateLimitData[Name] = {}
	end

	local Entry = RateLimitData[Name][UserId]

	if not Entry or (Now - Entry.WindowStart) >= Config.Window then
		-- New window
		RateLimitData[Name][UserId] = { Count = 1, WindowStart = Now }
		return true
	end

	if Entry.Count >= Config.MaxCalls then
		warn(
			string.format(
				"[Networker] Rate limit exceeded: '%s' by %s (%d) — %d/%d calls in %.2fs window",
				Name,
				Player.Name,
				UserId,
				Entry.Count,
				Config.MaxCalls,
				Config.Window
			)
		)
		return false
	end

	Entry.Count += 1
	return true
end

-- Clean up rate limit data when a player leaves
if SERVER then
	Players.PlayerRemoving:Connect(function(Player)
		const UserId = Player.UserId
		for _, PlayerData in pairs(RateLimitData) do
			PlayerData[UserId] = nil
		end
	end)
end

-- ─────────────────────────────────────────────
-- PUBLIC API
-- ─────────────────────────────────────────────

--- Remote event utility with rate limiting and improved reliability.
--- @class Networker
local Networker = {}

--- Sets a custom rate limit for a specific event or function.
--- Server-only. Call this before clients start firing the event.
--- @within Networker
--- @param Name string -- The remote name to configure.
--- @param MaxCalls number -- Maximum calls allowed per window.
--- @param Window number -- Duration of the window in seconds.
function Networker.SetRateLimit(Name: string, MaxCalls: number, Window: number)
	assert(SERVER, "[Networker] SetRateLimit must be called on the server.")
	RateLimitConfigs[Name] = { MaxCalls = MaxCalls, Window = Window }
end

--- Fires an event or invokes a remote function.
---
--- **Server:** scans args for a Player instance; if found, fires only to that
--- client with the Player stripped from the payload. Otherwise fires to all clients.
---
--- **Client:** if the last argument is a function, treats the call as a RemoteFunction
--- invocation and passes the server return value into the callback.
--- Otherwise fires a RemoteEvent to the server.
--- @within Networker
--- @param Name string -- The name of the RemoteEvent or RemoteFunction.
--- @param ... any -- Arguments forwarded to the remote.
--- @return any? -- Return value when invoking a RemoteFunction from the client.
function Networker.Fire(Name: string, ...: any): any?
	local Args: { any } = { ... }

	if SERVER then
		local Player: Player? = nil
		local FilteredArgs: { any } = {}

		-- Separate the Player from the rest of the args
		for _, Arg in ipairs(Args) do
			if typeof(Arg) == "Instance" and Arg:IsA("Player") then
				if not Player then
					Player = Arg -- take the first Player found
				end
				-- intentionally excluded from FilteredArgs
			else
				table.insert(FilteredArgs, Arg)
			end
		end

		const Event = _Event(Name)

		if Player then
			Event:FireClient(Player, table.unpack(FilteredArgs))
		else
			Event:FireAllClients(table.unpack(FilteredArgs))
		end
	else
		local Last = Args[#Args]

		if typeof(Last) == "function" then
			Args[#Args] = nil
			const Callback = Last :: Callback
			const Result = _Function(Name):InvokeServer(table.unpack(Args))
			Callback(Result)
			return Result
		else
			_Event(Name):FireServer(table.unpack(Args))
		end
	end

	return nil
end

--- Connects a callback to a named remote, with automatic server-side rate limiting.
---
--- **Server:** pass `true` as the third argument to bind to a RemoteFunction
--- (`OnServerInvoke`) instead of a RemoteEvent.
---
--- **Client:** always binds to `OnClientEvent` on a RemoteEvent.
--- @within Networker
--- @param Name string -- The name of the remote.
--- @param Callback Callback -- The handler to invoke.
--- @param IsFunction boolean? -- Server-only: bind to a RemoteFunction if true.
--- @return Connection -- The RBXScriptConnection or RemoteFunction.
function Networker.Connect(Name: string, Callback: Callback, IsFunction: boolean?): Connection
	if SERVER then
		if IsFunction then
			const Fn = _Function(Name)
			Fn.OnServerInvoke = function(Player: Player, ...: any): any?
				if not _CheckRateLimit(Name, Player) then
					return nil
				end
				return Callback(Player, ...)
			end
			return Fn
		end

		return _Event(Name).OnServerEvent:Connect(function(Player: Player, ...: any)
			if not _CheckRateLimit(Name, Player) then
				return
			end
			Callback(Player, ...)
		end)
	else
		return _Event(Name).OnClientEvent:Connect(Callback)
	end
end

--- Disconnects a connection returned by `Networker.Connect`.
--- Accepts either an RBXScriptConnection or a RemoteFunction,
--- clearing `OnServerInvoke` or `OnClientInvoke` accordingly.
--- @within Networker
--- @param Conn Connection -- The connection to disconnect.
function Networker.Disconnect(Conn: Connection)
	if typeof(Conn) == "RBXScriptConnection" then
		(Conn :: RBXScriptConnection):Disconnect()
	elseif typeof(Conn) == "Instance" and (Conn :: Instance):IsA("RemoteFunction") then
		const Fn = Conn :: RemoteFunction
		if SERVER then
			Fn.OnServerInvoke = function()
				return nil
			end
		else
			Fn.OnClientInvoke = function()
				return nil
			end
		end
	end
end

--- Creates or returns the RemoteEvent with the given name.
--- Server-only — use in a bootstrapper to pre-create events before clients connect.
--- @within Networker
--- @param Name string -- The name of the RemoteEvent.
--- @return RemoteEvent
function Networker.Event(Name: string): RemoteEvent
	assert(SERVER, "[Networker] Networker.Event must be called on the server.")
	return _Event(Name)
end

--- Creates or returns a RemoteFunction with the given name.
--- Server-only — use in a bootstrapper to pre-create functions before clients connect.
--- @within Networker
--- @param Name string -- The name of the RemoteFunction.
--- @return RemoteFunction
function Networker.Function(Name: string): RemoteFunction
	assert(SERVER, "[Networker] Networker.Function must be called on the server.")
	return _Function(Name)
end

--- Invokes a client-side RemoteFunction and returns the result.
--- Server-only — blocks the calling thread until the client responds.
--- @within Networker
--- @param Name string -- The name of the RemoteFunction.
--- @param Player Player -- The client to invoke.
--- @param ... any -- Arguments forwarded to the client handler.
--- @return any? -- Whatever the client handler returns.
function Networker.Invoke(Name: string, Player: Player, ...: any): any?
	assert(SERVER, "[Networker] Networker.Invoke must be called on the server.")
	return _Function(Name):InvokeClient(Player, ...)
end

--- Binds a callback to a RemoteFunction's `OnClientInvoke`.
--- Client-only — the return value of the callback is sent back to the server.
--- @within Networker
--- @param Name string -- The name of the RemoteFunction.
--- @param Callback Callback -- The handler; its return value is the response.
--- @return RemoteFunction
function Networker.Handle(Name: string, Callback: Callback): RemoteFunction
	assert(not SERVER, "[Networker] Networker.Handle must be called on the client.")
	const Fn = _Function(Name)
	Fn.OnClientInvoke = Callback
	return Fn
end

return Networker
