-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- IMPORTS
local Animations = require(ReplicatedStorage.Shared.Utilities.Animations)
local Effects = require(ReplicatedStorage.Shared.Utilities.Effects)
local Forces = require(ReplicatedStorage.Shared.Utilities.Forces)

-- INITIALIZE
Animations.Listen()
Effects.Listen()
Forces.Listen()
