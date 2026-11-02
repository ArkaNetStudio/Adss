---
tags: [lights, handoff]
data: 2026-11-02
---
# Prompt per una nuova sessione (locale, con Roblox Studio MCP)

```text
Sei in una sessione LOCALE sul mio PC con l'MCP "Roblox_Studio" collegato e Roblox Studio aperto sul mio place "Lights". Lavora in autonomia: fai tu tutti i passaggi in Studio tramite MCP, non chiedermi di copiare file a mano.

CONTESTO
- Gioco: LIGHTS, horror psicologico multiplayer Roblox (1-4 giocatori) del gruppo ArkanetStudio. Paura del buio, neon che lampeggiano, blackout, entita' che appaiono nel buio, estetica VHS.
- Repo GitHub: ArkaNetStudio/Adss, branch claude/admiring-gauss-vejvob. Fai git pull di quel branch.
- Codice Luau (Rojo): roblox/lights/ (default.project.json). Documentazione e stato: vault Obsidian in obsidian/LIGHTS/ (leggi "LIGHTS - Home", "06 Decisioni", "07 Stato implementazione", "02 Roadmap milestone").
- Mappatura: src/shared -> ReplicatedStorage/LIGHTS (Config, Maps, Net, Rules); src/server -> ServerScriptService/LIGHTS (Main Script + DataService, LobbyBuilder, Geometry, Lights, Apparition, Events, Matchmaking, Packages/ProfileStore); src/client -> StarterPlayer/StarterPlayerScripts/LIGHTS (Main LocalScript + Settings, Effects, VHS, UIKit, Menu, Voting).
- Test logica: `lune run tests/Rules.spec.luau` da roblox/lights (deve restare verde).

DECISIONI GIA' PRESE (non richiederle)
1. Screenshot/video sono di Apeirophobia: solo riferimento per estetica e audio.
2. Matchmaking: coda + votazione mappe, max 4 giocatori per gruppo; da soli dopo 25 s.
3. Difficolta' selezionabile (votata insieme alla mappa): scala durata partita e aggressivita' dell'entita'.
4. Un solo place: lobby e mappe nella stessa mappa, distanti tra loro.
5. Salvataggi con ProfileStore (incluso in Packages, non modificarlo).
6. Generi tu tutto (codice, geometria, testi, GUI) tranne i modelli dei mostri, che fornira' l'utente. Audio e immagini richiedono ID caricati dal gruppo: lasciali configurabili in Config e dichiaralo.
7. Lobby: hangar industriale stile riferimenti con la scritta LIGHTS al centro.
8. VHS come il video di riferimento + REC con pallino rosso lampeggiante e angoli del mirino.
9. Modifica SEMPRE il place esistente "Lights", non creare place nuovi.

COMPITO IMMEDIATO
1. Porta il codice di roblox/lights dentro "Lights" via MCP (sostituendo le cartelle LIGHTS esistenti nei tre servizi).
2. In modalita' Edit esegui `require(game.ServerScriptService.LIGHTS.LobbyBuilder).bake()` cosi' la lobby compare nel Workspace (Workspace.LIGHTS_Lobby). Se esiste gia', non cancellarla senza chiedermelo.
3. Avvia Play, leggi l'Output, correggi ogni errore nel repo E nel place, ripeti finche' e' pulito.
4. Completa la checklist "Da provare in Studio" di 07 Stato implementazione (anche test con 2 client). Fai screenshot della lobby e confrontali con i riferimenti; migliora la resa se serve.
5. Poi prosegui con la Milestone 4 (spostamento del gruppo nella mappa, round: 5 min esplorazione scalati dalla difficolta' + estrazione configurabile, obiettivi, vittoria individuale, morte -> spettatore, ritorno in lobby) e le successive, nell'ordine della roadmap. Ogni milestone va testata in Studio prima di passare alla successiva.

REGOLE
- Non dichiarare completo nulla che non hai testato in Studio. Niente placeholder spacciati per funzioni finite.
- Logica economica e sensibile solo sul server; valida ogni remote.
- Commit e push sul branch claude/admiring-gauss-vejvob; aggiorna il vault Obsidian (07 Stato implementazione) a ogni milestone.
- Rispondimi in italiano, in modo semplice: non sono un programmatore.
```
