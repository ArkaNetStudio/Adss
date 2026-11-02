--!strict
--[[
	Config.lua — valori regolabili di LIGHTS (ReplicatedStorage/LIGHTS/Config).
	Letto da server e client. Il client lo usa solo per mostrare valori: le decisioni restano al server.
]]

local Config = {}

-- ============================================================
-- MATCHMAKING E VOTAZIONE (un solo place: lobby e mappe sono nella stessa mappa)
-- ============================================================
Config.Match = {
	MaxPlayers = 4, -- giocatori per gruppo
	QueueWaitSeconds = 25, -- dopo questo tempo il gruppo parte anche incompleto (anche da solo)
	VoteSeconds = 20, -- durata della votazione (finisce prima se tutti hanno votato)
	ResultSeconds = 5, -- quanto resta visibile il risultato prima della preparazione
}

-- Difficolta': scala il tempo di esplorazione e l'aggressivita' dell'entita'.
-- timeScale > 1 = piu' tempo. aggression > 1 = entita' piu' veloce, piu' attenta, cooldown piu' brevi.
Config.Difficulties = {
	{ Id = "Easy", Name = "FACILE", TimeScale = 1.3, Aggression = 0.7 },
	{ Id = "Normal", Name = "NORMALE", TimeScale = 1.0, Aggression = 1.0 },
	{ Id = "Hard", Name = "DIFFICILE", TimeScale = 0.85, Aggression = 1.3 },
	{ Id = "Nightmare", Name = "INCUBO", TimeScale = 0.7, Aggression = 1.65 },
}
Config.DefaultDifficulty = "Normal" -- usata se nessuno vota la difficolta'

-- ============================================================
-- ROUND (usati dalla Milestone 4)
-- ============================================================
Config.Round = {
	ExplorationSeconds = 300, -- 5 minuti, poi scalati dalla difficolta'
	ExtractionSeconds = 90, -- indipendente dal timer principale
}

-- ============================================================
-- NOVITA' (pannello e tabellone nel mondo)
-- ============================================================
Config.News = {
	{ Title = "Rework 0.2", Body = "Nuova lobby, coda a gruppi da 4 e votazione delle facility." },
	{ Title = "Difficolta'", Body = "Votate anche la difficolta': cambia il tempo e la ferocia dell'entita'." },
	{ Title = "Avviso", Body = "Le luci del settore C sono instabili. Non restate al buio." },
}

-- ============================================================
-- AUDIO — ID dal Creator Store. "" = suono saltato, nessun errore.
-- ============================================================
Config.Sounds = {
	Ambience = "", -- tono di fondo del capannone (loop)
	Buzz = "", -- ronzio neon (loop, 3D)
	PowerDown = "",
	PowerUp = "",
	Crackle = "",
	Door = "",
	Static = "",
	Alarm = "", -- annuncio di partita pronta
	UiHover = "",
	UiClick = "",
}

-- Texture opzionale di grana VHS (Decal caricato). "" = grana disattivata, il resto del VHS funziona.
Config.VHS = {
	NoiseImage = "",
	BaseIntensity = 0.35, -- intensita' in lobby (0..1). Gli eventi la alzano temporaneamente.
}

-- ============================================================
-- LUCI E BLACKOUT DELLA LOBBY (secondi)
-- ============================================================
Config.Lights = {
	FlickerIntervalMin = 4,
	FlickerIntervalMax = 16,
	UnstableChance = 0.25,
	CutIntervalMin = 9,
	CutIntervalMax = 15,
	BriefCutChance = 0.35,
	BlackoutMinGap = 480,
	BlackoutMaxGap = 780,
	BlackoutDurationMin = 5,
	BlackoutDurationMax = 8,
	RestoreSpread = 1.1,
	TriggerLampOffTime = 2.5,
}

Config.Apparition = {
	BlackoutChance = 0.55,
	CutChance = 0.12,
	GlobalCooldown = 150,
	MinPlayerDistance = 40,
}

Config.Events = {
	TickMin = 20,
	TickMax = 40,
	GlobalCooldown = 14,
	DoorCooldown = 150,
	ShadowCooldown = 60,
	MonitorCooldown = 45,
	GlimpseCooldown = 420,
	GlimpseChance = 0.04,
}

-- ============================================================
-- IMPOSTAZIONI DI DEFAULT (salvate nel profilo ProfileStore)
-- ============================================================
Config.SettingsDefaults = {
	Shadows = true,
	Bloom = true,
	Fog = true,
	ReduceFlicker = false, -- riduce lampeggi e glitch del client
	VHS = true, -- filtro VHS a schermo
	MusicVolume = 8,
	EffectsVolume = 8,
}

return Config
