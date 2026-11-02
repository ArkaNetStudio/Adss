--!strict
--[[
	Main.server.lua — avvio del server di LIGHTS (lobby e, dalle prossime milestone, partite nello stesso place).
	Ordine: dati -> illuminazione -> lobby -> luci -> sagome -> eventi -> matchmaking.
	La lobby e' salvata nel place (Workspace.LIGHTS_Lobby); se manca viene costruita a runtime.
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

local rng = Random.new(LobbyBuilder.SEED)
Geometry.setupLighting()
-- La lobby salvata nel place (costruita in Studio con LobbyBuilder.bake) ha la precedenza:
-- a runtime la si costruisce solo se manca, cosi' le modifiche fatte a mano in Studio restano.
local saved = Workspace:FindFirstChild("LIGHTS_Lobby")
if not saved then
	warn("[LIGHTS] Workspace.LIGHTS_Lobby non trovato: lobby costruita a runtime. Esegui LobbyBuilder.bake() in Studio per vederla in Edit.")
end
local layout = LobbyBuilder.collect(saved or LobbyBuilder.build(rng))

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
