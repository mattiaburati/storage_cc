-- Sistema di Storage con Autocrafting - Versione Funzionante
-- Versione: 2.2 - Funzioni base ripristinate + crafting semplice
-- Autore: Claude AI

-- Configurazione
local OUTPUT_SIDE = nil
local TURTLE_NAME = "turtle_1"

-- Variabili globali
local chests = {}
local inventory = {}
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

-- Variabili crafting
local currentMode = "STORAGE" -- "STORAGE" o "CRAFTING"
local recipes = {}
local selectedRecipe = nil
local craftQuantity = 1

-- Ricette predefinite semplici
recipes = {
    {
        name = "Stick",
        result = "minecraft:stick",
        count = 4,
        ingredients = {
            {slot = 5, item = "minecraft:oak_planks", count = 1},
            {slot = 9, item = "minecraft:oak_planks", count = 1}
        }
    },
    {
        name = "Crafting Table",
        result = "minecraft:crafting_table", 
        count = 1,
        ingredients = {
            {slot = 1, item = "minecraft:oak_planks", count = 1},
            {slot = 2, item = "minecraft:oak_planks", count = 1},
            {slot = 5, item = "minecraft:oak_planks", count = 1},
            {slot = 6, item = "minecraft:oak_planks", count = 1}
        }
    },
    {
        name = "Chest",
        result = "minecraft:chest",
        count = 1,
        ingredients = {
            {slot = 1, item = "minecraft:oak_planks", count = 1},
            {slot = 2, item = "minecraft:oak_planks", count = 1},
            {slot = 3, item = "minecraft:oak_planks", count = 1},
            {slot = 5, item = "minecraft:oak_planks", count = 1},
            {slot = 7, item = "minecraft:oak_planks", count = 1},
            {slot = 9, item = "minecraft:oak_planks", count = 1},
            {slot = 10, item = "minecraft:oak_planks", count = 1},
            {slot = 11, item = "minecraft:oak_planks", count = 1}
        }
    }
}

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
    
    if string.find(name, "sword") or string.find(name, "axe") or string.find(name, "pickaxe") 
       or string.find(name, "shovel") or string.find(name, "hoe") then
        return "T", colors.yellow
    elseif string.find(name, "ingot") or string.find(name, "iron") or string.find(name, "gold") then
        return "M", colors.orange
    elseif string.find(name, "diamond") or string.find(name, "emerald") then
        return "G", colors.cyan
    elseif string.find(name, "ore") or string.find(name, "coal") then
        return "O", colors.brown
    elseif string.find(name, "wood") or string.find(name, "plank") or string.find(name, "log") then
        return "W", colors.green
    elseif string.find(name, "seed") or string.find(name, "wheat") then
        return "F", colors.lime
    else
        return "?", colors.white
    end
end

-- Funzione per pulire i nomi degli item
local function cleanItemName(itemName)
    local cleanName = itemName
    local colonPos = string.find(cleanName, ":")
    if colonPos then
        cleanName = string.sub(cleanName, colonPos + 1)
    end
    
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
                return name
            end
        end
    else
        local sides = {"top", "bottom", "front", "back", "left", "right"}
        for _, side in ipairs(sides) do
            if peripheral.isPresent(side) then
                local pType = peripheral.getType(side)
                if string.find(pType, "chest") or string.find(pType, "barrel") or 
                   string.find(pType, "shulker") or pType == "minecraft:chest" then
                    return side
                end
            end
        end
    end
    
    return nil
end

-- Funzione per trovare tutte le chest connesse
local function findChests()
    chests = {}
    local peripherals = peripheral.getNames()
    
    for _, name in ipairs(peripherals) do
        local pType = peripheral.getType(name)
        if string.find(pType, "chest") or string.find(pType, "barrel") or 
           string.find(pType, "shulker") or pType == "minecraft:chest" then
            if name ~= OUTPUT_SIDE then
                table.insert(chests, name)
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
    
    table.sort(filteredItems, function(a, b)
        return string.lower(a.displayName) < string.lower(b.displayName)
    end)
end

-- Funzione per trasferire item
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

-- Funzione per verificare se turtle e disponibile
local function isTurtleAvailable()
    return peripheral.isPresent(TURTLE_NAME), peripheral.wrap(TURTLE_NAME)
end

