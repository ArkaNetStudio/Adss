--!strict
--[[
	DataService.lua — profilo persistente di ogni giocatore con ProfileStore (session lock, salvataggi periodici,
	protezione da duplicazioni tra server). Unico punto di accesso ai dati salvati.
	Oggi: impostazioni. Lo schema contiene gia' economia e statistiche per le milestone 10-12,
	cosi' i profili non andranno migrati.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("LIGHTS")
local Config = require(shared:WaitForChild("Config"))
local Net = require(shared:WaitForChild("Net"))
local ProfileStore = require(script.Parent.Packages.ProfileStore)

local DataService = {}

local TEMPLATE = {
	Version = 1,
	Coins = 0,
	XP = 0,
	Level = 1,
	Wins = 0,
	Score = 0,
	Stats = { Matches = 0, Escapes = 0, Deaths = 0, Objectives = 0 },
	Inventory = {}, -- [itemId] = true
	Equipped = {},
	Achievements = {},
	Receipts = {}, -- PurchaseId gia' accreditati (anti-duplicazione Developer Products)
	Settings = table.clone(Config.SettingsDefaults),
}

local store = ProfileStore.New("LIGHTS_Player_v1", TEMPLATE)
local profiles: { [Player]: any } = {}

-- Tiene solo le impostazioni note con il tipo giusto; i volumi sono interi 0..10.
local function sanitizeSettings(input: any): { [string]: any }
	local clean = table.clone(Config.SettingsDefaults)
	if typeof(input) ~= "table" then
		return clean
	end
	for key, default in Config.SettingsDefaults do
		local value = input[key]
		if typeof(value) == typeof(default) then
			clean[key] = if typeof(default) == "number" then math.clamp(math.floor(value), 0, 10) else value
		end
	end
	return clean
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync("user_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		-- Sessione non ottenibile (DataStore in errore o giocatore uscito): meglio rientrare che giocare senza salvataggi.
		player:Kick("Impossibile caricare i tuoi dati. Riprova tra poco.")
		return
	end
	profile:AddUserId(player.UserId) -- GDPR
	profile:Reconcile()
	profile.Data.Settings = sanitizeSettings(profile.Data.Settings)
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Sessione dati chiusa da un altro server. Rientra nel gioco.")
	end)
	if player.Parent == Players then
		profiles[player] = profile
	else
		profile:EndSession()
	end
end

-- Profilo attivo del giocatore (nil finche' non e' caricato).
function DataService.get(player: Player): any?
	return profiles[player]
end

-- Attende il profilo fino a timeout secondi.
function DataService.wait(player: Player, timeout: number): any?
	local waited = 0
	while not profiles[player] and waited < timeout and player.Parent == Players do
		task.wait(0.1)
		waited += 0.1
	end
	return profiles[player]
end

function DataService.init()
	Net.func("GetSettings").OnServerInvoke = function(player: Player)
		local profile = DataService.wait(player, 10)
		return if profile then profile.Data.Settings else table.clone(Config.SettingsDefaults)
	end
	Net.event("SetSettings").OnServerEvent:Connect(function(player: Player, input: any)
		local profile = profiles[player]
		if profile then
			profile.Data.Settings = sanitizeSettings(input)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		local profile = profiles[player]
		profiles[player] = nil
		if profile then
			profile:EndSession()
		end
	end)
end

return DataService
