--!nonstrict
-- Studio-only cheat panel: give all kaijus, resources, max chain, and spawn any wild kaiju in front of you.
-- The server only accepts these commands in Studio (DevService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KaijuRegistry = require(Shared.Data.KaijuRegistry)
local Palette = require(Shared.Visual.Palette)
local Remotes = require(Shared.Net.Remotes)

local ClientState = require(script.Parent.Parent.Controllers.ClientState)
local UIKit = require(script.Parent.UIKit)

local DevPanel = {}

local C = UIKit.Colors
local frame: Frame = nil

local function command(name: string, extra: { [string]: any }?)
	local payload = { command = name }
	for k, v in extra or {} do
		payload[k] = v
	end
	ClientState.request(Remotes.Actions.DevCommand, payload)
end

local function heading(parent: Instance, text: string, order: number)
	UIKit.label(text, { Font = UIKit.FontTitle, TextSize = 21, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order, Parent = parent })
end

local function grid(parent: Instance, order: number, cellWidth: number): Frame
	return UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	}, {
		UIKit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(cellWidth, 54),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

function DevPanel.init(gui: ScreenGui, onClose: () -> ())
	local content
	frame, content = UIKit.panel(gui, "Dev cheats (Studio only)", onClose)
	local list = UIKit.scrolling(content)
	local purple = Color3.fromRGB(110, 70, 140)

	heading(list, "Collection & resources", 1)
	local general = grid(list, 2, 168)
	for i, entry in {
		{ "Give all 18 kaijus", "allKaijus" },
		{ "+1,000 Kaiju Cells", "cells" },
		{ "+$1,000", "money" },
		{ "Unlock all chains", "maxChain" },
	} do
		UIKit.button(entry[1], purple, function()
			command(entry[2])
		end, { TextSize = 15, LayoutOrder = i, Parent = general })
	end

	heading(list, "Spawn a wild kaiju in front of you", 3)
	UIKit.label("It appears where you're looking and can be battled normally. Spawned kaijus don't respawn.", {
		TextSize = 14,
		TextColor3 = C.textDim,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 4,
		Parent = list,
	})
	local spawns = grid(list, 5, 168)
	for i, species in KaijuRegistry.all() do
		UIKit.button(("%s\nKL %d"):format(species.displayName, species.kl), Palette.KL[species.kl]:Lerp(Color3.fromRGB(30, 30, 40), 0.35), function()
			command("spawn", { speciesId = species.id })
		end, { TextSize = 15, LayoutOrder = i, Parent = spawns })
	end
	local clear = grid(list, 6, 220)
	UIKit.button("Clear spawned kaijus", C.bad, function()
		command("clearSpawns")
	end, { TextSize = 15, Parent = clear })
	return frame
end

function DevPanel.setVisible(visible: boolean)
	if frame then
		frame.Visible = visible
	end
end

return DevPanel
