local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Effects = require(ReplicatedStorage.Shared.Utilities.Effects)

local JUMP_COOLDOWN = 1.5 -- seconds

local CharacterController = {}

function CharacterController.OnCharacterAdded(Character: Model)
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return
	end

	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)

	local jumpReady = true

	Humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
		if Humanoid.Jump then
			if not jumpReady then
				Humanoid.Jump = false
				return
			end

			jumpReady = false
			task.delay(JUMP_COOLDOWN, function()
				jumpReady = true
			end)
		end
	end)

	Humanoid.StateChanged:Connect(function(HumanoidState: Enum.HumanoidStateType)
		if HumanoidState == Enum.HumanoidStateType.Landed then
			Effects.Emit(
				"Landed",
				Character.HumanoidRootPart:FindFirstChild("GroundAttachment") :: Attachment,
				{ InheritColor = true }
			)
		end
	end)
end

return CharacterController
