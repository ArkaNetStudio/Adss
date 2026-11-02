--!strict
--[[
	Main.server.lua — avvio del server di LIGHTS (lobby e, dalle prossime milestone, partite nello stesso place).
	Ordine: dati -> illuminazione -> lobby -> luci -> sagome -> eventi -> matchmaking.
	Il seed fisso rende la lobby uguale a ogni avvio del server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("LIGHTS")
local Config = require(shared:WaitForChild("Config"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local Geometry = require(script.Parent:WaitForChild("Geometry"))
local LobbyBuilder = require(script.Parent:WaitForChild("LobbyBuilder"))
local Lights = require(script.Parent:WaitForChild("Lights"))
local Apparition = require(script.Parent:WaitForChild("Apparition"))
local Events = require(script.Parent:WaitForChild("Events"))
local Matchmaking = require(script.Parent:WaitForChild("Matchmaking"))

DataService.init()

local rng = Random.new(20261102)
Geometry.setupLighting()
local layout = LobbyBuilder.build(rng)

Lights.init(layout.lamps, rng)
Apparition.init(layout.spots, layout.folder, rng)
Events.init(layout.door, layout.monitors, layout.shadowPaths, layout.folder, rng)

if Config.Sounds.Ambience ~= "" then
	local ambience = Instance.new("Sound")
	ambience.SoundId = Config.Sounds.Ambience
	ambience.Looped = true
	ambience.Volume = 0.3
	ambience.SoundGroup = Lights.groups.Ambient
	ambience.Parent = SoundService
	ambience:Play()
end

Matchmaking.init()

-- I monitor della baia mostrano lo stato della coda (diegetico: lo stesso dato dell'interfaccia).
local function refreshDeployScreens()
	local count = Workspace:GetAttribute("LightsQueueCount") or 0
	for index, screen in layout.deployScreens do
		screen.Text = string.format("BAIA %d\nRICERCA SQUADRA\nIN CODA %d/%d", index, count, Config.Match.MaxPlayers)
	end
end
Workspace:GetAttributeChangedSignal("LightsQueueCount"):Connect(refreshDeployScreens)
refreshDeployScreens()

task.spawn(Lights.run, function(kind: string, duration: number)
	Apparition.duringDark(kind, duration)
end, function()
	Apparition.clear()
end)
task.spawn(Events.run)
task.spawn(Matchmaking.run)
