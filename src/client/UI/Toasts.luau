--!nonstrict
-- Short feedback messages at the top of the screen.

local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent.UIKit)

local Toasts = {}

local container: Frame = nil
local KIND_COLORS = {
	info = UIKit.Colors.panelLight,
	good = Color3.fromRGB(46, 120, 74),
	error = Color3.fromRGB(150, 50, 50),
}

function Toasts.init(gui: ScreenGui)
	container = UIKit.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0.9, 0, 0, 200),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = gui,
	}, {
		UIKit.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center),
		UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(560, 200) }),
	})
end

function Toasts.show(text: string, kind: string?)
	if not container then
		return
	end
	local toast = UIKit.new("TextLabel", {
		BackgroundColor3 = KIND_COLORS[kind or "info"] or KIND_COLORS.info,
		BackgroundTransparency = 0.05,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = UIKit.FontBold,
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		TextWrapped = true,
		Text = text,
		ZIndex = 51,
		Parent = container,
	}, { UIKit.corner(10), UIKit.padding(10) })
	task.delay(3.5, function()
		local tween = TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
	local children = {}
	for _, child in container:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(children, child)
		end
	end
	if #children > 4 then
		children[1]:Destroy()
	end
end

return Toasts
