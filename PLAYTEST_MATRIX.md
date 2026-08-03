# Milestone 2 - matrice di playtest

## Stato automatico

| Copertura | Stato | Evidenza |
|---|---|---|
| 7 preset x Easy/Normal/Hard x 5.000 seed | PASS | 105.000 generazioni pure |
| 7 preset x Easy/Normal/Hard x 2 run deterministiche | PASS | 42/42 integrazioni Studio |
| Runtime 1, 2 e 6 client | PASS | 126/126 casi, 378/378 ACK, probe 9/9 |
| Receipt retry e riconnessione | PASS | cronologia da 125 ricevute senza doppio accredito |
| Estrazione anti-teleport | PASS | progresso, tempo e posizione convalidati sul server |

## Casi manuali da eseguire per ogni preset

Usare almeno un seed registrato per livello e annotare sempre build, seed, preset, difficolta e ruolo.

| Asse | Valori richiesti | Stato |
|---|---|---|
| Gruppo | Solo, 2, 3, 4, 5, 6 | Da eseguire |
| Ruolo | Solo, Seer, Operator | Da eseguire |
| Input | tastiera/mouse, gamepad, touch | Da eseguire |
| Avatar | R6, R15, scala minima e massima supportata | Da eseguire |
| Rete | ping normale, latenza alta simulata | Da eseguire |
| Continuita | morte, reset, disconnessione, riconnessione | Da eseguire |
| Anti-cheese | salto gate, ingresso laterale, teleport, spam | Da eseguire |
| Difficolta | 20 seed Easy, 20 Normal, 20 Hard | Da eseguire |

## Scheda singolo test

| Campo | Valore |
|---|---|
| Data / tester | |
| Build / ambiente | |
| Seed / preset / difficolta | |
| Gruppo / ruolo | |
| Input / dispositivo / avatar | |
| Ping | |
| Completata | si / no |
| Tempo stanza | |
| Interazioni / errori | |
| Istruzioni comprese entro 10 secondi | si / no |
| Punto di confusione | |
| Exploit tentato / risultato | |
| Note | |

## Target di uscita

- Completamento 65-85% dopo il primo incontro.
- Mediana per stanza 20-35 secondi; percentile 95 sotto 60 secondi.
- Nessuna stanza oltre 1,5 volte la media dei fallimenti.
- In Gruppo la soluzione richiede comunicazione tra Seer e Operator.
- Istruzioni comprese entro 10 secondi dopo la prima dimostrazione.

## Correzioni integrate prima del playtest manuale

- Signal Chamber ed Echo Sequence usano parole e forme distinte oltre al colore.
- Invisible Floor richiede le cinque righe in ordine per lo stesso Operator, blocca salti e aggiramenti laterali e
  mostra al Seer numeri di riga ad alto contrasto.
- Echo Sequence mostra il progresso pubblico `STEP n / totale` e conserva cooldown e blocco spam server-side.
- Frequency Vault genera una distanza di rotazione esatta per livello, mai gia risolta.
- Power Grid parte da mosse valide verso una soluzione nota e verifica il minimo numero di azioni.
- Mirror Relay e Rune Circuit sono nella rotazione, con varianti Easy/Normal/Hard e indizi non basati solo sul colore.
