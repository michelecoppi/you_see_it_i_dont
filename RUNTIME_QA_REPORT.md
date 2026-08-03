# Runtime QA report — baseline 0.1.0

Data: 2026-08-02
Seed: `SEED-0000424242`
Risultato: **PASS**

## Matrice Studio

| Client | Preset x run | Ruoli | ACK | Telemetria | Error probe | Esito |
|---:|---:|---|---:|---:|---:|---|
| 1 | 5 x 2 | Solo | 10/10 | 10 | 1/1 | PASS |
| 2 | 5 x 2 | Seer/Operator, ordine invertito al run 2 | 20/20 | 20 | 2/2 | PASS |
| 6 | 5 x 2 | Seer/Operator, ordine invertito al run 2 | 60/60 | 60 | 6/6 | PASS |
| **Totale** | **30 casi** | **Solo, Seer, Operator** | **90/90** | **90** | **9/9** | **PASS** |

Ogni caso forza un preset, genera la stanza con lo stesso seed, esegue `RoomGenerator:Validate()`, controlla i marker
di ruolo e richiede a ogni client di confermare preset, ruolo, stanza e seed replicati. Il probe errori verifica il
prefisso `[QA][Client]` e la rimozione di percorso utente, email e token fittizi.

## Blocker trovato e corretto

La prima sessione configurata con 6 client ha iniziato i casi quando soltanto 4 client erano gia connessi. Il runner
ora attende che il numero di client resti stabile per 15 secondi, con timeout complessivo di 45 secondi. La ripetizione
ha registrato correttamente `clients=6 cases=10/10 errorProbe=true`.

## Milestone 1 avviata

- Cinque moduli puri estratti da `RoomGenerator`.
- Contratto comune: `GenerateSolution`, `BuildInitialState`, `Validate`.
- 5.000 seed per preset, 25.000 generazioni totali: PASS.
- Test d'integrazione deterministico di tutti i preset, due run con lo stesso seed: PASS.
- Smoke runtime dopo il refactor, 1 client e 10 casi: PASS.

## Livelli di difficolta espliciti

- Livelli versionati: `Easy`, `Normal` (default) e `Hard`.
- 5.000 seed per preset e livello, 75.000 generazioni pure totali: PASS.
- Test d'integrazione deterministico: cinque preset per tre livelli, due run con lo stesso seed (`30/30`): PASS.
- Matrice runtime estesa, 1 client Solo, propagazione difficolta e probe errori (`30/30`): PASS.
- Matrice runtime estesa, 2 client Seer/Operator alternati (`30/30`, `60/60` ACK): PASS.
- Matrice runtime estesa, 6 client Seer/Operator alternati (`30/30`, `180/180` ACK): PASS.
- Totale difficolta: `90/90` casi, `270/270` ACK e probe errori `9/9`.

## Chiusura sicurezza Milestone 1

- Ledger ricevute senza eliminazione degli ID storici: retry immediato, 125 ricevute successive e riconnessione
  simulata non duplicano Shards o contatori.
- Accredito persistente eseguito dentro `UpdateAsync`, riconciliando la cronologia salvata prima della concessione.
- Estrazione rifiutata se il round non e attivo, le stanze non sono complete, il tempo e implausibile o il
  personaggio non si trova realmente sul pad.
- Suite Studio aggiornata: `receipts, extraction security, remote guard, interactions, seeds, puzzles and
  RoomGenerator passed`.

## Ripetizione post-P0 server-authoritative

La matrice e stata ripetuta dopo l'introduzione di Alternate Vision e console server-authoritative:

- 1 client, ruolo Solo: `clients=1 cases=10/10 errorProbe=true`;
- 2 client, ruoli Seer/Operator alternati: `clients=2 cases=10/10 errorProbe=true`;
- 6 client, ruoli Seer/Operator alternati: `clients=6 cases=10/10 errorProbe=true`.

Totale post-P0: **30/30 casi PASS**. Il playtest manuale Solo ha inoltre verificato Signal e PowerGrid durante
Alternate Vision, inclusi revoca a scadenza, cooldown, blocco console, telemetria e rendering locale. Sono stati
corretti lo spawn che intersecava Signal/PhaseFloor e il fallback del renderer per indizi senza `Shape` o `Material`.

Il checkpoint di sicurezza successivo aggiunge `RemoteGuard`: schema chiuso per ogni azione di `LobbyEvent`, limite
globale anti-flood, bucket indipendenti per lobby, visione ed economia, limite puzzle aggiuntivo ai cooldown delle
console e logging campionato dei payload rifiutati. Anche richieste di visione fuori fase, azioni economiche durante
una spedizione e identificatori di catalogo inesistenti vengono scartati e registrati.

La suite aggiornata e stata eseguita in Studio con esito PASS, inclusi fuzz payload, rate limit, refill e reset per
player. Uno smoke test sul place di gioco ha poi avviato Solo/Signal e ottenuto `AlternateVisionUsed` dal server con
HUD `CONSOLE LOCKED`, senza errori di integrazione.

## Limiti noti non bloccanti per Milestone 0

Il validatore volumetrico copre gate, console, spawn, percorso e parti bloccanti. I playthrough manuali completi,
R6/R15, gamepad e touch appartengono alla matrice della Milestone 2.

## Estensione Milestone 2 - catalogo a 7 preset

- Aggiunti `MirrorRelay` e `RuneCircuit`, entrambi con Easy/Normal/Hard e contratto puro deterministico.
- Suite logica: `105.000/105.000` generazioni PASS.
- Integrazione RoomGenerator: `42/42` casi PASS.
- Runtime 1 client: `42/42`, `42/42` ACK, error probe valido.
- Runtime 2 client: `42/42`, `84/84` ACK, error probe valido.
- Runtime 6 client: `42/42`, `252/252` ACK, error probe valido.
- Totale runtime M2: `126/126` casi e `378/378` ACK.
