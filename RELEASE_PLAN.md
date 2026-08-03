# Piano di produzione e rilascio

## Obiettivo

Portare **YOU SEE IT, I DON'T** dal prototipo attuale a un gioco Roblox pubblicabile, sicuro, leggibile e sostenibile nel tempo. Il piano è ordinato per dipendenze: prima si rende affidabile il ciclo di gioco, poi si bilanciano progressione e monetizzazione, quindi si aggiungono live-ops e contenuti stagionali.

La stima iniziale è di **14-18 settimane per uno sviluppatore**, da ricalibrare dopo l'alpha. Le settimane indicano l'ordine di lavoro, non date di pubblicazione obbligatorie.

## Stato di partenza

Il prototipo dispone già di:

- lobby fisica, coda Solo e Gruppo da 2-6 giocatori;
- round con 3 stanze estratte casualmente da 7 preset;
- Signal Chamber, Invisible Floor, Echo Sequence, Frequency Vault, Power Grid, Mirror Relay e Rune Circuit;
- ruoli Seer, Operator e modalità Solo con Alternate Vision;
- profilo persistente, Reality Shards, ricompensa giornaliera, statistiche e telemetria per puzzle;
- catalogo cosmetici, Game Pass e Developer Product già predisposti nel codice;
- HUD di partita, shop, loadout e pannello statistiche.

I principali rischi da chiudere prima del rilascio sono:

1. gli indizi nascosti tramite visibilità client possono essere ispezionati da un client modificato;
2. manca una suite automatica per verificare migliaia di generazioni e impedire soft-lock;
3. gli ID Marketplace sono ancora non configurati;
4. l'economia è definita, ma non ancora validata con dati reali di playtest;
5. non esistono ancora pass stagionale, missioni, calendario eventi e strumenti live-ops;
6. UI e geometria richiedono una matrice di controllo su dispositivi e risoluzioni diverse.

## Principi non negoziabili

- Il server decide sempre soluzione, progresso, ricompense, acquisti ed equipaggiamento.
- Nessun acquisto Robux aumenta potenza o rende più facile un puzzle.
- Ogni stanza deve essere completabile in Solo e in Gruppo, con tastiera, gamepad e touch.
- Colore, audio o testo non devono essere l'unico modo per capire un indizio.
- Ogni milestone termina con criteri misurabili: non si passa alla successiva solo perché la funzione “sembra finita”.
- I nuovi contenuti vengono attivati tramite configurazione versionata, senza duplicare la logica centrale del round.

---

## Milestone 0 — Baseline e strumenti di qualità

**Durata:** settimana 1
**Priorità:** P0

### Lavoro

- Congelare una build baseline e assegnarle una versione.
- Aggiungere un identificatore riproducibile del seed a ogni spedizione e registrarlo in telemetria.
- Separare la configurazione per ambiente: Studio, test privato, soft launch e produzione.
- Introdurre controlli statici/formattazione Luau e una cartella di test.
- Creare una modalità QA che permetta di scegliere preset, seed, ruolo, numero di giocatori e stanza da avviare.
- Definire un pannello/debug log per: seed, preset, tempo stanza, errori, interazioni e motivo del fallimento.

### Criteri di uscita

- Un bug segnalato con seed e versione può essere riprodotto in Studio.
- Ogni preset può essere avviato direttamente senza svolgere un round completo.
- Gli errori server e client sono distinguibili e non contengono dati sensibili.

---

## Milestone 1 — Generazione affidabile e anti-cheat

**Durata:** settimane 2-3
**Priorità:** P0

### Contratto comune per tutte le stanze

Ogni preset deve implementare lo stesso ciclo:

1. `GenerateSolution(seed, difficulty)` crea prima una soluzione valida.
2. `BuildInitialState(solution)` produce uno stato non già risolto.
3. `Validate()` controlla raggiungibilità, collisioni, numero minimo di azioni e presenza di tutti gli oggetti obbligatori.
4. Il server conserva soluzione e progresso; il client riceve solo ciò che il suo ruolo può conoscere.
5. La stanza comunica avvio, interazioni, errore, completamento e tempo tramite un'interfaccia comune.

