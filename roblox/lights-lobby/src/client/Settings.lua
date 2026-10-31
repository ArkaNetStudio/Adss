--!strict
--[[
	Settings.lua — impostazioni del giocatore (client). Carica i valori dal server, li applica
	a illuminazione e volume, e li rimanda al server quando cambiano.
	Le ombre, il bagliore e la nebbia sono locali: non cambiano la lobby degli altri giocatori.
]]

local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("LightsLobby")
local Config = require(shared:WaitForChild("Config"))
local Net = require(shared:WaitForChild("Net"))

local Settings = {}

Settings.values = {} :: { [string]: any }
local listeners: { () -> () } = {}
local baseDensity: number? = nil

-- Applica i valori correnti a Lighting e ai gruppi audio.
function Settings.apply()
	local values = Settings.values
	if next(values) == nil then
		return
	end
	Lighting.GlobalShadows = values.Shadows

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Enabled = values.Bloom
	end

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		baseDensity = baseDensity or atmosphere.Density
		atmosphere.Density = if values.Fog then baseDensity else 0
	end

	local ambient = SoundService:FindFirstChild("LightsAmbient") :: SoundGroup?
	if ambient then
		ambient.Volume = values.MusicVolume / 10
	end
	local effects = SoundService:FindFirstChild("LightsEffects") :: SoundGroup?
	if effects then
		effects.Volume = values.EffectsVolume / 10
	end

	for _, listener in listeners do
		listener()
	end
end

-- Cambia una impostazione, la applica subito e la salva sul server.
function Settings.set(key: string, value: any)
	Settings.values[key] = value
	Settings.apply()
	Net.event("SetSettings"):FireServer(Settings.values)
end

-- Chiamato quando cambiano le impostazioni (es. il menu aggiorna i pulsanti).
function Settings.onChanged(listener: () -> ())
	table.insert(listeners, listener)
end

-- Carica le impostazioni salvate. Il server risponde subito con i default se non ha dati.
function Settings.load()
	local remote = Net.func("GetSettings")
	local ok, values = pcall(function()
		return remote:InvokeServer()
	end)
	Settings.values = if ok and typeof(values) == "table" then values else table.clone(Config.SettingsDefaults)
	Settings.apply()
end

return Settings
