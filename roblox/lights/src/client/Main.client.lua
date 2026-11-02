--!strict
--[[
	Main.client.lua — avvio del client di LIGHTS.
	Ordine: impostazioni (dal profilo) -> effetti delle luci -> filtro VHS -> menu -> votazione.
]]

local Settings = require(script.Parent.Settings)
local Effects = require(script.Parent.Effects)
local VHS = require(script.Parent.VHS)
local Menu = require(script.Parent.Menu)
local Voting = require(script.Parent.Voting)

Settings.load()
Effects.start()
VHS.start()
Menu.start()
Voting.start()
