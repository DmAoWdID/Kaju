--!nonstrict
-- Battle screen: a 3D arena (BattleArena) plus HP/AP plates at the top and an action bar at the bottom.
-- It is a view of server state only. BattleSync payloads are queued and processed in order, so each
-- round's animation finishes before the next state is shown.
-- Phases: select (pick your kaiju) -> fight (Attack / Defend / Save) -> reward (capture or cells) -> ended.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KaijuRegistry = require(Shared.Data.KaijuRegistry)
local Palette = require(Shared.Visual.Palette)
local Remotes = require(Shared.Net.Remotes)

local ClientState = require(script.Parent.Parent.Controllers.ClientState)
local BattleArena = require(script.Parent.Parent.Battle.BattleArena)
local UIKit = require(script.Parent.UIKit)

local BattleUI = {}

local C = UIKit.Colors

local overlay: Frame = nil
local title: TextLabel = nil
local logLabel: TextLabel = nil
local plates = {}
local rows = {}
local fightButtons = {}
local rewardButtons = {}
local selectList: ScrollingFrame = nil
local isOpen = false
local busy = false -- a request is in flight
local animating = false -- a round is playing
local current = nil
local lastEventsKey: string? = nil
local queue = {}
local processing = false
local onOpenChanged: ((boolean) -> ())? = nil

-- ───────────────────────────── plates ─────────────────────────────

local function makePlate(parent: Instance, side: string)
	local isPlayer = side == "player"
	local align = if isPlayer then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
	local frame = UIKit.new("Frame", {
		Name = side .. "Plate",
		AnchorPoint = if isPlayer then Vector2.new(0, 0) else Vector2.new(1, 0),
		Position = if isPlayer then UDim2.fromOffset(0, 0) else UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(400, 104),
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.1,
		Parent = parent,
	}, { UIKit.corner(14), UIKit.stroke(C.stroke, 2), UIKit.padding(10) })
	local name = UIKit.label("", { Font = UIKit.FontTitle, TextSize = 24, TextXAlignment = align, Size = UDim2.new(1, -70, 0, 28), Position = if isPlayer then UDim2.new() else UDim2.fromOffset(70, 0), Parent = frame })
	local badge = UIKit.klBadge(1, {
		AnchorPoint = if isPlayer then Vector2.new(1, 0) else Vector2.new(0, 0),
		Position = if isPlayer then UDim2.new(1, 0, 0, 2) else UDim2.fromOffset(0, 2),
		Parent = frame,
	})
	local sub = UIKit.label("", { TextSize = 15, TextColor3 = C.textDim, TextXAlignment = align, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 18), Parent = frame })
	local hpBack = UIKit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(30, 30, 38),
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = frame,
	}, { UIKit.corner(9) })
	local hpFill = UIKit.new("Frame", {
		BackgroundColor3 = C.hp,
		Size = UDim2.fromScale(1, 1),
		AnchorPoint = if isPlayer then Vector2.new(0, 0) else Vector2.new(1, 0),
		Position = if isPlayer then UDim2.fromScale(0, 0) else UDim2.fromScale(1, 0),
		Parent = hpBack,
	}, { UIKit.corner(9) })
	local hpText = UIKit.label("", { TextSize = 13, Font = UIKit.FontBold, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = hpBack })
	local apRow = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = frame,
	}, {
		UIKit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 5),
			HorizontalAlignment = if isPlayer then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	UIKit.label("AP", { TextSize = 14, Font = UIKit.FontBold, TextColor3 = C.ap, Size = UDim2.fromOffset(22, 20), LayoutOrder = if isPlayer then 0 else 99, Parent = apRow })
	local pips = {}
	for i = 1, 5 do
		pips[i] = UIKit.new("Frame", {
			BackgroundColor3 = C.ap,
			Size = UDim2.fromOffset(20, 20),
			LayoutOrder = if isPlayer then i else 6 - i,
			Parent = apRow,
		}, { UIKit.corner(10) })
	end
	return { frame = frame, name = name, badge = badge, sub = sub, hpFill = hpFill, hpText = hpText, pips = pips, hp = nil, maxHp = nil }
end

local function setHp(plate, hp: number, maxHp: number)
	plate.hp, plate.maxHp = hp, maxHp
	local ratio = math.clamp(hp / maxHp, 0, 1)
	TweenService:Create(plate.hpFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(ratio, 1) }):Play()
	plate.hpFill.BackgroundColor3 = if ratio > 0.5 then C.hp elseif ratio > 0.25 then C.accent else C.bad
	plate.hpText.Text = ("%d / %d HP"):format(math.max(0, hp), maxHp)
end

