-- SERVICES
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- IMPORT
local Idle = require(ServerScriptService.Server.StateMachine.States.Idle)
local StateMachine = require(script.Parent.StateMachine)

local StateMachineInstance = StateMachine.new(Idle.new())

RunService.Heartbeat:Connect(function(dt: number)
	StateMachineInstance:Update(dt)
end)
