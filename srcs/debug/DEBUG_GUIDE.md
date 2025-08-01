# Sistema di Debug - Guida Rapida

## 🎯 Panoramica

Hai ora a disposizione un sistema di debug completo che ti permette di controllare tutti i messaggi di debug senza rimuovere il codice dai tuoi script.

## 🚀 Utilizzo Immediato

### Sostituire i `print()` esistenti

**Prima (vecchio modo):**
```gdscript
print("Giocatore si è mosso a: ", position)
print("Errore nel caricamento mappa")
```

**Dopo (nuovo modo):**
```gdscript
GlobalVariables.d_player_input("Giocatore si è mosso a: " + str(position))
GlobalVariables.d_error("Errore nel caricamento mappa", "MAP_GENERATION")
```

### Funzioni principali

```gdscript
# Livelli di debug (dal più importante al meno importante)
GlobalVariables.d_error("Errore critico!", "CATEGORY")      # 🔴 Sempre importante
GlobalVariables.d_warning("Attenzione!", "CATEGORY")        # 🟡 Problemi potenziali
GlobalVariables.d_info("Informazione generale", "CATEGORY") # 🔵 Eventi importanti
GlobalVariables.d_debug("Debug dettagliato", "CATEGORY")    # 🟢 Debug normale
GlobalVariables.d_verbose("Trace dettagliato", "CATEGORY")  # ⚪ Tutto

# Scorciatoie per categorie comuni
GlobalVariables.d_player_input("Movimento giocatore")
GlobalVariables.d_menu("Interazione menu")
GlobalVariables.d_network("Evento di rete")
GlobalVariables.d_map_gen("Generazione mappa")
GlobalVariables.d_game_state("Cambio stato gioco")
GlobalVariables.d_level_mgmt("Gestione livelli")
```

## ⚙️ Configurazione

### Cambiare preset debug

Modifica il file `global_script/debug_config.gd`:

```gdscript
# Cambia questo valore per controllare il debug
const CURRENT_PRESET: DebugPreset = DebugPreset.DEVELOPMENT
```

### Preset disponibili

| Preset | Quando usarlo |
|--------|---------------|
| `RELEASE` | 🚀 Build finale - nessun debug |
| `BASIC` | 🔧 Solo errori e warning |
| `DEVELOPMENT` | 💻 Sviluppo normale |
| `FULL_DEBUG` | 🐛 Debug intensivo |
| `CUSTOM` | 🎛️ Configurazione personalizzata |

## 📋 Esempi Pratici

### Debugging del movimento giocatore
```gdscript
func move_player(direction: Vector2):
    GlobalVariables.d_player_input("Tentativo movimento: " + str(direction))
    
    if not can_move(direction):
        GlobalVariables.d_warning("Movimento bloccato", "PLAYER_INPUT")
        return
    
    position += direction
    GlobalVariables.d_debug("Nuova posizione: " + str(position), "PLAYER_INPUT")
```

### Debugging del caricamento mappe
```gdscript
func load_map(map_path: String):
    GlobalVariables.d_info("Caricando mappa: " + map_path, "MAP_GENERATION")
    
    if not FileAccess.file_exists(map_path):
        GlobalVariables.d_error("File mappa non trovato: " + map_path, "MAP_GENERATION")
        return false
    
    GlobalVariables.d_debug("Mappa caricata con successo", "MAP_GENERATION")
    return true
```

### Debugging della rete
```gdscript
func _on_peer_connected(peer_id: int):
    GlobalVariables.d_network("Peer connesso: " + str(peer_id))
    
    if authenticated_peers.has(peer_id):
        GlobalVariables.d_warning("Peer già autenticato", "NETWORK")
        return
    
    GlobalVariables.d_verbose("Iniziando autenticazione per peer: " + str(peer_id), "NETWORK")
```

## 🔧 Configurazione Avanzata

### Debug solo per specifiche categorie
```gdscript
# In debug_config.gd, usa CUSTOM preset:
const CURRENT_PRESET: DebugPreset = DebugPreset.CUSTOM
const CUSTOM_DEBUG_LEVEL = Level.DEBUG
const CUSTOM_CATEGORIES = {
    "PLAYER_INPUT": true,    # Solo debug del giocatore
    "MENU": true,            # Solo debug del menu
    "NETWORK": false,        # Disabilita debug di rete
    "MAP_GENERATION": false, # Disabilita debug mappe
    # ... altre categorie = false
    "GENERAL": true
}
```

### Controllo runtime
```gdscript
# Accesso diretto al DebugManager
var debug_manager = get_node("/root/DebugManager")

# Abilita/disabilita categorie a runtime
debug_manager.enable_category("PLAYER_INPUT")
debug_manager.disable_category("MENU")

# Cambia livello debug a runtime
debug_manager.set_level(debug_manager.Level.VERBOSE)

# Mostra stato attuale
debug_manager.print_debug_status()
```

## 📚 Migrazione dei Script Esistenti

### Step 1: Identifica i print
Cerca tutti i `print()` nei tuoi script

### Step 2: Categorizza
Decidi quale categoria e livello usare:
- Errori → `d_error`
- Warning → `d_warning`  
- Info generali → `d_info`
- Debug normale → `d_debug`
- Trace dettagliato → `d_verbose`

### Step 3: Sostituisci
```gdscript
# Prima
print("Debug message")

# Dopo  
GlobalVariables.d_debug("Debug message", "APPROPRIATE_CATEGORY")
```

## 🎮 Durante lo Sviluppo

### Per lavorare normalmente
```gdscript
const CURRENT_PRESET: DebugPreset = DebugPreset.DEVELOPMENT
```

### Per debug intensivo di una feature
```gdscript
const CURRENT_PRESET: DebugPreset = DebugPreset.FULL_DEBUG
```

### Per build di release
```gdscript
const CURRENT_PRESET: DebugPreset = DebugPreset.RELEASE
```

## 📁 File del Sistema

- `debug_manager.gd` - Gestione centrale del debug
- `debug_config.gd` - Configurazioni e preset
- `global_variables.gd` - Funzioni helper (d_debug, d_error, etc.)
- `DEBUG_SYSTEM.md` - Documentazione completa
- `debug_test.gd` - Script di test
- `debug_control_panel.gd` - Pannello di controllo UI (opzionale)

## 🚨 Importante

1. **Non rimuovere** i messaggi di debug dal codice
2. **Cambia solo** il preset in `debug_config.gd`
3. **Usa categorie appropriate** per organizzare i messaggi
4. **Testa sempre** con preset RELEASE prima del deploy finale

Il sistema è già configurato e pronto all'uso! 🎉
