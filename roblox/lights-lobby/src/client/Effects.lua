--!strict
--[[
	Effects.lua — effetti visivi locali sincronizzati con le luci del server.
	- Logo LIGHTS: si spegne con il blackout, ripete il lampeggio al ritorno della corrente, ha glitch ogni tanto.
	- Monitor: quando il server lo segnala, mostra statica per un istante.
	Con "Riduci lampeggi" attivo gli effetti stroboscopici del client si fermano (le luci della lobby restano).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("LightsLobby")
local Net = require(shared:WaitForChild("Net"))
local Settings = require(script.Parent.Settings)

local Effects = {}

local COLS, ROWS = 24, 14 -- griglia della statica del monitor
local letters: { TextLabel } = {}
local powered = true
local grids: { [Instance]: { Frame } } = {}

local function reduced(): boolean
	return Settings.values.ReduceFlicker == true
end

-- Trova le lettere del logo (tag LightsLogo, creato dal server nel Builder).
local function findLogo()
	table.clear(letters)
	local panel = CollectionService:GetTagged("LightsLogo")[1]
	local gui = panel and panel:FindFirstChildOfClass("SurfaceGui")
	if not gui then
		return
	end
	for _, child in gui:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(letters, child)
		end
	end
end

local function setLogo(visible: boolean)
	for _, letter in letters do
		letter.TextTransparency = if visible then 0.05 else 1
		letter.TextStrokeTransparency = if visible then 0.55 else 1
	end
end

-- Dopo il ritorno della corrente: il logo ripete qualche lampeggio prima di stabilizzarsi.
local function logoFlicker()
	for _ = 1, 6 do
		if not powered then
			return
		end
		for _, letter in letters do
			letter.TextTransparency = if math.random() < 0.5 then 1 else 0.05
		end
		task.wait(0.05 + math.random() * 0.1)
	end
	setLogo(powered)
end

-- Glitch sporadico di una lettera: si sposta di poco e si attenua per un attimo.
local function glitch()
	while true do
		task.wait(6 + math.random() * 8)
		if reduced() or not powered or #letters == 0 then
			continue
		end
		local letter = letters[math.random(1, #letters)]
		local base = letter.Position
		letter.Position = base + UDim2.fromScale((math.random() - 0.5) * 0.03, 0)
		letter.TextTransparency = 0.6
		task.wait(0.08)
		letter.Position = base
		letter.TextTransparency = 0.05
	end
end

-- Griglia di celle nere, creata una volta per schermo e riutilizzata.
local function gridFor(screen: Frame): { Frame }
	local existing = grids[screen]
	if existing then
		return existing
	end
	local cells = {}
	for row = 1, ROWS do
		for col = 1, COLS do
			local cell = Instance.new("Frame")
			cell.BorderSizePixel = 0
			cell.Size = UDim2.fromScale(1 / COLS, 1 / ROWS)
			cell.Position = UDim2.fromScale((col - 1) / COLS, (row - 1) / ROWS)
			cell.BackgroundColor3 = Color3.new(0, 0, 0)
			cell.Parent = screen
			table.insert(cells, cell)
		end
	end
	grids[screen] = cells
	return cells
end

-- Statica per circa 0.35 secondi sullo schermo del monitor indicato dal server.
local function showStatic(monitor: Instance)
	local gui = monitor:FindFirstChildOfClass("SurfaceGui")
	local screen = gui and gui:FindFirstChild("Screen")
	if not screen or not screen:IsA("Frame") then
		return
	end
	local cells = gridFor(screen)
	for _ = 1, 7 do
		for _, cell in cells do
			local v = 0.15 + math.random() * 0.6
			cell.BackgroundColor3 = Color3.new(v, v, v)
		end
		task.wait(0.05)
	end
	for _, cell in cells do
		cell.BackgroundColor3 = Color3.new(0, 0, 0)
	end
end

function Effects.start()
	findLogo()
	CollectionService:GetInstanceAddedSignal("LightsLogo"):Connect(findLogo)

	Net.event("LightsEvent").OnClientEvent:Connect(function(kind: string, arg: any)
		if kind == "cut" or kind == "blackout" then
			powered = false
			setLogo(false)
		elseif kind == "restore" then
			powered = true
			if reduced() then
				setLogo(true)
			else
				task.spawn(logoFlicker)
			end
		elseif kind == "static" and not reduced() and typeof(arg) == "Instance" then
			task.spawn(showStatic, arg)
		end
	end)

	task.spawn(glitch)
end

return Effects
