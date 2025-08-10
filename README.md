# Storage System v2.0 - CC:Tweaked Modular Edition

Un sistema storage avanzato per ComputerCraft: Tweaked con interfaccia GUI moderna e controllo tramite mouse.

## Caratteristiche

- **Interfaccia GUI Moderna**: Design grafico intuitivo con mouse support
- **Filtri Avanzati**: Filtra gli oggetti per categoria e ricerca testuale
- **Trasferimenti Intelligenti**: Trasferisci quantità precise dalla storage all'output
- **Organizzazione Automatica**: Consolida automaticamente gli oggetti simili
- **Supporto Rete**: Funziona sia con peripheral diretti che reti wireless
- **Modular Design**: Architettura modulare per facile manutenzione

## Installazione Rapida

### Metodo 1: Installer Automatico (Raccomandato)
```lua
wget run https://raw.githubusercontent.com/[YOUR_REPO]/main/installer.lua
```

### Metodo 2: Download Manuale
```lua
wget https://raw.githubusercontent.com/[YOUR_REPO]/main/storage_main.lua
wget https://raw.githubusercontent.com/[YOUR_REPO]/main/storage_core.lua
wget https://raw.githubusercontent.com/[YOUR_REPO]/main/storage_gui.lua
wget https://raw.githubusercontent.com/[YOUR_REPO]/main/storage_utils.lua
```

## Setup Iniziale

1. **Configura l'Hardware:**
   - Advanced Computer o Computer normale
   - Almeno una chest per storage
   - Una chest separata per output
   - Modem wireless (opzionale, per reti)

2. **Avvia il Programma:**
   ```lua
   storage_main
   ```
   oppure:
   ```lua
   lua storage_main.lua
   ```

3. **Prima Configurazione:**
   - Il sistema rileverà automaticamente le chest
   - Usa il bottone "OUTPUT" per selezionare la chest di destinazione
   - Il sistema scansionerà automaticamente l'inventario

## Controlli

### Mouse
- **Click su Item**: Seleziona un oggetto per il trasferimento
- **Click su Categorie**: Filtra gli oggetti per tipo
- **Scroll**: Scorri la lista degli oggetti
- **Click sui Bottoni**: Interagisci con i controlli

### Tastiera
- **Q**: Esci dal programma
- **Backspace**: Cancella caratteri nella ricerca
- **Numeri**: Inserisci quantità durante i trasferimenti
- **Enter**: Conferma trasferimento
- **Escape**: Annulla operazione

## Bottoni Interfaccia

- **OUTPUT**: Cambia chest di output
- **REFRESH**: Aggiorna inventario
- **ORGANIZE**: Consolida oggetti simili
- **DEBUG**: Mostra informazioni debug

## Categorie Filtri

| Icona | Categoria | Descrizione |
|-------|-----------|-------------|
| * | TUTTI | Mostra tutti gli oggetti |
| T | UTENSILI | Tools, armi, attrezzi |
| M | METALLI | Lingotti, placche, ingranaggi |
| G | GEMME | Diamanti, smeraldi, cristalli |
| O | MINERALI | Minerali grezzi, carbone, redstone |
| W | LEGNO | Legname, tavole, bastoni |
| F | CIBO | Semi, cibo, ingredienti |
| B | BLOCCHI | Blocchi da costruzione |
| E | TECH | Macchine, circuiti, componenti |
| L | LIQUIDI | Secchi, bottiglie, fluidi |

## Requisiti Sistema

- **ComputerCraft: Tweaked** (ultima versione)
- **Minecraft**: 1.16+ (raccomandato)
- **HTTP abilitato** in `computercraft.cfg`:
  ```
  http_enable=true
  ```

## Struttura Moduli

```
storage_system/
├── storage_main.lua    # Entry point e loop principale
├── storage_core.lua    # Logica core e gestione storage  
├── storage_gui.lua     # Interfaccia grafica e eventi
├── storage_utils.lua   # Funzioni utility e helper
└── installer.lua       # Script di installazione automatica
```

## Configurazione Avanzata

### Modi di Funzionamento
- **Diretto**: Peripheral collegati direttamente al computer
- **Rete**: Peripheral connessi via modem wireless

### Compatibilità Peripheral
- `minecraft:chest` - Chest vanilla
- `*chest*` - Chest di mod (Iron Chests, etc.)
- `*barrel*` - Barrel vari
- `*shulker*` - Shulker box

## Risoluzione Problemi

### Errore "HTTP non abilitato"
Modifica `config/computercraft.cfg`:
```
http_enable=true
```

### Nessuna chest trovata
- Verifica connessioni peripheral
- Controlla cavi/modem di rete
- Usa il comando DEBUG per diagnostica

### Errori di moduli mancanti
- Reinstalla con l'installer automatico
- Verifica che tutti i 4 file siano presenti

## Contribuire

1. Fork del progetto
2. Crea feature branch (`git checkout -b feature/nuova-funzione`)
3. Commit modifiche (`git commit -m 'Aggiunge nuova funzione'`)
4. Push al branch (`git push origin feature/nuova-funzione`)
5. Apri Pull Request

## Licenza

Questo progetto è rilasciato sotto licenza MIT. Vedi file `LICENSE` per dettagli.

## Supporto

- **Issues**: [GitHub Issues](https://github.com/[YOUR_REPO]/issues)
- **Wiki**: [GitHub Wiki](https://github.com/[YOUR_REPO]/wiki)
- **Discussions**: [GitHub Discussions](https://github.com/[YOUR_REPO]/discussions)

---

*Storage System v2.0 - Gestisci il tuo storage Minecraft come un professionista!*