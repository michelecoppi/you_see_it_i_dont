# Alpha playtest guidato

Questo protocollo serve a ottenere prove sul ciclo completo. I test automatici di seed e struttura sono documentati in `PLAYTEST_MATRIX.md`; non sostituiscono l'osservazione di giocatori reali.

## Preparazione

1. Pubblicare una build privata con numero di build registrato e telemetria di test separata.
2. Reclutare almeno 10 giocatori che non abbiano sviluppato il gioco. Non spiegare i puzzle prima della prima run.
3. Usare `PLAYTEST_MATRIX.md` per distribuire i sette preset tra Solo e gruppi, le tre difficoltà e gli input desktop, touch e gamepad. Annotare sempre seed e build.
4. Per il controllo visivo, raccogliere screenshot di lobby, ogni stanza, HUD, Cosmetics e My Stats su desktop, telefono piccolo e tablet. Misurare FPS e memoria sul telefono di riferimento.

## Sessione individuale

| Momento | Azione del tester | Da osservare |
|---|---|---|
| Primo accesso | Entrare senza istruzioni esterne | Capisce dove iniziare entro 60 secondi? |
| Prima spedizione | Scegliere Solo o Gruppo | Sa descrivere Seer e Operator? Trova i controlli? |
| Puzzle | Completare tre stanze | Tempi, errori, comunicazione, punti in cui si blocca |
| Interruzione | Morte/reset o disconnessione concordata | Il round e il profilo restano coerenti? |
| Lobby | Aprire shop, statistiche e Daily Reactor | I pulsanti sono leggibili e raggiungibili? |
| Ritorno | Rientrare con lo stesso account | Shards, cosmetici e statistiche sono invariati? |

Per ogni test compilare la scheda in `PLAYTEST_MATRIX.md` e annotare il tempo fino alla prima spedizione, l'esito del round, i puzzle incontrati e un commento testuale del giocatore. Chiedere solo alla fine: «Che cosa pensavi di dover fare?» e «Dove ti sei fermato?».

## Gate prima dell'apertura pubblica

- Nessun bug che blocca round, salvataggio, coda o acquisti.
- Almeno 80% dei nuovi tester avvia una spedizione senza aiuto esterno.
- Almeno 70% spiega correttamente la differenza tra Seer e Operator dopo la prima run.
- HUD e menu completi su telefono e gamepad; nessun comando essenziale coperto dai controlli Roblox.
- Nessun indizio segreto visibile al ruolo sbagliato, anche dopo reset e cambio stanza.
- Nessun calo di prestazioni persistente sul dispositivo mobile di riferimento.

Se un gate non passa, correggere il problema e ripetere il caso con persone che non hanno visto la versione precedente. Segnare esplicitamente `NON TESTATO` dove mancano tester o dispositivi: una build riuscita non equivale a un playtest.
