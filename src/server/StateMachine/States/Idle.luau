local ServerScriptService = game:GetService("ServerScriptService")
local State = require(script.Parent.Parent.State)
local Extend = require(ServerScriptService.Server.Functions.Extend)
local Idle = Extend(State, { ["Name"] = "Idle" })

return Idle