La generazione deve partire dalla soluzione e costruire il problema a ritroso. Randomizzare separatamente obiettivo e geometria rende più probabili configurazioni impossibili o banali.

### Anti-cheat e sicurezza

- Non replicare nel `Workspace` gli indizi segreti destinati al Seer. Inviare i dati soltanto ai client autorizzati, che costruiscono localmente la rappresentazione visiva.
- In Solo inviare l'indizio solo durante la finestra Alternate Vision; scaduta la finestra, invalidare l'interazione e rimuovere la visualizzazione.
- Per ogni azione verificare sul server:
  - giocatore partecipante al round;
  - fase e stanza correnti;
  - ruolo autorizzato;
  - distanza reale personaggio-console;
  - console appartenente alla stanza attiva;
  - cooldown specifico dell'azione;
  - ordine valido rispetto allo stato del puzzle.
- Applicare rate limit distinti a lobby, puzzle, equipaggiamento e telemetria; registrare e scartare payload sconosciuti o fuori schema.
- Rendere impossibile completare una stanza o l'estrazione con un semplice teleport: verificare progresso server, posizione plausibile e tempo minimo compatibile.
- Mantenere Shards, inventario e ricompense esclusivamente server-side.
- Verificare che le ricevute Developer Product siano idempotenti e che una stessa ricevuta non possa accreditare due volte.
- Fuzzare i RemoteEvent con tipi errati, stringhe molto lunghe, azioni ripetute, ID inesistenti e richieste fuori fase.

### Test automatici della generazione

- Almeno **5.000 seed per preset e livello di difficoltà**.
- Nessun errore, riferimento mancante, soluzione iniziale già completata o configurazione senza soluzione.
- Nessuna parte critica fuori dal volume assegnato alla stanza.
- Nessuna sovrapposizione tra gate, console, percorso, spawn e parti bloccanti.
- Percorso ingresso-uscita percorribile da un avatar standard.
- Test deterministico: lo stesso seed genera la stessa soluzione logica.

### Criteri di uscita

- 25.000+ generazioni consecutive senza soft-lock o eccezioni.
- Tutte le richieste di completamento vengono convalidate sul server.
- Un Operator modificato non può leggere dal DataModel gli indizi del Seer.
- Nessuna duplicazione di Shards in test di riconnessione, retry e ricevuta ripetuta.

---

## Milestone 2 — Qualità delle stanze e nuovi puzzle

**Durata:** settimane 4-6
**Priorità:** P0 per le stanze attuali, P1 per le nuove

### Matrice di playtest per ogni stanza

Ogni preset viene provato in:

- Solo;
- Gruppo da 2, 3, 4, 5 e 6 giocatori;
- ruolo Seer e Operator;
- tastiera/mouse, gamepad e touch;
- avatar R6 e R15, altezze/scale supportate;
- ping normale e simulato alto;
- morte, reset, disconnessione e riconnessione;
- ingresso anticipato, tentativo di saltare gate e aggiramento laterale;
- 20 seed manuali facili, medi e difficili, oltre alla suite automatica.

Per ogni test registrare: completata sì/no, tempo, errori, azioni, punti di confusione, exploit tentato e dispositivo.

### Obiettivi di bilanciamento delle stanze

Primi target da validare con playtest:

- percentuale di completamento per stanza: **65-85%** per utenti che l'hanno già incontrata almeno una volta;
- mediana di completamento: **20-35 secondi**;
- 95° percentile: meno di **60 secondi**;
- nessuna stanza con fallimenti oltre 1,5 volte la media delle altre;
- nessun seed risolvibile senza comunicazione in Gruppo;
- istruzioni comprese entro 10 secondi dopo la prima dimostrazione/tutorial.

### Correzioni alle stanze attuali

- **Signal Chamber:** aggiungere simboli e forme oltre ai colori; variare il mapping senza rendere leggibile la risposta all'Operator.
- **Invisible Floor:** validare il passaggio ordinato tra righe, impedire salti o attraversamenti laterali e offrire un'alternativa visiva ad alto contrasto.
- **Echo Sequence:** introdurre lunghezza/difficoltà controllata, feedback chiaro sulla posizione della sequenza e protezione dallo spam.
- **Frequency Vault:** evitare stati iniziali troppo vicini o identici all'obiettivo; garantire un numero minimo/massimo di rotazioni.
- **Power Grid:** generare lo stato iniziale applicando mosse valide da una soluzione nota; limitare configurazioni troppo lunghe o già risolte.

