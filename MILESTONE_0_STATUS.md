# Milestone 0 - stato baseline e qualita

## Build

- Versione: `0.1.0-baseline.1`
- Build ID: `baseline-2026-08-02.1`
- Stato: **GO — chiusa il 2026-08-02**

## Completato

- Configurazioni separate per `Studio`, `PrivateTest`, `SoftLaunch` e `Production`.
- Seed round-local, normalizzato e riproducibile; RNG lobby separato dall'RNG di generazione.
- Ordine preset deterministico estratto in un modulo testabile.
- Seed, versione e ambiente inclusi in telemetria, attributi della generazione e pannello QA.
- Modalita QA server-authoritative limitata a Studio, con seed, preset, ruolo, numero player e stanza iniziale.
- Validatore strutturale iniziale per folder, extraction pad, modelli, gate, indici e preset duplicati/sconosciuti.
- Log distinti `[QA][Server]` e `[QA][Client]` per tempi, interazioni, errori e motivo di conclusione.
- StyLua, Selene e Rojo fissati in `rokit.toml`; progetto di test separato dalla build normale.
- Runner runtime dedicato con report `PASS/FAIL`, ACK di ogni client, telemetria e probe di sanitizzazione errori.
- Attesa client stabilizzata prima dell'avvio della matrice, per includere anche i client Studio piu lenti a connettersi.

## Verifiche eseguite

- StyLua check: superato.
- Selene: `0 errors`, `0 warnings`, `0 parse errors`.
- Build Rojo gioco: superata.
- Build Rojo test: superata.
- `git diff --check`: superato.
- Test Luau in `tests.rbxlx`: superato in Studio (seed, preset, puzzle, generazione e sicurezza interazioni).
- Matrice automatica RoomGenerator: superata in Studio per tutti i cinque preset con seed `SEED-0000424242`, due
  generazioni per preset, firma deterministica identica, validazione strutturale e contratti Seer/Operator
  (`10/10` generazioni superate).
- Smoke test QA a 1 client: superato con seed `SEED-0000424242`, preset iniziale `PowerGrid`, ruolo `Solo` e stanza 1.
- Riproducibilita smoke test: due run consecutivi hanno generato lo stesso ordine
  `PowerGrid, PhaseFloor, FrequencyDials`.
- Overlay client e log server: seed, build, ambiente, stanza e preset coerenti.
- Validazione geometrica pavimento: superata in Studio con `PhaseFloor`; threshold, trim e chasm non intersecano piu
  il `ChamberDeck` statico.
- Matrice runtime Studio: superata con **1, 2 e 6 client**. Ogni sessione ha eseguito i cinque preset due volte con
  seed `SEED-0000424242` (`30/30` casi complessivi, `90` ACK client validi e `90` eventi telemetrici).
- Ruoli verificati: `Solo` a 1 client; `Seer` e `Operator` in entrambi gli ordini nei test multi-client.
- Probe errori client: superato su tutti i client; prefisso `[QA][Client]` presente e percorso utente, email e token
  di prova rimossi.
- Audit moduli puri: **5.000 seed per ciascuno dei cinque preset**, `25.000` generazioni consecutive senza eccezioni,
  stato iniziale risolto, soluzione irraggiungibile o violazione dei vincoli logici coperti.
- Smoke runtime post-refactor: `PASS`, 1 client, `10/10` casi e probe errori valido.
- Implementato il validatore volumetrico per gate, console, spawn, percorso e parti bloccanti, con tolleranza per i
  contatti intenzionali e gruppi per le parti appartenenti alla stessa console.
- Gli indizi Seer non sono piu istanze o attributi del DataModel server: restano in memoria, vengono inviati con
  `FireClient` al Seer e al Solo soltanto durante una finestra Alternate Vision autorizzata, quindi sono costruiti
  localmente dal client autorizzato.