-- Funzione per craftare un item
local function craftItem(recipe, quantity)
    local available, turtle = isTurtleAvailable()
    if not available then
        return false, "Turtle non trovata: " .. TURTLE_NAME
    end
    
    if not OUTPUT_SIDE then
        return false, "Chest di output non configurata"
    end
    
    -- Verifica materiali
    for _, ingredient in ipairs(recipe.ingredients) do
        if not inventory[ingredient.item] or inventory[ingredient.item].total < ingredient.count * quantity then
            return false, "Materiali insufficienti: " .. cleanItemName(ingredient.item)
        end
    end
    
    -- Trasferisci materiali alla turtle
    for _, ingredient in ipairs(recipe.ingredients) do
        local needed = ingredient.count * quantity
        local transferred = 0
        
        for _, location in ipairs(inventory[ingredient.item].locations) do
            if transferred >= needed then break end
            
            local sourceChest = peripheral.wrap(location.chest)
            if sourceChest then
                local toTransfer = math.min(needed - transferred, location.count)
                local moved = sourceChest.pushItems(TURTLE_NAME, location.slot, toTransfer)
                transferred = transferred + moved
            end
        end
        
        if transferred < needed then
            return false, "Non riuscito a trasferire abbastanza " .. cleanItemName(ingredient.item)
        end
    end
    
    -- Imposta griglia crafting
    for slot = 1, 16 do
        turtle.select(slot)
        local item = turtle.getItemDetail(slot)
        if item then
            -- Trova dove mettere questo item nella griglia
            local gridSlot = nil
            for _, ingredient in ipairs(recipe.ingredients) do
                if ingredient.item == item.name and ingredient.slot then
                    gridSlot = ingredient.slot
                    break
                end
            end
            
            if gridSlot then
                turtle.transferTo(gridSlot, ingredient.count)
            end
        end
    end
    
    -- Esegui crafting
    local crafted = 0
    for i = 1, quantity do
        if turtle.craft() then
            crafted = crafted + 1
        else
            break
        end
    end
    
    -- Restituisci risultati
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.getItemCount(slot) > 0 then
            turtle.drop()
        end
    end
    
    return crafted > 0, "Craftati " .. crafted .. " item"
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
    drawBox(1, 1, w, 3, colors.blue, colors.white)
    
    term.setCursorPos(2, 2)
    term.write("STORAGE SYSTEM v2.2 - " .. currentMode)
    
    -- Stats
    local chestText = "Chest: " .. #chests
    local itemText = "Item: " .. tablelength(inventory)
    
    term.setCursorPos(w - 25, 2)
    term.write(chestText .. " | " .. itemText)
    
    -- Mode buttons
    drawButton(2, 3, 10, 1, "STORAGE", (currentMode == "STORAGE") and colors.white or colors.lightGray, colors.black)
    drawButton(13, 3, 10, 1, "CRAFTING", (currentMode == "CRAFTING") and colors.white or colors.lightGray, colors.black)
end

