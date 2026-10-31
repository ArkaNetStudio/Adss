--!strict
--[[
	Main.server.lua — avvio della lobby LIGHTS (server).
	Ordine: illuminazione -> mappa -> luci -> sagome -> eventi -> impostazioni -> matchmaking.
	Il seed fisso rende la mappa e il ritmo delle luci uguali a ogni avvio del server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local shared = ReplicatedStorage:WaitForChild("LightsLobby")
local Config = require(shared:WaitForChild("Config"))

local Geometry = require(script.Parent:WaitForChild("Geometry"))
local Builder = require(script.Parent:WaitForChild("Builder"))
local Lights = require(script.Parent:WaitForChild("Lights"))
local Apparition = require(script.Parent:WaitForChild("Apparition"))
local Events = require(script.Parent:WaitForChild("Events"))
local PlayerSettings = require(script.Parent:WaitForChild("PlayerSettings"))
local Matchmaking = require(script.Parent:WaitForChild("Matchmaking"))

local rng = Random.new(20261031)

Geometry.setupLighting()
local layout = Builder.build(rng)

Lights.init(layout.lamps, rng)
Apparition.init(layout.spots, layout.folder, rng)
Events.init(layout.door, layout.monitors, layout.folder, rng)

-- Ronzio di fondo costante, non posizionato (si sente ovunque nella lobby).
if Config.Sounds.Ambience ~= "" then
	local ambience = Instance.new("Sound")
	ambience.SoundId = Config.Sounds.Ambience
	ambience.Looped = true
	ambience.Volume = 0.3
	ambience.SoundGroup = Lights.groups.Ambient
	ambience.Parent = SoundService
	ambience:Play()
end

PlayerSettings.init()
Matchmaking.init()

-- Ciclo luci: le sagome compaiono solo durante il buio e spariscono prima che le luci tornino.
task.spawn(Lights.run, function(kind: string, duration: number)
	Apparition.duringDark(kind, duration)
end, function()
	Apparition.clear()
end)
task.spawn(Events.run)
task.spawn(Matchmaking.run)
