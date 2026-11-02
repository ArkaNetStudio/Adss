---
tags: [lights, decisioni]
data: 2026-11-02
---
# Decisioni (risposte alla Milestone 1)

| # | Domanda | Decisione |
|---|---|---|
| 1 | Riferimenti | Screenshot e video vengono da **Apeirophobia**: sono riferimenti per estetica e suono, non c'e' un place esistente da analizzare |
| 2 | Matchmaking | **Coda + votazione delle mappe**, massimo 4 giocatori per gruppo |
| 3 | Video Backrooms | Solo esempio di resa grafica e audio, non una mappa da fare |
| 4 | Difficolta' | **Selezionabile** (votata insieme alla mappa). Scala la durata della partita e l'aggressivita' dell'entita' |
| 5 | Places | **Tutto nello stesso place**: lobby e mappe nella stessa mappa, distanti tra loro |
| 6 | Proprietario | Gruppo **ArkanetStudio** (animazioni, audio e prodotti vanno pubblicati dal gruppo) |
| 7 | Salvataggi | **ProfileStore** |
| 8 | Asset | Genero io tutto **tranne i modelli dei mostri**, che fornirai tu |
| 9 | Lobby | Rifatta da capo e diversa, ma con stile simile alla v0.1 e la scritta **LIGHTS al centro** |
| 10 | VHS | Come nel video (grana, colore) + estetica videocamera: **REC**, pallino rosso lampeggiante, angoli del mirino |

## Conseguenze tecniche
- Un solo server ospita lobby e partite: ogni partita usa una **copia della mappa in uno slot libero** lontano dalla lobby (vedi [[01 Architettura]], da aggiornare in Milestone 4). Il passaggio lobby→partita diventa uno spostamento del personaggio, non un teletrasporto tra place: niente MemoryStore.
- Limite: il server Roblox ha un massimo di giocatori; con gruppi da 4 nello stesso server bisogna dimensionare `MaxPlayers` e il numero di slot mappa.
- "Genero tutto" vale per codice, geometria, testi e interfacce. **Audio e immagini non si possono generare da codice**: servono ID caricati dal gruppo (vedi [[03 Asset necessari]]). Il VHS funziona senza, la grana richiede una texture.