### Nuove stanze candidate

Implementarne inizialmente **2**, tenendo le altre in backlog:

1. **Mirror Relay** — il Seer vede destinazione e polarità del raggio; l'Operator ruota specchi. Si genera partendo da un percorso ottico valido e poi si alterano alcuni specchi.
2. **Rune Circuit** — il Seer vede la relazione tra simboli; l'Operator collega nodi o inserisce fusibili nell'ordine corretto. Simboli e pattern sostituiscono la dipendenza dal colore.
3. **Constellation Lock** — il Seer vede una costellazione da ricreare; l'Operator ruota anelli e allinea punti. Adatta a difficoltà progressive.
4. **Pressure Protocol** — due azioni devono avvenire in una finestra temporale descritta dal Seer. In Solo diventa una prova memoria-sequenza, non una richiesta simultanea impossibile.

Ogni nuova stanza deve avere varianti facili/medie, supporto Solo, telemetria propria e almeno 5.000 seed validati prima di entrare nella rotazione pubblica.

### Criteri di uscita

- Le 5 stanze attuali rispettano la matrice e gli obiettivi di completamento.
- Almeno 2 nuove stanze sono pronte, per un catalogo di 7.
- Tre run consecutive non possono proporre esattamente la stessa terna nello stesso ordine allo stesso giocatore, quando il catalogo lo consente.

---

## Milestone 3 — Progressione, economia e cosmetici

**Durata:** settimane 7-8
**Priorità:** P0

### Obiettivo economico

Il giocatore deve ottenere presto una scelta significativa, senza esaurire la collezione dopo poche run. La collezione non deve essere l'unico obiettivo: mastery dei puzzle, missioni, titoli e pass stagionale danno progressione a lungo termine.

### Lettura dei valori attuali

Oggi il catalogo soft-currency contiene 7 oggetti per un costo totale di **3.550 Shards**. Il profilo parte con 150, il Daily assegna 50 e una run Gruppo perfetta può assegnarne 50 (25 base + 10 zero errori + 15 Gruppo). Nel caso ideale rimangono quindi circa 67 vittorie perfette per comprare l'intero catalogo; con round da 81 secondi più transizioni, un giocatore intensivo può esaurire la progressione principale in poche ore. Il problema non è soltanto il payout: il catalogo e gli obiettivi permanenti sono ancora troppo piccoli.

### Prima proposta di bilanciamento

I valori sono un punto di partenza da simulare e poi sostituire con quelli derivati dalla telemetria:

| Elemento | Target iniziale |
|---|---:|
| Shards iniziali | 75-100 |
| Vittoria base | 25-30 |
| Bonus zero errori | 8-10 |
| Bonus gruppo | 8-12 |
| Daily base | 25-35 |
| Cosmetico introduttivo | 150-250 |
| Cosmetico comune | 300-500 |
| Cosmetico raro | 700-1.100 |
| Cosmetico epico | 1.400-2.200 |
| Cosmetico aspirazionale | 3.000-5.000 |

Target di esperienza:

- primo acquisto dopo **3-5 run riuscite** anche senza Daily;
- una scelta interessante ogni **6-10 run**, non tutto il catalogo;
- nessun giocatore può comprare ogni cosmetico di lancio con i soli Shards iniziali e poche ricompense giornaliere;
- il bonus Gruppo incoraggia la cooperazione ma non rende Solo economicamente inutile;
- evitare ricompense per fallimento facilmente automatizzabili; eventuale premio partecipazione è limitato e richiede progresso reale.

### Strumenti e contenuti

