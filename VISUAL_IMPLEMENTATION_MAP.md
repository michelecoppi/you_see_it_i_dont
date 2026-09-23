# Mappa dei riferimenti grafici

Audit del 23 settembre 2026 delle immagini in `docs/images` e dei builder/UI esistenti. I concept sono direzione artistica; le scritte e i layout dei puzzle illustrati non sostituiscono le regole attuali.

| Riferimento | Implementazione Roblox prevista | Sistema esistente / file | Rischio gameplay | Rischio prestazioni |
|---|---|---|---|---|
| `art_direction.png`: laboratorio metallico, ciano fisico, viola nascosto, arancione di avviso | Tema condiviso, luce più neutra, bagliore contenuto, decorazioni senza collisione | `MapBuilder`, `LobbyBuilder`, `RoomGenerator`, client UI; nuovo `VisualTheme` | Medio: contrasto di indizi e colori | Medio: luci e trasparenze |
| `lobby.png`: portali, percorso centrale, postazioni laterali | Rilievi, cornici, segnaletica e percorsi; mantenere posizioni e prompt | `LobbyBuilder` | Medio: accesso alle postazioni | Medio: istanze decorative |
| `expedition_lab.png`: tre camere e estrazione | Archi, guide luminose e gerarchia delle soglie nelle stesse coordinate | `MapBuilder`, `RoomGenerator` | Alto: collisioni e stanze future | Medio: luci |
| `rooms/room_signal_chamber.png`: emettitori e console | Basi a più livelli, indicatori e clue locale esistente | `RoomGenerator` | Alto: sequenza e segretezza | Basso |
| `rooms/room_invisible_floor.png`: chasm e percorso rivelato | Cornice di contenimento e tracce locali solo al Seer | `RoomGenerator`, `SeerClueRenderer` | Alto: percorso segreto e bypass | Basso |
| `rooms/room_echo_sequence.png`: pad di colore | Cornici e indicatori sui pad esistenti | `RoomGenerator` | Medio: colori distinti | Basso |
| `rooms/room_frequency_vault.png`: quadranti | Marcatori di corsia sulle console attuali | `RoomGenerator` | Medio: non suggerire passi errati | Basso |
| `rooms/room_power_grid.png`: nodi e circuiti | Collegamenti decorativi e stato visivo dei nodi | `RoomGenerator` | Medio: leggibilità dello stato | Basso |
| `hud_ui.png`: pannelli scuri con bordo ciano/viola | Tema UI e gerarchia del timer, dettagli a pressione, menu | `init.client`, `LobbyController` | Medio: touch e gamepad | Basso |
| `player_roles.png`: osservatore viola, operatore ciano | Trattamento HUD e indicatore locale dell'avatar, senza avatar sostitutivi | `init.client` | Alto: non rivelare clue ad altri ruoli | Basso |
| `cosmetic_drone.png`: sfera bianca con occhio e proiettore | Guscio sferico, occhio, moduli laterali e proiettore con poche parti | `SoloDrone` | Basso: solo estetica | Basso |
| `game_icon.png`: branding | Caricamento manuale nel Creator Dashboard | Documentazione | Nessuno | Nessuno |

Già presenti: tutti i punti di interazione della lobby, cinque puzzle di base più Mirror Relay e Rune Circuit, ruolo Seer/Operator, ALT VISION, HUD compatto e drone Solo. Parziali: colore e geometria delle stanze, portali, luci, UI. Mancanti: tema condiviso e dettagli architettonici che rendano la direzione artistica riconoscibile. Le immagini della Frequency Vault e del Power Grid mostrano topologie diverse dal puzzle implementato: la resa sarà adattata alle regole correnti. Nessuna immagine verrà usata come texture di gioco.
