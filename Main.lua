local PlayerService = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local lplr = PlayerService.LocalPlayer

local RenderHelper = {}
local mainblur
function RenderHelper:Init()
	local blur = Instance.new("DepthOfFieldEffect", Lighting)
	blur.FarIntensity = 0
	blur.FocusDistance = 51.6
	blur.InFocusRadius = 50
	blur.NearIntensity = 0.8
	mainblur = blur
end

local function CreateTriangle(p1, p2, p3, part1, part2)
	local len1, len2, len3 = (p1 - p2).magnitude, (p2 - p3).magnitude, (p3 - p1).magnitude
	local maxLen = math.max(len1, len2, len3)
	local main, side1, side2 = p1, p2, p3
	if len1 == maxLen then main, side1, side2 = p1, p2, p3
	elseif len2 == maxLen then main, side1, side2 = p2, p3, p1
	else main, side1, side2 = p3, p1, p2 end

	local parallelOffset = ((side1 - main).x * (side2 - main).x + (side1 - main).y * (side2 - main).y + (side1 - main).z * (side2 - main).z) / (main - side1).magnitude
	local perpendicularOffset = math.sqrt((side2 - main).magnitude ^ 2 - parallelOffset * parallelOffset)
	local differenceOffset = (main - side1).magnitude - parallelOffset

	local baseFrame = CFrame.new(side1, main)
	local angleOffset = CFrame.Angles(math.pi / 2, 0, 0)
	local base = baseFrame

	local topLook = (base * angleOffset).lookVector
	local midPoint = main + CFrame.new(main, side1).lookVector * parallelOffset
	local targetLook = CFrame.new(midPoint, side2).lookVector
	local dotProduct = topLook:Dot(targetLook)

	local angleCorrection = CFrame.Angles(0, 0, math.acos(dotProduct))
	base = base * angleCorrection

	if ((base * angleOffset).lookVector - targetLook).magnitude > 0.01 then
		base = base * CFrame.Angles(0, 0, -2 * math.acos(dotProduct))
	end

	base = base * CFrame.new(0, perpendicularOffset / 2, -(differenceOffset + parallelOffset / 2))

	local mirroredBase = baseFrame * angleCorrection * CFrame.Angles(0, math.pi, 0)
	if ((mirroredBase * angleOffset).lookVector - targetLook).magnitude > 0.01 then
		mirroredBase = mirroredBase * CFrame.Angles(0, 0, 2 * math.acos(dotProduct))
	end

	mirroredBase = mirroredBase * CFrame.new(0, perpendicularOffset / 2, differenceOffset / 2)

	if not part1 then
		part1 = Instance.new("Part")
		part1.FormFactor = "Custom"
		part1.TopSurface = 0
		part1.BottomSurface = 0
		part1.Anchored = true
		part1.CanCollide = false
		part1.Material = "Glass"
		part1.Size = Vector3.new(0.2, 0.2, 0.2)
		local mesh = Instance.new("SpecialMesh", part1)
		mesh.MeshType = 2
		mesh.Name = "WedgeMesh"
	end

	part1.WedgeMesh.Scale = Vector3.new(0, perpendicularOffset / 0.2, parallelOffset / 0.2)
	part1.CFrame = base

	if not part2 then part2 = part1:Clone() end
	part2.WedgeMesh.Scale = Vector3.new(0, perpendicularOffset / 0.2, differenceOffset / 0.2)
	part2.CFrame = mirroredBase

	return part1, part2
end

local function CreateQuad(v1, v2, v3, v4, parts)
	parts[1], parts[2] = CreateTriangle(v1, v2, v3, parts[1], parts[2])
	parts[3], parts[4] = CreateTriangle(v3, v2, v4, parts[3], parts[4])
end

function RenderHelper:BlurFrame(frame, options)
	local properties = {Transparency = 0.98, BrickColor = BrickColor.new("Institutional white")}

	if options ~= nil then
		properties = options
	end

	local camera = workspace.CurrentCamera

	local parts = {}
	local f = Instance.new('Folder', camera)
	f.Name = frame.Name

	local parents = {}
	do
		local function add(child)
			if child:IsA'GuiObject' then
				parents[#parents + 1] = child
				add(child.Parent)
			end
		end
		add(frame)
	end

	local function UpdateOrientation(fetchProps)
		local zIndex = 1 - 0.05*frame.ZIndex
		local tl, br = frame.AbsolutePosition, frame.AbsolutePosition + frame.AbsoluteSize
		local tr, bl = Vector2.new(br.x, tl.y), Vector2.new(tl.x, br.y)
		do
			local rot = 0;
			for _, v in ipairs(parents) do
				rot = rot + v.Rotation
			end
			if rot ~= 0 and rot%180 ~= 0 then
				local mid = tl:lerp(br, 0.5)
				local s, c = math.sin(math.rad(rot)), math.cos(math.rad(rot))
				local vec = tl
				tl = Vector2.new(c*(tl.x - mid.x) - s*(tl.y - mid.y), s*(tl.x - mid.x) + c*(tl.y - mid.y)) + mid
				tr = Vector2.new(c*(tr.x - mid.x) - s*(tr.y - mid.y), s*(tr.x - mid.x) + c*(tr.y - mid.y)) + mid
				bl = Vector2.new(c*(bl.x - mid.x) - s*(bl.y - mid.y), s*(bl.x - mid.x) + c*(bl.y - mid.y)) + mid
				br = Vector2.new(c*(br.x - mid.x) - s*(br.y - mid.y), s*(br.x - mid.x) + c*(br.y - mid.y)) + mid
			end
		end
		CreateQuad(
			camera:ScreenPointToRay(tl.x, tl.y, zIndex).Origin, 
			camera:ScreenPointToRay(tr.x, tr.y, zIndex).Origin, 
			camera:ScreenPointToRay(bl.x, bl.y, zIndex).Origin, 
			camera:ScreenPointToRay(br.x, br.y, zIndex).Origin, 
			parts
		)
		if fetchProps then
			for _, pt in pairs(parts) do
				pt.Parent = f
			end
			for propName, propValue in pairs(properties) do
				for _, pt in pairs(parts) do
					pt[propName] = propValue
				end
			end
		end
	end

	UpdateOrientation(true)
	RunService:BindToRenderStep(tostring(math.random(100000000,999999999)), 2000, UpdateOrientation)
end

function RenderHelper:SetBlurIntensity(i)
	mainblur.NearIntensity = i
end


function RenderHelper:getCoreGui()
	local x, z = pcall(function()
		Instance.new("ScreenGui", game:GetService("CoreGui"))
	end)

	if not x then
		return lplr.PlayerGui
	end
	return game:GetService("CoreGui")
end

return RenderHelper
