--!strict
--[[
	UIKit.lua — mattoni dell'interfaccia di LIGHTS, condivisi da Menu e Voting.
	Stile: nero, grigio, bianco, rosso scuro con moderazione; bordo bianco sottile; titoli con
	sdoppiamento rosso/ciano (aberrazione VHS) come nei riferimenti. Niente immagini caricate.
]]

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIKit = {}

UIKit.Colors = {
	Panel = Color3.fromRGB(10, 12, 16),
	Button = Color3.fromRGB(14, 17, 22),
	Text = Color3.fromRGB(238, 240, 242),
	Muted = Color3.fromRGB(150, 154, 160),
	Red = Color3.fromRGB(150, 24, 28),
	Cyan = Color3.fromRGB(40, 200, 210),
}
UIKit.Mono = Enum.Font.RobotoMono
UIKit.Body = Enum.Font.Gotham

-- Crea un'istanza con le sue proprieta'.
function UIKit.create(className: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(className)
	for key, value in props do
		(object :: any)[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

function UIKit.tween(object: Instance, time: number, props: { [string]: any })
	TweenService:Create(object, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

function UIKit.border(parent: Instance, thickness: number?, transparency: number?): UIStroke
	return UIKit.create("UIStroke", {
		Color = UIKit.Colors.Text,
		Thickness = thickness or 2,
		Transparency = transparency or 0.1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function UIKit.panel(parent: Instance, props: { [string]: any }): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or UIKit.Colors.Panel
	props.BackgroundTransparency = props.BackgroundTransparency or 0.08
	props.BorderSizePixel = 0
	return UIKit.create("Frame", props, parent)
end

-- Testo che si adatta alla casella, con dimensione massima.
function UIKit.text(parent: Instance, props: { [string]: any }, maxSize: number?): TextLabel
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.TextColor3 = props.TextColor3 or UIKit.Colors.Text
	props.Font = props.Font or UIKit.Mono
	props.TextScaled = true
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	local label: TextLabel = UIKit.create("TextLabel", props, parent)
	UIKit.create("UITextSizeConstraint", { MaxTextSize = maxSize or 22, MinTextSize = 9 }, label)
	return label
end

-- Titolo con aberrazione cromatica: copia rossa e copia ciano sfalsate sotto il testo bianco.
function UIKit.title(parent: Instance, text: string, props: { [string]: any }, maxSize: number): Frame
	props.BackgroundTransparency = 1
	local holder: Frame = UIKit.create("Frame", props, parent)
	for _, layer in { { UIKit.Colors.Red, -2 }, { UIKit.Colors.Cyan, 2 }, { UIKit.Colors.Text, 0 } } do
		UIKit.text(holder, {
			Text = text,
			Font = UIKit.Mono,
			TextColor3 = layer[1],
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(layer[2], 0),
			TextTransparency = if layer[2] == 0 then 0 else 0.25,
		}, maxSize)
	end
	return holder
end

-- Pulsante: riquadro nero con bordo bianco. Al passaggio il bordo si accende, alla pressione si rimpicciolisce.
function UIKit.button(parent: Instance, label: string, props: { [string]: any }, maxSize: number?): TextButton
	props.AutoButtonColor = false
	props.BackgroundColor3 = props.BackgroundColor3 or UIKit.Colors.Button
	props.BackgroundTransparency = props.BackgroundTransparency or 0.05
	props.BorderSizePixel = 0
	props.Font = props.Font or UIKit.Mono
	props.Text = label
	props.TextColor3 = props.TextColor3 or UIKit.Colors.Text
	props.TextScaled = true
	props.Selectable = true
	local b: TextButton = UIKit.create("TextButton", props, parent)
	local edge = UIKit.border(b, 2, 0.15)
	UIKit.create("UITextSizeConstraint", { MaxTextSize = maxSize or 26, MinTextSize = 10 }, b)
	UIKit.create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, b)
	local scale = UIKit.create("UIScale", {}, b)
	local function hover(on: boolean)
		UIKit.tween(edge, 0.12, { Transparency = if on then 0 else 0.15, Thickness = if on then 3 else 2 })
	end
	b.MouseEnter:Connect(function()
		hover(true)
	end)
	b.MouseLeave:Connect(function()
		hover(false)
	end)
	b.SelectionGained:Connect(function()
		hover(true)
	end)
	b.SelectionLost:Connect(function()
		hover(false)
	end)
	b.MouseButton1Down:Connect(function()
		UIKit.tween(scale, 0.06, { Scale = 0.96 })
	end)
	b.MouseButton1Up:Connect(function()
		UIKit.tween(scale, 0.12, { Scale = 1 })
	end)
	return b
end

-- Riga "ETICHETTA:  ◀ valore ▶". onStep(-1 | 1) cambia il valore; ritorna la funzione per aggiornare il testo.
function UIKit.selector(parent: Instance, label: string, order: number, onStep: (number) -> ()): ((string) -> (), TextButton)
	local row = UIKit.panel(parent, { Size = UDim2.new(1, 0, 0, 52), LayoutOrder = order })
	UIKit.border(row, 1, 0.6)
	UIKit.text(row, { Text = label, Position = UDim2.fromScale(0.04, 0.15), Size = UDim2.fromScale(0.46, 0.7) }, 24)
	local left = UIKit.button(row, "◀", { Size = UDim2.fromScale(0.09, 0.7), Position = UDim2.fromScale(0.52, 0.15) }, 22)
	local value = UIKit.text(row, {
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromScale(0.62, 0.15),
		Size = UDim2.fromScale(0.26, 0.7),
	}, 24)
	local right = UIKit.button(row, "▶", { Size = UDim2.fromScale(0.09, 0.7), Position = UDim2.fromScale(0.89, 0.15) }, 22)
	left.Activated:Connect(function()
		onStep(-1)
	end)
	right.Activated:Connect(function()
		onStep(1)
	end)
	return function(text: string)
		value.Text = text
	end, left
end

-- Scala un'interfaccia disegnata su base 1280x720 alla dimensione reale dello schermo (PC, mobile, console).
function UIKit.scaleToScreen(scale: UIScale)
	local function update()
		local camera = Workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.55, 1.25)
	end
	update()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end

return UIKit
