--!strict
--[[
	Menu.lua — interfaccia della lobby (client). Stile sobrio: pannelli scuri semitrasparenti, testo bianco,
	pochi tween. Tutto e' costruito in codice (nessun asset grafico da caricare).
	- Stato: giocatori nella lobby e in coda.
	- GIOCA (entra/esce dalla coda), PARTITA PRIVATA, IMPOSTAZIONI.
	- Aggiornamenti dalla Config.News.
	Layout orizzontale su PC e console, verticale su mobile (rilevato dalla dimensione dello schermo).
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("LightsLobby")
local Config = require(shared:WaitForChild("Config"))
local Net = require(shared:WaitForChild("Net"))
local Settings = require(script.Parent.Settings)

local Menu = {}

local PANEL = Color3.fromRGB(8, 9, 11)
local BUTTON = Color3.fromRGB(20, 21, 25)
local PRIMARY = Color3.fromRGB(34, 36, 42)
local TEXT = Color3.fromRGB(238, 242, 246)
local MUTED = Color3.fromRGB(150, 156, 164)
local PANEL_TRANSPARENCY = 0.3

local player = Players.LocalPlayer
local gui: ScreenGui
local statusPanel: Frame
local newsPanel: Frame
local actionStack: Frame
local settingsPanel: Frame
local settingsScale: UIScale
local playersLabel: TextLabel
local queueLabel: TextLabel
local toast: TextLabel
local queueButton: TextButton
local privateButton: TextButton
local settingsButton: TextButton
local closeButton: TextButton
local firstControl: GuiObject? = nil
local queued = false
local toastToken = 0
local refreshers: { () -> () } = {}

-- Crea un'istanza e ne imposta le proprieta' in un solo passaggio.
local function create(className: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(className)
	for key, value in props do
		(object :: any)[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

local function tween(object: Instance, time: number, props: { [string]: any })
	TweenService:Create(object, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function corner(parent: Instance, radius: number)
	create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(parent: Instance, transparency: number): UIStroke
	return create("UIStroke", { Color = TEXT, Transparency = transparency, Thickness = 1 }, parent)
end

local function panel(name: string, position: UDim2, size: UDim2, anchor: Vector2?): Frame
	local frame = create("Frame", {
		Name = name,
		AnchorPoint = anchor or Vector2.zero,
		Position = position,
		Size = size,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = PANEL_TRANSPARENCY,
		BorderSizePixel = 0,
	}, gui)
	corner(frame, 8)
	stroke(frame, 0.88)
	return frame
end

-- Testo che si adatta alla sua casella (TextScaled), con dimensione massima.
local function text(parent: Instance, props: { [string]: any }, maxSize: number?): TextLabel
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.TextColor3 = props.TextColor3 or TEXT
	props.Font = props.Font or Enum.Font.Gotham
	props.TextScaled = true
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	local label: TextLabel = create("TextLabel", props, parent)
	create("UITextSizeConstraint", { MaxTextSize = maxSize or 20, MinTextSize = 10 }, label)
	return label
end

-- Pulsante con bordo sottile che si accende al passaggio e si rimpicciolisce alla pressione.
local function button(parent: Instance, label: string, order: number, height: number, primary: boolean?): TextButton
	local b: TextButton = create("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = if primary then PRIMARY else BUTTON,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		Font = Enum.Font.GothamBold,
		Text = label,
		TextColor3 = TEXT,
		TextScaled = true,
		LayoutOrder = order,
		Selectable = true,
	}, parent)
	corner(b, 6)
	local edge = stroke(b, if primary then 0.5 else 0.8)
	create("UITextSizeConstraint", { MaxTextSize = if primary then 22 else 18, MinTextSize = 11 }, b)
	local scale = create("UIScale", {}, b)
	b.MouseEnter:Connect(function()
		tween(edge, 0.15, { Transparency = 0.25 })
	end)
	b.MouseLeave:Connect(function()
		tween(edge, 0.15, { Transparency = if primary then 0.5 else 0.8 })
	end)
	b.MouseButton1Down:Connect(function()
		tween(scale, 0.06, { Scale = 0.97 })
	end)
	b.MouseButton1Up:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
	end)
	return b
end

-- Piccolo testo di avviso in basso al centro, si spegne da solo dopo qualche secondo.
local function showToast(message: string)
	toastToken += 1
	local token = toastToken
	toast.Text = message
	tween(toast, 0.2, { TextTransparency = 0, TextStrokeTransparency = 0.5 })
	task.delay(3.5, function()
		if token == toastToken then
			tween(toast, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

local function refreshCounts()
	playersLabel.Text = "Nella lobby: " .. #Players:GetPlayers() .. " / " .. Players.MaxPlayers
	queueLabel.Text = "In coda: " .. tostring(Workspace:GetAttribute("LightsQueueCount") or 0)
end

local function refreshQueueButton()
	queueButton.Text = if queued then "ESCI DALLA CODA" else "GIOCA"
end

-- Disposizione: orizzontale su schermo largo, verticale su telefono (schermo piu' alto che largo).
local function relayout()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	if viewport.X < viewport.Y then
		statusPanel.Position = UDim2.fromScale(0.04, 0.04)
		statusPanel.Size = UDim2.fromScale(0.92, 0.11)
		newsPanel.AnchorPoint = Vector2.new(0.5, 0)
		newsPanel.Position = UDim2.fromScale(0.5, 0.17)
		newsPanel.Size = UDim2.fromScale(0.92, 0.2)
		actionStack.Position = UDim2.fromScale(0.04, 0.6)
		actionStack.Size = UDim2.fromScale(0.92, 0.36)
		settingsPanel.Size = UDim2.fromScale(0.94, 0.8)
	else
		statusPanel.Position = UDim2.fromScale(0.03, 0.05)
		statusPanel.Size = UDim2.fromScale(0.26, 0.13)
		newsPanel.AnchorPoint = Vector2.new(1, 0)
		newsPanel.Position = UDim2.fromScale(0.97, 0.05)
		newsPanel.Size = UDim2.fromScale(0.27, 0.4)
		actionStack.Position = UDim2.fromScale(0.03, 0.55)
		actionStack.Size = UDim2.fromScale(0.24, 0.38)
		settingsPanel.Size = UDim2.fromScale(0.42, 0.72)
	end
end

-- Riga di impostazioni: interruttore ON/OFF oppure stepper "-  valore  +" (0..10).
local function settingRow(parent: Instance, order: number, key: string, label: string, isToggle: boolean): GuiObject
	local row = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = order }, parent)
	text(row, { Text = label, Size = UDim2.fromScale(0.58, 1) }, 18)

	if isToggle then
		local toggle = button(row, "OFF", 1, 0)
		toggle.AnchorPoint = Vector2.new(1, 0.5)
		toggle.Position = UDim2.fromScale(1, 0.5)
		toggle.Size = UDim2.fromScale(0.3, 0.8)
		toggle.Activated:Connect(function()
			Settings.set(key, not Settings.values[key])
		end)
		table.insert(refreshers, function()
			toggle.Text = if Settings.values[key] then "ON" else "OFF"
		end)
		return toggle
	end

	local holder = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromScale(0.36, 0.8),
	}, row)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, holder)
	local minus = button(holder, "-", 1, 0)
	minus.Size = UDim2.fromScale(0.22, 1)
	local value = text(holder, { Text = "8", TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(0.3, 1), LayoutOrder = 2 }, 18)
	local plus = button(holder, "+", 3, 0)
	plus.Size = UDim2.fromScale(0.22, 1)

	minus.Activated:Connect(function()
		Settings.set(key, math.max(0, (Settings.values[key] or 0) - 1))
	end)
	plus.Activated:Connect(function()
		Settings.set(key, math.min(10, (Settings.values[key] or 0) + 1))
	end)
	table.insert(refreshers, function()
		value.Text = tostring(Settings.values[key])
	end)
	return minus
end

local function buildSettings()
	settingsPanel = panel("Settings", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.42, 0.72), Vector2.new(0.5, 0.5))
	settingsPanel.Visible = false
	settingsScale = create("UIScale", {}, settingsPanel)

	text(settingsPanel, { Text = "IMPOSTAZIONI", Font = Enum.Font.Michroma, Position = UDim2.fromScale(0.06, 0.04), Size = UDim2.fromScale(0.7, 0.08) }, 24)
	local rows = create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.06, 0.16), Size = UDim2.fromScale(0.88, 0.66) }, settingsPanel)
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, rows)

	firstControl = settingRow(rows, 1, "Shadows", "Ombre", true)
	settingRow(rows, 2, "Bloom", "Bagliore delle luci", true)
	settingRow(rows, 3, "Fog", "Nebbia", true)
	settingRow(rows, 4, "ReduceFlicker", "Riduci lampeggi", true)
	settingRow(rows, 5, "MusicVolume", "Volume ambiente", false)
	settingRow(rows, 6, "EffectsVolume", "Volume effetti", false)

	closeButton = create("TextButton", {
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromScale(0.4, 0.09),
		BackgroundColor3 = BUTTON,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "CHIUDI",
		TextColor3 = TEXT,
		TextScaled = true,
		Selectable = true,
	}, settingsPanel)
	corner(closeButton, 6)
	stroke(closeButton, 0.8)
	create("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 11 }, closeButton)

	settingsButton.Activated:Connect(function()
		settingsPanel.Visible = true
		settingsScale.Scale = 0.94
		tween(settingsScale, 0.18, { Scale = 1 })
		if UserInputService.GamepadEnabled and firstControl then
			GuiService.SelectedObject = firstControl
		end
	end)
	closeButton.Activated:Connect(function()
		settingsPanel.Visible = false
		if UserInputService.GamepadEnabled then
			GuiService.SelectedObject = queueButton
		end
	end)
end

local function buildHud()
	gui = create("ScreenGui", {
		Name = "LightsLobbyUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	statusPanel = panel("Status", UDim2.fromScale(0.03, 0.05), UDim2.fromScale(0.26, 0.13))
	text(statusPanel, { Text = "LIGHTS", Font = Enum.Font.Michroma, Position = UDim2.fromScale(0.06, 0.08), Size = UDim2.fromScale(0.88, 0.34) }, 26)
	playersLabel = text(statusPanel, { Text = "", TextColor3 = MUTED, Position = UDim2.fromScale(0.06, 0.5), Size = UDim2.fromScale(0.88, 0.2) }, 16)
	queueLabel = text(statusPanel, { Text = "", TextColor3 = MUTED, Position = UDim2.fromScale(0.06, 0.74), Size = UDim2.fromScale(0.88, 0.2) }, 16)

	actionStack = create("Frame", { Name = "Actions", BackgroundTransparency = 1 }, gui)
	create("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, actionStack)
	queueButton = button(actionStack, "GIOCA", 1, 60, true)
	privateButton = button(actionStack, "PARTITA PRIVATA", 2, 46)
	settingsButton = button(actionStack, "IMPOSTAZIONI", 3, 46)

	newsPanel = panel("News", UDim2.fromScale(0.97, 0.05), UDim2.fromScale(0.27, 0.4), Vector2.new(1, 0))
	text(newsPanel, { Text = "AGGIORNAMENTI", TextColor3 = MUTED, Position = UDim2.fromScale(0.05, 0.03), Size = UDim2.fromScale(0.9, 0.08) }, 14)
	local list = create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.05, 0.13),
		Size = UDim2.fromScale(0.9, 0.84),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageTransparency = 0.6,
	}, newsPanel)
	create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	for index, item in Config.News do
		local entry = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = index }, list)
		text(entry, { Text = item.Title, Font = Enum.Font.GothamBold, Size = UDim2.new(1, 0, 0, 18) }, 16)
		text(entry, { Text = item.Body, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 30) }, 13)
	end

	toast = text(gui, {
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.92),
		Size = UDim2.fromScale(0.6, 0.05),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
	}, 18)

	buildSettings()
end

function Menu.start()
	repeat
		task.wait()
	until Workspace.CurrentCamera

	buildHud()
	relayout()
	refreshCounts()
	refreshQueueButton()

	queueButton.Activated:Connect(function()
		queued = not queued
		refreshQueueButton()
		Net.event("QueueRequest"):FireServer(queued)
	end)
	privateButton.Activated:Connect(function()
		queued = false
		refreshQueueButton()
		Net.event("PrivateRequest"):FireServer()
	end)

	-- Il server conferma o rifiuta: il terzo argomento (se presente) dice se il giocatore e' in coda.
	Net.event("Notice").OnClientEvent:Connect(function(message: string, inQueue: any)
		if typeof(inQueue) == "boolean" then
			queued = inQueue
			refreshQueueButton()
		end
		showToast(message)
	end)

	Players.PlayerAdded:Connect(refreshCounts)
	Players.PlayerRemoving:Connect(refreshCounts)
	Workspace:GetAttributeChangedSignal("LightsQueueCount"):Connect(refreshCounts)
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(relayout)

	Settings.onChanged(function()
		for _, refresh in refreshers do
			refresh()
		end
	end)
	for _, refresh in refreshers do
		refresh()
	end

	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = queueButton
	end
end

return Menu
