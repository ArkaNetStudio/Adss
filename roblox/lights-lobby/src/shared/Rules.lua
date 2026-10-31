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

-- Decide cosa fare della coda: "idle" (vuota), "wait", "countdown".
function Rules.queueDecision(count: number, waited: number, minPlayers: number, maxWait: number): string
	if count <= 0 then
		return "idle"
	end
	if count >= minPlayers or waited >= maxWait then
		return "countdown"
	end
	return "wait"
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
