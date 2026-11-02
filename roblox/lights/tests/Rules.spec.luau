--!strict
--[[
	Self-check della logica pura (Rules.lua).
	Esecuzione: lune run tests/Rules.spec.luau  (dalla cartella lights-lobby)
	Nessun output di errore = tutti i test passano; un fallimento lancia un errore con il nome del caso.
	Il generatore finto ha lo stesso metodo NextNumber di Random di Roblox.
]]

local Rules = require("../src/shared/Rules")

local function check(name: string, condition: boolean)
	if not condition then
		error("FAIL: " .. name, 2)
	end
end

-- Generatore che restituisce sempre lo stesso valore.
local function fixed(value: number)
	return {
		NextNumber = function(_self: any): number
			return value
		end,
	}
end

-- cooldown
check("cooldown libero se mai usato", Rules.cooldownReady(nil, 10, 60) == true)
check("cooldown bloccato prima del tempo", Rules.cooldownReady(100, 130, 60) == false)
check("cooldown sbloccato dopo il tempo", Rules.cooldownReady(100, 160, 60) == true)

-- scelta pesata: rng=0 sceglie la prima voce con peso; rng alto sceglie l'ultima; peso 0 non viene mai scelto
local entries = { { name = "a", weight = 1 }, { name = "b", weight = 0 }, { name = "c", weight = 3 } }
check("pesata: rng=0 sceglie la prima", Rules.pickWeighted(fixed(0), entries) == "a")
check("pesata: rng alto sceglie c", Rules.pickWeighted(fixed(0.99), entries) == "c")
check("pesata: peso zero mai scelto", Rules.pickWeighted(fixed(0.5), { { name = "x", weight = 0 } }) == nil)

-- intervalli
check("random tra min e max", Rules.randomBetween(fixed(0.5), 4, 8) == 6)
check("ritardo riaccensione dentro lo spread", Rules.restoreDelay(fixed(1), 1.1) <= 1.1)

-- gruppi (max 4, attesa 25 s)
check("coda vuota = nessun gruppo", Rules.groupSize(0, 100, 4, 25) == 0)
check("coda piena = gruppo pieno subito", Rules.groupSize(6, 0, 4, 25) == 4)
check("due giocatori, poco tempo = attesa", Rules.groupSize(2, 5, 4, 25) == 0)
check("timeout = parte chi c'e'", Rules.groupSize(2, 25, 4, 25) == 2)
check("timeout = anche da solo", Rules.groupSize(1, 30, 4, 25) == 1)

-- votazione
local maps = { "A", "B", "C" }
check("vince il piu' votato", Rules.resolveVote(fixed(0.9), { p1 = "B", p2 = "B", p3 = "A" }, maps) == "B")
check("pareggio: estrazione tra i pari (rng 0 -> primo)", Rules.resolveVote(fixed(0), { p1 = "C", p2 = "A" }, maps) == "A")
check("pareggio: estrazione tra i pari (rng alto -> ultimo)", Rules.resolveVote(fixed(0.99), { p1 = "C", p2 = "A" }, maps) == "C")
check("nessun voto: fallback", Rules.resolveVote(fixed(0.99), {}, maps, "B") == "B")
check("nessun voto, senza fallback: estrazione", Rules.resolveVote(fixed(0.99), {}, maps) == "C")
check("voti non validi ignorati", Rules.resolveVote(fixed(0), { p1 = "X", p2 = "X", p3 = "C" }, maps) == "C")
local counts = Rules.tally({ p1 = "A", p2 = "A", p3 = "B" })
check("conteggio voti", counts.A == 2 and counts.B == 1 and counts.C == nil)

-- durata round
check("esplorazione normale = 300", Rules.explorationSeconds(300, 1) == 300)
check("esplorazione incubo = 210", Rules.explorationSeconds(300, 0.7) == 210)

-- postazioni della sagoma: distances e' il margine (distanza - distanza minima richiesta), soglia 0
check("nessuna postazione utilizzabile = nil", Rules.pickSpot(fixed(0), { -5, -10 }, 0) == nil)
check("sceglie solo postazioni utilizzabili", Rules.pickSpot(fixed(0), { -5, 40, 50 }, 0) == 2)

print("Rules.spec: tutti i test passano")
