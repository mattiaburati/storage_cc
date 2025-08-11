-- Sistema di Storage con GUI per CC:Tweaked
-- Versione: 2.0 - Solo Computer
-- Autore: Claude AI

-- Configurazione
local OUTPUT_SIDE = nil
local SCAN_DELAY = 1

-- Variabili globali
local chests = {}
local inventory = {}
local outputChestType = nil
local w, h = term.getSize()
local totalSlots = 0
local usedSlots = 0

-- Variabili GUI
local searchQuery = ""
local selectedItem = nil
local selectedQuantity = 1
local scrollPos = 0
local filteredItems = {}
local statusMessage = "Sistema avviato"
local statusColor = colors.green
local quantityInputMode = false
local quantityInputBuffer = ""

-- Funzione per calcolare spazio storage
local function calculateStorageSpace()
    totalSlots = 0
    usedSlots = 0
    
    for _, chestName in ipairs(chests) do
        local chest = peripheral.wrap(chestName)
        if chest and chest.size then
            local chestSize = chest.size()
            totalSlots = totalSlots + chestSize
            
            if chest.list then
                local items = chest.list()
                for slot, item in pairs(items) do
                    if item and item.count > 0 then
                        usedSlots = usedSlots + 1
                    end
                end
            end
        end
    end
end

-- Funzione per ottenere icona e colore di un item
local function getItemIcon(itemName)
    local name = string.lower(itemName)
    
    -- Tools & Weapons
    if string.find(name, "sword") or string.find(name, "axe") or string.find(name, "pickaxe") 
       or string.find(name, "shovel") or string.find(name, "hoe") then
        return "T", colors.yellow -- Tool
    end
    
    -- Ingots & Metals
    if string.find(name, "ingot") or string.find(name, "plate") or string.find(name, "gear")
       or string.find(name, "iron") or string.find(name, "gold") or string.find(name, "copper")
       or string.find(name, "tin") or string.find(name, "steel") or string.find(name, "aluminum") then
        return "M", colors.orange -- Metal
    end
    
    -- Gems & Crystals
    if string.find(name, "diamond") or string.find(name, "emerald") or string.find(name, "gem")
       or string.find(name, "crystal") or string.find(name, "quartz") then
        return "G", colors.cyan -- Gem
    end
    
    -- Ores & Raw materials
    if string.find(name, "ore") or string.find(name, "raw") or string.find(name, "coal")
       or string.find(name, "redstone") or string.find(name, "lapis") then
        return "O", colors.brown -- Ore
    end
    
    -- Wood & Organic
    if string.find(name, "wood") or string.find(name, "log") or string.find(name, "plank")
       or string.find(name, "sapling") or string.find(name, "leaves") or string.find(name, "stick") then
        return "W", colors.green -- Wood
    end
    
    -- Food & Seeds
    if string.find(name, "seed") or string.find(name, "wheat") or string.find(name, "bread")
       or string.find(name, "apple") or string.find(name, "carrot") or string.find(name, "potato") then
        return "F", colors.lime -- Food
    end
    
    -- Blocks & Building
    if string.find(name, "block") or string.find(name, "brick") or string.find(name, "stone")
       or string.find(name, "cobble") or string.find(name, "sand") or string.find(name, "dirt") then
        return "B", colors.gray -- Block
    end
    
    -- Mechanical & Tech
    if string.find(name, "machine") or string.find(name, "gear") or string.find(name, "circuit")
       or string.find(name, "motor") or string.find(name, "coil") or string.find(name, "valve") then
        return "E", colors.blue -- Engineering
    end
    
    -- Fluids & Containers
    if string.find(name, "bucket") or string.find(name, "bottle") or string.find(name, "tank")
       or string.find(name, "fluid") or string.find(name, "water") or string.find(name, "lava") then
        return "L", colors.purple -- Liquid
    end
    
    -- Default
    return "?", colors.white -- Unknown
end

-- Funzione per pulire i nomi degli item (rimuove prefissi mod)
local function cleanItemName(itemName)
    -- Rimuove prefissi come "minecraft:", "thermal:", "mekanism:", etc.
    local cleanName = itemName
    local colonPos = string.find(cleanName, ":")
    if colonPos then
        cleanName = string.sub(cleanName, colonPos + 1)
    end
    
    -- Sostituisce underscore con spazi e capitalizza
    cleanName = string.gsub(cleanName, "_", " ")
    cleanName = string.gsub(cleanName, "(%a)([%w_']*)", function(first, rest)
        return string.upper(first) .. string.lower(rest)
    end)
    
    return cleanName
