# YOU SEE IT, I DON'T

## Direzione grafica

Le immagini in `docs/images` guidano l'aspetto del laboratorio, della lobby, delle stanze e dell'HUD. I colori, il contrasto e le luci comuni sono definiti in `src/shared/VisualTheme.luau`; la corrispondenza tra i concept e gli elementi Roblox è in `VISUAL_IMPLEMENTATION_MAP.md`. Le illustrazioni non sono texture caricate nel gioco: le forme sono realizzate con istanze Roblox e gli indizi segreti continuano a essere creati soltanto sul client autorizzato.

Per usare `docs/images/game_icon.png` come icona dell'esperienza, caricarla manualmente nel Roblox Creator Dashboard dell'esperienza pubblicata. Il repository non contiene una pipeline di upload o ID asset per questa immagine.

Prototipo Roblox cooperativo basato su realta asimmetriche: i giocatori condividono gli stessi ambienti, ma ricevono indizi e possibilita diverse.

La roadmap completa da prototipo a lancio e disponibile in [`RELEASE_PLAN.md`](RELEASE_PLAN.md). La Milestone 0 e
chiusa con esito GO; risultati e limiti della matrice sono in [`RUNTIME_QA_REPORT.md`](RUNTIME_QA_REPORT.md).

## Baseline e ambienti

La baseline corrente e `0.1.0-baseline.1` (`baseline-2026-08-02.1`). Versione e build ID sono definiti in
`src/shared/BuildInfo.luau` e vengono inclusi nei log QA e nello stato del round.

Le configurazioni `Studio`, `PrivateTest`, `SoftLaunch` e `Production` separano telemetria, persistenza e ID Marketplace.
In Studio si puo provare un profilo impostando l'attributo DataModel `EnvironmentOverride`. Per una build pubblicata,
l'ambiente viene scelto dal valore versionato `Environment.PublishedEnvironment`; un client non puo cambiarlo a runtime.

## Flusso attuale

1. Il giocatore nasce in una lobby fisica.
2. Entra nel portale Solo oppure nella coda Gruppo da 2-6 giocatori.
3. La lavagna della lobby mostra quanti utenti sono in attesa e il countdown di partenza.
4. Alla partenza il server della lobby crea una **nuova sessione** (un server riservato) e teletrasporta lì la squadra.
5. Nel nuovo server la spedizione genera tre mini-stanze in ordine casuale.
6. Completate tutte le stanze, il gruppo raggiunge la piattaforma di estrazione e riceve Reality Shards.
7. Dopo il risultato la squadra torna automaticamente in una lobby pubblica.

## Sessioni di partita (server riservati)

Ogni spedizione gira in un server tutto suo, quindi la lobby resta sempre libera e più spedizioni possono svolgersi in
parallelo.

- **Lobby** (server pubblico): gestisce code, shop e classifiche. Quando una partita parte salva i profili, chiama
  `TeleportService:ReserveServer` e teletrasporta la squadra con `TeleportAsync` passando i dati della sessione
  (ID sessione, modalità, lista dei giocatori, difficoltà).
- **Match** (server riservato): costruisce solo il laboratorio, accetta esclusivamente i giocatori elencati nei dati della
  sessione, aspetta tutta la squadra (massimo 25 secondi, poi parte con chi è arrivato), esegue la spedizione e alla fine
  salva i profili e riporta tutti nella lobby. Chi arriva in ritardo viene rimandato alla lobby.
- Durante il viaggio il client mostra una schermata di transizione che resta visibile anche nel caricamento del nuovo
  server (`TeleportService:SetTeleportGui` + `ReplicatedFirst/TeleportArrival`).
- Se la prenotazione o il teletrasporto falliscono dopo i tentativi previsti, la spedizione viene eseguita nel server della
  lobby come prima, così il gioco resta giocabile.
- Il contratto dei dati è in `src/shared/MatchSession.luau` (testato in `tests/MatchSession.spec.luau`), le chiamate a
  `TeleportService` in `src/server/MatchSessionService.luau`, i parametri in `Config.Sessions`.

