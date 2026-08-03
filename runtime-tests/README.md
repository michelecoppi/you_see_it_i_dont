# Runtime QA matrix

Build `runtime-tests.project.json`, open the generated place in Roblox Studio and start sessions with 1, 2 and 6 clients.
The server waits until the connected-client count is stable for 15 seconds, generates every preset twice at each
`Easy`, `Normal` and `Hard` level with seed `SEED-0000424242`, validates difficulty propagation, role
markers and structure, requires an acknowledgement from every real client, emits QA/telemetry logs and verifies the
shared client-error redaction path. A successful session ends with:

```text
[QA][Matrix] complete | result=PASS | clients=N cases=42/42 errorProbe=true
```
