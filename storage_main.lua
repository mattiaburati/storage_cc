-- storage_main.lua - Script principale del sistema storage
-- Coordina tutti i moduli e gestisce il loop principale

-- Caricamento moduli
local Core = require("storage_core")
local GUI = require("storage_gui")
local Utils = require("storage_utils")

-- Funzione per selezionare chest di output
local function selectOutputChest()
    term.clear()
    term.setCursorPos(1, 1)
    
    Utils.printColored("=== SELEZIONA CHEST DI OUTPUT ===", colors.yellow)
    print("")
    
    local availableChests = {}
    local peripherals = peripheral.getNames()
    
    -- Trova tutte le chest disponibili
    for _, name in ipairs(peripherals) do
        local pType = peripheral.getType(name)
        if string.find(pType, "chest") or string.find(pType, "barrel") or 
           string.find(pType, "shulker") or pType == "minecraft:chest" then
            table.insert(availableChests, {name = name, type = pType})
        end
    end
    
    if #availableChests == 0 then
        Utils.printColored("Nessuna chest trovata!", colors.red)
        print("Premi un tasto per tornare...")
        os.pullEvent("key")
        return
    end
    
    Utils.printColored("CHEST DISPONIBILI:", colors.cyan)
    for i, chest in ipairs(availableChests) do
        local status = ""
        if chest.name == Core.config.OUTPUT_SIDE then
            status = " (ATTUALE)"
        end
        print(i .. ". " .. chest.name .. " (" .. chest.type .. ")" .. status)
    end
    
    print("")
    Utils.printColored("Inserisci il numero della chest (0 per annullare): ", colors.white)
    local input = read()
    local choice = tonumber(input)
    
    if choice and choice >= 1 and choice <= #availableChests then
        Core.config.OUTPUT_SIDE = availableChests[choice].name
        
        GUI.setStatus("Output cambiato: " .. Core.config.OUTPUT_SIDE, colors.lime)
        
        -- Riaggiorna le chest di storage (escludi la nuova output)
        Core.findChests()
        if #Core.chests > 0 then
            Core.scanInventories()
            GUI.updateFilteredItems()
        end
        
        Utils.printColored("Output impostato su: " .. Core.config.OUTPUT_SIDE, colors.lime)
    elseif choice == 0 then
        Utils.printColored("Operazione annullata", colors.yellow)
    else
        Utils.printColored("Scelta non valida", colors.red)
    end
    
    sleep(2)
end

