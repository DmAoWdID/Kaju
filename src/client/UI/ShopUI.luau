--!nonstrict
-- Chain shop and enclosure catalogue. Prices shown here are for display; the server charges from config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Net.Remotes)

local ClientState = require(script.Parent.Parent.Controllers.ClientState)
local UIKit = require(script.Parent.UIKit)

local ShopUI = {}

local C = UIKit.Colors
local frame: Frame = nil
local list: ScrollingFrame = nil
local startBuild: (string) -> () = function() end
local priced: { { button: TextButton, price: number } } = {} -- buttons whose state depends on money

local function section(text: string, order: number)
	UIKit.label(text, { Font = UIKit.FontTitle, TextSize = 22, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = order, Parent = list })
end

local function row(order: number, titleText: string, detail: string, buttonText: string, color: Color3, enabled: boolean, onClick)
	local item = UIKit.new("Frame", {
		BackgroundColor3 = C.panelLight,
		Size = UDim2.new(1, -12, 0, 76),
		LayoutOrder = order,
		Parent = list,
	}, { UIKit.corner(12), UIKit.padding(10) })
	UIKit.label(titleText, { Font = UIKit.FontBold, TextSize = 19, Size = UDim2.new(1, -180, 0, 24), Parent = item })
	UIKit.label(detail, { TextSize = 15, TextColor3 = C.textDim, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, -180, 0, 28), Parent = item })
	local button = UIKit.button(buttonText, color, onClick, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(160, 52),
		TextSize = 17,
		Parent = item,
	})
	UIKit.setEnabled(button, enabled)
	return button
end

local function rebuild()
	table.clear(priced)
	for _, child in list:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local data = ClientState.data
	if not data then
		return
	end
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	section("Chains", nextOrder())
	for _, chain in GameConfig.Chains do
		local detail = ("Length %dm  ·  captures up to KL %d"):format(chain.lengthMeters, chain.maxKL)
		if chain.tier <= data.chainTier then
			row(nextOrder(), chain.displayName, detail, if chain.tier == data.chainTier then "Equipped" else "Owned", C.good, false, function() end)
		elseif chain.tier == data.chainTier + 1 then
			local button = row(nextOrder(), chain.displayName, detail, ("Buy  $%s"):format(UIKit.formatNumber(chain.price)), C.accent, data.money >= chain.price, function()
				ClientState.request(Remotes.Actions.BuyChain, { tier = chain.tier })
			end)
			table.insert(priced, { button = button, price = chain.price })
		else
			row(nextOrder(), chain.displayName, detail, "Locked", C.disabled, false, function() end)
		end
	end

	section("Enclosures", nextOrder())
	local sizes = {}
	for id, size in GameConfig.Enclosures do
		table.insert(sizes, { id = id, size = size })
	end
	table.sort(sizes, function(a, b)
		return a.size.order < b.size.order
	end)
	for _, entry in sizes do
		local size = entry.size
		local klText = if size.minKL == size.maxKL then ("KL %d"):format(size.minKL) else ("KL %d–%d"):format(size.minKL, size.maxKL)
		local button = row(nextOrder(), size.displayName, ("For %s kaijus  ·  place it in your park"):format(klText), ("Build  $%s"):format(UIKit.formatNumber(size.price)), Color3.fromRGB(80, 160, 110), data.money >= size.price, function()
			startBuild(entry.id)
		end)
		table.insert(priced, { button = button, price = size.price })
	end
end

function ShopUI.init(gui: ScreenGui, onClose: () -> (), onBuild: (string) -> ())
	startBuild = onBuild
	local content
	frame, content = UIKit.panel(gui, "Shop", onClose)
	list = UIKit.scrolling(content)
	ClientState.onChanged(function(scope)
		if not frame.Visible then
			return
		end
		if scope == "full" then
			rebuild()
		elseif ClientState.data then
			for _, entry in priced do
				UIKit.setEnabled(entry.button, ClientState.data.money >= entry.price)
			end
		end
	end)
	return frame
end

function ShopUI.setVisible(visible: boolean)
	frame.Visible = visible
	if visible then
		rebuild()
	end
end

return ShopUI
