---
tags: [lights, architettura]
---
# Architettura (proposta)

> [!info] Proposta da confermare in [[04 Domande aperte]]. Codice in Luau, sync con Rojo, logica sensibile solo sul server.

## Places (un'unica esperienza)
| Place | Ruolo |
|---|---|
| **Lobby** | menu, matchmaking/stanze, votazione, shop, inventario, leaderboard, statistiche |
| **Match** | un solo place per tutte le mappe. Le mappe sono Model in `ServerStorage/Maps/<MapId>` e vengono caricate all'avvio del server |

Perche' un solo place di gioco: una nuova mappa = una cartella + un modulo di definizione, nessun nuovo place da pubblicare.

**Passaggio lobby -> partita**: il server lobby fa `ReserveServer`, scrive la configurazione della partita (mapId, lista UserId, seed obiettivi) in **MemoryStore** con chiave `PrivateServerId`, poi `TeleportAsync`. Il server match legge la configurazione da MemoryStore, **non** dai TeleportData (falsificabili lato client). Chi non e' nella lista viene rimandato in lobby.

## Struttura sorgenti
```
src/
  shared/            ReplicatedStorage/LIGHTS
    Config/          valori di bilanciamento (round, stamina, sanity, economia)
    Maps/            definizioni mappa (id, nome, difficolta', entita', pool obiettivi)
    Items/           catalogo shop (id, prezzo, tipo) — letto da entrambi, deciso dal server
    Net.lua          remote tipizzati
    Rules/           logica pura testabile (votazione, obiettivi, economia, sanity)
  lobby/server/      Matchmaking, Voting, Shop, Leaderboards, Purchases
  match/server/      RoundService, ObjectiveService, EntityService, SanityService, SpectatorService
  server-common/     DataService (profili), Analytics
  client/            CameraController, Movement, Stamina, Flashlight, VHS, Sanity FX, UI/*
tests/               lune: Rules/*
```

## Stati
**Coda / gruppo (lobby)**: `Idle -> Queued -> SquadFound -> Voting(20s) -> Preparing -> Teleporting`. Uscita di un giocatore in qualsiasi stato: il gruppo torna `Queued` se scende sotto il minimo; in `Teleporting` il fallimento rimette in coda chi resta.

**Round (match)**: `WaitingPlayers(max 30s) -> Intro -> Exploration(300s) -> Extraction(Config.ExtractionSeconds) -> Results -> ReturnToLobby`.
- Uscita sbloccata solo a obiettivi completati.
- Vittoria **individuale**: chi tocca l'uscita in Extraction.
- Morto -> spettatore. Disconnesso -> conta come non fuggito.

**Votazione**: un voto per giocatore, cambiabile; vince il massimo; pareggio = estrazione casuale tra i pari; nessun voto = mappa casuale tra le disponibili. Logica pura in `Rules`, testata.

## Entita' (cervello comune + comportamento specifico)
Stati: `Dormant, Observe, Stalk, Hunt, Attack, Vanish, FakeOut`. Server-autoritativo, `PathfindingService`, rilevamento per vista (raycast + cono) e rumore (sprint, torcia). Ogni entita' e' un modulo che pesa le transizioni e aggiunge abilita' proprie (es. compare solo al buio, si muove solo se non guardata).

## Sistemi giocatore
- **Stamina**: client predice per reattivita', server traccia lo sprint e applica la velocita' (`WalkSpeed` deciso dal server).
- **Sanity**: calcolata dal server (distanza e tempo vicino all'entita'), inviata al client che applica blur/VHS/allucinazioni. Mai schermo inutilizzabile: limiti massimi fissi agli effetti.
- **Torcia**: batteria tenuta dal server; a 0 resta spenta per il round, salvo gadget.

## Dati
DataStore con **session lock** (UpdateAsync con id sessione e timestamp), retry con backoff, salvataggio periodico + uscita + `BindToClose`.
```
{ version, coins, xp, level, wins, score, stats{}, inventory{}, equipped{}, achievements{}, receipts{} }
```
- **Developer Products**: `ProcessReceipt` idempotente: se `PurchaseId` e' gia' in `receipts` -> `PurchaseGranted`; altrimenti accredita, salva, poi `PurchaseGranted`. Se il salvataggio fallisce -> `NotProcessedYet`.
- **Gamepass**: `UserOwnsGamePassAsync` lato server, in cache per sessione.
- **Leaderboard**: OrderedDataStore `Wins` e `Score`, aggiornate ogni 300 s, top 50 in cache, errori assorbiti.

## Validazione client
Ogni remote: controllo tipi, frequenza, stato (es. niente acquisti in partita), distanza (interazioni con oggetti). Monete, XP, prezzi e premi esistono solo sul server.