-- Funzione debug
local function showDebug()
    term.clear()
    term.setCursorPos(1, 1)
    
    print("=== DEBUG INFO ===")
    print("Modalita rete:", Core.hasModem() and "SI" or "NO")
    print("Output chest:", Core.config.OUTPUT_SIDE or "NON CONFIGURATA")
    print("Chest storage:", #Core.chests)
    print("Tipi item:", Utils.tablelength(Core.inventory))
    print("Storage slots:", Core.usedSlots .. "/" .. Core.totalSlots)
    print("")
    
    print("=== LEGENDA ICONE ===")
    term.setTextColor(colors.yellow); term.write("T"); term.setTextColor(colors.white); print(" = Tools/Utensili")
    term.setTextColor(colors.orange); term.write("M"); term.setTextColor(colors.white); print(" = Metal/Metalli")
    term.setTextColor(colors.cyan); term.write("G"); term.setTextColor(colors.white); print(" = Gems/Gemme")
    term.setTextColor(colors.brown); term.write("O"); term.setTextColor(colors.white); print(" = Ores/Minerali")
    term.setTextColor(colors.green); term.write("W"); term.setTextColor(colors.white); print(" = Wood/Legno")
    term.setTextColor(colors.lime); term.write("F"); term.setTextColor(colors.white); print(" = Food/Cibo")
    term.setTextColor(colors.gray); term.write("B"); term.setTextColor(colors.white); print(" = Blocks/Blocchi")
    term.setTextColor(colors.blue); term.write("E"); term.setTextColor(colors.white); print(" = Engineering/Tech")
    term.setTextColor(colors.purple); term.write("L"); term.setTextColor(colors.white); print(" = Liquids/Liquidi")
    print("")
    
    print("=== MODULI CARICATI ===")
    print("✓ storage_core.lua")
    print("✓ storage_gui.lua") 
    print("✓ storage_utils.lua")
    print("✓ storage_main.lua")
    print("")
    
    local peripherals = peripheral.getNames()
    print("PERIPHERAL DISPONIBILI:")
    for _, name in ipairs(peripherals) do
        local pType = peripheral.getType(name)
        print("- " .. name .. " (" .. pType .. ")")
    end
    
    print("\nPremi un tasto per tornare...")
    os.pullEvent("key")
end

-- Gestore eventi click avanzato
local function handleAdvancedClick(x, y, button)
    local controlsX, controlsY = GUI.handleClick(x, y, button)
    
    if controlsX and controlsY then
        -- Gestione bottoni non gestiti direttamente dalla GUI
        local w, h = term.getSize()
        local availableHeight = h - controlsY
        
        -- Bottone OUTPUT
        if x >= controlsX + 1 and x <= controlsX + 6 and y == controlsY + 8 and not GUI.getQuantityInputMode() then
            selectOutputChest()
        end
        
        -- Bottone REFRESH
        if x >= controlsX + 1 and x <= controlsX + 6 and y == controlsY + 9 and not GUI.getQuantityInputMode() then
            GUI.setStatus("Aggiornamento inventario...", colors.yellow)
            GUI.drawStatusBar()
            Core.scanInventories()
            GUI.updateFilteredItems()
            GUI.setStatus("Inventario aggiornato!", colors.lime)
        end
        
        -- Bottone ORGANIZE
        if x >= controlsX + 1 and x <= controlsX + 6 and y == controlsY + 10 and not GUI.getQuantityInputMode() then
            GUI.setStatus("Avvio ordinamento storage...", colors.yellow)
            GUI.drawStatusBar()
            
            local success, message = Core.organizeStorage()
            if success then
                GUI.setStatus(message, colors.lime)
                -- Refresh dopo l'ordinamento
                Core.scanInventories()
                GUI.updateFilteredItems()
            else
                GUI.setStatus("ERRORE: " .. message, colors.red)
            end
        end
        
        -- Bottone DEBUG (solo se visibile)
        if availableHeight > 13 and x >= controlsX + 1 and x <= controlsX + 6 and y == controlsY + 12 and not GUI.getQuantityInputMode() then
            showDebug()
        end
    end
end

-- Funzione principale
local function main()
    term.clear()
    term.setCursorPos(1, 1)
    
    -- Inizializzazione
    print("=================================")
    print("    STORAGE SYSTEM v2.0          ")
    print("    Modular Edition              ")
    print("=================================")
    print("")
    print("Inizializzazione sistema storage...")
    
    -- Inizializza core
    Core.config.OUTPUT_SIDE, _ = Core.findOutputChest()
    Core.findChests()
    
    if #Core.chests > 0 then
        print("Scansione inventari...")
        Core.scanInventories()
        GUI.updateFilteredItems()
    else
        -- Anche senza chest, inizializza i valori
        Core.totalSlots = 0
        Core.usedSlots = 0
    end
    
    print("Caricamento interfaccia...")
    sleep(1)
    
    GUI.setStatus("Sistema pronto - " .. #Core.chests .. " chest trovate", colors.lime)
    
    -- Loop principale GUI
    while true do
        GUI.drawGUI()
        
        local event, param1, param2, param3 = os.pullEvent()
        
        if event == "mouse_click" then
            handleAdvancedClick(param2, param3, param1)
        elseif event == "mouse_scroll" then
            GUI.handleScroll(param1)
        elseif event == "key" then
            if param1 == keys.q then
                break
            else
                GUI.handleKeyboard(param1)
            end
        elseif event == "char" then
            GUI.handleChar(param1)
        end
    end
    
    term.clear()
    term.setCursorPos(1, 1)
    print("Sistema storage terminato.")
    print("Grazie per aver usato Storage System v2.0!")
end

-- Gestione errori
local success, error = pcall(main)
if not success then
    term.clear()
    term.setCursorPos(1, 1)
    Utils.printColored("ERRORE CRITICO:", colors.red)
    print(error)
    print("")
    print("Verifica che tutti i moduli siano installati:")
    print("- storage_core.lua")
    print("- storage_gui.lua") 
    print("- storage_utils.lua")
    print("")
    print("Usa l'installer per reinstallare i moduli.")
end
