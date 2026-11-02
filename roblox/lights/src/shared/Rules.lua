--!strict
--[[
	Rules.lua — logica pura (nessun tipo Roblox), quindi testabile fuori da Studio.
	Usata da Lights, Events, Apparition e Matchmaking. Vedi tests/Rules.spec.luau.
]]

local Rules = {}

-- Vero se e' passato abbastanza tempo dall'ultima volta (o se non e' mai successo).
function Rules.cooldownReady(lastAt: number?, now: number, cooldown: number): boolean
	return lastAt == nil or now - lastAt >= cooldown
end

-- rng e' un Random di Roblox oppure qualsiasi oggetto con un metodo NextNumber (per i test).
-- Sceglie una voce con probabilita' proporzionale al peso. Restituisce nil se tutti i pesi sono 0.
function Rules.pickWeighted(rng: { NextNumber: (any) -> number }, entries: { { name: string, weight: number } }): string?
	local total = 0
	for _, entry in entries do
		total += math.max(entry.weight, 0)
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for _, entry in entries do
		roll -= math.max(entry.weight, 0)
		if roll <= 0 and entry.weight > 0 then
			return entry.name
		end
	end
	return nil
end

-- Attesa casuale tra min e max.
function Rules.randomBetween(rng: { NextNumber: (any) -> number }, min: number, max: number): number
	return min + (max - min) * rng:NextNumber()
end

-- Ritardo di riaccensione di una singola lampada, in [0, spread].
function Rules.restoreDelay(rng: { NextNumber: (any) -> number }, spread: number): number
	return rng:NextNumber() * spread
end

-- Quanti giocatori prendere dalla coda per formare un gruppo (0 = aspetta).
-- Coda piena (>= maxPlayers) -> gruppo pieno subito; altrimenti, dopo maxWait secondi, parte chi c'e' (anche 1).
function Rules.groupSize(queued: number, waited: number, maxPlayers: number, maxWait: number): number
	if queued >= maxPlayers then
		return maxPlayers
	end
	if queued > 0 and waited >= maxWait then
		return queued
	end
	return 0
end

-- Risultato di una votazione. votes: voto di ciascun giocatore (valori fuori da options ignorati).
-- Vince il piu' votato; pareggio = estrazione tra i pari; nessun voto = fallback se valido, altrimenti estrazione tra tutte.
function Rules.resolveVote(rng: { NextNumber: (any) -> number }, votes: { [any]: string }, options: { string }, fallback: string?): string
	local counts: { [string]: number } = {}
	for _, option in options do
		counts[option] = 0
	end
	local any = false
	for _, choice in votes do
		if counts[choice] ~= nil then
			counts[choice] += 1
			any = true
		end
	end
	local pool = {}
	if any then
		local best = 0
		for _, option in options do
			best = math.max(best, counts[option])
		end
		for _, option in options do
			if counts[option] == best then
				table.insert(pool, option)
			end
		end
	elseif fallback and counts[fallback] ~= nil then
		return fallback
	else
		pool = table.clone(options)
	end
	local pick = math.floor(rng:NextNumber() * #pool) + 1
	return pool[math.min(pick, #pool)]
end

-- Conta i voti per opzione (per mostrarli in tempo reale).
function Rules.tally(votes: { [any]: string }): { [string]: number }
	local counts = {}
	for _, choice in votes do
		counts[choice] = (counts[choice] or 0) + 1
	end
	return counts
end

-- Durata dell'esplorazione scalata dalla difficolta' (secondi interi). L'estrazione resta fissa.
function Rules.explorationSeconds(base: number, timeScale: number): number
	return math.floor(base * timeScale + 0.5)
end

-- Sceglie a caso una postazione per la sagoma. distances[i] = distanza minima dei giocatori dalla postazione i.
-- Restituisce l'indice scelto, oppure nil se nessuna postazione e' abbastanza lontana.
function Rules.pickSpot(rng: { NextNumber: (any) -> number }, distances: { number }, minDistance: number): number?
	local valid = {}
	for index, distance in distances do
		if distance >= minDistance then
			table.insert(valid, index)
		end
	end
	if #valid == 0 then
		return nil
	end
	local pick = math.floor(rng:NextNumber() * #valid) + 1
	return valid[math.min(pick, #valid)]
end

return Rules
