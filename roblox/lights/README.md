# LIGHTS

Horror multiplayer per Roblox (1-4 giocatori). Un solo place: lobby e facility nella stessa mappa, a distanza.
Stato e decisioni di progetto: `obsidian/LIGHTS/` (vault Obsidian).

## Dove va ogni file in Roblox Studio

Con Rojo (`rojo serve` da questa cartella, poi Connect nel plugin) la mappatura e' automatica (`default.project.json`).
A mano: crea una cartella `LIGHTS` in ciascuno dei tre servizi e incolla i file.

| Cartella repo | Studio | Contenuto |
|---|---|---|
| `src/shared/` | `ReplicatedStorage/LIGHTS` | ModuleScript: `Config`, `Maps`, `Net`, `Rules` |
| `src/server/` | `ServerScriptService/LIGHTS` | Script `Main`; ModuleScript `DataService`, `LobbyBuilder`, `Geometry`, `Lights`, `Apparition`, `Events`, `Matchmaking`; cartella `Packages` con `ProfileStore` |
| `src/client/` | `StarterPlayer/StarterPlayerScripts/LIGHTS` | LocalScript `Main`; ModuleScript `Settings`, `Effects`, `VHS`, `UIKit`, `Menu`, `Voting` |

I RemoteEvent vengono creati dal server in `ReplicatedStorage/LIGHTS/Remotes`.

## Sistemi

| Sistema | File | Note |
|---|---|---|
| Lobby (hangar, insegna LIGHTS, ballatoio, baia di partenza, area informazioni) | `LobbyBuilder.lua` | costruita all'avvio del server, seed fisso |
| Luci: lampeggi, interruzioni, blackout, riaccensione scaglionata | `Lights.lua` | server-autoritativo |
| Sagome nel buio e dietro il vetro, eventi casuali | `Apparition.lua`, `Events.lua` | cooldown e distanza dai giocatori |
| Coda (gruppi max 4, anche da soli dopo 25 s) e votazione facility + difficolta' | `Matchmaking.lua`, `Voting.lua` | voti validati e sincronizzati dal server |
| Profilo giocatore (session lock) | `DataService.lua` + `Packages/ProfileStore.lua` | oggi salva le impostazioni |
| Filtro VHS con REC, mirino, timecode | `VHS.lua` | sotto le interfacce, intensita' dinamica |
| Menu (GIOCA, coda, Impostazioni, Novita') | `Menu.lua`, `UIKit.lua` | scala unica per PC/mobile/console |

## Da configurare

- `Config.Sounds`: ID audio (vuoti = silenzio, nessun errore).
- `Config.VHS.NoiseImage`: ID di una texture di grana (vuoto = niente grana, il resto del VHS funziona).
- Studio: *Impostazioni gioco > Sicurezza > Accesso API a Studio* per provare ProfileStore; `Lighting.Technology = ShadowMap`.

## Test

```bash
lune run tests/Rules.spec.luau
```
Copre cooldown, scelte pesate, gruppi, voti (pareggi, nessun voto, voti non validi), durata del round.

## Limiti attuali

- Le facility non sono ancora costruite (`Maps.lua`, `Built = false`): se una vince la votazione, il gruppo viene avvisato e torna in lobby.
- Nessun test in Roblox Studio finora: il comportamento a runtime e' da verificare.
- `ProfileStore.lua` e' il modulo ufficiale di MadStudio (loleris), incluso senza modifiche.
