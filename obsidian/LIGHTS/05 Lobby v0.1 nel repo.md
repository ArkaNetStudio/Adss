---
tags: [lights, codice]
---
# Lobby v0.1 nel repo

> [!note] Sostituita dalla lobby 0.2 (`roblox/lights/`). Riusati: Lights, Apparition, Events, Rules, Effects, Settings. Rimossi: Builder, Menu, PlayerSettings.

Cartella `roblox/lights-lobby/` (commit `cb41591`). Mai provata in Studio.

| Sistema | File | Riuso nel rework |
|---|---|---|
| Luci (lampeggi, blackout, riaccensione scaglionata) | `src/server/Lights.lua` | Si', da agganciare alle lampade della mappa vera tramite tag invece del Builder |
| Sagoma nel buio | `src/server/Apparition.lua` | Si', come evento della lobby |
| Eventi casuali | `src/server/Events.lua` | Si' |
| Mappa procedurale | `src/server/Builder.lua`, `Geometry.lua` | No: sostituita dalla lobby modellata |
| Coda e partita privata | `src/server/Matchmaking.lua` | Base per la Milestone 3, da estendere con gruppi e votazione |
| Impostazioni giocatore | `src/server/PlayerSettings.lua` | Confluisce nel profilo unico (DataService) |
| Menu | `src/client/Menu.lua` | No: va rifatto sul layout degli screenshot |
| Logica pura + test | `src/shared/Rules.lua`, `tests/Rules.spec.luau` | Si', da estendere |
