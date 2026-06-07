--!strict
-- VSCode remote event utility.
-- @author : BakedAleska
-- @date : 05/31/2026

-- SERVICES
local RunService = game:GetService("RunService")

-- CONSTANTS
const SERVER = RunService:IsServer()

-- VARIABLES
local Events = script.Events :: Folder
local Functions = script.Functions :: Folder

-- TYPES
type callback = (...any) -> any
type connection = RBXScriptConnection | RemoteFunction

local Networker = {}

--[[
	Returns a RemoteEvent by name, creating it if it doesn't exist yet.
	On the server the remote is created under the Events folder.
	On the client waits up to 10 seconds for the server to create it.

	@param Name string -- The name of the RemoteEvent.
	@return RemoteEvent
--]]
local function _Event(Name: string): RemoteEvent
	local Remote: RemoteEvent
	if SERVER then
		local Existing = Events:FindFirstChild(Name)
		if Existing and Existing:IsA("RemoteEvent") then
			Remote = Existing
		else
			local New = Instance.new("RemoteEvent")
			New.Name = Name
			New.Parent = Events
			Remote = New
		end
	else
		local Found = Events:WaitForChild(Name, 10)
		assert(Found and Found:IsA("RemoteEvent"), "[Networker] Event timed out or not found: " .. Name)
		Remote = Found :: RemoteEvent
	end

	return Remote
end

--[[
	Returns a RemoteFunction by name, creating it if it doesn't exist yet.
	On the server the remote is created under the Functions folder.
	On the client waits up to 10 seconds for the server to create it.

	@param Name string -- The name of the RemoteFunction.
	@return RemoteFunction
--]]
local function _Function(Name: string): RemoteFunction
	local Remote: RemoteFunction
	if SERVER then
		local Existing = Functions:FindFirstChild(Name)
		if Existing and Existing:IsA("RemoteFunction") then
			Remote = Existing
		else
			local New = Instance.new("RemoteFunction")
			New.Name = Name
			New.Parent = Functions
			Remote = New
		end
	else
		local Found = Functions:WaitForChild(Name, 10)
		assert(Found and Found:IsA("RemoteFunction"), "[Networker] Function timed out or not found: " .. Name)
		Remote = Found :: RemoteFunction
	end

	return Remote
end

--[[
	Fires an event or invokes a remote function.

	Server: scans args for a Player or character; if found fires to that specific
	client with the Player stripped from the payload, otherwise fires to all clients.

	Client: if the last argument is a function treats the call as a RemoteFunction
	invocation and passes the server return value into the callback.
	Otherwise fires a RemoteEvent to the server.

	@param Name string -- The name of the RemoteEvent or RemoteFunction.
	@param ...  any    -- Arguments forwarded to the remote. A trailing function on the client triggers an invoke.
	@return any?       -- The server return value when invoking a RemoteFunction on the client.
--]]
function Networker.Fire(Name: string, ...: any): any?
	local Args: { any } = { ... }

	if SERVER then
		local Player: Player? = nil

		for _, Arg in ipairs(Args) do
			if typeof(Arg) == "Instance" then
				if Arg:IsA("Player") then
					Player = Arg
					continue
				end
			end
		end

		local Event = _Event(Name)

		if Player then
			Event:FireClient(Player, table.unpack(Args))
		else
			Event:FireAllClients(table.unpack(Args))
		end
	else
		local Last = Args[#Args]

		if typeof(Last) == "function" then
			Args[#Args] = nil
			local callback = Last :: callback
			local Result = _Function(Name):InvokeServer(table.unpack(Args))
			callback(Result)
			return Result
		else
			_Event(Name):FireServer(table.unpack(Args))
		end
	end

	return nil
end

--[[
	Connects a callback to a named remote.

	Server: named functions (debug.info name ~= "") bind to OnServerInvoke on a
	RemoteFunction — use this for request/response flows. Anonymous functions bind
	to OnServerEvent on a RemoteEvent.

	Client: always binds to OnClientEvent on a RemoteEvent.

	@param Name     string   -- The name of the RemoteEvent or RemoteFunction.
	@param callback callback -- The handler to invoke when the remote fires.
	@return connection       -- The resulting RBXScriptconnection or RemoteFunction.
--]]
function Networker.Connect(Name: string, callback: callback): connection
	if SERVER then
		if debug.info(callback, "n") ~= "" then
			local Fn = _Function(Name)
			Fn.OnServerInvoke = callback
			return Fn
		end
		return _Event(Name).OnServerEvent:Connect(callback)
	else
		return _Event(Name).OnClientEvent:Connect(callback)
	end
end

--[[
	Creates or returns the RemoteEvent with the given name.
	Server-only — use in ServerBootstrapper to pre-create events before clients connect.

	@param Name string -- The name of the RemoteEvent.
	@return RemoteEvent
--]]

function Networker.Event(Name: string): RemoteEvent
	assert(SERVER, "[Networker] Networker.Event must be called on the server.")
	return _Event(Name)
end

--[[
	Creates or returns RemoteFunction with the given name.
	Server-only — use in ServerBootstrapper to pre-create functions before clients connect.

	@param Name string -- The name of the RemoteFunction.
	@return RemoteFunction
--]]
function Networker.Function(Name: string): RemoteFunction
	assert(SERVER, "[Networker] Networker.Function must be called on the server.")
	return _Function(Name)
end

--[[
	Invokes a client-side RemoteFunction and returns the result.
	Server-only — blocks the calling thread until the client responds.

	@param Name   string -- The name of the RemoteFunction.
	@param Player Player -- The client to invoke.
	@param ...    any    -- Arguments forwarded to the client handler.
	@return any?         -- Whatever the client handler returns.
--]]
function Networker.Invoke(Name: string, Player: Player, ...: any): any?
	assert(SERVER, "[Networker] Networker.Invoke must be called on the server.")
	return _Function(Name):InvokeClient(Player, ...)
end

--[[
	Binds a callback to a RemoteFunction's OnClientInvoke.
	Client-only — the return value of callback is sent back to the server.

	@param Name     string   -- The name of the RemoteFunction.
	@param callback callback -- The handler; its return value is the response.
	@return RemoteFunction
--]]
function Networker.Handle(Name: string, callback: callback): RemoteFunction
	assert(not SERVER, "[Networker] Networker.Handle must be called on the client.")
	local Fn = _Function(Name)
	Fn.OnClientInvoke = callback
	return Fn
end

return Networker