- Alternate Vision e server-authoritative: il server conserva scadenza e ricarica, concede ogni attivazione e revoca
  gli indizi alla scadenza. Tutte le console condividono controlli server-side per ruolo, visione, cooldown, distanza,
  stanza attiva e appartenenza della console alla stanza corrente.
- Quality gate post-P0: StyLua, Selene e build Rojo gioco/test/runtime superati; la matrice Studio e stata ripetuta
  con 1, 2 e 6 client dopo il refactor server-authoritative (`30/30` casi, `90/90` ACK, error probe valido).
- Playtest Alternate Vision post-P0: Signal e PowerGrid superati in Solo; durata, revoca, cooldown, blocco console,
  telemetria singola e rendering locale degli indizi verificati senza errori client.
- Verifica RemoteGuard in Studio: suite schema/fuzz/rate-limit PASS e smoke Solo/Signal con Alternate Vision concessa
  dal server, `AlternateVisionUsed` registrato e console bloccata durante la finestra.

## Verifiche trasferite alle milestone successive

- Il playthrough manuale completo di interazione/completamento, i dispositivi e gli avatar R6/R15 restano nella
  matrice di playtest della Milestone 2; non bloccano piu il gate tecnico della baseline.

## Milestone 1 — stato avvio

- **Completato:** estrazione dei cinque puzzle in moduli puri con `GenerateSolution`, `BuildInitialState` e `Validate`.
- **Completato:** runner logico deterministico da 5.000 seed per preset per il livello di difficolta corrente.
- **Completato nel codice:** validatore geometrico volumetrico e indizi Seer inviati soltanto ai client autorizzati.
- **Completato nel codice:** Alternate Vision e interazioni console server-authoritative con schema di validazione unico.
- **Completato nel codice:** `RemoteGuard` con contratti payload rigorosi, rate limit separati per lobby, visione,
  economia e puzzle, logging campionato dei rifiuti e fuzz test dedicati.
- **Implementato nel codice:** livelli espliciti `Easy`, `Normal` e `Hard`, propagati in generazione, QA, telemetria
  e pannello client; i vincoli logici sono specifici per preset e la matrice pura copre 5.000 seed per combinazione.
- **Verificato in Studio:** suite logica da 75.000 generazioni e matrice runtime estesa con 1, 2 e 6 client
  (`90/90` casi, `270/270` ACK e probe errori `9/9`).
- **Completato e verificato:** ricevute Developer Product idempotenti senza scadenza delle ricevute storiche;
  retry, cronologia lunga e riconnessione coperti dalla suite Studio.
- **Completato e verificato:** estrazione convalidata dal server per progresso stanze, tempo minimo, partecipazione,
  stato del goal e distanza reale dal pad; i tentativi implausibili vengono rifiutati e registrati.

## Rollback e flag

- La modalita QA e disattivata di default (`Config.QA.Enabled = false`) e viene ignorata fuori da Studio.
- Il logging extra fuori da Studio e disattivato di default (`Config.Debug.EnableServerLog = false`).
- L'ambiente pubblicato torna a Production impostando `Environment.PublishedEnvironment = Environment.Names.Production`.

## Milestone 2 - avanzamento

- Catalogo portato da 5 a 7 preset con `MirrorRelay` e `RuneCircuit` in rotazione.
- Suite pura: 5.000 seed per preset e livello, `105.000/105.000` generazioni PASS.
- Integrazione deterministica Studio: 7 preset x 3 livelli x 2 run, `42/42` PASS.
- Runtime Studio: `42/42` casi con 1, 2 e 6 client; totale `126/126` casi, `378/378` ACK e probe `9/9`.
- Signal ed Echo distinguono gli input con parole e forme oltre al colore; Echo mostra il progresso pubblico.
- Invisible Floor richiede il passaggio ordinato delle righe per lo stesso Operator e rifiuta salti o deviazioni.
- Resta aperta la matrice manuale su touch, gamepad, R6/R15, scale avatar, latenza e riconnessione.
