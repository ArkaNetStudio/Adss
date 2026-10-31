--!strict
--[[
	Matchmaking.lua — coda per GIOCA e partite private, dalla lobby al luogo della partita (Config.Match.PlaceId).
	- GIOCA: il giocatore entra in coda. Quando ci sono abbastanza giocatori (o dopo un'attesa massima)
	  parte un conto alla rovescia e tutti vengono teletrasportati insieme.
	- PARTITA PRIVATA: il server riserva un server privato e vi porta solo chi l'ha chiesto.
	Senza PlaceId configurato non si teletrasporta nessuno: il giocatore riceve un avviso.
]]

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("LightsLobby")
local Config = require(shared:WaitForChild("Config"))
local Rules = require(shared:WaitForChild("Rules"))
local Net = require(shared:WaitForChild("Net"))

local Matchmaking = {}

local queue: { Player } = {}
local queued: { [Player]: boolean } = {}
local queueStartedAt: number? = nil
local countdownActive = false
local lastRequest: { [Player]: number } = {}
local notice: RemoteEvent
local queueRequest: RemoteEvent
local privateRequest: RemoteEvent

-- Il numero in coda e' un attributo di Workspace: il client lo legge e lo mostra senza altri remote.
local function publishCount()
	Workspace:SetAttribute("LightsQueueCount", #queue)
end

-- Avviso al giocatore. inQueue (opzionale) dice al client se e' in coda, cosi' il pulsante resta coerente.
local function say(player: Player, text: string, inQueue: boolean?)
	notice:FireClient(player, text, inQueue)
end

local function leaveQueue(player: Player)
	if not queued[player] then
		return
	end
	queued[player] = nil
	for index, entry in queue do
		if entry == player then
			table.remove(queue, index)
			break
		end
	end
	if #queue == 0 then
		queueStartedAt = nil
	end
	publishCount()
end

-- Conto alla rovescia, poi teletrasporto a gruppi di massimo Config.Match.MaxTeleportBatch.
local function launch()
	for seconds = Config.Match.CountdownSeconds, 1, -1 do
		if #queue == 0 then
			countdownActive = false
			return
		end
		for _, player in queue do
			say(player, "Partita tra " .. seconds .. " s")
		end
		task.wait(1)
	end

	local players = {}
	for _, player in queue do
		if player.Parent == Players then
			table.insert(players, player)
		end
	end
	queue = {}
	queued = {}
	queueStartedAt = nil
	publishCount()
	countdownActive = false

	local batch = Config.Match.MaxTeleportBatch
	for first = 1, #players, batch do
		local last = math.min(first + batch - 1, #players)
		local group = table.move(players, first, last, 1, {})
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(Config.Match.PlaceId, group)
		end)
		if not ok then
			warn("[LIGHTS] Teletrasporto fallito: " .. tostring(err))
			for _, player in group do
				say(player, "Teletrasporto non riuscito. Riprova tra poco.")
			end
		end
	end
end

-- Decide ogni secondo se far partire il conto alla rovescia.
function Matchmaking.run()
	while true do
		task.wait(1)
		local waited = if queueStartedAt then os.clock() - queueStartedAt else 0
		local decision = Rules.queueDecision(#queue, waited, Config.Match.MinPlayersToStart, Config.Match.QueueWaitSeconds)
		if decision == "countdown" and not countdownActive then
			countdownActive = true
			task.spawn(launch)
		end
	end
end

-- Limite di frequenza: evita spam di richieste dal client.
local function allowed(player: Player): boolean
	local now = os.clock()
	local last = lastRequest[player]
	if last and now - last < 0.5 then
		return false
	end
	lastRequest[player] = now
	return true
end

function Matchmaking.init()
	notice = Net.event("Notice")
	queueRequest = Net.event("QueueRequest")
	privateRequest = Net.event("PrivateRequest")

	queueRequest.OnServerEvent:Connect(function(player: Player, wantQueue: any)
		if typeof(wantQueue) ~= "boolean" or not allowed(player) then
			return
		end
		if Config.Match.PlaceId == 0 then
			say(player, "Le partite non sono ancora collegate.", false)
			return
		end
		if wantQueue then
			if not queued[player] then
				queued[player] = true
				table.insert(queue, player)
				queueStartedAt = queueStartedAt or os.clock()
				publishCount()
			end
			say(player, "Sei in coda.", true)
		else
			leaveQueue(player)
			say(player, "Hai lasciato la coda.", false)
		end
	end)

	privateRequest.OnServerEvent:Connect(function(player: Player)
		if not allowed(player) then
			return
		end
		if Config.Match.PlaceId == 0 then
			say(player, "Le partite non sono ancora collegate.")
			return
		end
		leaveQueue(player)
		-- ReserveServer restituisce il codice di accesso; il server privato accoglie solo questo giocatore.
		local ok, accessCode = pcall(function()
			return TeleportService:ReserveServer(Config.Match.PlaceId)
		end)
		if not ok then
			warn("[LIGHTS] ReserveServer fallito: " .. tostring(accessCode))
			say(player, "Impossibile creare la partita privata.")
			return
		end
		local teleported, err = pcall(function()
			TeleportService:TeleportToPrivateServer(Config.Match.PlaceId, accessCode, { player })
		end)
		if not teleported then
			warn("[LIGHTS] Teletrasporto privato fallito: " .. tostring(err))
			say(player, "Teletrasporto non riuscito. Riprova tra poco.")
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		leaveQueue(player)
		lastRequest[player] = nil
	end)
end

return Matchmaking
