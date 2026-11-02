--!strict
--[[
	Menu.lua — interfaccia della lobby: GIOCA (coda), stato coda, Impostazioni, Novita', avvisi.
	Geometria in pixel su una base 1280x720, scalata da un UIScale: stessa resa su PC, mobile e console.
	Shop, inventario e classifiche non hanno ancora un pulsante: arrivano con le milestone 10-11.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("LIGHTS")
local Config = require(shared:WaitForChild("Config"))
local Net = require(shared:WaitForChild("Net"))
local Settings = require(script.Parent.Settings)
local UIKit = require(script.Parent.UIKit)

local Menu = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local hud: Frame
local playButton: TextButton
local queueLabel: TextLabel
local lobbyLabel: TextLabel
local toast: TextLabel
local openPanel: Frame? = nil
local queued = false
local toastToken = 0

local function showToast(message: string)
	toastToken += 1
	local token = toastToken
	toast.Text = message
	UIKit.tween(toast, 0.2, { TextTransparency = 0, TextStrokeTransparency = 0.4 })
	task.delay(3.5, function()
		if token == toastToken then
			UIKit.tween(toast, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

local function refresh()
	playButton.Text = if queued then "✕  ANNULLA" else "▶  GIOCA"
	local count = Workspace:GetAttribute("LightsQueueCount") or 0
	local deadline = Workspace:GetAttribute("LightsQueueDeadline") or 0
	if queued then
		local left = math.max(0, math.ceil(deadline - Workspace:GetServerTimeNow()))
		queueLabel.Text = string.format("RICERCA SQUADRA   %d/%d   %d s", count, Config.Match.MaxPlayers, left)
	else
		queueLabel.Text = ""
	end
	lobbyLabel.Text = string.format("NELLA LOBBY  %d/%d", #Players:GetPlayers(), Players.MaxPlayers)
end

-- Pannello centrale con titolo VHS e pulsante INDIETRO rosso, come nei riferimenti.
local function modal(name: string, title: string): (Frame, Frame)
	local panel = UIKit.panel(gui:FindFirstChild("Root") :: Frame, {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromOffset(680, 520),
		Visible = false,
	})
	UIKit.border(panel, 2, 0.4)
	UIKit.title(panel, title, { Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 56) }, 52)
	local body = UIKit.create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(28, 86),
		Size = UDim2.new(1, -56, 1, -170),
	}, panel)
	local back = UIKit.button(panel, "◀  INDIETRO", {
		BackgroundColor3 = UIKit.Colors.Red,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 28, 1, -18),
		Size = UDim2.fromOffset(220, 54),
	}, 26)
	back.Activated:Connect(function()
		Menu.close()
	end)
	return panel, body
end

function Menu.close()
	if openPanel then
		openPanel.Visible = false
		openPanel = nil
	end
	hud.Visible = true
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = playButton
	end
end

local function open(panel: Frame, firstControl: GuiObject?)
	Menu.close()
	openPanel = panel
	panel.Visible = true
	hud.Visible = false
	local scale = panel:FindFirstChildOfClass("UIScale") or UIKit.create("UIScale", {}, panel)
	scale.Scale = 0.95
	UIKit.tween(scale, 0.2, { Scale = 1 })
	if UserInputService.GamepadEnabled and firstControl then
		GuiService.SelectedObject = firstControl
	end
end

local function buildSettings(): (Frame, GuiObject?)
	local panel, body = modal("Settings", "IMPOSTAZIONI")
	UIKit.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, body)
	local refreshers: { () -> () } = {}
	local first: GuiObject? = nil
	local rows = {
		{ "Shadows", "OMBRE" },
		{ "Bloom", "BAGLIORE" },
		{ "Fog", "NEBBIA" },
		{ "VHS", "FILTRO VHS" },
		{ "ReduceFlicker", "RIDUCI LAMPEGGI" },
		{ "MusicVolume", "AMBIENTE" },
		{ "EffectsVolume", "EFFETTI" },
	}
	for order, row in rows do
		local key, label = row[1], row[2]
		local isNumber = typeof(Config.SettingsDefaults[key]) == "number"
		local setText, control = UIKit.selector(body, label .. ":", order, function(step: number)
			local current = Settings.values[key]
			if isNumber then
				Settings.set(key, math.clamp((current or 0) + step, 0, 10))
			else
				Settings.set(key, not current)
			end
		end)
		first = first or control
		table.insert(refreshers, function()
			local value = Settings.values[key]
			setText(if isNumber then tostring(value) elseif value then "SI" else "NO")
		end)
	end
	local function refreshAll()
		for _, f in refreshers do
			f()
		end
	end
	Settings.onChanged(refreshAll)
	refreshAll()
	return panel, first