- Creare un simulatore dell'economia per 1, 7, 14 e 30 giorni con profili casual, regolari e intensivi.
- Registrare tutte le fonti e i sink: saldo iniziale, round, Daily, missioni, eventi, acquisti e rimborsi.
- Aggiungere almeno **12 cosmetici soft-currency al lancio** distribuiti tra Drone, Trail, Vision e Title.
- Aggiungere 2 nuovi slot visibili ma non invasivi, per esempio `Aura` e `ExtractionEffect`.
- Introdurre set coordinati e preview 3D prima dell'acquisto.
- Aggiungere ricompense di mastery non acquistabili per: 10/25/50 completamenti, zero-error run e mastery di ogni puzzle.
- Evitare che oggetti esclusivi di abilità vengano confusi con prodotti Robux.

### Criteri di uscita

- La simulazione non mostra completamento del catalogo core in meno di 30 giorni per un giocatore regolare.
- Il primo cosmetico è raggiungibile nella prima sessione lunga o nelle prime due sessioni normali.
- Nessuna fonte o sink manca dalla telemetria economica.
- Il catalogo offre almeno 3 scelte accessibili, 5 intermedie e 4 a lungo termine.

---

## Milestone 4 — Robux e affidabilità degli acquisti

**Durata:** settimana 9
**Priorità:** P0

### Offerta di lancio consigliata

- **3 Developer Product** ripetibili per pacchetti di Shards, con convenienza crescente ma senza salti eccessivi.
- **2-4 Game Pass cosmetici** permanenti oppure bundle coerenti, tra cui Void Drone e Prismatic Vision già predisposti.
- Nessun revive a pagamento, soluzione puzzle, tempo extra esclusivo o moltiplicatore che alteri le classifiche.
- Pass stagionale premium trattato separatamente nella milestone live-ops.

I prezzi Robux vanno scelti dopo aver verificato catalogo, durata media della sessione e valore percepito. Non inserirli nel codice come testo: mostrare sempre il prezzo restituito da MarketplaceService.

### Flusso tecnico

- Creare prodotti e pass nel Creator Dashboard e inserire gli ID per ambiente.
- Confermare sempre oggetto, tipo e prezzo nel prompt ufficiale Roblox.
- Gestire acquisto riuscito, annullato, pending, retry, giocatore disconnesso e ownership già esistente.
- Per Developer Product, concedere il bene solo tramite `ProcessReceipt` e rendere la registrazione idempotente.
- Per Game Pass, verificare ownership all'accesso e dopo l'acquisto; ripristinare automaticamente il cosmetico posseduto.
- Aggiungere telemetria funnel: visualizzazione, click, prompt, acquisto, annullamento e accredito completato.
- Effettuare test reali in un universo di staging, non soltanto in Studio.

### Criteri di uscita

- 100% delle ricevute di test vengono accreditate una sola volta.
- Un acquisto interrotto viene recuperato senza assistenza manuale.
- Ogni cosmetico premium posseduto viene ripristinato al nuovo accesso.
- Shop e gioco dichiarano chiaramente che i prodotti sono cosmetici.

---

## Milestone 5 — Polish estetico, geometria e UI

**Durata:** settimane 9-10, in parallelo ai test Marketplace
**Priorità:** P0

### Ambiente

- Definire volumi/footprint ufficiali per lobby, laboratorio e ogni stanza.
- Aggiungere un controllo automatico delle intersezioni usando overlap query sulle parti marcate come muri, gate, console, spawn e percorsi.
- Controllare compenetrazione tra decorazioni e gameplay, z-fighting, parti fluttuanti, aperture laterali e oggetti che bloccano avatar grandi.
- Uniformare griglia, spessori, materiali, palette, luci e densità degli effetti.
- Creare una passata specifica di performance: numero parti, luci, particelle, trasparenze e uso memoria su dispositivo mobile debole.
- Rendere chiaramente distinti zona lobby, transizione e camere di spedizione.

### UI

- Definire una mappa dei layer: HUD di round, prompt/notice, modali e overlay visione, con ZIndex centralizzati.
- Usare safe-area e inset del dispositivo; nessun pulsante essenziale sotto notch, barra Roblox o controlli touch.
- Impedire l'apertura simultanea di shop, stats, wardrobe e HUD incompatibili.
- Ridimensionare catalogo e card in base alla larghezza: una colonna su telefono, due su tablet/desktop.
- Verificare testo lungo, localizzazione futura, scroll, focus gamepad e dimensione minima dei target touch.
- Fornire opzioni: riduzione motion, flash e particelle; alto contrasto; volume separato; indizi con simboli.