Di default lobby e spedizioni usano **lo stesso place** (i server riservati sono istanze dello stesso place). Per usare un
place separato per le partite imposta `Sessions.MatchPlaceId` (e `Sessions.LobbyPlaceId`) nel profilo di
`src/shared/EnvironmentConfig.luau`: entrambi i place devono appartenere alla stessa esperienza e contenere questo progetto.

`TeleportService` non funziona in Studio: lì lobby e spedizione restano nello stesso server. Per provare il comportamento
del server di partita in Studio imposta prima di **Play**:

```lua
workspace:SetAttribute("ServerRoleOverride", "Match") -- oppure "Lobby" per provare il fallback locale
```

La difficolta del round e esplicita e versionata: `Easy`, `Normal` (default) o `Hard`. Il livello viene scelto dal
server, applicato in modo deterministico a tutte le stanze della spedizione e mostrato nell'HUD.

## Mini-stanze procedurali

- **Signal Chamber**: sequenza nascosta di 1, 2 o 3 segnali.
- **Invisible Floor**: percorso rettilineo, variabile o con una svolta obbligatoria a ogni riga.
- **Echo Sequence**: sequenza nascosta di 3, 4 o 5 colori.
- **Frequency Vault**: ogni quadrante richiede esattamente 1, 2 o 3 scatti in avanti.
- **Power Grid**: configurazione con soluzione ottima garantita di 1, 2 o 3 pressioni.

Ogni spedizione sceglie tre preset diversi e ne mescola l'ordine. La soluzione, lo stato iniziale e la validazione dei
cinque puzzle sono moduli puri in `src/shared/Puzzles`; `RoomGenerator.luau` si occupa della rappresentazione e delle
interazioni Roblox.

## Mappe con Blender

L'architettura e le decorazioni di lobby e laboratorio sono una scena Blender (`blender/maps.blend`) esportata in moduli
Luau (`src/server/MapLayouts`) e istanziata da `src/server/MapLayoutBuilder.luau`. Gli elementi con logica (portali,
console, bacheche, stanze procedurali) restano in Luau. Flusso di lavoro, convenzioni e comandi sono in
[`blender/README.md`](blender/README.md); le anteprime renderizzate sono in `docs/images/blender`.

## Pacing e playtest

- Il timer non è più fissato a 120 secondi: usa 15 secondi di base più 22 secondi per stanza, con un minimo di 60.
- Con tre stanze il budget iniziale è quindi di 81 secondi.
- Il risultato finale mostra il tempo totale e lo split di ogni mini-stanza.
- L'Output di Studio registra righe `[Pacing]` con tempo, media di sessione, valore minimo e massimo per ogni preset.

## Modalita Solo

- Premi `Q` o usa **ALT VISION** su mobile per mostrare gli indizi per quattro secondi.
- Durante la visione alternativa le console sono bloccate.
- Memorizza l'indizio, disattiva la visione e completa l'azione.
- Un drone cosmetico accompagna il giocatore.
- Durata, ricarica e blocco delle console sono convalidati dal server; gli indizi Solo vengono inviati soltanto durante
  la finestra autorizzata.

## Lobby, economia e shop

- Lobby 3D di 108x94 stud progettata in Blender: pareti con angoli smussati, finestre alte, lucernario sopra l'Hub Core,
  prisma sospeso, colonne, fioriere, panchine e skyline esterno.
- Portali fisici Solo e Gruppo.
- I pulsanti UI **Cosmetics** e **My Stats** sono visibili solo nella lobby.
- **Cosmetics** apre un unico menu per acquistare ed equipaggiare gli oggetti; **My Stats** mostra le statistiche personali complete.
- Due lavagne mostrano i migliori esploratori per uscite riuscite e la classifica ironica delle uscite fallite.
- Nelle partite pubblicate le classifiche sono globali e persistenti; in Studio mostrano i dati della sessione di test.
- Countdown della coda visibile su una lavagna nel mondo.
- **Daily Reactor**: ricompensa giornaliera di 50 Reality Shards con streak persistente.
- **Reality Mixer**: tre pulsanti cambiano in modo condiviso l'energia cromatica della lobby.
- **Field Briefing**: terminale fisico con suggerimenti casuali sugli enigmi e sulla cooperazione.
- **Anomaly Pad**: piattaforma centrale interattiva che lancia il personaggio con un effetto particellare.
- Reality Shards ottenibili completando le spedizioni e spendibili in cosmetici.
- Hook sicuri per Developer Products e Game Pass; gli ID restano da configurare prima della pubblicazione.
- In Studio i salvataggi persistenti sono disabilitati e viene usato un profilo di prova.