end

local function buildNews(): Frame
	local panel, body = modal("News", "NOVITA'")
	UIKit.create("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }, body)
	for index, item in Config.News do
		local entry = UIKit.create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 76), LayoutOrder = index }, body)
		UIKit.text(entry, { Text = item.Title, Size = UDim2.new(1, 0, 0, 28) }, 26)
		UIKit.text(entry, {
			Text = item.Body,
			Font = UIKit.Body,
			TextColor3 = UIKit.Colors.Muted,
			TextWrapped = true,
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(1, 0, 0, 42),
		}, 18)
	end
	return panel
end

local function tile(parent: Instance, label: string, x: number): TextButton
	return UIKit.button(parent, label, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, x, 0, 104),
		Size = UDim2.fromOffset(150, 64),
	}, 18)
end

local function build()
	gui = UIKit.create("ScreenGui", {
		Name = "LightsMenu",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	local root = UIKit.create("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
	UIKit.scaleToScreen(UIKit.create("UIScale", {}, root))

	hud = UIKit.create("Frame", { Name = "Hud", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, root)
	lobbyLabel = UIKit.text(hud, {
		Text = "",
		TextColor3 = UIKit.Colors.Muted,
		Position = UDim2.new(0, 92, 0, 80),
		Size = UDim2.fromOffset(300, 22),
	}, 18)

	local bar = UIKit.create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(600, 172),
	}, hud)
	queueLabel = UIKit.text(bar, {
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(500, 24),
	}, 20)
	playButton = UIKit.button(bar, "▶  GIOCA", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(360, 88),
	}, 40)
	local settingsTile = tile(bar, "IMPOSTAZIONI", -80)
	local newsTile = tile(bar, "NOVITA'", 80)

	toast = UIKit.text(root, {
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(700, 28),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
	}, 24)

	local settingsPanel, firstSetting = buildSettings()
	local newsPanel = buildNews()

	playButton.Activated:Connect(function()
		queued = not queued
		refresh()
		Net.event("QueueRequest"):FireServer(queued)
	end)
	settingsTile.Activated:Connect(function()
		open(settingsPanel, firstSetting)
	end)
	newsTile.Activated:Connect(function()
		open(newsPanel, nil)
	end)
end

-- Nasconde il menu mentre e' aperta la votazione.
function Menu.setVisible(visible: boolean)
	gui.Enabled = visible
	if visible then
		queued = false
		refresh()
	end
end

function Menu.notify(message: string)
	showToast(message)
end

function Menu.start()
	repeat
		task.wait()
	until Workspace.CurrentCamera
	build()
	refresh()

	Net.event("Notice").OnClientEvent:Connect(function(message: string, inQueue: any)
		if typeof(inQueue) == "boolean" then
			queued = inQueue
			refresh()
		end
		showToast(message)
	end)
	Players.PlayerAdded:Connect(refresh)
	Players.PlayerRemoving:Connect(refresh)
	Workspace:GetAttributeChangedSignal("LightsQueueCount"):Connect(refresh)
	task.spawn(function()
		while true do -- conto alla rovescia della coda
			task.wait(0.5)
			if queued then
				refresh()
			end
		end
	end)

	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = playButton
	end
end

return Menu
