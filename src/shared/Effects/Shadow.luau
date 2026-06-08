local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

return function(Character: Model, Duration: number)
	local Clone = Instance.new("Model")
	Clone.Name = "ShadowClone"

	local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local Location = if Root then Root.CFrame else nil

	for _, Part in Character:GetDescendants() do
		if not Part:IsA("BasePart") then
			continue
		end
		if Part.Name == "HumanoidRootPart" or Part.Name == "Collide" or Part:HasTag("Effect") then
			continue
		end
		if Part.Name == "Handle" and Part.Parent and Part.Parent:IsA("Model") then
			continue
		end

		local Ghost = Instance.new("Part")
		Ghost.Name = Part.Name
		Ghost.Size = Part.Size
		Ghost.CFrame = if Location and Root
			then Location:ToWorldSpace(Root.CFrame:ToObjectSpace(Part.CFrame))
			else Part.CFrame
		Ghost.Color = Color3.new(0, 0, 0)
		Ghost.Transparency = 0.7
		Ghost.Anchored = true
		Ghost.CanCollide = false
		Ghost.CanQuery = false
		Ghost.CanTouch = false
		Ghost.CastShadow = false

		local Mesh = Part:FindFirstChildOfClass("SpecialMesh") or Part:FindFirstChildOfClass("BlockMesh")
		if Mesh then
			local MeshClone = Mesh:Clone() :: SpecialMesh | BlockMesh
			MeshClone.Parent = Ghost
		elseif Part.Name == "Head" then
			local FallbackMesh = Instance.new("SpecialMesh")
			FallbackMesh.MeshType = Enum.MeshType.Sphere
			FallbackMesh.Parent = Ghost
		end

		Ghost.Parent = Clone
	end

	Clone.Parent = Workspace
	Debris:AddItem(Clone, Duration)

	task.spawn(function()
		local Steps = 30
		local Interval = Duration / Steps
		for i = 1, Steps do
			task.wait(Interval)
			local Alpha = i / Steps
			for _, Ghost in Clone:GetChildren() do
				if Ghost:IsA("BasePart") then
					Ghost.Transparency = 0.7 + (0.3 * Alpha)
				end
			end
		end
	end)
end
