--!strict
--[[
	Voting.lua — schermata cinematografica di votazione (client).
	Mostra le facility (nome, descrizione, difficolta' base, giocatori, entita', voti in tempo reale),
	il selettore di difficolta' e il tempo rimasto. Tutti i numeri arrivano dal server (MatchState):
	il client invia solo il proprio voto, che il server valida.
	Le facility non hanno ancora un'immagine: l'anteprima e' un riquadro VHS con il nome (le immagini
	si aggiungeranno quando le mappe esisteranno, Milestone 5 e 8).
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("LIGHTS")
local Config = require(shared:WaitForChild("Config"))
local Maps = require(shared:WaitForChild("Maps"))
local Net = require(shared:WaitForChild("Net"))
local UIKit = require(script.Parent.UIKit)
local Menu = require(script.Parent.Menu)

local Voting = {}

type Card = { frame: Frame, edge: UIStroke, votes: TextLabel, bar: Frame }

local gui: ScreenGui
local timer: TextLabel
local squad: TextLabel
local resultTitle: Frame? = nil
local resultHolder: Frame
local cardsHolder: Frame
local difficultyRow: Frame
local cards: { [string]: Card } = {}
local setDifficultyText: (string) -> ()
local firstCard: GuiObject? = nil
local state = "None"
local endsAt = 0
local lastPayload: any = nil
local difficultyIndex = 2 -- NORMALE

local function difficultyName(id: string): string
	for _, d in Config.Difficulties do
		if d.Id == id then
			return d.Name
		end
	end
	return id
end

local function buildCard(parent: Instance, index: number, map: Maps.MapInfo): Card
	local frame = UIKit.button(parent, "", {
		Position = UDim2.fromOffset((index - 1) * 296, 0),
		Size = UDim2.fromOffset(280, 360),
		BackgroundColor3 = UIKit.Colors.Panel,
		TextTransparency = 1,
	})
	local edge = frame:FindFirstChildOfClass("UIStroke") :: UIStroke
	-- Anteprima: riquadro scuro con scanline e nome, finche' non esiste l'immagine della mappa.
	local preview = UIKit.panel(frame, { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 112), BackgroundColor3 = Color3.fromRGB(4, 5, 7) })
	for y = 0, 108, 4 do
		UIKit.create("Frame", { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(40, 44, 48), BackgroundTransparency = 0.5, BorderSizePixel = 0 }, preview)
	end
	UIKit.title(preview, map.Name, { Position = UDim2.fromOffset(8, 30), Size = UDim2.new(1, -16, 0, 50) }, 26)

	local y = 132
	local function line(text: string, color: Color3, height: number, size: number, font: Enum.Font?)
		local label = UIKit.text(frame, {
			Text = text,
			TextColor3 = color,
			Font = font or UIKit.Mono,
			TextWrapped = true,
			Position = UDim2.fromOffset(14, y),
			Size = UDim2.new(1, -28, 0, height),
		}, size)
		y += height + 4
		return label
	end
	line(map.Description, UIKit.Colors.Muted, 50, 15, UIKit.Body)
	line("DIFFICOLTA': " .. string.upper(map.BaseDifficulty), UIKit.Colors.Text, 18, 16)
	line("GIOCATORI: " .. map.Players, UIKit.Colors.Text, 18, 16)
	line("ENTITA': " .. string.upper(map.Entity), UIKit.Colors.Text, 18, 16)
	line(map.EntityHint, UIKit.Colors.Muted, 40, 14, UIKit.Body)
	local votes = line("VOTI: 0", UIKit.Colors.Text, 20, 18)
	local track = UIKit.panel(frame, { Position = UDim2.new(0, 14, 1, -18), Size = UDim2.new(1, -28, 0, 6), BackgroundColor3 = Color3.fromRGB(40, 42, 46) })
	local bar = UIKit.panel(track, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = UIKit.Colors.Red, BackgroundTransparency = 0 })

	frame.Activated:Connect(function()
		Net.event("Vote"):FireServer("map", map.Id)
	end)
	return { frame = frame, edge = edge, votes = votes, bar = bar }
end

