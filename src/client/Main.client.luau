--!nonstrict
-- Client entry point: builds the UI and wires controllers together.

local Controllers = script.Parent.Controllers
local UI = script.Parent.UI

local ClientState = require(Controllers.ClientState)
local BuildController = require(Controllers.BuildController)
local KaijuAnimator = require(Controllers.KaijuAnimator)
local UIKit = require(UI.UIKit)
local Toasts = require(UI.Toasts)
local Hud = require(UI.Hud)
local BattleUI = require(UI.BattleUI)
local CollectionUI = require(UI.CollectionUI)
local ShopUI = require(UI.ShopUI)
local DevPanel = require(UI.DevPanel)

local gui = UIKit.screenGui("KaijuParkUI", 5)

Toasts.init(gui)
ClientState.setToastHandler(Toasts.show)
ClientState.init()
KaijuAnimator.init()

-- Only one panel open at a time.
local panels = {}
local function closePanels()
	for _, panel in panels do
		panel.setVisible(false)
	end
end
local function openPanel(panel)
	closePanels()
	BuildController.stop()
	panel.setVisible(true)
end

CollectionUI.init(gui, closePanels)
ShopUI.init(gui, closePanels, function(sizeId)
	closePanels()
	BuildController.start(sizeId)
end)
DevPanel.init(gui, closePanels)
panels = { CollectionUI, ShopUI, DevPanel }

Hud.init(gui, {
	collection = function()
		openPanel(CollectionUI)
	end,
	shop = function()
		openPanel(ShopUI)
	end,
	build = function()
		openPanel(ShopUI) -- enclosures are chosen in the shop, then placed in build mode
	end,
	dev = function()
		openPanel(DevPanel)
	end,
})

BuildController.init(gui)

BattleUI.init(gui, function(inBattle)
	if inBattle then
		closePanels()
		BuildController.stop()
	end
	Hud.setMenuVisible(not inBattle)
end)
