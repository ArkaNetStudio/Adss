--!strict
--[[
	Apparition.lua — la sagoma. Compare per pochissimi istanti in una postazione lontana da tutti i giocatori,
	di solito durante un blackout, e scompare sempre prima che le luci tornino.
	Rara per design: chance basse + cooldown globale. Tutti vedono la stessa sagoma (e' lato server).
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("LightsLobby")
local Config = require(shared:WaitForChild("Config"))
local Rules = require(shared:WaitForChild("Rules"))

local Apparition = {}

export type Spot = { name: string, position: Vector3, minDistance: number }

local rng: Random
local spots: { Spot } = {}
local folder: Instance
local lastShownAt: number? = nil
local generation = 0 -- aumenta a ogni clear: cancella le apparizioni gia' programmate
local current: Model? = nil

local SILHOUETTE = Color3.fromRGB(12, 12, 14)

-- Sagoma alta e sottile (circa 8 studs), leggermente piegata in avanti: niente volto, niente dettagli.
local function buildFigure(at: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Silhouette"

	local function piece(name: string, size: Vector3, cframe: CFrame)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = SILHOUETTE
		p.Transparency = 1
		p.Size = size
		p.CFrame = at * cframe
		p.Parent = model
	end

	piece("Legs", Vector3.new(1.4, 4.4, 0.8), CFrame.new(0, 2.2, 0))
	piece("Torso", Vector3.new(1.8, 4, 0.9), CFrame.new(0, 5.2, 0))
	piece("ArmL", Vector3.new(0.4, 4.8, 0.4), CFrame.new(-1.2, 4, 0))
	piece("ArmR", Vector3.new(0.4, 4.8, 0.4), CFrame.new(1.2, 4, 0))
	piece("Head", Vector3.new(1.1, 1.5, 1.0), CFrame.new(0, 7.6, 0.4) * CFrame.Angles(math.rad(-10), 0, 0))
	model.Parent = folder
	return model
end

local function clearFigure()
	if current then
		current:Destroy()
		current = nil
	end
end

-- Mostra la sagoma per "duration" secondi: fade-in, pausa, fade-out.
local function show(position: Vector3, duration: number, gen: number)
	if gen ~= generation then
		return
	end
	clearFigure()
	local model = buildFigure(CFrame.lookAt(position, Vector3.new(0, position.Y, 0)))
	current = model
	local fadeIn = TweenInfo.new(0.25, Enum.EasingStyle.Quad)
	local fadeOut = TweenInfo.new(0.3, Enum.EasingStyle.Quad)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			TweenService:Create(p, fadeIn, { Transparency = 0.1 }):Play()
		end
	end
	task.delay(duration, function()
		if current ~= model then
			return
		end
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				TweenService:Create(p, fadeOut, { Transparency = 1 }):Play()
			end
		end
		Debris:AddItem(model, 0.4)
		current = nil
	end)
end

-- Distanza minima tra la postazione e il giocatore piu' vicino, meno la distanza minima richiesta da quella postazione.
-- Valore >= 0 = postazione utilizzabile.
local function margins(spot: Spot): number
	local closest = math.huge
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			closest = math.min(closest, (root.Position - spot.position).Magnitude)
		end
	end
	return closest - spot.minDistance
end

-- Prepara il modulo con le postazioni del layout. Chiamalo una volta all'avvio.
function Apparition.init(layoutSpots: { Spot }, parent: Instance, random: Random)
	spots = layoutSpots
	folder = parent
	rng = random
end

-- Durante un blackout o un'interruzione: decide con probabilita' se mostrare la sagoma, in un momento casuale del buio.
function Apparition.duringDark(kind: string, duration: number)
	local chance = if kind == "blackout" then Config.Apparition.BlackoutChance else Config.Apparition.CutChance
	if rng:NextNumber() > chance then
		return
	end
	if not Rules.cooldownReady(lastShownAt, os.clock(), Config.Apparition.GlobalCooldown) then
		return
	end

	local distances = {}
	for index, spot in spots do
		distances[index] = margins(spot)
	end
	local index = Rules.pickSpot(rng, distances, 0)
	if not index then
		return
	end

	lastShownAt = os.clock()
	local at = Rules.randomBetween(rng, 0.35, 0.75) * duration
	local length = Rules.randomBetween(rng, 0.6, 1.1)
	local gen = generation
	task.delay(at, show, spots[index].position, length, gen)
end

-- Sagoma dietro il vetro con le luci accese: rarissima e molto breve, solo se nessuno e' vicino alla postazione.
function Apparition.glimpse()
	local index = nil
	for i, spot in spots do
		if spot.name == "glass" then
			index = i
		end
	end
	if not index then
		return
	end
	if margins(spots[index]) < 0 then
		return
	end
	lastShownAt = os.clock()
	show(spots[index].position, Rules.randomBetween(rng, 0.35, 0.5), generation)
end

-- Rimuove la sagoma e annulla quelle programmate: si chiama appena le luci tornano.
function Apparition.clear()
	generation += 1
	clearFigure()
end

return Apparition
