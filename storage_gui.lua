-- storage_gui.lua - Interfaccia grafica del sistema storage
-- Gestisce il rendering GUI e l'interazione utente

local StorageGUI = {}

-- Dipendenze
local Core = require("storage_core")
local Utils = require("storage_utils")

-- Variabili GUI
StorageGUI.filteredItems = {}
StorageGUI.scrollOffset = 0
StorageGUI.searchFilter = ""
StorageGUI.selectedCategory = "ALL"
StorageGUI.quantityInput = ""
StorageGUI.quantityInputMode = false
StorageGUI.selectedItem = nil
StorageGUI.statusMessage = ""
StorageGUI.statusColor = colors.white

-- Categorie disponibili
StorageGUI.categories = {
    {id = "ALL", name = "TUTTI", icon = "*", color = colors.white},
    {id = "TOOLS", name = "UTENSILI", icon = "T", color = colors.yellow},
    {id = "METALS", name = "METALLI", icon = "M", color = colors.orange},
    {id = "GEMS", name = "GEMME", icon = "G", color = colors.cyan},
    {id = "ORES", name = "MINERALI", icon = "O", color = colors.brown},
    {id = "WOOD", name = "LEGNO", icon = "W", color = colors.green},
    {id = "FOOD", name = "CIBO", icon = "F", color = colors.lime},
    {id = "BLOCKS", name = "BLOCCHI", icon = "B", color = colors.gray},
    {id = "TECH", name = "TECH", icon = "E", color = colors.blue},
    {id = "LIQUIDS", name = "LIQUIDI", icon = "L", color = colors.purple}
}

-- Getter per quantityInputMode
function StorageGUI.getQuantityInputMode()
    return StorageGUI.quantityInputMode
end

-- Funzione per impostare messaggio di stato
function StorageGUI.setStatus(message, color)
    StorageGUI.statusMessage = message or ""
    StorageGUI.statusColor = color or colors.white
end

