--!strict
--[[
	PlayerSettings.lua — impostazioni audio e grafiche per giocatore, salvate nel DataStore.
	Il server valida ogni valore: il client non puo' impostare nulla di diverso dai tipi attesi.
	Se il DataStore non risponde (es. Studio senza API abilitate) si usano i valori di default, senza errori.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("LightsLobby")
local Config = require(shared:WaitForChild("Config"))
local Net = require(shared:WaitForChild("Net"))

local PlayerSettings = {}

local store = DataStoreService:GetDataStore("LightsSettings_v1")
local cache: { [number]: { [string]: any } } = {}

local function defaults(): { [string]: any }
	local copy = {}
	for key, value in Config.SettingsDefaults do
		copy[key] = value
	end
	return copy
end

-- Tiene solo le chiavi note con il tipo giusto. I volumi sono numeri interi 0..10.
local function sanitize(input: any): { [string]: any }
	local clean = defaults()
	if typeof(input) ~= "table" then
		return clean
	end
	for key, default in Config.SettingsDefaults do
		local value = input[key]
		if typeof(value) == typeof(default) then
			if typeof(default) == "number" then
				clean[key] = math.clamp(math.floor(value), 0, 10)
			else
				clean[key] = value
			end
		end
	end
	return clean
end

local function load(player: Player)
	local ok, saved = pcall(function()
		return store:GetAsync("user_" .. player.UserId)
	end)
	cache[player.UserId] = sanitize(if ok then saved else nil)
	if not ok then
		warn("[LIGHTS] Impostazioni non caricate per " .. player.Name .. ", uso i valori di default")
	end
end

function PlayerSettings.init()
	local getSettings = Net.func("GetSettings")
	local setSettings = Net.event("SetSettings")

	-- Il client chiede le impostazioni all'avvio: attende il caricamento (max 5 s), poi usa i default.
	getSettings.OnServerInvoke = function(player: Player)
		local waited = 0
		while not cache[player.UserId] and waited < 5 do
			task.wait(0.1)
			waited += 0.1
		end
		return cache[player.UserId] or defaults()
	end

	setSettings.OnServerEvent:Connect(function(player: Player, input: any)
		if cache[player.UserId] then
			cache[player.UserId] = sanitize(input)
		end
	end)

	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(load, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		local data = cache[player.UserId]
		cache[player.UserId] = nil
		if data then
			pcall(function()
				store:SetAsync("user_" .. player.UserId, data)
			end)
		end
	end)
end

return PlayerSettings
