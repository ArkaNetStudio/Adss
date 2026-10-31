# LIGHTS — Lobby

Lobby horror psicologica per Roblox. La struttura abbandonata viene costruita a runtime dal server
(nessun asset esterno richiesto), le luci sono il sistema principale, il menu è in codice.

## Struttura

| Percorso repo | Dove va in Roblox Studio | Tipo | Ruolo |
|---|---|---|---|
| `src/shared/Config.lua` | `ReplicatedStorage/LightsLobby/Config` | ModuleScript | **Tutti i valori regolabili** (ID partita, audio, tempi, news) |
| `src/shared/Net.lua` | `ReplicatedStorage/LightsLobby/Net` | ModuleScript | Crea/attende i RemoteEvent |
| `src/shared/Rules.lua` | `ReplicatedStorage/LightsLobby/Rules` | ModuleScript | Logica pura: cooldown, scelte casuali, coda |
| `src/server/Main.server.lua` | `ServerScriptService/LightsLobby/Main` | Script | Avvio server (ordine dei moduli) |
| `src/server/Builder.lua` | `ServerScriptService/LightsLobby/Builder` | ModuleScript | Costruisce la mappa: sala, corridoi, porta, monitor, logo |
| `src/server/Geometry.lua` | `ServerScriptService/LightsLobby/Geometry` | ModuleScript | Mattoni geometrici e illuminazione (Lighting, nebbia, bagliore) |
| `src/server/Lights.lua` | `ServerScriptService/LightsLobby/Lights` | ModuleScript | Lampeggi, interruzioni, blackout, riaccensione, lampade sotto cui si passa |
| `src/server/Apparition.lua` | `ServerScriptService/LightsLobby/Apparition` | ModuleScript | La sagoma (solo nel buio o dietro il vetro) |
| `src/server/Events.lua` | `ServerScriptService/LightsLobby/Events` | ModuleScript | Porta che si chiude, ombra, monitor, eventi casuali |
| `src/server/Matchmaking.lua` | `ServerScriptService/LightsLobby/Matchmaking` | ModuleScript | Coda GIOCA e partita privata |
| `src/server/PlayerSettings.lua` | `ServerScriptService/LightsLobby/PlayerSettings` | ModuleScript | Impostazioni per giocatore (DataStore) |
| `src/client/Main.client.lua` | `StarterPlayer/StarterPlayerScripts/LightsLobby/Main` | LocalScript | Avvio client |
| `src/client/Settings.lua` | `StarterPlayer/StarterPlayerScripts/LightsLobby/Settings` | ModuleScript | Applica e salva le impostazioni |
| `src/client/Effects.lua` | `StarterPlayer/StarterPlayerScripts/LightsLobby/Effects` | ModuleScript | Logo e monitor sincronizzati con le luci |
| `src/client/Menu.lua` | `StarterPlayer/StarterPlayerScripts/LightsLobby/Menu` | ModuleScript | Interfaccia: stato, GIOCA, partita privata, news, impostazioni |

Il `Remotes` folder e i RemoteEvent vengono creati dal server in `ReplicatedStorage/LightsLobby/Remotes`: non serve crearli.

## Metodo 1 — con Rojo (consigliato)

1. Installa Rojo e il plugin Rojo in Studio.
2. Dalla cartella `roblox/lights-lobby`: `rojo serve`
3. In Studio: Plugin Rojo → **Connect**.

`default.project.json` mappa già ogni cartella nel posto giusto.

## Metodo 2 — senza Rojo (copia manuale)

Crea le cartelle `LightsLobby` in `ReplicatedStorage`, `ServerScriptService` e `StarterPlayerScripts`
e incolla il contenuto di ogni file seguendo la tabella sopra.
Gli script `Main.server.lua` e `Main.client.lua` diventano `Script` e `LocalScript` di nome **Main**.

## Impostazioni da fare prima di pubblicare

1. **`Config.Match.PlaceId`** — ID del luogo della partita vera. Con `0` GIOCA e PARTITA PRIVATA mostrano un avviso
   e non teletrasportano nessuno.
2. **`Config.Sounds`** — incolla gli ID audio dal Creator Store (Toolbox → Audio). Con `""` il suono viene saltato.
   Ricerche consigliate sono scritte nel commento di `Config.lua`.
3. **Lighting.Technology** — impostalo in Studio su `ShadowMap` (migliore compatibilità PC, mobile e console).
   Non si può cambiare da script.
4. **Impostazioni di gioco → Sicurezza → "Abilita accesso API a Studio"** — serve per provare il salvataggio
   delle impostazioni in Studio. Senza, il gioco usa i valori di default senza errori.

## Test della logica

```bash
lune run tests/Rules.spec.luau
```
(Lune: <https://lune-org.github.io/docs>). Il test copre cooldown, scelte pesate, decisione della coda e postazioni della sagoma.

## Limiti noti

- La mappa è costruita a runtime con seed fisso: si modifica nel codice di `Builder.lua`, non trascinando parti in Studio.
- Le impostazioni di luce (ombre, bagliore, nebbia) sono locali al singolo giocatore. Le luci della lobby
  (lampeggi, blackout) sono decise dal server e sono uguali per tutti.
- "Riduci lampeggi" ferma gli effetti stroboscopici del client (logo, statica). Le luci del mondo restano quelle del server.
- Nessun audio è incluso: senza ID audio la lobby è silenziosa.