## Spazi di gioco

- Il laboratorio della spedizione (68x150 stud) è progettato in Blender: nervature e capriate, finestre alte, luci a
  soffitto per ogni camera, airlock d'ingresso, cornici dei cancelli e baia di estrazione con aloni e piloni.
- Il perimetro collidibile è identico a prima, quindi la validazione geometrica di `RoomGenerator` continua a valere.
- Le tre camere procedurali sono piu larghe e piu distanti tra loro, con console e percorsi riposizionati.
- Cartelli, numeri e pannelli-indizio delle stanze successive restano nascosti finche la stanza non viene attivata.
- I nomi delle camere sono integrati nella parete laterale, senza pannelli sospesi al centro del percorso.
- Il labirinto invisibile ha pareti di contenimento e un ingresso obbligato: non puo essere aggirato passando ai lati.

## HUD della spedizione

- Durante la partita restano visibili solo fase, timer e i comandi indispensabili.
- Tieni premuto `H` su tastiera o `L1` su gamepad per mostrare ruolo, istruzioni e stato completo.
- Su mobile tieni premuto il piccolo pulsante **HOLD INFO**.

## Statistiche e telemetria

- Il pulsante **My Stats** nella lobby mostra carriera, win rate, tempo giocato, streak, economia e prestazioni per ogni puzzle.
- L'archivio include anche fallimenti, attività nella lobby, ricompense giornaliere, terminali visitati, interazioni e percentuale di completamento di ogni puzzle.
- Il profilo versione 2 salva sessioni, spedizioni Solo/Gruppo, stanze raggiunte e completate, errori, interazioni, ALT VISION, code, cosmetici e Shards.
- Ogni puzzle distingue quante volte è stato selezionato, effettivamente raggiunto e completato.
- In Studio gli eventi sono stampati come `[Telemetry]` e `[TelemetryEconomy]` nell'Output.
- Nelle partite pubblicate gli stessi dati vengono inviati ad `AnalyticsService` per le dashboard del Creator Hub.
- Le azioni ripetute vengono aggregate per stanza per non produrre un evento Analytics per ogni pressione.
- Ogni spedizione registra anche build, ambiente e un ID seed come `SEED-0000000001`.

## Modalita QA in Studio

La modalita QA e server-authoritative e non puo attivarsi fuori da Studio. Prima di premere **Play**, imposta gli attributi
seguenti su `Workspace` dalla finestra Properties o dalla Command Bar:

| Attributo | Tipo | Esempio | Effetto |
|---|---|---|---|
| `QAEnabled` | boolean | `true` | Attiva l'avvio automatico QA. |
| `QASeed` | number | `424242` | Riproduce la stessa generazione. |
| `QAPreset` | string | `PowerGrid` | Forza il preset nella stanza iniziale scelta. |
| `QADifficulty` | string | `Hard` | Seleziona `Easy`, `Normal` o `Hard` per l'intera spedizione. |
| `QARole` | string | `Operator` | Assegna il ruolo al primo tester; il secondo riceve il ruolo complementare. |
| `QAPlayerCount` | number | `2` | Attende questo numero di player Studio, da 1 a 6. |
| `QAStartRoom` | number | `2` | Apre le stanze precedenti e avvia direttamente questa stanza. |

Esempio dalla Command Bar:

```lua
workspace:SetAttribute("QAEnabled", true)
workspace:SetAttribute("QASeed", 424242)
workspace:SetAttribute("QAPreset", "PowerGrid")
workspace:SetAttribute("QADifficulty", "Hard")
workspace:SetAttribute("QARole", "Operator")
workspace:SetAttribute("QAPlayerCount", 1)
workspace:SetAttribute("QAStartRoom", 1)
```

Il pannello arancione mostra lato client build, ambiente, seed, stanza, preset e difficolta. L'Output usa il prefisso `[QA][Server]`
per generazione, tempi, interazioni, errori e motivo di conclusione; gli errori locali usano `[QA][Client]`.

## Controlli di qualita

Il tutorial compare al primo ingresso in lobby e si riapre con **HOW TO PLAY**. Lo shop e le statistiche si adattano agli schermi stretti e supportano la navigazione con gamepad.

Per controllare il catalogo e preparare una pubblicazione:

```powershell
pwsh -File .\scripts\economy_audit.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\release-preflight.ps1 -Environment Production
```

`ECONOMY_AUDIT.md` documenta prezzi e ricompense; `docs/ALPHA_PLAYTEST.md` descrive le prove con giocatori reali. Il preflight segnala gli ID Marketplace mancanti e le verifiche manuali prima della pubblicazione.

Le versioni degli strumenti sono fissate in `rokit.toml`:

```powershell
rokit install
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\quality.ps1
rojo build tests.project.json --output tests.rbxlx
```

Lo script verifica formato, lint e build sia del gioco sia dei test, eliminando poi gli artefatti temporanei. L'ultimo
comando crea il place di test da aprire in Studio: avvia un server e il runner esegue anche 5.000 seed per ognuno dei
cinque puzzle, oppure interrompe l'esecuzione con l'asserzione fallita.

## Avvio in Studio

```powershell
rojo serve
```

Collega il plugin Rojo 7 di Roblox Studio a `localhost:34872`, quindi premi **Play**. Dopo modifiche ai file, Rojo sincronizza automaticamente il progetto collegato.

## Struttura principale

- `src/server/LobbyBuilder.luau`: stanza lobby, portali e lavagna della coda.
- `src/server/MapBuilder.luau`: guscio e atmosfera del laboratorio.
- `src/server/RoomGenerator.luau`: generazione e logica dei preset di mini-stanza.
- `src/server/QAService.luau`: selezione protetta di seed, preset, ruolo, player e stanza per i test Studio.
- `src/server/RoundDebugService.luau`: log strutturati di riproduzione e diagnostica round.
- `src/server/RemoteGuard.luau`: contratti e rate limit server-side per remoti e interazioni puzzle.
- `src/server/PlayerDataService.luau`: profilo, Shards, acquisti e ricevute.
- `src/server/CosmeticsService.luau`: applicazione dei cosmetici equipaggiati.
- `src/server/SoloDrone.luau`: compagno della modalita Solo.
- `src/server/init.server.luau`: matchmaking, ruoli, round, ricompense e validazione server.
- `src/client/init.client.luau`: HUD, ALT VISION e visibilita per ruolo.
- `src/client/SeerClueRenderer.luau`: costruzione locale degli indizi ricevuti soltanto da Seer/Solo.
- `src/client/LobbyController.luau`: stato della coda, shop cosmetico, loadout e statistiche.
- `src/shared/Config.luau`: bilanciamento, catalogo e configurazione monetizzazione.
- `src/shared/Difficulty.luau`: nomi, ordine, default e normalizzazione dei livelli di difficolta.
- `src/shared/BuildInfo.luau`: versione baseline e build ID.
- `src/shared/EnvironmentConfig.luau`: profili per ambiente.
- `src/shared/SeedUtil.luau`: validazione e identificatore stabile dei seed.
- `src/shared/PresetOrder.luau`: selezione deterministica e testabile dei preset del round.
- `src/shared/Puzzles/`: contratto puro `GenerateSolution`, `BuildInitialState` e `Validate` per i cinque puzzle.
- `runtime-tests/`: matrice Studio automatica per 1, 2 e 6 client con report `PASS/FAIL`.