end

-- Funzione helper per contare elementi tabella
local function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

-- Funzione helper per stampare con colori
local function printColored(text, color)
    if color then
        term.setTextColor(color)
    end
    print(text)
    term.setTextColor(colors.white)
end

-- Funzione per impostare status
local function setStatus(message, color)
    statusMessage = message
    statusColor = color or colors.white
end

-- Funzione per rilevare se siamo in modalita rete
local function hasModem()
    local peripherals = peripheral.getNames()
    for _, name in ipairs(peripherals) do
        local pType = peripheral.getType(name)
        if pType == "modem" then
            return true
        end
    end
    return false
end

-- Funzione per rilevare automaticamente la chest di output
local function findOutputChest()
    local peripherals = peripheral.getNames()
    local networkMode = hasModem()
    
    if networkMode then
        for _, name in ipairs(peripherals) do
            local pType = peripheral.getType(name)
            if (string.find(pType, "chest") or string.find(pType, "barrel") or 
                string.find(pType, "shulker") or pType == "minecraft:chest") and
               string.find(name, "minecraft:") then
                return name, "networked"
            end
        end
    else
        local sides = {"top", "bottom", "front", "back", "left", "right"}
        for _, side in ipairs(sides) do
            if peripheral.isPresent(side) then
                local pType = peripheral.getType(side)
                if string.find(pType, "chest") or string.find(pType, "barrel") or 
                   string.find(pType, "shulker") or pType == "minecraft:chest" then
                    return side, "direct"
                end
            end
        end
    end
    
    return nil, nil
end

-- Funzione per trovare tutte le chest connesse
local function findChests()
    chests = {}
    local peripherals = peripheral.getNames()
    local networkMode = hasModem()
    
    for _, name in ipairs(peripherals) do
        local pType = peripheral.getType(name)
        if string.find(pType, "chest") or string.find(pType, "barrel") or 
           string.find(pType, "shulker") or pType == "minecraft:chest" then
            
            if networkMode then
                if string.find(name, "minecraft:") and name ~= OUTPUT_SIDE then
                    table.insert(chests, name)
                end
            else
                if name ~= OUTPUT_SIDE then
                    table.insert(chests, name)
                end
            end
        end
    end
    
    return #chests
end

-- Funzione per scansionare tutti gli inventari
local function scanInventories()
    inventory = {}
    
    for _, chestName in ipairs(chests) do
        local chest = peripheral.wrap(chestName)
        if chest and chest.list then
            local items = chest.list()
            
            for slot, item in pairs(items) do
                local itemName = item.name
                local itemCount = item.count
                local cleanDisplayName = item.displayName and cleanItemName(item.displayName) or cleanItemName(itemName)
                
                if not inventory[itemName] then
                    inventory[itemName] = {
                        total = 0,
                        locations = {}
                    }
                end
                
                inventory[itemName].total = inventory[itemName].total + itemCount
                
                table.insert(inventory[itemName].locations, {
                    chest = chestName,
                    slot = slot,
                    count = itemCount,
                    displayName = cleanDisplayName
                })
            end
        end
    end
    
    -- Calcola spazio storage
    calculateStorageSpace()
    updateFilteredItems()
end

-- Funzione per aggiornare lista filtrata
function updateFilteredItems()
    filteredItems = {}
    local query = string.lower(searchQuery)
    
    for itemName, data in pairs(inventory) do
        local displayName = data.locations[1] and data.locations[1].displayName or itemName
        
        if query == "" or string.find(string.lower(itemName), query) or 
           string.find(string.lower(displayName), query) then
            table.insert(filteredItems, {
                name = itemName,
                displayName = displayName,
                total = data.total
            })
        end
    end
    
    -- Ordina alfabeticamente
    table.sort(filteredItems, function(a, b)
        return string.lower(a.displayName) < string.lower(b.displayName)
    end)
end