local function setPlate(plate, info)
	if not info then
		plate.name.Text = "Choose your kaiju"
		plate.sub.Text = ""
		plate.badge.Visible = false
		plate.hpFill.Size = UDim2.fromScale(0, 1)
		plate.hpText.Text = ""
		for _, pip in plate.pips do
			pip.Visible = false
		end
		return
	end
	plate.name.Text = info.name
	plate.sub.Text = ("Level %d"):format(info.level)
	plate.badge.Visible = true
	plate.badge.Text = "KL " .. info.kl
	plate.badge.BackgroundColor3 = Palette.KL[info.kl]
	if info.hp then
		setHp(plate, info.hp, info.maxHp)
		for i, pip in plate.pips do
			pip.Visible = i <= info.maxAp
			pip.BackgroundTransparency = if i <= info.ap then 0 else 0.75
		end
	else
		plate.hpFill.Size = UDim2.fromScale(1, 1)
		plate.hpText.Text = ""
		for _, pip in plate.pips do
			pip.Visible = false
		end
	end
end

-- ───────────────────────────── rows / buttons ─────────────────────────────

local function showRow(name: string?)
	for key, row in rows do
		row.Visible = key == name
	end
end

local function refreshFightButtons()
	local snap = current and current.snapshot
	local canAct = snap ~= nil and current.phase == "fight" and not animating and not busy
	for action, button in fightButtons do
		UIKit.setEnabled(button, canAct and snap.available[action] == true)
	end
	if snap then
		fightButtons.Attack.Text = ("ATTACK\nuse %d AP"):format(snap.player.ap)
	end
end

local function send(action: string, payload)
	if busy then
		return
	end
	busy = true
	refreshFightButtons()
	ClientState.request(action, payload)
	busy = false
	refreshFightButtons()
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

-- ───────────────────────────── flow ─────────────────────────────

local function open(payload)
	isOpen = true
	lastEventsKey = nil
	overlay.Visible = true
	ProximityPromptService.Enabled = false
	setPlate(plates.player, nil)
	setPlate(plates.wild, payload.wild)
	showRow(nil)
	BattleArena.start(payload.wild.speciesId)
	if onOpenChanged then
		onOpenChanged(true)
	end
end

local function close()
	isOpen = false
	current = nil
	table.clear(queue)
	overlay.Visible = false
	ProximityPromptService.Enabled = true
	BattleArena.stop()
	if onOpenChanged then
		onOpenChanged(false)
	end
end

