--!strict
--[[
	Main.client.lua — avvio del client della lobby LIGHTS.
	Ordine: impostazioni (caricate dal server) -> effetti sincronizzati con le luci -> interfaccia.
]]

local Settings = require(script.Parent.Settings)
local Effects = require(script.Parent.Effects)
local Menu = require(script.Parent.Menu)

Settings.load()
Effects.start()
Menu.start()
