--!strict
--[[
	Config.lua — tutti i valori regolabili della lobby LIGHTS.
	Modulo condiviso (ReplicatedStorage/LightsLobby/Config).
	Modifica qui: non serve toccare gli script.
]]

local Config = {}

-- ============================================================
-- PARTITA / MATCHMAKING
-- ============================================================
Config.Match = {
	-- ID del luogo (place) della partita vera. 0 = non ancora collegato:
	-- i pulsanti GIOCA e PARTITA PRIVATA mostrano un avviso invece di teletrasportare.
	PlaceId = 0,
	MinPlayersToStart = 2, -- con questo numero in coda il conto alla rovescia parte subito
	QueueWaitSeconds = 40, -- dopo questo tempo una partita parte anche con 1 solo giocatore
	CountdownSeconds = 8,
	MaxTeleportBatch = 50, -- limite di Roblox per una singola chiamata TeleportAsync
}

-- ============================================================
-- AGGIORNAMENTI (pannello news e tabellone nel mondo)
-- ============================================================
Config.News = {
	{ Title = "Benvenuto in LIGHTS", Body = "Le luci sono instabili. Non fidarti del buio." },
	{ Title = "Nuova area", Body = "Il corridoio ovest e' stato riaperto. Qualcosa e' rimasto li' dentro." },
	{ Title = "Avviso", Body = "Se vedi una sagoma dietro un vetro, non avvicinarti." },
}

-- ============================================================
-- AUDIO
-- Inserisci qui gli ID audio presi dal Creator Store (Toolbox > Audio).
-- Lasciando "" il suono viene semplicemente saltato: nessun errore.
-- Ricerche consigliate: "fluorescent hum", "electric buzz loop", "power down",
-- "power up", "metal scrape distant", "tv static", "door creak slow", "electric crackle".
-- ============================================================
Config.Sounds = {
	Ambience = "", -- rumore di fondo costante (loop)
	Buzz = "", -- ronzio di una lampada (loop, 3D)
	PowerDown = "", -- spegnimento corrente
	PowerUp = "", -- riaccensione
	Crackle = "", -- fruscio elettrico durante i blackout
	Metal = "", -- rumore metallico lontano
	Door = "", -- cigolio della porta che si chiude
	Static = "", -- disturbo del monitor
}

-- ============================================================
-- LUCI E BLACKOUT (tempi in secondi)
-- ============================================================
Config.Lights = {
	FlickerIntervalMin = 4, -- intervallo tra un lampeggio e il successivo di una lampada
	FlickerIntervalMax = 16,
	UnstableChance = 0.25, -- quota di lampade "malate" che lampeggiano piu' spesso
	CutIntervalMin = 9, -- intervallo tra un evento luci e il successivo
	CutIntervalMax = 15,
	BriefCutChance = 0.35, -- probabilita' di una breve interruzione (0.4-1.2 s)
	BlackoutMinGap = 480, -- un blackout generale non arriva prima di 8 minuti...
	BlackoutMaxGap = 780, -- ...e non dopo 13 minuti
	BlackoutDurationMin = 5,
	BlackoutDurationMax = 8,
	RestoreSpread = 1.1, -- ritardo massimo con cui le lampade si riaccendono
	TriggerLampOffTime = 2.5, -- quanto resta spenta la lampada quando un giocatore ci passa sotto
}

-- ============================================================
-- APPARIZIONI (sagome)
-- ============================================================
Config.Apparition = {
	BlackoutChance = 0.55, -- chance che un blackout generale mostri una sagoma
	CutChance = 0.12, -- chance durante una breve interruzione
	GlobalCooldown = 150, -- secondi minimi tra due apparizioni
	MinPlayerDistance = 40, -- la sagoma compare solo se nessun giocatore e' a meno di questa distanza
}

-- ============================================================
-- EVENTI CASUALI (tempi in secondi)
-- ============================================================
Config.Events = {
	TickMin = 20,
	TickMax = 40,
	GlobalCooldown = 14, -- nessun evento casuale piu' frequente di cosi'
	DoorCooldown = 150,
	ShadowCooldown = 60,
	MonitorCooldown = 45,
	GlimpseCooldown = 420, -- la sagoma dietro il vetro e' la piu' rara
	GlimpseChance = 0.04, -- chance per tick di tentare la sagoma dietro il vetro
}

-- ============================================================
-- IMPOSTAZIONI DI DEFAULT (salvate per giocatore nel DataStore)
-- ============================================================
Config.SettingsDefaults = {
	Shadows = true, -- ombre globali
	Bloom = true, -- bagliore delle luci
	Fog = true, -- nebbia volumetrica
	ReduceFlicker = false, -- riduce i lampeggi degli effetti del client (logo, monitor)
	MusicVolume = 8, -- 0..10
	EffectsVolume = 8, -- 0..10
}

return Config