local function drawStorageMode()
    if currentMode ~= "STORAGE" then return end
    
    -- Search box
    drawBox(2, 5, w-2, 1, colors.lightGray, colors.black)
    term.setCursorPos(2, 5)
    term.write("Cerca: " .. searchQuery)
    if not quantityInputMode then
        term.write("_")
    end
    
    -- Item list
    local listY = 7
    local listHeight = h - 9
    
    drawBox(2, listY, w-12, listHeight, colors.gray, colors.white)
    
    -- Header lista
    term.setCursorPos(3, listY)
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.write(string.format("%-" .. (w-22) .. "s %8s", "NOME ITEM", "QTA"))
    
    -- Items
    local startIndex = scrollPos + 1
    local endIndex = math.min(startIndex + listHeight - 2, #filteredItems)
    
    for i = startIndex, endIndex do
        local item = filteredItems[i]
        local y = listY + 1 + (i - startIndex)
        
        local bg = (selectedItem == item.name) and colors.yellow or colors.gray
        local fg = (selectedItem == item.name) and colors.black or colors.white
        
        drawBox(2, y, w-12, 1, bg, fg)
        
        local icon, iconColor = getItemIcon(item.name)
        
        term.setCursorPos(3, y)
        term.setBackgroundColor(bg)
        term.setTextColor(iconColor)
        term.write(icon)
        
        term.setCursorPos(5, y)
        term.setTextColor(fg)
        local displayName = item.displayName
        local maxNameLength = w-26
        if string.len(displayName) > maxNameLength then
            displayName = string.sub(displayName, 1, maxNameLength-3) .. "..."
        end
        
        term.write(string.format("%-" .. maxNameLength .. "s %8d", displayName, item.total))
    end
    
    -- Controls
    local controlsX = w - 9
    local controlsY = 7
    
    drawBox(controlsX, controlsY, 8, h - controlsY - 1, colors.lightBlue, colors.black)
    
    term.setCursorPos(controlsX + 1, controlsY + 1)
    term.write("CTRL")
    
    -- Quantity
    term.setCursorPos(controlsX + 1, controlsY + 2)
    term.write("Qta:")
    
    local qtyBg = quantityInputMode and colors.yellow or colors.white
    drawBox(controlsX + 1, controlsY + 3, 6, 1, qtyBg, colors.black)
    term.setCursorPos(controlsX + 1, controlsY + 3)
    
    if quantityInputMode then
        term.write(" " .. quantityInputBuffer .. "_")
    else
        term.write(" " .. tostring(selectedQuantity))
    end
    
    -- Buttons
    drawButton(controlsX + 1, controlsY + 4, 2, 1, "-", colors.red, colors.white)
    drawButton(controlsX + 4, controlsY + 4, 2, 1, "+", colors.green, colors.white)
    
    local transferEnabled = selectedItem ~= nil and OUTPUT_SIDE ~= nil
    local transferBg = transferEnabled and colors.lime or colors.gray
    drawButton(controlsX + 1, controlsY + 6, 6, 1, "GET", transferBg, colors.black)
    
    drawButton(controlsX + 1, controlsY + 8, 6, 1, "OUTPUT", colors.cyan, colors.white)
    drawButton(controlsX + 1, controlsY + 9, 6, 1, "REFRESH", colors.orange, colors.black)
end

local function drawCraftingMode()
    if currentMode ~= "CRAFTING" then return end
    
    -- Recipe list
    drawBox(2, 5, w-12, 1, colors.lightGray, colors.black)
    term.setCursorPos(3, 5)
    term.write("RICETTE DISPONIBILI")
    
    for i, recipe in ipairs(recipes) do
        local y = 6 + i
        if y > h - 3 then break end
        
        local bg = (selectedRecipe == i) and colors.yellow or colors.gray
        local fg = (selectedRecipe == i) and colors.black or colors.white
        
        drawBox(2, y, w-12, 1, bg, fg)
        term.setCursorPos(3, y)
        term.write(recipe.name .. " -> " .. cleanItemName(recipe.result) .. " x" .. recipe.count)
    end
    
    -- Crafting controls
    local controlsX = w - 9
    local controlsY = 7
    
    drawBox(controlsX, controlsY, 8, h - controlsY - 1, colors.lightBlue, colors.black)
    
    term.setCursorPos(controlsX + 1, controlsY + 1)
    term.write("CRAFT")
    
    -- Quantity
    drawButton(controlsX + 1, controlsY + 3, 6, 1, "Qta: " .. craftQuantity, colors.white, colors.black, false)
    drawButton(controlsX + 1, controlsY + 4, 2, 1, "-", colors.red, colors.white)
    drawButton(controlsX + 4, controlsY + 4, 2, 1, "+", colors.green, colors.white)
    
    -- Craft button
    local craftEnabled = selectedRecipe ~= nil
    local craftBg = craftEnabled and colors.lime or colors.gray
    drawButton(controlsX + 1, controlsY + 6, 6, 1, "CRAFT", craftBg, colors.black)
    
    -- Turtle status
    local turtleAvailable = isTurtleAvailable()
    term.setCursorPos(controlsX + 1, controlsY + 8)
    term.setTextColor(turtleAvailable and colors.lime or colors.red)
    term.write("Turtle:")
    term.setCursorPos(controlsX + 1, controlsY + 9)
    term.write(turtleAvailable and "OK" or "NO")
end

local function drawStatusBar()
    drawBox(1, h, w, 1, colors.black, statusColor)
    term.setCursorPos(2, h)
    term.write(statusMessage)
    
    if currentMode == "STORAGE" and selectedItem and inventory[selectedItem] then
        local available = inventory[selectedItem].total
        local statusText = "Disponibili: " .. available
        term.setCursorPos(w - string.len(statusText) - 1, h)
        term.write(statusText)
    end
end

local function drawGUI()
    term.clear()
    drawHeader()
    drawStorageMode()
    drawCraftingMode()
    drawStatusBar()
end

-- Funzione per selezionare chest di output
local function selectOutputChest()
    term.clear()
    term.setCursorPos(1, 1)
    
    print("=== SELEZIONA CHEST DI OUTPUT ===")
    print("")
    
    local availableChests = {}
    local peripherals = peripheral.getNames()
    
    for _, name in ipairs(peripherals) do
        local pType = peripheral.getType(name)
        if string.find(pType, "chest") or string.find(pType, "barrel") or 
           string.find(pType, "shulker") or pType == "minecraft:chest" then
            table.insert(availableChests, {name = name, type = pType})
        end
    end
    
    if #availableChests == 0 then
        print("Nessuna chest trovata!")
        print("Premi un tasto per tornare...")
        os.pullEvent("key")
        return
    end
    
    print("CHEST DISPONIBILI:")
    for i, chest in ipairs(availableChests) do
        local status = ""
        if chest.name == OUTPUT_SIDE then
            status = " (ATTUALE)"
        end
        print(i .. ". " .. chest.name .. " (" .. chest.type .. ")" .. status)
    end
    
    print("")
    print("Inserisci il numero della chest (0 per annullare): ")
    local input = read()
    local choice = tonumber(input)
    
    if choice and choice >= 1 and choice <= #availableChests then
        OUTPUT_SIDE = availableChests[choice].name
        
        setStatus("Output cambiato: " .. OUTPUT_SIDE, colors.lime)
        findChests()
        if #chests > 0 then
            scanInventories()
        end
        
        print("Output impostato su: " .. OUTPUT_SIDE)
    elseif choice == 0 then
        print("Operazione annullata")
    else
        print("Scelta non valida")
    end
    
    sleep(2)
end

-- Gestione eventi
local function handleClick(x, y, button)
    -- Mode buttons
    if y == 3 then
        if x >= 2 and x <= 11 then
            currentMode = "STORAGE"
            return
        elseif x >= 13 and x <= 22 then
            currentMode = "CRAFTING"
            return
        end
    end
    
    if currentMode == "STORAGE" then
        -- Lista item
        if x >= 2 and x <= w-12 and y >= 8 then
            local clickIndex = scrollPos + (y - 7)
            
            if clickIndex >= 1 and clickIndex <= #filteredItems then
                selectedItem = filteredItems[clickIndex].name
                selectedQuantity = 1
                quantityInputMode = false
                quantityInputBuffer = ""
                setStatus("Selezionato: " .. filteredItems[clickIndex].displayName, colors.lime)
            end
        end
        
        -- Storage controls
        local controlsX = w - 9
        local controlsY = 7
        
        if x >= controlsX then
            -- Quantity input
            if x >= controlsX + 1 and x <= controlsX + 6 and y == controlsY + 3 then
                if not quantityInputMode then
                    quantityInputMode = true
                    quantityInputBuffer = tostring(selectedQuantity)
                    setStatus("Inserisci quantita (Enter per confermare)", colors.yellow)
                end
            end
            
            -- - button
            if x >= controlsX + 1 and x <= controlsX + 2 and y == controlsY + 4 and not quantityInputMode then
                if selectedQuantity > 1 then
                    selectedQuantity = selectedQuantity - 1
                end
            end
            
            -- + button
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
            
            -- GET button
            if x >= controlsX + 1 and x <= controlsX + 6 and y == controlsY + 6 and not quantityInputMode then
                if selectedItem and OUTPUT_SIDE then
                    setStatus("Trasferimento in corso...", colors.yellow)
                    drawStatusBar()
                    
                    local success, message = transferItem(selectedItem, selectedQuantity)
                    if success then
                        setStatus(message, colors.lime)
                        scanInventories()
                    else
                        setStatus("ERRORE: " .. message, colors.red)
                    end
                else
                    setStatus("Seleziona item e configura output", colors.red)
                end
            end
            
            -- OUTPUT button
            if x >= controlsX + 1 and x <= controlsX + 6 and y == controlsY + 8 and not quantityInputMode then
                selectOutputChest()
            end
            
            -- REFRESH button  
            if x >= controlsX + 1 and x <= controlsX + 6 and y == controlsY + 9 and not quantityInputMode then
                setStatus("Aggiornamento inventario...", colors.yellow)
                drawStatusBar()
                scanInventories()
                setStatus("Inventario aggiornato!", colors.lime)
            end
        end
        
    elseif currentMode == "CRAFTING" then
        -- Recipe selection
        if x >= 2 and x <= w-12 and y >= 7 then
            local recipeIndex = y - 6
            if recipeIndex >= 1 and recipeIndex <= #recipes then
                selectedRecipe = recipeIndex
                setStatus("Selezionata: " .. recipes[recipeIndex].name, colors.lime)
            end
        end
        
        -- Crafting controls
        local controlsX = w - 9
        local controlsY = 7
        
        if x >= controlsX then
            -- - button
            if x >= controlsX + 1 and x <= controlsX + 2 and y == controlsY + 4 then
                if craftQuantity > 1 then
                    craftQuantity = craftQuantity - 1
                end
            end
            
            -- + button
            if x >= controlsX + 4 and x <= controlsX + 5 and y == controlsY + 4 then
                craftQuantity = craftQuantity + 1
            end
            
            -- CRAFT button
            if x >= controlsX + 1 and x <= controlsX + 6 and y == controlsY + 6 then
                if selectedRecipe then
                    local recipe = recipes[selectedRecipe]
                    setStatus("Crafting in corso...", colors.yellow)
                    drawStatusBar()
                    
                    local success, message = craftItem(recipe, craftQuantity)
                    if success then
                        setStatus(message, colors.lime)
                        scanInventories()
                    else
                        setStatus("ERRORE: " .. message, colors.red)
                    end
                else
                    setStatus("Seleziona una ricetta", colors.red)
                end
            end
        end
    end
end

local function handleScroll(dir)
    if currentMode == "STORAGE" then
        local listHeight = h - 9
        local maxVisible = listHeight - 1
        local maxScroll = math.max(0, #filteredItems - maxVisible)
        
        scrollPos = scrollPos + (dir * 3)
        scrollPos = math.max(0, math.min(scrollPos, maxScroll))
    end
end

local function handleKeyboard(key)
    if quantityInputMode then
        if key == keys.enter then
            local newQuantity = tonumber(quantityInputBuffer)
            if newQuantity and newQuantity > 0 then
                if selectedItem and inventory[selectedItem] then
                    local maxAvailable = inventory[selectedItem].total
                    selectedQuantity = math.min(newQuantity, maxAvailable)
                else
                    selectedQuantity = newQuantity
                end
                setStatus("Quantita impostata: " .. selectedQuantity, colors.lime)
            else
                setStatus("Quantita non valida", colors.red)
            end
            quantityInputMode = false
            quantityInputBuffer = ""
        elseif key == keys.backspace then
            if string.len(quantityInputBuffer) > 0 then
                quantityInputBuffer = string.sub(quantityInputBuffer, 1, -2)
            end
        elseif key == keys.escape then
            quantityInputMode = false
            quantityInputBuffer = ""
            setStatus("Input quantita annullato", colors.yellow)
        end
    else
        if currentMode == "STORAGE" then
            if key == keys.backspace then
                if string.len(searchQuery) > 0 then
                    searchQuery = string.sub(searchQuery, 1, -2)
                    updateFilteredItems()
                    scrollPos = 0
                end
            elseif key == keys.up then
                handleScroll(-1)
            elseif key == keys.down then
                handleScroll(1)
            end
        end
    end
end

local function handleChar(char)
    if quantityInputMode then
        if string.match(char, "%d") and string.len(quantityInputBuffer) < 6 then
            quantityInputBuffer = quantityInputBuffer .. char
        end
    else
        if currentMode == "STORAGE" then
            if string.len(searchQuery) < 20 then
                searchQuery = searchQuery .. char
                updateFilteredItems()
                scrollPos = 0
            end
        end
    end
end

-- Main function
local function main()
    term.clear()
    term.setCursorPos(1, 1)
    
    print("=================================")
    print("  STORAGE SYSTEM v2.2 FIXED     ")
    print("  Con Autocrafting Base          ")
    print("=================================")
    print("")
    print("Inizializzazione sistema...")
    
    OUTPUT_SIDE = findOutputChest()
    findChests()
    
    if #chests > 0 then
        print("Scansione inventari...")
        scanInventories()
    else
        totalSlots = 0
        usedSlots = 0
        updateFilteredItems()
    end
    
    print("Sistema pronto!")
    sleep(1)
    
    setStatus("Sistema pronto - " .. #chests .. " chest trovate", colors.lime)
    
    -- Main loop
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

main()