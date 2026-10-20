--!nonstrict
-- Battle overlay. Purely a view of server state (BattleSync) plus buttons that send requests.
-- Phases: select (pick your kaiju) -> fight (Attack / Defend / Save) -> reward (capture or cells) -> ended.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KaijuRegistry = require(Shared.Data.KaijuRegistry)
local Palette = require(Shared.Visual.Palette)
local Remotes = require(Shared.Net.Remotes)

local ClientState = require(script.Parent.Parent.Controllers.ClientState)
local KaijuViewport = require(script.Parent.KaijuViewport)
local UIKit = require(script.Parent.UIKit)

local BattleUI = {}

local C = UIKit.Colors
local player = Players.LocalPlayer

local overlay: Frame = nil
local title: TextLabel = nil
local logLabel: TextLabel = nil
local cards = {}
local rows = {}
local fightButtons = {}
local rewardButtons = {}
local selectList: ScrollingFrame = nil
local isOpen = false
local busy = false
local current = nil
local onOpenChanged: ((boolean) -> ())? = nil

local function makeCard(parent: Instance, side: string)
	local isPlayer = side == "player"
	local frame = UIKit.new("Frame", {
		Name = side .. "Card",
		BackgroundColor3 = C.panelLight,
		Size = UDim2.new(0.5, -8, 0, 144),
		LayoutOrder = if isPlayer then 1 else 2,
		Parent = parent,
	}, { UIKit.corner(14), UIKit.padding(10) })
	local viewport = KaijuViewport.create({
		Size = UDim2.fromOffset(112, 112),
		Position = if isPlayer then UDim2.fromOffset(0, 0) else UDim2.new(1, -112, 0, 0),
		Parent = frame,
	})
	local info = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Position = if isPlayer then UDim2.fromOffset(122, 0) else UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, -122, 1, 0),
		Parent = frame,
	})
	local align = if isPlayer then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
	local name = UIKit.label("", { Font = UIKit.FontTitle, TextSize = 24, TextXAlignment = align, Size = UDim2.new(1, 0, 0, 28), Parent = info })
	local sub = UIKit.label("", { TextSize = 16, TextColor3 = C.textDim, TextXAlignment = align, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 20), Parent = info })
	local badge = UIKit.klBadge(1, {
		AnchorPoint = if isPlayer then Vector2.new(0, 0) else Vector2.new(1, 0),
		Position = if isPlayer then UDim2.fromOffset(0, 54) else UDim2.new(1, 0, 0, 54),
		Parent = info,
	})
	local hpBack = UIKit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(30, 30, 38),
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = info,
	}, { UIKit.corner(8) })
	local hpFill = UIKit.new("Frame", {
		BackgroundColor3 = C.hp,
		Size = UDim2.fromScale(1, 1),
		AnchorPoint = if isPlayer then Vector2.new(0, 0) else Vector2.new(1, 0),
		Position = if isPlayer then UDim2.fromScale(0, 0) else UDim2.fromScale(1, 0),
		Parent = hpBack,
	}, { UIKit.corner(8) })
	local hpText = UIKit.label("", {
		TextSize = 13,
		Font = UIKit.FontBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = hpBack,
	})
	local apRow = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = info,
	}, {
		UIKit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 5),
			HorizontalAlignment = if isPlayer then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	UIKit.label("AP", { TextSize = 14, Font = UIKit.FontBold, TextColor3 = C.ap, Size = UDim2.fromOffset(22, 18), LayoutOrder = if isPlayer then 0 else 99, Parent = apRow })
	local pips = {}
	for i = 1, 5 do
		pips[i] = UIKit.new("Frame", {
			BackgroundColor3 = C.ap,
			Size = UDim2.fromOffset(18, 18),
			LayoutOrder = if isPlayer then i else 6 - i,
			Parent = apRow,
		}, { UIKit.corner(9) })
	end
	return { frame = frame, viewport = viewport, name = name, sub = sub, badge = badge, hpFill = hpFill, hpText = hpText, pips = pips, lastHp = nil, mirror = not isPlayer }
end

