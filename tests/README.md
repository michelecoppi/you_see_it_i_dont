# Luau smoke tests

This suite has no package dependencies. Build `tests.project.json` with Rojo, open the generated place in Roblox Studio,
and start a server session. The `Tests` server script fails with an error if an assertion does not pass and prints
`[QA][Tests] receipts, extraction security, remote guard, interactions, seeds, puzzles and RoomGenerator passed` on success. The
suite covers seed normalization, stable identifiers, deterministic preset order, direct placement of a forced QA
preset, structural validation and two identical generations with seed `SEED-0000424242` for every preset. It also
audits 5.000 seed per preset and difficulty (`Easy`, `Normal`, `Hard`) through the pure `GenerateSolution`,
`BuildInitialState` and `Validate` contract (105.000 generations total across seven presets), verifies
that initial states are not solved, checks the explicit difficulty constraints and verifies logical reachability. It also exercises
the server console validator against inactive rooms, foreign consoles, missing console markers and excessive distance.
`RemoteGuard.spec` fuzzes invalid types, oversized strings, unknown actions and extra fields, then verifies independent
rate limits for lobby, Alternate Vision, economy and puzzle interactions, global flood protection and sampled logs.
`ReceiptLedger.spec` verifica retry, riconnessione e una cronologia superiore al precedente limite di 50 ricevute.
`RoundCompletionValidator.spec` copre progresso incompleto, tempo implausibile, posizione distante e goal bloccato.
Mirror Relay e Rune Circuit verificano inoltre percorso noto, numero di azioni, reset e determinismo.

Example build command:

```sh
rojo build tests.project.json --output tests.rbxlx
```

The test place is separate from `default.project.json`, so the runner is not included in normal game builds.