-- Funzione per ordinare e consolidare gli oggetti nelle chest
local function organizeStorage()
    if #chests == 0 then
        return false, "Nessuna chest trovata"
    end
    
    setStatus("Analizzando inventario per ordinamento...", colors.yellow)
    
    -- Prima scansiona tutto
    local itemMap = {}
    local totalMoved = 0
    
    -- Mappa tutti gli oggetti e le loro posizioni
    for _, chestName in ipairs(chests) do
        local chest = peripheral.wrap(chestName)
        if chest and chest.list then
            local items = chest.list()
            for slot, item in pairs(items) do
                local itemName = item.name
                if not itemMap[itemName] then
                    itemMap[itemName] = {}
                end
                table.insert(itemMap[itemName], {
                    chest = chestName,
                    slot = slot,
                    count = item.count,
                    maxCount = item.maxCount or 64
                })
            end
        end
    end
    
    -- Per ogni tipo di oggetto, consolida nelle chest
    for itemName, locations in pairs(itemMap) do
        if #locations > 1 then -- Solo se l'oggetto e in piu chest
            setStatus("Consolidando: " .. cleanItemName(itemName), colors.yellow)
            
            -- Ordina per quantita (prima le chest piu piene)
            table.sort(locations, function(a, b)
                return a.count > b.count
            end)
            
            local targetChest = locations[1].chest -- Chest con piu oggetti di questo tipo
            local targetPeripheral = peripheral.wrap(targetChest)
            
            if targetPeripheral then
                -- Sposta tutti gli oggetti dalle altre chest alla target
                for i = 2, #locations do
                    local sourceLocation = locations[i]
                    local sourceChest = peripheral.wrap(sourceLocation.chest)
                    
                    if sourceChest then
                        local moved = sourceChest.pushItems(targetChest, sourceLocation.slot)
                        if moved > 0 then
                            totalMoved = totalMoved + moved
                        end
                    end
                end
            end
        end
    end
    
    return true, "Ordinamento completato! Spostati " .. totalMoved .. " oggetti"
end

local function transferItem(itemName, quantity)
    if not inventory[itemName] then
        return false, "Item non trovato"
    end
    
    if not OUTPUT_SIDE then
        return false, "Chest di output non configurata"
    end
    
    local outputChest = peripheral.wrap(OUTPUT_SIDE)
    if not outputChest then
        return false, "Chest di output non accessibile"
    end
    
    local remaining = quantity
    local transferred = 0
    
    for _, location in ipairs(inventory[itemName].locations) do
        if remaining <= 0 then break end
        
        local sourceChest = peripheral.wrap(location.chest)
        if sourceChest then
            local toTransfer = math.min(remaining, location.count)
            local moved = sourceChest.pushItems(OUTPUT_SIDE, location.slot, toTransfer)
            
            if moved > 0 then
                transferred = transferred + moved
                remaining = remaining - moved
            end
        end
    end
    
    return transferred > 0, "Trasferiti " .. transferred .. "/" .. quantity .. " item"
end

-- Funzioni GUI
local function drawBox(x, y, width, height, bg, fg)
    term.setBackgroundColor(bg or colors.black)
    term.setTextColor(fg or colors.white)
    
    for row = y, y + height - 1 do
        term.setCursorPos(x, row)
        term.write(string.rep(" ", width))
    end
end

local function drawButton(x, y, width, height, text, bg, fg, centered)
    drawBox(x, y, width, height, bg, fg)
    
    if centered == nil then centered = true end
    
    if centered then
        local textX = x + math.floor((width - string.len(text)) / 2)
        local textY = y + math.floor(height / 2)
        term.setCursorPos(textX, textY)
    else
        term.setCursorPos(x + 1, y)
    end
    
    term.write(text)
end