local function setCard(card, info)
	if not info then
		card.name.Text = "Choose a kaiju"
		card.sub.Text = ""
		card.badge.Visible = false
		card.hpFill.Size = UDim2.fromScale(0, 1)
		card.hpText.Text = ""
		for _, pip in card.pips do
			pip.Visible = false
		end
		KaijuViewport.show(card.viewport, nil)
		card.lastHp = nil
		return
	end
	card.name.Text = info.name
	card.sub.Text = ("Level %d"):format(info.level)
	card.badge.Visible = true
	card.badge.Text = "KL " .. info.kl
	card.badge.BackgroundColor3 = Palette.KL[info.kl]
	KaijuViewport.show(card.viewport, info.speciesId, card.mirror)
	if info.hp then
		local ratio = math.clamp(info.hp / info.maxHp, 0, 1)
		TweenService:Create(card.hpFill, TweenInfo.new(0.35), { Size = UDim2.fromScale(ratio, 1) }):Play()
		card.hpFill.BackgroundColor3 = if ratio > 0.5 then C.hp elseif ratio > 0.25 then C.accent else C.bad
		card.hpText.Text = ("%d / %d HP"):format(info.hp, info.maxHp)
		if card.lastHp and info.hp < card.lastHp then
			card.frame.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
			TweenService:Create(card.frame, TweenInfo.new(0.5), { BackgroundColor3 = C.panelLight }):Play()
		end
		card.lastHp = info.hp
		for i, pip in card.pips do
			pip.Visible = i <= info.maxAp
			pip.BackgroundTransparency = if i <= info.ap then 0 else 0.75
		end
	else
		card.hpFill.Size = UDim2.fromScale(1, 1)
		card.hpText.Text = ""
		for _, pip in card.pips do
			pip.Visible = false
		end
	end
end

local function showRow(name: string)
	for key, row in rows do
		row.Visible = key == name
	end
end

local function setCamera(model: Model?)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if not model or not model.Parent then
		camera.CameraType = Enum.CameraType.Custom
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local _, size = model:GetBoundingBox()
	local target = model:GetPivot().Position + Vector3.new(0, size.Y * 0.45, 0)
	local away = Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
	local distance = math.max(size.X, size.Y, size.Z) * 1.1 + 18
	local camPos = target + away * distance + Vector3.new(0, size.Y * 0.35 + 6, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	-- shift the view up so the kaiju sits above the battle panel
	local goal = CFrame.lookAt(camPos, target) * CFrame.new(0, -size.Y * 0.35, 0)
	TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { CFrame = goal }):Play()
end

local function open()
	if isOpen then
		return
	end
	isOpen = true
	overlay.Visible = true
	ProximityPromptService.Enabled = false
	for _, card in cards do
		card.lastHp = nil
	end
	if onOpenChanged then
		onOpenChanged(true)
	end
end

local function close()
	isOpen = false
	current = nil
	overlay.Visible = false
	ProximityPromptService.Enabled = true
	setCamera(nil)
	if onOpenChanged then
		onOpenChanged(false)
	end
end

local function send(action: string, payload)
	if busy then
		return
	end
	busy = true
	ClientState.request(action, payload)
	busy = false
end

local function rebuildSelectList()
	for _, child in selectList:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local data = ClientState.data
	if not data then
		return
	end
	local owned = {}
	for _, k in data.kaijus do
		local species = KaijuRegistry.get(k.speciesId)
		if species then
			table.insert(owned, { kaiju = k, species = species })
		end
	end
	table.sort(owned, function(a, b)
		if a.species.kl ~= b.species.kl then
			return a.species.kl > b.species.kl
		end
		return a.kaiju.level > b.kaiju.level
	end)
	for i, entry in owned do
		local k, species = entry.kaiju, entry.species
		UIKit.button(
			("%s\nKL %d · Lv %d"):format(species.displayName, species.kl, k.level),
			Palette.KL[species.kl]:Lerp(Color3.fromRGB(30, 30, 40), 0.35),
			function()
				send(Remotes.Actions.BattleChooseKaiju, { instanceId = k.instanceId })
			end,
			{ Size = UDim2.fromOffset(170, 64), LayoutOrder = i, TextSize = 17, Parent = selectList }
		)
	end
end

local function render(payload)
	current = payload
	local snap = payload.snapshot
	setCard(cards.wild, if snap then snap.wild else payload.wild)
	setCard(cards.player, if snap then snap.player else nil)

	if payload.phase == "select" then
		title.Text = ("A wild %s appears! Choose your kaiju."):format(payload.wild.name)
		logLabel.Text = ""
		rebuildSelectList()
		showRow("select")
	elseif payload.phase == "fight" then
		title.Text = ("Round %d  ·  Your move"):format(snap.round)
		local lines = {}
		for _, e in snap.events or {} do
			table.insert(lines, e.text)
		end
		logLabel.Text = if #lines > 0 then table.concat(lines, "\n") else "Spend action points to Attack, Defend, or Save them for a stronger attack."
		local ap = snap.player.ap
		fightButtons.Attack.Text = ("ATTACK\nuse %d AP"):format(ap)
		UIKit.setEnabled(fightButtons.Attack, snap.available.Attack)
		UIKit.setEnabled(fightButtons.Defend, snap.available.Defend)
		UIKit.setEnabled(fightButtons.Save, snap.available.Save)
		showRow("fight")
	elseif payload.phase == "reward" then
		title.Text = "Victory!"
		local lines = {}
		for _, e in snap.events or {} do
			table.insert(lines, e.text)
		end
		logLabel.Text = table.concat(lines, "\n")
		local reward = payload.reward
		if reward.canCapture then
			rewardButtons.capture.Text = ("CAPTURE\nwith %s"):format(reward.chainName)
			UIKit.setEnabled(rewardButtons.capture, true)
		else
			rewardButtons.capture.Text = ("CAPTURE\nneeds %s"):format(reward.requiredChain or "a longer chain")
			UIKit.setEnabled(rewardButtons.capture, false)
		end
		rewardButtons.cells.Text = ("DEFEAT\n+%d Kaiju Cells"):format(reward.cells)
		showRow("reward")
	elseif payload.phase == "ended" then
		local result = payload.result or {}
		local headline = ({
			captured = "Captured!",
			cells = "Kaiju Cells collected",
			escaped = "It escaped…",
			defeat = "Defeated",
			draw = "Draw",
			forfeit = "Battle over",
		})[result.outcome] or "Battle over"
		title.Text = headline
		logLabel.Text = result.text or ""
		showRow("ended")
	end
