--!nonstrict
-- Always-visible HUD: money, Kaiju Cells, chain, persistence notice, and the main menu buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared.Progression.Progression)
local Remotes = require(Shared.Net.Remotes)

local ClientState = require(script.Parent.Parent.Controllers.ClientState)
local UIKit = require(script.Parent.UIKit)

local Hud = {}

local C = UIKit.Colors
local root: Frame = nil
local menu: Frame = nil
local moneyLabel: TextLabel = nil
local cellsLabel: TextLabel = nil
local chainLabel: TextLabel = nil
local saveNotice: TextLabel = nil

local function currencyChip(parent: Instance, color: Color3, icon: string, order: number): TextLabel
	local chip = UIKit.new("Frame", {
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromOffset(190, 44),
		LayoutOrder = order,
		Parent = parent,
	}, { UIKit.corner(22), UIKit.stroke(color, 2) })
	UIKit.label(icon, {
		Font = UIKit.FontTitle,
		TextSize = 22,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(44, 44),
		Parent = chip,
	})
	return UIKit.label("0", {
		Font = UIKit.FontTitle,
		TextSize = 24,
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -54, 1, 0),
		Parent = chip,
	})
end

-- handlers: { collection, shop, build } callbacks
function Hud.init(gui: ScreenGui, handlers)
	root = UIKit.new("Frame", {
		Name = "Hud",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})

	local currencies = UIKit.new("Frame", {
		Name = "Currencies",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(200, 200),
		Parent = root,
	}, { UIKit.list(Enum.FillDirection.Vertical, 8) })
	UIKit.autoScale(currencies)
	moneyLabel = currencyChip(currencies, C.money, "$", 1)
	cellsLabel = currencyChip(currencies, C.cells, "◆", 2)
	chainLabel = UIKit.label("", { TextSize = 15, TextColor3 = C.textDim, LayoutOrder = 3, Size = UDim2.fromOffset(200, 20) })
	chainLabel.Parent = currencies
	saveNotice = UIKit.label("", {
		TextSize = 14,
		TextColor3 = C.accent,
		LayoutOrder = 4,
		Size = UDim2.fromOffset(200, 36),
		Visible = false,
		Parent = currencies,
	})

	-- Studio-only cheat panel (the server only accepts DevCommand in Studio).
	if RunService:IsStudio() and handlers.dev then
		UIKit.button("DEV cheats", Color3.fromRGB(110, 70, 140), handlers.dev, {
			Size = UDim2.fromOffset(200, 36),
			TextSize = 15,
			LayoutOrder = 5,
			Parent = currencies,
		})
	end

	menu = UIKit.new("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(150, 330),
		BackgroundTransparency = 1,
		Parent = root,
	}, { UIKit.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Right) })
	UIKit.autoScale(menu)

	local function menuButton(text: string, color: Color3, order: number, fn)
		UIKit.button(text, color, fn, { Size = UDim2.fromOffset(150, 54), LayoutOrder = order, TextSize = 20, Parent = menu })
	end
	menuButton("Collection", Color3.fromRGB(90, 110, 200), 1, handlers.collection)
	menuButton("Shop", Color3.fromRGB(200, 130, 50), 2, handlers.shop)
	menuButton("Build", Color3.fromRGB(80, 160, 110), 3, handlers.build)
	menuButton("My Park", Color3.fromRGB(70, 150, 150), 4, function()
		ClientState.request(Remotes.Actions.Travel, { destination = "park" })
	end)
	menuButton("Wilds", Color3.fromRGB(110, 120, 80), 5, function()
		ClientState.request(Remotes.Actions.Travel, { destination = "wilds" })
	end)

	ClientState.onChanged(Hud.refresh)
end

function Hud.refresh()
	local data = ClientState.data
	if not data then
		return
	end
	moneyLabel.Text = UIKit.formatNumber(data.money)
	cellsLabel.Text = UIKit.formatNumber(data.kaijuCells) .. " Cells"
	local chain = Progression.chain(data.chainTier)
	chainLabel.Text = if chain then ("%s (up to KL %d)"):format(chain.displayName, chain.maxKL) else ""
	local persistence = ClientState.persistence
	if persistence and (persistence.mode ~= "datastore" or not persistence.saving) then
		saveNotice.Visible = true
		saveNotice.Text = if persistence.mode ~= "datastore"
			then "Test mode: progress is not saved"
			else "Save unavailable this session"
	else
		saveNotice.Visible = false
	end
end

function Hud.setMenuVisible(visible: boolean)
	if menu then
		menu.Visible = visible
	end
end

return Hud