local function eventsKey(snap): string?
	if not snap or not snap.events or #snap.events == 0 then
		return nil
	end
	return ("%d|%s|%d"):format(snap.round, snap.state, #snap.events)
end

-- Plays the snapshot's round once (payloads can repeat the same final round).
local function playRoundIfNew(snap)
	local key = eventsKey(snap)
	if not key or key == lastEventsKey then
		return false
	end
	lastEventsKey = key
	animating = true
	refreshFightButtons()
	title.Text = "…"
	local lines = {}
	for _, e in snap.events do
		table.insert(lines, e.text)
	end
	logLabel.Text = table.concat(lines, "   ")
	BattleArena.playRound(snap.events, function(targetSide, damage)
		local plate = plates[targetSide]
		if plate.hp and plate.maxHp then
			setHp(plate, plate.hp - damage, plate.maxHp)
		end
	end)
	animating = false
	return true
end

local HEADLINES = {
	captured = "Captured!",
	cells = "Kaiju Cells collected",
	escaped = "It escaped…",
	defeat = "Defeated",
	draw = "Draw",
	forfeit = "Battle over",
}

local function process(payload)
	if not isOpen then
		if payload.phase == "ended" and not payload.snapshot then
			-- e.g. timeout notice for a battle whose screen was already closed
			ClientState.toast((payload.result and payload.result.text) or "Battle over", "info")
			return
		end
		open(payload)
	end
	current = payload
	local snap = payload.snapshot

	if payload.phase == "select" then
		title.Text = ("A wild %s appears! Choose your kaiju."):format(payload.wild.name)
		logLabel.Text = ""
		rebuildSelectList()
		showRow("select")
		return
	end

	if snap and not BattleArena.hasPlayer(snap.player.speciesId) and payload.phase ~= "ended" then
		showRow(nil)
		title.Text = ("Go, %s!"):format(snap.player.name)
		setPlate(plates.player, snap.player)
		setPlate(plates.wild, snap.wild)
		BattleArena.setPlayer(snap.player.speciesId)
	end

	if payload.phase == "fight" then
		if playRoundIfNew(snap) then
			setPlate(plates.player, snap.player)
			setPlate(plates.wild, snap.wild)
		else
			setPlate(plates.player, snap.player)
			setPlate(plates.wild, snap.wild)
			logLabel.Text = "Attack spends all your AP — Save first for a stronger hit. Defend blocks half."
		end
		title.Text = ("Round %d  ·  Your move"):format(snap.round)
		showRow("fight")
		refreshFightButtons()
	elseif payload.phase == "reward" then
		showRow(nil)
		playRoundIfNew(snap)
		setPlate(plates.player, snap.player)
		setPlate(plates.wild, snap.wild)
		BattleArena.knockOut("wild")
		title.Text = "Victory!"
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
		showRow(nil)
		local result = payload.result or {}
		if snap and playRoundIfNew(snap) then
			setPlate(plates.player, snap.player)
			setPlate(plates.wild, snap.wild)
		end
		if result.outcome == "defeat" then
			BattleArena.knockOut("player")
		elseif result.outcome == "captured" then
			BattleArena.capture()
		elseif result.outcome == "cells" then
			BattleArena.dissolve(result.cells)
		elseif result.outcome == "escaped" then
			BattleArena.escape()
		elseif result.outcome == "forfeit" then
			BattleArena.retreat()
		end
		title.Text = HEADLINES[result.outcome] or "Battle over"
		logLabel.Text = result.text or ""
		showRow("ended")
	end
end

local function pump()
	if processing then
		return
	end
	processing = true
	while #queue > 0 do
		local payload = table.remove(queue, 1)
		local ok, err = pcall(process, payload)
		if not ok then
			warn("[BattleUI] " .. tostring(err))
		end
	end
	processing = false
end

-- ───────────────────────────── init ─────────────────────────────

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

	-- top: HP/AP plates + title
	local top = UIKit.new("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(1100, 150),
		BackgroundTransparency = 1,
		Parent = overlay,
	})
	UIKit.autoScale(top)
	plates.player = makePlate(top, "player")
	plates.wild = makePlate(top, "wild")
	UIKit.label("VS", {
		Font = UIKit.FontTitle,
		TextSize = 34,
		TextColor3 = C.accent,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.fromOffset(120, 40),
		Parent = top,
	})
	title = UIKit.label("", {
		Font = UIKit.FontTitle,
		TextSize = 26,
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 114),
		Size = UDim2.new(1, 0, 0, 32),
		Parent = top,
	})

	-- bottom: log + action rows
	local bottom = UIKit.new("Frame", {
		Name = "Bottom",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(940, 140),
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.15,
		Parent = overlay,
	}, { UIKit.corner(18), UIKit.stroke(C.stroke, 2), UIKit.padding(10) })
	UIKit.autoScale(bottom)
	logLabel = UIKit.label("", {
		TextSize = 15,
		TextColor3 = C.textDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = bottom,
	})

	local function row(name: string): Frame
		local r = UIKit.new("Frame", {
			Name = name .. "Row",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 86),
			Visible = false,
			Parent = bottom,
		})
		rows[name] = r
		return r
	end

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

	local fightRow = row("fight")
	UIKit.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center).Parent = fightRow
	local function actionButton(action: string, text: string, color: Color3, order: number)
		fightButtons[action] = UIKit.button(text, color, function()
			if animating then
				return
			end
			send(Remotes.Actions.BattleAction, { action = action })
		end, { Size = UDim2.fromOffset(200, 80), TextSize = 20, LayoutOrder = order, Parent = fightRow })
	end
	actionButton("Attack", "ATTACK", C.attack, 1)
	actionButton("Defend", "DEFEND\nuse 1 AP", C.defend, 2)
	actionButton("Save", "SAVE\nkeep AP", C.save, 3)
	UIKit.button("Retreat", C.disabled, function()
		if not animating then
			send(Remotes.Actions.BattleForfeit)
		end
	end, { Size = UDim2.fromOffset(120, 80), LayoutOrder = 4, Parent = fightRow })

	local rewardRow = row("reward")
	UIKit.list(Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center).Parent = rewardRow
	rewardButtons.capture = UIKit.button("CAPTURE", Color3.fromRGB(80, 150, 220), function()
		send(Remotes.Actions.BattleResolve, { choice = "capture" })
	end, { Size = UDim2.fromOffset(280, 80), TextSize = 20, LayoutOrder = 1, Parent = rewardRow })
	rewardButtons.cells = UIKit.button("DEFEAT", Color3.fromRGB(60, 170, 150), function()
		send(Remotes.Actions.BattleResolve, { choice = "cells" })
	end, { Size = UDim2.fromOffset(280, 80), TextSize = 20, LayoutOrder = 2, Parent = rewardRow })

	local endedRow = row("ended")
	UIKit.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center).Parent = endedRow
	UIKit.button("Continue", C.good, close, { Size = UDim2.fromOffset(240, 72), TextSize = 22, Parent = endedRow })

	Remotes.event(Remotes.Events.BattleSync).OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.wild) ~= "table" then
			return
		end
		table.insert(queue, payload)
		task.spawn(pump)
	end)

	ClientState.onChanged(function(scope)
		if scope == "full" and isOpen and current and current.phase == "select" then
			rebuildSelectList()
		end
	end)
end

return BattleUI
