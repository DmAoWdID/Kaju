--!nonstrict
-- Renders a kaiju portrait in a ViewportFrame using the shared model factory.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KaijuModelFactory = require(Shared.Visual.KaijuModelFactory)
local KaijuRegistry = require(Shared.Data.KaijuRegistry)
local Palette = require(Shared.Visual.Palette)

local UIKit = require(script.Parent.UIKit)

local KaijuViewport = {}

function KaijuViewport.create(props: { [string]: any }): ViewportFrame
	local base = {
		BackgroundColor3 = Color3.fromRGB(52, 58, 78),
		Size = UDim2.fromOffset(110, 110),
		Ambient = Color3.fromRGB(170, 170, 185),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
	}
	for k, v in props do
		base[k] = v
	end
	return UIKit.new("ViewportFrame", base, { UIKit.corner(12) })
end

-- Shows `speciesId` in the viewport (replacing whatever was there). `mirror` turns it to face left.
function KaijuViewport.show(viewport: ViewportFrame, speciesId: string?, mirror: boolean?)
	if viewport:GetAttribute("SpeciesId") == speciesId then
		return
	end
	viewport:SetAttribute("SpeciesId", speciesId)
	viewport:ClearAllChildren()
	UIKit.corner(12).Parent = viewport
	local species = speciesId and KaijuRegistry.get(speciesId)
	if not species then
		return
	end
	viewport.BackgroundColor3 = Palette.KL[species.kl]:Lerp(Color3.fromRGB(30, 32, 44), 0.7)
	local model = KaijuModelFactory.build(species)
	local yaw = if mirror then math.rad(-35) else math.rad(35)
	model:PivotTo(CFrame.Angles(0, yaw, 0))
	model.Parent = viewport

	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
	local focus = cf.Position
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, radius * 0.25, -distance), focus)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

return KaijuViewport