### Matrice visiva obbligatoria

- Desktop 1280×720, 1920×1080 e ultrawide.
- Telefono piccolo e grande, portrait bloccato/gestito e landscape.
- Tablet 4:3.
- Gamepad con navigazione completa senza mouse.
- UI scale Roblox minima e massima supportata.
- Screenshot della stessa schermata a ogni risoluzione per confronto regressivo.

### Criteri di uscita

- Zero sovrapposizioni tra controlli essenziali in tutte le risoluzioni target.
- Zero intersezioni P0 tra parti di gameplay in lobby e spedizione.
- Tutti i menu sono completabili con touch e gamepad.
- Frame rate e memoria rispettano il budget definito sul dispositivo mobile di riferimento.

---

## Milestone 6 — Eventi, missioni e pass stagionale

**Durata:** settimane 11-12
**Priorità:** P1 per il lancio, P0 prima della prima stagione

### Fondazione live-ops

- Configurazione eventi con ID, versione, data UTC di inizio/fine, feature flag, missioni, ricompense e fallback.
- Salvataggio separato per progressione permanente, stagione corrente e receipt premium.
- Missioni server-authoritative basate sugli eventi già tracciati: completa stanze, gioca in Gruppo, zero errori, usa diversi puzzle.
- Nessuna missione deve incentivare spam, abbandono del team o sabotaggio.
- Possibilità di disattivare rapidamente stanza, missione o ricompensa difettosa.

### Stagione 1 consigliata

- Durata iniziale: **8 settimane**.
- 30 livelli, con traccia gratuita e premium.
- XP da missioni giornaliere, settimanali e gioco normale; limite alle attività ripetitive abusabili.
- Ricompense: Shards, palette, Trail, Drone, Title, Aura ed Extraction Effect.
- La traccia premium contiene soltanto cosmetici e valuta, mai vantaggi nei puzzle.
- Prevedere recupero delle missioni settimanali per chi entra tardi; evitare obbligo di accesso quotidiano perfetto.
- Nessuna ricompensa premium viene persa per un errore di salvataggio o cambio stagione.

### Calendario eventi iniziale

1. **Launch Anomaly** (2 settimane): missioni comunitarie/personali e una variante estetica delle stanze.
2. **Halloween / Fractured Signals**: modificatori visivi, 1 stanza temporanea o variante, set cosmetico a tema.
3. **Winter Convergence**: lobby stagionale, missioni cooperative e ricompense non basate solo sul grind.
4. **Weekend Mutations** ricorrenti: ordine stanze, difficoltà o regole modificate senza alterare la sicurezza della soluzione.

Ogni evento deve essere preparato almeno due settimane prima, provato in staging e accompagnato da piano di attivazione, rollback e fine evento.

### Criteri di uscita

- Cambio stagione testato avanti e indietro senza perdita di progressione permanente.
- XP e reward non possono essere concessi dal client.
- Le missioni si aggiornano una sola volta per evento valido.
- Evento e pass possono essere disattivati senza bloccare lobby o round.

---

## Milestone 7 — Alpha, beta e soft launch

**Durata:** settimane 13-16
**Priorità:** P0

### Alpha chiusa

Campione: 10-20 tester che non hanno sviluppato il gioco.

Obiettivi:

- osservare il primo accesso senza spiegazioni vocali;
- verificare tutorial, comprensione dei ruoli e comunicazione;
- raccogliere almeno 30 completamenti per stanza;
- classificare ogni bug P0 blocco/data loss/exploit, P1 gameplay/UX, P2 polish.

Gate alpha:

- zero P0 aperti;
- almeno 80% dei tester avvia una spedizione senza aiuto esterno;
- almeno 70% comprende la differenza Seer/Operator dopo la prima run;
- nessuna stanza fuori dagli intervalli di difficoltà concordati.

### Beta

Campione: 50-200 utenti, server pubblici controllati.

Obiettivi:

- testare matchmaking 2-6, server pieni, abbandoni e riconnessioni;
- misurare inflazione Shards, acquisti soft, utilizzo cosmetici e funnel Robux di staging;
- verificare mobile e gamepad su dispositivi reali;
- test di carico DataStore, Analytics e receipt.

