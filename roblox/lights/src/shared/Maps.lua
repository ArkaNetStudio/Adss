--!strict
--[[
	Maps.lua — catalogo delle facility votabili. Aggiungere una mappa = aggiungere una voce qui
	+ il suo modulo di costruzione (Milestone 5 e 8).
	Built = false: la mappa compare nella votazione ma, se vince, il gruppo viene avvisato e torna in lobby.
]]

export type MapInfo = {
	Id: string,
	Name: string,
	Description: string,
	BaseDifficulty: string,
	Players: string,
	Entity: string,
	EntityHint: string,
	Built: boolean,
}

local Maps: { MapInfo } = {
	{
		Id = "ResearchFacility",
		Name = "THE RESEARCH FACILITY",
		Description = "Laboratorio sotterraneo evacuato in fretta. Le celle di contenimento sono aperte.",
		BaseDifficulty = "Media",
		Players = "1-4",
		Entity = "Soggetto 07",
		EntityHint = "Osserva da lontano. Si avvicina solo quando nessuno lo guarda.",
		Built = false,
	},
	{
		Id = "PowerStation",
		Name = "THE POWER STATION",
		Description = "Centrale elettrica fuori servizio. I generatori si riaccendono da soli.",
		BaseDifficulty = "Alta",
		Players = "1-4",
		Entity = "Il Guasto",
		EntityHint = "Vive nei blackout. Quando la corrente torna, sparisce.",
		Built = false,
	},
	{
		Id = "Hospital",
		Name = "THE HOSPITAL",
		Description = "Reparto chiuso dal 1998. L'obitorio e' l'unica stanza ancora illuminata.",
		BaseDifficulty = "Media",
		Players = "1-4",
		Entity = "L'Infermiera",
		EntityHint = "Segue il rumore dei passi. Camminare e' piu' sicuro che correre.",
		Built = false,
	},
	{
		Id = "Bunker",
		Name = "THE BUNKER",
		Description = "Bunker militare sigillato. Le porte blindate rispondono ancora al sistema di sicurezza.",
		BaseDifficulty = "Molto alta",
		Players = "1-4",
		Entity = "Sentinella",
		EntityHint = "Pattuglia i tunnel. Ti caccia se resti sotto le luci rosse.",
		Built = false,
	},
}

return Maps
