--!nonstrict
-- Small helpers for building UI in code. Touch-friendly sizes; everything scales with UIScale.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Visual.Palette)

local UIKit = {}

local C = Palette.UI
UIKit.Colors = C
UIKit.FontTitle = Enum.Font.FredokaOne
UIKit.FontBody = Enum.Font.GothamMedium
UIKit.FontBold = Enum.Font.GothamBold

function UIKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	if props then
		local parent = props.Parent
		for k, v in props do
			if k ~= "Parent" then
				inst[k] = v
			end
		end
		if children then
			for _, child in children do
				child.Parent = inst
			end
		end
		if parent then
			inst.Parent = parent
		end
	elseif children then
		for _, child in children do
			child.Parent = inst
		end
	end
	return inst
end

function UIKit.corner(radius: number?): UICorner
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UIKit.stroke(color: Color3?, thickness: number?): UIStroke
	return UIKit.new("UIStroke", {
		Color = color or C.stroke,
		Thickness = thickness or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return UIKit.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function UIKit.list(direction: Enum.FillDirection?, spacing: number?, align: Enum.HorizontalAlignment?): UIListLayout
	return UIKit.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, spacing or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})
end

function UIKit.label(text: string, props: { [string]: any }?): TextLabel
	local base = {
		BackgroundTransparency = 1,
		Font = UIKit.FontBody,
		TextColor3 = C.text,
		TextSize = 18,
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 22),
	}
	for k, v in props or {} do
		base[k] = v
	end
	return UIKit.new("TextLabel", base)
end

-- A rounded button. Returns the TextButton; use UIKit.setEnabled to toggle.
function UIKit.button(text: string, color: Color3, onClick: () -> (), props: { [string]: any }?): TextButton
	local base = {
		AutoButtonColor = true,
		BackgroundColor3 = color,
		Font = UIKit.FontBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 18,
		Text = text,
		Size = UDim2.fromOffset(160, 48),
		TextWrapped = true,
	}
	for k, v in props or {} do
		base[k] = v
	end
	local button = UIKit.new("TextButton", base, { UIKit.corner(10), UIKit.stroke(Color3.fromRGB(0, 0, 0), 1) })
	button:SetAttribute("BaseColor", color)
	button:SetAttribute("Enabled", true)
	local busy = false
	button.Activated:Connect(function()
		if busy or not button:GetAttribute("Enabled") then
			return
		end
		busy = true
		local ok, err = pcall(onClick)
		busy = false
		if not ok then
			warn("[UI] button handler failed: " .. tostring(err))
		end
	end)
	return button
end

function UIKit.setEnabled(button: TextButton, enabled: boolean)
	button:SetAttribute("Enabled", enabled)
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then button:GetAttribute("BaseColor") else C.disabled
	button.TextTransparency = if enabled then 0 else 0.35
end

-- Modal panel centred on screen with a title and close button. Returns (frame, contentFrame).
function UIKit.panel(parent: Instance, title: string, onClose: () -> ()): (Frame, Frame)
	local frame = UIKit.new("Frame", {
		Name = title .. "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.82, 0),
		BackgroundColor3 = C.panel,
		Visible = false,
		ZIndex = 10,
		Parent = parent,
	}, {
		UIKit.corner(16),
		UIKit.stroke(C.stroke, 2),
		UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(760, 620) }),
	})
	UIKit.label(title, {
		Font = UIKit.FontTitle,
		TextSize = 30,
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.new(1, -90, 0, 38),
		Parent = frame,
	})
	UIKit.button("X", C.bad, onClose, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(44, 44),
		TextSize = 22,
		Parent = frame,
	})
	local content = UIKit.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 1, -74),
		Parent = frame,
	})
	return frame, content
end

function UIKit.scrolling(parent: Instance): ScrollingFrame
	return UIKit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,
		Parent = parent,
	}, { UIKit.list(Enum.FillDirection.Vertical, 10), UIKit.padding(4) })
end

-- Scales an offset-sized cluster (HUD, battle panel) so it fits phones and large monitors.
-- Scale-sized panels don't need this.
function UIKit.autoScale(target: GuiObject)
	local scale = UIKit.new("UIScale", { Parent = target })
	local function update()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local size = camera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.62, 1.3)
	end
	update()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(update)
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end

function UIKit.screenGui(name: string, displayOrder: number): ScreenGui
	return UIKit.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
end

function UIKit.klBadge(kl: number, props: { [string]: any }?): TextLabel
	local base = {
		BackgroundTransparency = 0,
		BackgroundColor3 = Palette.KL[kl] or C.panelLight,
		Font = UIKit.FontBold,
		TextColor3 = Color3.fromRGB(20, 20, 24),
		TextSize = 16,
		Text = "KL " .. kl,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(52, 24),
	}
	for k, v in props or {} do
		base[k] = v
	end
	local badge = UIKit.label("", base)
	UIKit.corner(12).Parent = badge
	return badge
end

function UIKit.formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

return UIKit
