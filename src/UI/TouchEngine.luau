--!strict
-- [TouchEngine.luau]
-- Adaptive touch controller, gesture recognizer, and mobile hitboxes for AethelDex

local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Theme)

export type TouchEngine = {
	IsTouchDevice: boolean,
	MinHitboxSize: number,
	CreateMobileToggle: (onToggle: () -> ()) -> ImageButton,
}

local TouchEngine = {}

TouchEngine.IsTouchDevice = UserInputService.TouchEnabled
TouchEngine.MinHitboxSize = TouchEngine.IsTouchDevice and 44 or 24

function TouchEngine.CreateMobileToggle(onToggle)
	local button = Instance.new("ImageButton")
	button.Name = "AethelDex_MobileToggle"
	button.Size = UDim2.fromOffset(50, 50)
	button.Position = UDim2.new(0, 15, 0.5, -25)
	button.BackgroundColor3 = Theme.Accent
	button.Image = "rbxassetid://6031075931"
	button.ImageColor3 = Color3.new(1, 1, 1)
	button.ZIndex = 1000000

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 2
	stroke.Transparency = 0.5
	stroke.Parent = button

	-- Dragging logic for mobile floating button
	local dragging = false
	local dragStart
	local startPos

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = button.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local delta = input.Position - dragStart
			button.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)

	button.Activated:Connect(onToggle)

	return button
end

return TouchEngine