Gate beta:

- nessuna perdita o duplicazione dati;
- almeno 99,5% di sessioni senza errore server fatale;
- tasso di completamento round complessivo 55-75%;
- nessun preset scelto/abbandonato in modo anomalo rispetto agli altri;
- tutorial, shop e round completi su tutti i dispositivi supportati.

### Soft launch

Durata minima: 1-2 settimane senza campagne grandi.

Primi target da usare come segnali, non come garanzia di mercato:

- almeno 3 round medi per sessione dei giocatori che iniziano una run;
- ritorno D1 iniziale ≥20% e D7 ≥5-8%, da confrontare per sorgente e dispositivo;
- meno dell'1% di round con errore tecnico o soft-lock;
- ricevute Robux accreditate correttamente al 100%;
- nessun exploit economico confermato;
- economia entro ±15% rispetto alla velocità di guadagno simulata.

Se un gate fallisce, si corregge il sistema responsabile e si ripete la finestra di misurazione. Non si compensa una retention debole aumentando aggressivamente ricompense o prompt Robux.

---

## Milestone 8 — Release candidate e lancio

**Durata:** settimane 16-18
**Priorità:** P0

### Checklist release candidate

- Freeze di codice 3-5 giorni prima del lancio, salvo correzioni P0.
- Test completo di nuova utenza, utenza esistente e migrazione dati.
- Test di Solo e Gruppo con tutti e 7 i preset.
- Marketplace reale verificato con acquisto, annullamento e rejoin.
- Thumbnail, icona, descrizione, privacy, età/linee guida e localizzazione base completate.
- Tutorial, impostazioni accessibilità, report/feedback e link community pronti.
- Dashboard live con errori, DataStore, round, puzzle, economia e acquisti.
- Runbook con responsabile, rollback, disattivazione contenuti e comunicazione incidente.
- Evento Launch Anomaly già testato ma attivabile separatamente dal deploy principale.

### Gate finale Go/No-Go

**Go** soltanto se:

- zero bug P0 e nessun P1 che impedisca acquisto, salvataggio, matchmaking o completamento;
- suite seed, sicurezza e UI completamente verde;
- dati e receipt hanno superato retry/rejoin;
- prestazioni mobili rispettano il budget;
- almeno una settimana di soft launch stabile;
- contenuto e supporto delle prime due settimane sono già pronti.

---

## Ritmo dopo il lancio

- **Ogni giorno nella prima settimana:** errori, receipt, DataStore, exploit, soft-lock e anomalie economiche.
- **Ogni settimana:** rotazione missioni, analisi dei funnel, tuning controllato e correzioni.
- **Ogni 2-3 settimane:** piccolo evento/mutazione, nuovo cosmetico o variante stanza.
- **Ogni 6-8 settimane:** stagione, nuova stanza o aggiornamento di contenuto significativo.
- Cambiare una variabile economica alla volta e annotare versione/data per attribuire l'effetto.

## Ordine operativo immediato

Stato al 2026-08-02: punti 1-4 completati nel codice e verificati dalla suite Studio; il prossimo blocco e il punto 5.

1. Costruire QA mode, seed riproducibili e validatore delle stanze.
2. Spostare gli indizi segreti fuori dagli oggetti replicati e completare le validazioni server.
3. Eseguire la matrice sulle 5 stanze esistenti e correggere soft-lock/skip.
4. Implementare Mirror Relay e Rune Circuit usando il nuovo contratto.
5. Simulare e playtestare l'economia; solo dopo fissare valori e prezzi Robux.
6. Espandere catalogo e preview cosmetici.
7. Completare responsive UI e collision audit.
8. Implementare missioni/event config/pass stagionale.
9. Alpha, beta, soft launch e release secondo i gate sopra.

## Deliverable di controllo

Al termine di ogni milestone devono esistere:

- build/versione testata;
- report dei test e bug rimasti;
- metriche confrontate con i gate;
- decisione Go/No-Go motivata;
- backlog aggiornato con P0, P1 e P2;
- rollback o feature flag per ogni nuovo sistema ad alto rischio.