end

-- onToggle(isOpen) lets the HUD hide its menu during battles.
function BattleUI.init(gui: ScreenGui, onToggle: (boolean) -> ())
	onOpenChanged = onToggle

	overlay = UIKit.new("Frame", {
		Name = "Battle",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	local panel = UIKit.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(900, 372),
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.05,
		Parent = overlay,
	}, { UIKit.corner(18), UIKit.stroke(C.stroke, 2), UIKit.padding(12) })
	UIKit.autoScale(panel)

	title = UIKit.label("", {
		Font = UIKit.FontTitle,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = panel,
	})
	local cardRow = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 144),
		Parent = panel,
	}, { UIKit.list(Enum.FillDirection.Horizontal, 16) })
	cards.player = makeCard(cardRow, "player")
	cards.wild = makeCard(cardRow, "wild")

	logLabel = UIKit.label("", {
		TextSize = 16,
		TextColor3 = C.textDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 186),
		Size = UDim2.new(1, 0, 0, 56),
		Parent = panel,
	})

	local function row(name: string): Frame
		local r = UIKit.new("Frame", {
			Name = name .. "Row",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 92),
			Visible = false,
			Parent = panel,
		})
		rows[name] = r
		return r
	end

	-- select
	local selectRow = row("select")
	selectList = UIKit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -150, 1, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 6,
		BorderSizePixel = 0,
		Parent = selectRow,
	}, { UIKit.list(Enum.FillDirection.Horizontal, 10) })
	UIKit.button("Retreat", C.disabled, function()
		send(Remotes.Actions.BattleForfeit)
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(136, 64), Parent = selectRow })

	-- fight
	local fightRow = row("fight")
	UIKit.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center).Parent = fightRow
	local function actionButton(action: string, text: string, color: Color3, order: number)
		fightButtons[action] = UIKit.button(text, color, function()
			send(Remotes.Actions.BattleAction, { action = action })
		end, { Size = UDim2.fromOffset(196, 80), TextSize = 20, LayoutOrder = order, Parent = fightRow })
	end
	actionButton("Attack", "ATTACK", C.attack, 1)
	actionButton("Defend", "DEFEND\nuse 1 AP", C.defend, 2)
	actionButton("Save", "SAVE\nkeep AP", C.save, 3)
	UIKit.button("Retreat", C.disabled, function()
		send(Remotes.Actions.BattleForfeit)
	end, { Size = UDim2.fromOffset(120, 80), LayoutOrder = 4, Parent = fightRow })

	-- reward
	local rewardRow = row("reward")
	UIKit.list(Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center).Parent = rewardRow
	rewardButtons.capture = UIKit.button("CAPTURE", Color3.fromRGB(80, 150, 220), function()
		send(Remotes.Actions.BattleResolve, { choice = "capture" })
	end, { Size = UDim2.fromOffset(280, 80), TextSize = 20, LayoutOrder = 1, Parent = rewardRow })
	rewardButtons.cells = UIKit.button("DEFEAT", Color3.fromRGB(60, 170, 150), function()
		send(Remotes.Actions.BattleResolve, { choice = "cells" })
	end, { Size = UDim2.fromOffset(280, 80), TextSize = 20, LayoutOrder = 2, Parent = rewardRow })

	-- ended
	local endedRow = row("ended")
	UIKit.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center).Parent = endedRow
	UIKit.button("Continue", C.good, close, { Size = UDim2.fromOffset(240, 72), TextSize = 22, Parent = endedRow })

	Remotes.event(Remotes.Events.BattleSync).OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		local starting = not isOpen
		open()
		render(payload)
		if starting then
			setCamera(payload.model)
		end
	end)

	ClientState.onChanged(function(scope)
		if scope == "full" and isOpen and current and current.phase == "select" then
			rebuildSelectList()
		end
	end)
end

return BattleUI