-- Funzione per aggiornare la lista filtrata degli item
function StorageGUI.updateFilteredItems()
    StorageGUI.filteredItems = {}
    
    for itemName, data in pairs(Core.inventory) do
        local displayName = data.locations[1] and data.locations[1].displayName or Utils.cleanItemName(itemName)
        local icon, color = Utils.getItemIcon(itemName)
        
        -- Filtro per categoria
        local matchesCategory = StorageGUI.selectedCategory == "ALL" or 
                              (StorageGUI.selectedCategory == "TOOLS" and icon == "T") or
                              (StorageGUI.selectedCategory == "METALS" and icon == "M") or
                              (StorageGUI.selectedCategory == "GEMS" and icon == "G") or
                              (StorageGUI.selectedCategory == "ORES" and icon == "O") or
                              (StorageGUI.selectedCategory == "WOOD" and icon == "W") or
                              (StorageGUI.selectedCategory == "FOOD" and icon == "F") or
                              (StorageGUI.selectedCategory == "BLOCKS" and icon == "B") or
                              (StorageGUI.selectedCategory == "TECH" and icon == "E") or
                              (StorageGUI.selectedCategory == "LIQUIDS" and icon == "L")
        
        -- Filtro di ricerca
        local matchesSearch = StorageGUI.searchFilter == "" or 
                             string.find(string.lower(displayName), string.lower(StorageGUI.searchFilter))
        
        if matchesCategory and matchesSearch then
            table.insert(StorageGUI.filteredItems, {
                name = itemName,
                displayName = displayName,
                total = data.total,
                icon = icon,
                color = color
            })
        end
    end
    
    -- Ordina per nome
    table.sort(StorageGUI.filteredItems, function(a, b)
        return a.displayName < b.displayName
    end)
    
    -- Reset scroll se necessario
    if StorageGUI.scrollOffset > math.max(0, #StorageGUI.filteredItems - 10) then
        StorageGUI.scrollOffset = math.max(0, #StorageGUI.filteredItems - 10)
    end
end

-- Funzione per disegnare l'header
function StorageGUI.drawHeader()
    local w, h = term.getSize()
    
    -- Sfondo header
    Utils.drawBox(1, 1, w, 3, colors.gray, colors.white)
    
    -- Titolo
    term.setCursorPos(2, 2)
    term.setTextColor(colors.white)
    term.write("STORAGE SYSTEM v2.0")
    
    -- Info storage
    local storageInfo = Core.usedSlots .. "/" .. Core.totalSlots .. " slots"
    term.setCursorPos(w - string.len(storageInfo) - 1, 2)
    term.setTextColor(Utils.getUsageColor(Core.usedSlots, Core.totalSlots))
    term.write(storageInfo)
end

-- Funzione per disegnare le categorie
function StorageGUI.drawCategories()
    local w, h = term.getSize()
    local startY = 4
    
    -- Sfondo categorie
    Utils.drawBox(1, startY, w, 2, colors.lightGray, colors.black)
    
    local x = 2
    for _, cat in ipairs(StorageGUI.categories) do
        local isSelected = cat.id == StorageGUI.selectedCategory
        local bg = isSelected and colors.white or colors.lightGray
        local fg = isSelected and colors.black or cat.color
        
        term.setBackgroundColor(bg)
        term.setTextColor(fg)
        term.setCursorPos(x, startY + 1)
        term.write(" " .. cat.icon .. " ")
        
        x = x + 4
        if x >= w - 3 then break end
    end
    
    -- Reset colori
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
end

-- Funzione per disegnare la barra di ricerca
function StorageGUI.drawSearchBar()
    local w, h = term.getSize()
    local searchY = 6
    
    Utils.drawBox(1, searchY, w, 1, colors.black, colors.white)
    
    term.setCursorPos(2, searchY)
    term.write("Cerca: " .. StorageGUI.searchFilter)
    
    if string.len(StorageGUI.searchFilter) < w - 10 then
        term.write("_")
    end
end

-- Funzione per disegnare la lista degli item
function StorageGUI.drawItemList()
    local w, h = term.getSize()
    local startY = 8
    local endY = h - 3
    local visibleLines = endY - startY + 1
    
    -- Pulisce l'area lista
    for y = startY, endY do
        Utils.drawBox(1, y, w, 1, colors.black, colors.white)
    end
    
    -- Disegna gli item
    for i = 1, visibleLines do
        local itemIndex = StorageGUI.scrollOffset + i
        if itemIndex <= #StorageGUI.filteredItems then
            local item = StorageGUI.filteredItems[itemIndex]
            local y = startY + i - 1
            
            -- Evidenzia se selezionato per input quantità
            local bg = (StorageGUI.selectedItem == item.name and StorageGUI.quantityInputMode) and colors.blue or colors.black
            local fg = colors.white
            
            Utils.drawBox(1, y, w, 1, bg, fg)
            
            -- Icona colorata
            term.setCursorPos(2, y)
            term.setTextColor(item.color)
            term.write(item.icon)
            
            -- Nome item
            term.setCursorPos(4, y)
            term.setTextColor(colors.white)
            local maxNameLen = w - 15
            local displayName = item.displayName
            if string.len(displayName) > maxNameLen then
                displayName = string.sub(displayName, 1, maxNameLen - 3) .. "..."
            end
            term.write(displayName)
            
            -- Quantità
            term.setCursorPos(w - 8, y)
            term.setTextColor(colors.cyan)
            term.write(Utils.formatNumber(item.total))
        end
    end
    
    -- Indicatori scroll
    if StorageGUI.scrollOffset > 0 then
        term.setCursorPos(w, startY)
        term.setTextColor(colors.yellow)
        term.write("^")
    end
    
    if StorageGUI.scrollOffset < math.max(0, #StorageGUI.filteredItems - visibleLines) then
        term.setCursorPos(w, endY)
        term.setTextColor(colors.yellow)
        term.write("v")
    end
end

-- Funzione per disegnare i controlli
function StorageGUI.drawControls(x, y)
    local w, h = term.getSize()
    local controlsWidth = 8
    local availableHeight = h - y
    
    -- INPUT QUANTITÀ (se attivo)
    if StorageGUI.quantityInputMode and StorageGUI.selectedItem then
        Utils.drawButton(x, y, controlsWidth, 1, "QTA:", colors.blue, colors.white, false)
        Utils.drawButton(x, y + 1, controlsWidth, 1, StorageGUI.quantityInput .. "_", colors.lightBlue, colors.black, false)
        
        Utils.drawButton(x, y + 3, controlsWidth, 1, "INVIO", colors.green, colors.white)
        Utils.drawButton(x, y + 4, controlsWidth, 1, "ESC", colors.red, colors.white)
        
        y = y + 6
    end
    
    -- CONTROLLI STANDARD
    Utils.drawButton(x, y + 1, controlsWidth, 1, "OUTPUT", colors.orange, colors.white)
    Utils.drawButton(x, y + 2, controlsWidth, 1, "REFRESH", colors.yellow, colors.black)
    Utils.drawButton(x, y + 3, controlsWidth, 1, "ORGANIZE", colors.lime, colors.black)
    
    -- DEBUG (solo se c'è spazio)
    if availableHeight > 13 then
        Utils.drawButton(x, y + 5, controlsWidth, 1, "DEBUG", colors.purple, colors.white)
    end
    
    -- ISTRUZIONI
    local instrY = h - 1
    Utils.drawBox(1, instrY, w, 1, colors.gray, colors.white)
    term.setCursorPos(2, instrY)
    term.write("Mouse: Clicca | Scroll: Su/Giu | Q: Esci")
end

-- Funzione per disegnare la barra di stato
function StorageGUI.drawStatusBar()
    local w, h = term.getSize()
    local statusY = h - 2
    
    Utils.drawBox(1, statusY, w, 1, colors.black, StorageGUI.statusColor)
    term.setCursorPos(2, statusY)
    if StorageGUI.statusMessage ~= "" then
        term.write(StorageGUI.statusMessage)
    else
        term.write("Pronto - " .. #StorageGUI.filteredItems .. " oggetti visualizzati")
    end
end

-- Funzione principale per disegnare l'intera GUI
function StorageGUI.drawGUI()
    local w, h = term.getSize()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    StorageGUI.drawHeader()
    StorageGUI.drawCategories()
    StorageGUI.drawSearchBar()
    StorageGUI.drawItemList()
    
    -- Area controlli (lato destro)
    local controlsX = w - 8
    local controlsY = 8
    StorageGUI.drawControls(controlsX, controlsY)
    
    StorageGUI.drawStatusBar()
end

-- Gestione click del mouse
function StorageGUI.handleClick(x, y, button)
    local w, h = term.getSize()
    local controlsX = w - 8
    local controlsY = 8
    
    -- Click su categorie
    if y == 5 then
        local catX = 2
        for _, cat in ipairs(StorageGUI.categories) do
            if x >= catX and x <= catX + 2 then
                StorageGUI.selectedCategory = cat.id
                StorageGUI.scrollOffset = 0
                StorageGUI.updateFilteredItems()
                StorageGUI.setStatus("Filtro: " .. cat.name, cat.color)
                return controlsX, controlsY
            end
            catX = catX + 4
            if catX >= w - 3 then break end
        end
    end
    
    -- Click su lista item
    local listStartY = 8
    local listEndY = h - 3
    if x < controlsX and y >= listStartY and y <= listEndY then
        local itemIndex = StorageGUI.scrollOffset + (y - listStartY + 1)
        if itemIndex <= #StorageGUI.filteredItems then
            local item = StorageGUI.filteredItems[itemIndex]
            
            if not StorageGUI.quantityInputMode then
                -- Avvia input quantità
                StorageGUI.selectedItem = item.name
                StorageGUI.quantityInput = ""
                StorageGUI.quantityInputMode = true
                StorageGUI.setStatus("Inserisci quantità per " .. item.displayName, colors.cyan)
            end
        end
        return controlsX, controlsY
    end
    
    -- Click sui controlli input quantità
    if StorageGUI.quantityInputMode then
        -- INVIO
        if x >= controlsX and x <= controlsX + 7 and y == controlsY + 3 then
            StorageGUI.confirmTransfer()
            return controlsX, controlsY
        end
        
        -- ESC
        if x >= controlsX and x <= controlsX + 7 and y == controlsY + 4 then
            StorageGUI.cancelInput()
            return controlsX, controlsY
        end
    end
    
    return controlsX, controlsY
end

-- Gestione scroll
function StorageGUI.handleScroll(direction)
    local w, h = term.getSize()
    local visibleLines = (h - 3) - 8 + 1
    
    if direction > 0 then -- Scroll su
        StorageGUI.scrollOffset = math.max(0, StorageGUI.scrollOffset - 3)
    else -- Scroll giù
        local maxScroll = math.max(0, #StorageGUI.filteredItems - visibleLines)
        StorageGUI.scrollOffset = math.min(maxScroll, StorageGUI.scrollOffset + 3)
    end
end

-- Gestione tastiera
function StorageGUI.handleKeyboard(key)
    if StorageGUI.quantityInputMode then
        if key == keys.enter then
            StorageGUI.confirmTransfer()
        elseif key == keys.backspace then
            StorageGUI.quantityInput = string.sub(StorageGUI.quantityInput, 1, -2)
        elseif key == keys.escape then
            StorageGUI.cancelInput()
        end
    else
        if key == keys.backspace and string.len(StorageGUI.searchFilter) > 0 then
            StorageGUI.searchFilter = string.sub(StorageGUI.searchFilter, 1, -2)
            StorageGUI.updateFilteredItems()
        end
    end
end

-- Gestione caratteri
function StorageGUI.handleChar(char)
    if StorageGUI.quantityInputMode then
        if string.match(char, "%d") then
            StorageGUI.quantityInput = StorageGUI.quantityInput .. char
        end
    else
        if string.len(StorageGUI.searchFilter) < 20 then
            StorageGUI.searchFilter = StorageGUI.searchFilter .. char
            StorageGUI.scrollOffset = 0
            StorageGUI.updateFilteredItems()
        end
    end
end

-- Conferma trasferimento
function StorageGUI.confirmTransfer()
    if not StorageGUI.selectedItem or StorageGUI.quantityInput == "" then
        StorageGUI.setStatus("Inserisci una quantità valida", colors.red)
        return
    end
    
    local quantity = tonumber(StorageGUI.quantityInput)
    if not quantity or quantity <= 0 then
        StorageGUI.setStatus("Quantità non valida", colors.red)
        return
    end
    
    StorageGUI.setStatus("Trasferimento in corso...", colors.yellow)
    StorageGUI.drawStatusBar()
    
    local success, message = Core.transferItem(StorageGUI.selectedItem, quantity)
    
    if success then
        StorageGUI.setStatus(message, colors.lime)
        -- Aggiorna inventario
        Core.scanInventories()
        StorageGUI.updateFilteredItems()
    else
        StorageGUI.setStatus("ERRORE: " .. message, colors.red)
    end
    
    StorageGUI.cancelInput()
end

-- Annulla input
function StorageGUI.cancelInput()
    StorageGUI.quantityInputMode = false
    StorageGUI.selectedItem = nil
    StorageGUI.quantityInput = ""
    StorageGUI.setStatus("", colors.white)
end

return StorageGUI