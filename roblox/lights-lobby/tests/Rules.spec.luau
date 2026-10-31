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

-- coda
check("coda vuota = idle", Rules.queueDecision(0, 0, 2, 40) == "idle")
check("un giocatore, poco tempo = attesa", Rules.queueDecision(1, 5, 2, 40) == "wait")
check("abbastanza giocatori = countdown", Rules.queueDecision(2, 0, 2, 40) == "countdown")
check("timeout con un giocatore = countdown", Rules.queueDecision(1, 40, 2, 40) == "countdown")

-- postazioni della sagoma: distances e' il margine (distanza - distanza minima richiesta), soglia 0
check("nessuna postazione utilizzabile = nil", Rules.pickSpot(fixed(0), { -5, -10 }, 0) == nil)
check("sceglie solo postazioni utilizzabili", Rules.pickSpot(fixed(0), { -5, 40, 50 }, 0) == 2)

print("Rules.spec: tutti i test passano")