local function build()
	gui = UIKit.create("ScreenGui", {
		Name = "LightsVoting",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		Enabled = false,
		IgnoreGuiInset = true,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	UIKit.panel(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3 })
	local root = UIKit.create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1180, 660) }, gui)
	UIKit.scaleToScreen(UIKit.create("UIScale", {}, root))

	UIKit.title(root, "VOTAZIONE", { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 70) }, 64)
	squad = UIKit.text(root, { Text = "", TextColor3 = UIKit.Colors.Muted, Position = UDim2.fromOffset(0, 74), Size = UDim2.fromOffset(400, 24) }, 20)
	timer = UIKit.text(root, { Text = "", TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 74), Size = UDim2.fromOffset(200, 24) }, 22)

	cardsHolder = UIKit.create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 112), Size = UDim2.new(1, 0, 0, 360) }, root)
	for index, map in Maps do
		cards[map.Id] = buildCard(cardsHolder, index, map)
		firstCard = firstCard or cards[map.Id].frame
	end

	difficultyRow = UIKit.create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 496), Size = UDim2.fromOffset(640, 52) }, root)
	setDifficultyText = UIKit.selector(difficultyRow, "DIFFICOLTA':", 1, function(step: number)
		difficultyIndex = (difficultyIndex - 1 + step) % #Config.Difficulties + 1
		Net.event("Vote"):FireServer("difficulty", Config.Difficulties[difficultyIndex].Id)
	end)
	UIKit.text(root, {
		Text = "La difficolta' cambia la durata della partita e l'aggressivita' dell'entita'.",
		Font = UIKit.Body,
		TextColor3 = UIKit.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 556),
		Size = UDim2.fromOffset(700, 20),
	}, 16)

	resultHolder = UIKit.create("Frame", { BackgroundTransparency = 1, Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1000, 200) }, root)
end

local function render()
	local payload = lastPayload
	if not payload then
		return
	end
	squad.Text = string.format("SQUADRA  %d/%d", payload.size or 0, Config.Match.MaxPlayers)
	local voting = payload.state == "Voting"
	cardsHolder.Visible = voting
	difficultyRow.Visible = voting
	resultHolder.Visible = not voting

	if voting then
		local total = math.max(payload.size or 1, 1)
		for id, card in cards do
			local count = (payload.mapVotes and payload.mapVotes[id]) or 0
			card.votes.Text = "VOTI: " .. count
			card.bar.Size = UDim2.fromScale(count / total, 1)
			local mine = payload.myMap == id
			card.edge.Thickness = if mine then 4 else 2
			card.edge.Transparency = if mine then 0 else 0.5
		end
		local difficulty = Config.Difficulties[difficultyIndex]
		if payload.myDifficulty then
			for index, d in Config.Difficulties do
				if d.Id == payload.myDifficulty then
					difficultyIndex = index
					difficulty = d
				end
			end
		end
		local count = (payload.difficultyVotes and payload.difficultyVotes[difficulty.Id]) or 0
		setDifficultyText(difficulty.Name .. "  (" .. count .. ")")
	else
		if resultTitle then
			resultTitle:Destroy()
		end
		local text = "PREPARAZIONE..."
		if payload.result then
			local mapName = payload.result.map
			for _, map in Maps do
				if map.Id == payload.result.map then
					mapName = map.Name
				end
			end
			text = mapName .. "\n" .. difficultyName(payload.result.difficulty)
		end
		resultTitle = UIKit.title(resultHolder, text, { Size = UDim2.fromScale(1, 1) }, 56)
	end
end

function Voting.start()
	build()
	Net.event("MatchState").OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		local previous = state
		state = payload.state
		endsAt = payload.endsAt or 0
		if state == "None" then
			lastPayload = nil
			gui.Enabled = false
			Menu.setVisible(true)
			return
		end
		lastPayload = payload
		gui.Enabled = true
		Menu.setVisible(false)
		render()
		if previous ~= "Voting" and state == "Voting" and UserInputService.GamepadEnabled then
			GuiService.SelectedObject = firstCard
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			if gui.Enabled then
				timer.Text = string.format("%d s", math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow())))
			end
		end
	end)
end

return Voting
