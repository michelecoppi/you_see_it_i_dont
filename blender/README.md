# Mappe in Blender

La struttura e la grafica di **lobby** e **laboratorio della spedizione** sono modellate in Blender e poi esportate in
Roblox come parti native (niente mesh da caricare, niente asset ID): lo script di export legge la scena e scrive due
moduli Luau che il server trasforma in `Part` all'avvio.

```
blender/generate_maps.py  ──►  blender/maps.blend  ──►  blender/export_roblox.py  ──►  src/server/MapLayouts/*.luau
     (scena procedurale)        (modificabile a mano)        (Blender → Luau)            (MapLayoutBuilder.luau)
```

| File | Ruolo |
|---|---|
| `rbx.py` | Palette materiali Roblox, conversione assi, primitive (`block`, `cylinder`, `ball`, `ring`, `segment`). |
| `generate_maps.py` | Costruisce la scena da zero e salva `maps.blend`. **Sovrascrive** il file. |
| `maps.blend` | La scena: collezioni `Lobby`, `Expedition` e `Reference (code-built, not exported)`. |
| `export_roblox.py` | Esporta `Lobby` → `LobbyLayout.luau` ed `Expedition` → `ExpeditionLayout.luau`. |
| `render_previews.py` | Render Cycles delle viste principali in `docs/images/blender/`. |

## Comandi

Con Blender installato (4.2 o più recente):

```bash
blender -b -P blender/generate_maps.py                 # rigenera la scena procedurale
blender -b blender/maps.blend -P blender/export_roblox.py
blender -b blender/maps.blend -P blender/render_previews.py
```

Oppure senza interfaccia, con il modulo Python di Blender (`pip install bpy`, Python 3.11):

```bash
python3 blender/generate_maps.py
python3 blender/export_roblox.py
python3 blender/render_previews.py --quick            # --quick = bassa risoluzione
```

Dopo l'export basta sincronizzare con Rojo: al prossimo avvio `MapBuilder` e `LobbyBuilder` costruiscono la nuova mappa.

## Modificare la mappa a mano

1. Apri `blender/maps.blend`.
2. Sposta, scala, ruota, duplica o elimina oggetti dentro le collezioni `Lobby` ed `Expedition` (le sotto-collezioni
   diventano `Folder` in Roblox).
3. Per un oggetto nuovo usa un **Cube**, un **Cylinder** o una **UV Sphere** e assegna uno dei materiali della palette
   (il nome del materiale Blender decide materiale e colore Roblox).
4. Salva ed esegui `export_roblox.py`.

Attenzione: rieseguire `generate_maps.py` ricrea la scena da zero e cancella le modifiche manuali. Se modifichi il file a
mano, da quel momento considera `maps.blend` la fonte principale.

### Convenzioni

- 1 unità Blender = 1 stud. Blender è Z-up, Roblox Y-up: un punto Roblox `(x, y, z)` sta in Blender a `(x, -z, y)`.
- Le coordinate sono assolute nel mondo Roblox: la lobby è centrata in `x = 100`, il laboratorio in `x = 0`.
- Sono supportate solo le forme primitive di Roblox; mesh modificate in Edit Mode vengono esportate come il loro
  bounding box.
- Proprietà personalizzate (pannello *Object Properties → Custom Properties*):

| Proprietà | Effetto in Roblox |
|---|---|
| `rbx_name` | Nome della parte (altrimenti il nome dell'oggetto senza `.001`). |
| `rbx_shape` | `Block`, `Cylinder` o `Ball`. |
| `rbx_collide` | `false` = attraversabile (e anche esclusa da query/touch, salvo `rbx_query = true`). |
| `rbx_transparency` | Sovrascrive la trasparenza del materiale. |
| `rbx_shadow` | Forza `CastShadow`. |
| `rbx_role` | Attributo `GeometryRole` letto dalla validazione di `RoomGenerator` (es. `Support`). |
| `rbx_light` | `Point:range:brightness` oppure `Surface:range:brightness:Face:angle`. |
| `rbx_skip` | Non esportare (usato dai proxy di riferimento). |

### Nomi da non cambiare

- Lobby: `CeilingLightStrip`, `LobbyWallAccent`, `ColumnGlow` vengono ricolorati dal **Reality Mixer**.
- Laboratorio: `Floor` (con `rbx_role = Support`) è il pavimento ignorato dalla validazione geometrica.

### Vincoli di gameplay

La collezione `Reference (code-built, not exported)` mostra in wireframe gli ingombri delle parti create via codice
(portali, bacheche, console, camere, cancelli, estrazione). Nel laboratorio le parti **collidibili** non devono entrare nel
volume interno (`|x| < 34`, `-68 < z < 82`, `0.5 < y < 17.5`) vicino a cancelli, console e percorsi: la validazione di
`RoomGenerator` rifiuterebbe la spedizione. Le decorazioni interne vanno quindi impostate con `rbx_collide = false`.
Larghezza (68) e lunghezza (150) del guscio devono restare invariate perché i cancelli delle camere chiudono tutta la
larghezza.
