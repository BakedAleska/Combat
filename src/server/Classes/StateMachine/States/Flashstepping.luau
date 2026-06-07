local ServerScriptService = game:GetService("ServerScriptService")
local State = require(script.Parent.Parent.State)
local Extend = require(ServerScriptService.Server.Functions.Extend)
local Flashstepping = Extend(State, { ["Name"] = "Flashstepping", ["Priority"] = 9 })

return Flashstepping
