--!strict
--[[
	Matchmaking.lua — coda, gruppi (max Config.Match.MaxPlayers) e votazione di facility e difficolta'.
	Tutto nello stesso place: alla fine della votazione il gruppo viene passato a MatchService (Milestone 4).

	Flusso:  coda -> gruppo formato -> Voting -> Result -> Preparing
	- Gruppo formato quando la coda e' piena, oppure dopo QueueWaitSeconds con chi c'e' (anche 1 giocatore).
	- Votazione: ogni membro vota una facility e una difficolta'; il voto si puo' cambiare.
	  Finisce allo scadere o quando tutti hanno votato la facility. Pareggi e nessun voto: Rules.resolveVote.
	- Uscite/disconnessioni: il giocatore esce da coda e gruppo; un gruppo vuoto viene annullato.
	Il server e' l'unica fonte di verita': i client ricevono lo stato (MatchState) e mandano solo intenzioni validate.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("LIGHTS")
local Config = require(shared:WaitForChild("Config"))
local Rules = require(shared:WaitForChild("Rules"))
local Net = require(shared:WaitForChild("Net"))
local Maps = require(shared:WaitForChild("Maps"))

local Matchmaking = {}

type Group = {
	id: number,
	players: { Player },
	state: string, -- "Voting" | "Result" | "Preparing"
	mapVotes: { [Player]: string },
	difficultyVotes: { [Player]: string },
	endsAt: number,
	result: { map: string, difficulty: string }?,
}

local rng = Random.new()
local queue: { Player } = {}
local queueStartedAt: number? = nil
local groups: { [number]: Group } = {}
local groupOf: { [Player]: Group } = {}
local nextGroupId = 1
local lastRequest: { [Player]: number } = {}
local onGroupReady: ((Group) -> ())? = nil

local notice: RemoteEvent
local matchState: RemoteEvent

local MAP_IDS = {}
local MAP_BY_ID = {}
for _, map in Maps do
	table.insert(MAP_IDS, map.Id)
	MAP_BY_ID[map.Id] = map
end
local DIFFICULTY_IDS = {}
for _, difficulty in Config.Difficulties do
	table.insert(DIFFICULTY_IDS, difficulty.Id)
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function say(player: Player, text: string, inQueue: boolean?)
	notice:FireClient(player, text, inQueue)
end

-- Stato della coda pubblicato come attributi di Workspace (lo leggono i client e i monitor della lobby).
local function publishQueue()
	Workspace:SetAttribute("LightsQueueCount", #queue)
	Workspace:SetAttribute("LightsQueueDeadline", if queueStartedAt then queueStartedAt + Config.Match.QueueWaitSeconds else 0)
end

local function indexOf(list: { Player }, player: Player): number?
	for index, entry in list do
		if entry == player then
			return index
		end
	end
	return nil
end

local function leaveQueue(player: Player)
	local index = indexOf(queue, player)
	if index then
		table.remove(queue, index)
		if #queue == 0 then
			queueStartedAt = nil
		end
		publishQueue()
	end
end

-- Invia lo stato del gruppo a tutti i membri (voti in tempo reale, scadenza, risultato).
local function broadcast(group: Group)
	local payload = {
		state = group.state,
		endsAt = group.endsAt,
		size = #group.players,
		mapVotes = Rules.tally(group.mapVotes),
		difficultyVotes = Rules.tally(group.difficultyVotes),
		result = group.result,
	}
	for _, player in group.players do
		payload.myMap = group.mapVotes[player]
		payload.myDifficulty = group.difficultyVotes[player]
		matchState:FireClient(player, payload)
	end
end

local function disband(group: Group, message: string?)
	groups[group.id] = nil
	for _, player in group.players do
		groupOf[player] = nil
		matchState:FireClient(player, { state = "None" })
		if message then
			say(player, message, false)
		end
	end
end

local function allVoted(group: Group): boolean
	for _, player in group.players do
		if not group.mapVotes[player] then
			return false
		end
	end
	return true
end

-- Ciclo di vita di un gruppo: votazione, risultato, preparazione.
local function runGroup(group: Group)
	while groups[group.id] and now() < group.endsAt and not allVoted(group) do
		task.wait(0.25)
	end
	if not groups[group.id] then
		return -- annullato (tutti usciti)
	end

	group.result = {
		map = Rules.resolveVote(rng, group.mapVotes, MAP_IDS),
		difficulty = Rules.resolveVote(rng, group.difficultyVotes, DIFFICULTY_IDS, Config.DefaultDifficulty),
	}
	group.state = "Result"
	group.endsAt = now() + Config.Match.ResultSeconds
	broadcast(group)
	task.wait(Config.Match.ResultSeconds)
	if not groups[group.id] then
		return
	end

	local result = group.result :: { map: string, difficulty: string }
	local map = MAP_BY_ID[result.map]
	if not map.Built or not onGroupReady then
		-- Onesto: la facility non esiste ancora. Il gruppo torna in lobby invece di finire in una mappa vuota.
		disband(group, map.Name .. " non e' ancora costruita. Torni in lobby.")
		return
	end
	group.state = "Preparing"
	broadcast(group)
	;(onGroupReady :: (Group) -> ())(group)
end

local function formGroup(size: number)
	local members = {}
	for _ = 1, size do
		table.insert(members, table.remove(queue, 1))
	end
	queueStartedAt = if #queue > 0 then now() else nil
	publishQueue()

	local group: Group = {
		id = nextGroupId,
		players = members,
		state = "Voting",
		mapVotes = {},
		difficultyVotes = {},
		endsAt = now() + Config.Match.VoteSeconds,
		result = nil,
	}
	nextGroupId += 1
	groups[group.id] = group
	for _, player in members do
		groupOf[player] = group
		say(player, "Squadra trovata: votate la facility.", false)
	end
	broadcast(group)
	task.spawn(runGroup, group)
end

-- Uscita o disconnessione: fuori dalla coda e dal gruppo. Il gruppo vuoto viene annullato.
local function removePlayer(player: Player)
	leaveQueue(player)
	local group = groupOf[player]
	if group then
		groupOf[player] = nil
		local index = indexOf(group.players, player)
		if index then
			table.remove(group.players, index)
		end
		group.mapVotes[player] = nil
		group.difficultyVotes[player] = nil
		if #group.players == 0 then
			groups[group.id] = nil
		else
			broadcast(group)
		end
	end
	lastRequest[player] = nil
end

local function allowed(player: Player): boolean
	local t = os.clock()
	local last = lastRequest[player]
	if last and t - last < 0.25 then
		return false
	end
	lastRequest[player] = t
	return true
end

-- Chiamata da MatchService quando esiste: riceve il gruppo pronto per la partita.
function Matchmaking.setGroupReadyHandler(handler: (Group) -> ())
	onGroupReady = handler
end

function Matchmaking.run()
	while true do
		task.wait(0.5)
		local waited = if queueStartedAt then now() - queueStartedAt else 0
		local size = Rules.groupSize(#queue, waited, Config.Match.MaxPlayers, Config.Match.QueueWaitSeconds)
		if size > 0 then
			formGroup(size)
		end
	end
end

function Matchmaking.init()
	notice = Net.event("Notice")
	matchState = Net.event("MatchState")
	publishQueue()

	Net.event("QueueRequest").OnServerEvent:Connect(function(player: Player, wantQueue: any)
		if typeof(wantQueue) ~= "boolean" or not allowed(player) or groupOf[player] then
			return
		end
		if wantQueue then
			if not indexOf(queue, player) then
				table.insert(queue, player)
				queueStartedAt = queueStartedAt or now()
				publishQueue()
			end
			say(player, "In coda. Ricerca giocatori...", true)
		else
			leaveQueue(player)
			say(player, "Hai lasciato la coda.", false)
		end
	end)

	Net.event("Vote").OnServerEvent:Connect(function(player: Player, kind: any, value: any)
		local group = groupOf[player]
		if not group or group.state ~= "Voting" or not allowed(player) or typeof(value) ~= "string" then
			return
		end
		if kind == "map" and MAP_BY_ID[value] then
			group.mapVotes[player] = value
		elseif kind == "difficulty" and table.find(DIFFICULTY_IDS, value) then
			group.difficultyVotes[player] = value
		else
			return
		end
		broadcast(group)
	end)

	Players.PlayerRemoving:Connect(removePlayer)
end

return Matchmaking
