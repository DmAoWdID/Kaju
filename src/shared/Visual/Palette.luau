--!strict
-- Presentation colors (world + UI). Not gameplay data.

local Palette = {}

-- Each KL gets a distinct, readable color used on nameplates, badges and ground rings.
Palette.KL = table.freeze({
	[1] = Color3.fromRGB(96, 196, 120), -- green
	[2] = Color3.fromRGB(70, 150, 230), -- blue
	[3] = Color3.fromRGB(160, 100, 230), -- violet
	[4] = Color3.fromRGB(240, 140, 50), -- orange
	[5] = Color3.fromRGB(240, 196, 60), -- gold
})

Palette.UI = table.freeze({
	panel = Color3.fromRGB(28, 30, 40),
	panelLight = Color3.fromRGB(44, 48, 62),
	stroke = Color3.fromRGB(90, 96, 120),
	text = Color3.fromRGB(240, 240, 245),
	textDim = Color3.fromRGB(170, 176, 196),
	money = Color3.fromRGB(250, 210, 80),
	cells = Color3.fromRGB(120, 230, 200),
	good = Color3.fromRGB(90, 200, 120),
	bad = Color3.fromRGB(230, 90, 90),
	accent = Color3.fromRGB(250, 160, 60),
	attack = Color3.fromRGB(220, 80, 70),
	defend = Color3.fromRGB(70, 140, 220),
	save = Color3.fromRGB(230, 180, 60),
	disabled = Color3.fromRGB(70, 72, 84),
	hp = Color3.fromRGB(100, 210, 110),
	ap = Color3.fromRGB(250, 200, 70),
})

Palette.World = table.freeze({
	grass = Color3.fromRGB(116, 178, 92),
	grassDark = Color3.fromRGB(84, 140, 76),
	wildGrass = Color3.fromRGB(92, 150, 100),
	sand = Color3.fromRGB(226, 206, 150),
	rock = Color3.fromRGB(122, 118, 132),
	rockDark = Color3.fromRGB(86, 82, 98),
	water = Color3.fromRGB(62, 140, 190),
	wood = Color3.fromRGB(140, 96, 64),
	leaves = Color3.fromRGB(64, 132, 84),
	leavesAlt = Color3.fromRGB(150, 110, 170),
	pad = Color3.fromRGB(214, 196, 150),
	parkGround = Color3.fromRGB(130, 190, 110),
	fence = Color3.fromRGB(110, 84, 62),
})

function Palette.rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

return Palette