local function drawHeader()
    -- Header background
    drawBox(1, 1, w, 4, colors.blue, colors.white)
    
    -- Titolo
    term.setCursorPos(2, 2)
    term.write("STORAGE SYSTEM v2.0")
    
    -- Stats
    local chestText = "Chest: " .. #chests
    local itemText = "Item: " .. tablelength(inventory)
    local outputText = OUTPUT_SIDE and ("Output: " .. OUTPUT_SIDE) or "Output: N/A"
    
    term.setCursorPos(w - string.len(outputText) - 1, 2)
    term.write(outputText)
    
    term.setCursorPos(2, 3)
    term.write(chestText .. " | " .. itemText)
    
    -- Indicatore spazio storage
    if totalSlots > 0 then
        local freeSlots = totalSlots - usedSlots
        local usagePercent = math.floor((usedSlots / totalSlots) * 100)
        local storageText = string.format("Storage: %d/%d (%d%%)", usedSlots, totalSlots, usagePercent)
        
        -- Posizione per il testo storage
        term.setCursorPos(2, 4)
        term.write(storageText)
        
        -- Barra di riempimento (se c'e spazio)
        local barWidth = 20
        local barStartX = 2 + string.len(storageText) + 2
        
        if barStartX + barWidth < w - 2 then
            local filledWidth = math.floor((usedSlots / totalSlots) * barWidth)
            
            -- Background barra
            term.setCursorPos(barStartX, 4)
            term.setBackgroundColor(colors.lightGray)
            term.write(string.rep(" ", barWidth))
            
            -- Parte riempita (colore basato su percentuale)
            local barColor = colors.lime
            if usagePercent > 80 then
                barColor = colors.red
            elseif usagePercent > 60 then
                barColor = colors.orange
            elseif usagePercent > 40 then
                barColor = colors.yellow
            end
            
            term.setCursorPos(barStartX, 4)
            term.setBackgroundColor(barColor)
            term.write(string.rep(" ", filledWidth))
            
            -- Reset colore
            term.setBackgroundColor(colors.blue)
        end
    else
        term.setCursorPos(2, 4)
        term.write("Storage: N/A")
    end
end

local function drawSearchBox()
    -- Search box
    drawBox(2, 6, w-2, 1, colors.lightGray, colors.black)
    term.setCursorPos(2, 6)
    term.write("Cerca: " .. searchQuery .. "_")
end

local function drawItemList()
    local listY = 8
    local listHeight = h - 10
    local maxVisible = listHeight
    
    -- Background lista
    drawBox(2, listY, w-12, listHeight, colors.gray, colors.white)
    
    -- Header lista
    term.setCursorPos(3, listY)
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.write(string.format("%-" .. (w-22) .. "s %8s", "NOME ITEM", "QTA"))
    
    -- Item lista
    local startIndex = scrollPos + 1
    local endIndex = math.min(startIndex + maxVisible - 2, #filteredItems)
    
    for i = startIndex, endIndex do
        local item = filteredItems[i]
        local y = listY + 1 + (i - startIndex)
        
        local bg = colors.gray
        local fg = colors.white
        
        if selectedItem == item.name then
            bg = colors.yellow
            fg = colors.black
        end
        
        drawBox(2, y, w-12, 1, bg, fg)
        
        -- Ottieni icona e colore per l'item
        local icon, iconColor = getItemIcon(item.name)
        
        -- Disegna icona colorata
        term.setCursorPos(3, y)
        if selectedItem == item.name then
            term.setBackgroundColor(colors.yellow)
        else
            term.setBackgroundColor(colors.gray)
        end
        term.setTextColor(iconColor)
        term.write(icon)
        
        -- Disegna nome item
        term.setCursorPos(5, y)
        term.setTextColor(fg)
        local displayName = item.displayName
        local maxNameLength = w-26 -- Spazio per icona e quantita
        if string.len(displayName) > maxNameLength then
            displayName = string.sub(displayName, 1, maxNameLength-3) .. "..."
        end
        
        term.write(string.format("%-" .. maxNameLength .. "s %8d", displayName, item.total))
    end
    
    -- Scrollbar
    if #filteredItems > maxVisible - 1 then
        local scrollbarHeight = listHeight - 1
        local thumbHeight = math.max(1, math.floor(scrollbarHeight * (maxVisible - 1) / #filteredItems))
        local thumbPos = math.floor((scrollPos / math.max(1, #filteredItems - maxVisible + 1)) * (scrollbarHeight - thumbHeight))
        
        drawBox(w-10, listY + 1, 1, scrollbarHeight, colors.lightGray)
        drawBox(w-10, listY + 1 + thumbPos, 1, thumbHeight, colors.blue)
    end
end

local function drawControls()
    local controlsX = w - 9
    local controlsY = 8
    local availableHeight = h - controlsY
    
    -- Background pannello controlli
    drawBox(controlsX, controlsY, 8, availableHeight, colors.lightBlue, colors.black)
    
    -- Titolo
    term.setCursorPos(controlsX + 1, controlsY + 1)
    term.setBackgroundColor(colors.lightBlue)
    term.setTextColor(colors.black)
    term.write("CTRL")
    
    -- Quantita (compatta)
    term.setCursorPos(controlsX + 1, controlsY + 2)
    term.write("Qta:")
    
    -- Input quantita (clickabile)
    local qtyBg = quantityInputMode and colors.yellow or colors.white
    local qtyFg = quantityInputMode and colors.black or colors.black
    drawBox(controlsX + 1, controlsY + 3, 6, 1, qtyBg, qtyFg)
    term.setCursorPos(controlsX + 1, controlsY + 3)
    
    if quantityInputMode then
        term.write(" " .. quantityInputBuffer .. "_")
    else
        term.write(" " .. tostring(selectedQuantity))
    end
    
    -- Bottoni quantita (piu compatti)
    drawButton(controlsX + 1, controlsY + 4, 2, 1, "-", colors.red, colors.white)
    drawButton(controlsX + 4, controlsY + 4, 2, 1, "+", colors.green, colors.white)
    
    -- Bottone trasferimento
    local transferEnabled = selectedItem ~= nil and OUTPUT_SIDE ~= nil
    local transferBg = transferEnabled and colors.lime or colors.gray
    drawButton(controlsX + 1, controlsY + 6, 6, 1, "GET", transferBg, colors.black)
    
    -- Bottoni principali (compatti)
    drawButton(controlsX + 1, controlsY + 8, 6, 1, "OUTPUT", colors.cyan, colors.white)
    drawButton(controlsX + 1, controlsY + 9, 6, 1, "REFRESH", colors.orange, colors.black)
    drawButton(controlsX + 1, controlsY + 10, 6, 1, "ORDINA", colors.pink, colors.black)
    
    -- Solo se c'e spazio, mostra debug
    if availableHeight > 13 then
        drawButton(controlsX + 1, controlsY + 12, 6, 1, "DEBUG", colors.purple, colors.white)
    end
end

local function drawStatusBar()
    -- Status bar
    drawBox(1, h, w, 1, colors.black, statusColor)
    term.setCursorPos(2, h)
    term.write(statusMessage)
    
    -- Informazioni quantita
    if selectedItem and inventory[selectedItem] then
        local available = inventory[selectedItem].total
        local statusText = "Disponibili: " .. available
        term.setCursorPos(w - string.len(statusText) - 1, h)
        term.write(statusText)
    end
end

-- Funzione per selezionare chest di output
local function selectOutputChest()
    term.clear()
    term.setCursorPos(1, 1)
    
    printColored("=== SELEZIONA CHEST DI OUTPUT ===", colors.yellow)
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
        printColored("Nessuna chest trovata!", colors.red)
        print("Premi un tasto per tornare...")
        os.pullEvent("key")
        return
    end
    
    printColored("CHEST DISPONIBILI:", colors.cyan)
    for i, chest in ipairs(availableChests) do
        local status = ""
        if chest.name == OUTPUT_SIDE then
            status = " (ATTUALE)"
        end
        print(i .. ". " .. chest.name .. " (" .. chest.type .. ")" .. status)
    end
    
    print("")
    printColored("Inserisci il numero della chest (0 per annullare): ", colors.white)
    local input = read()
    local choice = tonumber(input)
    
    if choice and choice >= 1 and choice <= #availableChests then
        OUTPUT_SIDE = availableChests[choice].name
        outputChestType = hasModem() and "networked" or "direct"
        
        setStatus("Output cambiato: " .. OUTPUT_SIDE, colors.lime)
        
        -- Riaggiorna le chest di storage (escludi la nuova output)
        findChests()
        if #chests > 0 then
            scanInventories()
        end
        
        printColored("Output impostato su: " .. OUTPUT_SIDE, colors.lime)
    elseif choice == 0 then
        printColored("Operazione annullata", colors.yellow)
    else
        printColored("Scelta non valida", colors.red)
    end
    
    sleep(2)
end

local function drawGUI()
    term.clear()
    drawHeader()
    drawSearchBox()
    drawItemList()
    drawControls()
    drawStatusBar()
end

local function handleClick(x, y, button)
    -- Lista item (selezione)
    if x >= 2 and x <= w-12 and y >= 9 then
        local listY = 8
        local listHeight = h - 10
        local maxVisible = listHeight - 1
        local clickIndex = scrollPos + (y - listY)
        
        if clickIndex >= 1 and clickIndex <= #filteredItems then
            selectedItem = filteredItems[clickIndex].name
            selectedQuantity = 1
            quantityInputMode = false -- Esci dalla modalita input se selezioni nuovo item
            quantityInputBuffer = ""
            setStatus("Selezionato: " .. filteredItems[clickIndex].displayName, colors.lime)
        end
    end
    
    -- Controlli pannello destro
    local controlsX = w - 9
    local controlsY = 8
    
    if x >= controlsX then
        -- Click sulla quantita (per input manuale)
        if x >= controlsX + 1 and x <= controlsX + 6 and y == controlsY + 3 then
            if not quantityInputMode then
                quantityInputMode = true
                quantityInputBuffer = tostring(selectedQuantity)
                setStatus("Inserisci quantita (Enter per confermare, Esc per annullare)", colors.yellow)
            end
        end
        
        -- Bottone -
        if x >= controlsX + 1 and x <= controlsX + 2 and y == controlsY + 4 and not quantityInputMode then
            if selectedQuantity > 1 then
                selectedQuantity = selectedQuantity - 1
            end
        end
        
        -- Bottone +
        if x >= controlsX + 4 and x <= controlsX + 5 and y == controlsY + 4 and not quantityInputMode then
            if selectedItem and inventory[selectedItem] then
                local maxAvailable = inventory[selectedItem].total
                if selectedQuantity < maxAvailable then
                    selectedQuantity = selectedQuantity + 1
                end
            else
                selectedQuantity = selectedQuantity + 1
            end
        end
        
        -- Bottone GET
        if x >= controlsX + 1 and x <= controlsX + 6 and y == controlsY + 6 and not quantityInputMode then
            if selectedItem and OUTPUT_SIDE then
                setStatus("Trasferimento in corso...", colors.yellow)
                drawStatusBar()
                
                local success, message = transferItem(selectedItem, selectedQuantity)
                if success then
                    setStatus(message, colors.lime)
                    -- Refresh inventory dopo trasferimento
                    scanInventories()
                else
                    setStatus("ERRORE: " .. message, colors.red)
                end
            else
                setStatus("Seleziona item e configura output", colors.red)
            end
        end
        
        -- Bottone OUTPUT
        if x >= controlsX + 1 and x <= controlsX + 6 and y == controlsY + 8 and not quantityInputMode then
            selectOutputChest()
        end
        
        -- Bottone REFRESH - Fixed coordinates
        if x >= controlsX + 1 and x <= controlsX + 6 and y == controlsY + 9 and not quantityInputMode then
            setStatus("Aggiornamento inventario...", colors.yellow)
            drawStatusBar()
            scanInventories()
            setStatus("Inventario aggiornato!", colors.lime)
        end
        
        -- Bottone ORDINA - Fixed coordinates
        if x >= controlsX + 1 and x <= controlsX + 6 and y == controlsY + 10 and not quantityInputMode then
            setStatus("Avvio ordinamento storage...", colors.yellow)
            drawStatusBar()
            
            local success, message = organizeStorage()
            if success then
                setStatus(message, colors.lime)
                -- Refresh dopo l'ordinamento
                scanInventories()
            else
                setStatus("ERRORE: " .. message, colors.red)
            end
        end
        
        -- Bottone DEBUG (solo se visibile)
        local availableHeight = h - controlsY
        if availableHeight > 13 and x >= controlsX + 1 and x <= controlsX + 6 and y == controlsY + 12 and not quantityInputMode then
            -- Mostra debug in una finestra popup
            term.clear()
            term.setCursorPos(1, 1)
            
            print("=== DEBUG INFO ===")
            print("Modalita rete:", hasModem() and "SI" or "NO")
            print("Output chest:", OUTPUT_SIDE or "NON CONFIGURATA")
            print("Chest storage:", #chests)
            print("Tipi item:", tablelength(inventory))
            print("Dimensioni schermo:", w .. "x" .. h)
            print("Storage slots:", usedSlots .. "/" .. totalSlots)
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
            
            local peripherals = peripheral.getNames()
            print("PERIPHERAL DISPONIBILI:")
            for _, name in ipairs(peripherals) do
                local pType = peripheral.getType(name)
                print("- " .. name .. " (" .. pType .. ")")
            end
            
            print("\nPremi un tasto per tornare...")
            os.pullEvent("key")
        end
    end
    
    -- Scroll con click sulla scrollbar
    if x == w-10 and y >= 9 and y <= h-2 and not quantityInputMode then
        local listHeight = h - 10
        local maxVisible = listHeight - 1
        local maxScroll = math.max(0, #filteredItems - maxVisible)
        local scrollPercent = (y - 9) / (listHeight - 1)
        scrollPos = math.floor(scrollPercent * maxScroll)
        scrollPos = math.max(0, math.min(scrollPos, maxScroll))
    end
end

local function handleScroll(dir)
    local listHeight = h - 10
    local maxVisible = listHeight - 1
    local maxScroll = math.max(0, #filteredItems - maxVisible)
    
    scrollPos = scrollPos + (dir * 3) -- Scroll di 3 elementi
    scrollPos = math.max(0, math.min(scrollPos, maxScroll))
end

local function handleKeyboard(key)
    if quantityInputMode then
        -- Gestione input quantita
        if key == keys.enter then
            -- Conferma quantita
            local newQuantity = tonumber(quantityInputBuffer)
            if newQuantity and newQuantity > 0 then
                -- Limita alla quantita disponibile se un item e selezionato
                if selectedItem and inventory[selectedItem] then
                    local maxAvailable = inventory[selectedItem].total
                    selectedQuantity = math.min(newQuantity, maxAvailable)
                    if newQuantity > maxAvailable then
                        setStatus("Quantita limitata a " .. maxAvailable .. " (disponibili)", colors.orange)
                    else
                        setStatus("Quantita impostata: " .. selectedQuantity, colors.lime)
                    end
                else
                    selectedQuantity = newQuantity
                    setStatus("Quantita impostata: " .. selectedQuantity, colors.lime)
                end
            else
                setStatus("Quantita non valida", colors.red)
            end
            quantityInputMode = false
            quantityInputBuffer = ""
        elseif key == keys.backspace then
            -- Cancella carattere
            if string.len(quantityInputBuffer) > 0 then
                quantityInputBuffer = string.sub(quantityInputBuffer, 1, -2)
            end
        elseif key == keys.escape then
            -- Annulla input
            quantityInputMode = false
            quantityInputBuffer = ""
            setStatus("Input quantita annullato", colors.yellow)
        end
    else
        -- Gestione normale
        if key == keys.up then
            handleScroll(-1)
        elseif key == keys.down then
            handleScroll(1)
        elseif key == keys.backspace then
            if string.len(searchQuery) > 0 then
                searchQuery = string.sub(searchQuery, 1, -2)
                updateFilteredItems()
                scrollPos = 0
            end
        elseif key == keys.enter then
            if selectedItem and OUTPUT_SIDE then
                setStatus("Trasferimento in corso...", colors.yellow)
                drawGUI()
                
                local success, message = transferItem(selectedItem, selectedQuantity)
                if success then
                    setStatus(message, colors.lime)
                    scanInventories()
                else
                    setStatus("ERRORE: " .. message, colors.red)
                end
            end
        end
    end
end

local function handleChar(char)
    if quantityInputMode then
        -- Accetta solo numeri per la quantita
        if string.match(char, "%d") and string.len(quantityInputBuffer) < 6 then
            quantityInputBuffer = quantityInputBuffer .. char
        end
    else
        -- Ricerca normale
        if string.len(searchQuery) < 20 then
            searchQuery = searchQuery .. char
            updateFilteredItems()
            scrollPos = 0
        end
    end
end

-- Funzione principale
local function main()
    term.clear()
    term.setCursorPos(1, 1)
    
    -- Inizializzazione
    print("Inizializzazione sistema storage GUI...")
    
    OUTPUT_SIDE, outputChestType = findOutputChest()
    findChests()
    
    if #chests > 0 then
        print("Scansione inventari...")
        scanInventories()
    else
        -- Anche senza chest, inizializza i valori
        totalSlots = 0
        usedSlots = 0
    end
    
    print("Caricamento interfaccia...")
    sleep(1)
    
    setStatus("Sistema pronto - " .. #chests .. " chest trovate", colors.lime)
    
    -- Loop principale GUI
    while true do
        drawGUI()
        
        local event, param1, param2, param3 = os.pullEvent()
        
        if event == "mouse_click" then
            handleClick(param2, param3, param1)
        elseif event == "mouse_scroll" then
            handleScroll(param1)
        elseif event == "key" then
            if param1 == keys.q then
                break
            else
                handleKeyboard(param1)
            end
        elseif event == "char" then
            handleChar(param1)
        end
    end
    
    term.clear()
    term.setCursorPos(1, 1)
    print("Sistema storage terminato.")
end

-- Avvia il programma
main()