---
tags: [lights, stato]
data: 2026-11-02
---
# Stato implementazione

Codice: `roblox/lights/` (Rojo). Verifiche eseguite: parser Luau su tutti i file, `lune run tests/Rules.spec.luau` verde.
**Mai eseguito in Roblox Studio** — nessun sistema qui sotto e' da considerare completato finche' non passa il test di [[02 Roadmap milestone]].

## Milestone 2 — Lobby (scritta)
- Hangar 120x90, soffitto 34: pilastri con fascia rossa, finestre a nastro con luce fredda, capriate, tubature, macchie e pozzanghere riflettenti.
- Centro: basamento con grata e **insegna LIGHTS sospesa**, leggibile dai due lati, con tubo al neon.
- Nord: ballatoio con scala e ringhiera, scaffalature, sala controllo vetrata (sagoma dietro il vetro).
- Est: **baia di partenza** con 4 porte blindate, barra rossa (si spegne coi blackout) e monitor che mostrano la coda.
- Ovest: bacheca novita', rapporto 07-C (lore), porta di servizio che si chiude da sola, stanzino buio.
- Luci a campana con lampeggi, interruzioni, blackout rari, riaccensione scaglionata; due lampade si spengono quando ci passi sotto.
- Filtro **VHS**: scanline, vignettatura, tracking, strappi, colore e blur leggeri, REC lampeggiante, mirino, timecode, data. Intensita' sale con blackout e disturbi; si disattiva nelle impostazioni.

## Milestone 3 — GUI e matchmaking (scritta)
- Menu: `▶ GIOCA` / `✕ ANNULLA`, stato coda con conto alla rovescia, Impostazioni (7 opzioni con selettori ◀ ▶), Novita'.
- Coda: gruppi da 4; con meno giocatori parte dopo 25 s (anche da soli). Uscite e disconnessioni gestite.
- Votazione: 4 facility con descrizione, difficolta' base, giocatori, entita', voti in tempo reale; selettore difficolta'; pareggi e nessun voto gestiti (testati).
- Profilo ProfileStore con schema completo (monete, XP, inventario, ricevute...) — oggi usato solo per le impostazioni.

## Non ancora fatto
- Milestone 4: spostamento del gruppo nella mappa, round (esplorazione scalata dalla difficolta', estrazione), spettatore, ritorno in lobby.
- Milestone 5-13 (mappe, entita', stamina/sanity/torcia, prima persona, shop, leaderboard, monetizzazione).
- Shop, inventario, classifiche: nessun pulsante nel menu finche' non esistono.

## Lobby visibile in Edit (aggiornamento)
- La lobby si costruisce **una volta in Studio** dalla Command Bar: `require(game.ServerScriptService.LIGHTS.LobbyBuilder).bake()`, poi Ctrl+S.
- A runtime il server **riusa** `Workspace.LIGHTS_Lobby` e legge lampade, monitor, porta, percorsi ombra e postazioni sagome da tag (`LightsLamp`, `LightsMonitor`, `LightsDeployScreen`, `LightsDoor`, `LightsLogo`) e dai marcatori in `LIGHTS_Lobby/Markers`. Si possono spostare e duplicare in Studio.
- Se la lobby manca, viene costruita a runtime come prima (con un avviso in Output).

## Da provare in Studio (checklist Milestone 2-3)
- [ ] La lobby si costruisce senza errori in Output; 60 FPS su PC medio
- [ ] Lettere LIGHTS leggibili da entrambi i lati; si spengono coi blackout
- [ ] La scala porta al ballatoio (varco nella ringhiera)
- [ ] Monitor della baia aggiornano "IN CODA x/4"
- [ ] Test con 2 giocatori locali (Test > Clients and Servers): coda -> votazione -> risultato -> avviso "non ancora costruita" -> menu
- [ ] Un giocatore esce durante la votazione: l'altro continua
- [ ] Impostazioni salvate dopo il rientro (serve l'accesso API in Studio)
- [ ] Emulatore telefono e gamepad: menu e votazione utilizzabili
