-- Sistema di Storage Avanzato con Autocrafting
-- Versione: 2.1 - Con supporto autocrafting
-- Autore: Claude AI

-- Caricamento moduli
local Crafting = require("storage_crafting")
local Recipes = require("storage_recipes")

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
local currentMode = "STORAGE" -- "STORAGE", "CRAFTING", "RECIPES"
local craftingMode = "LIST" -- "LIST", "QUEUE", "STATUS"
local selectedRecipe = nil
local craftQuantity = 1

-- Inizializzazione moduli
local function initModules()
    local success, message = Crafting.init()
    if not success then
        setStatus("Errore crafting: " .. message, colors.red)
    end
    return success, message
end

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

-- Funzioni storage (riutilizzate dal sistema precedente)
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
    term.write("STORAGE SYSTEM v2.1 - " .. currentMode)
    
    -- Tabs
    local tabY = 3
    local tabWidth = math.floor(w / 3)
    
    -- Tab STORAGE
    local storageBg = (currentMode == "STORAGE") and colors.white or colors.lightGray
    local storageFg = (currentMode == "STORAGE") and colors.black or colors.gray
    drawButton(1, tabY, tabWidth, 1, "STORAGE", storageBg, storageFg)
    
    -- Tab CRAFTING
    local craftingBg = (currentMode == "CRAFTING") and colors.white or colors.lightGray
    local craftingFg = (currentMode == "CRAFTING") and colors.black or colors.gray
    drawButton(tabWidth + 1, tabY, tabWidth, 1, "CRAFTING", craftingBg, craftingFg)
    
    -- Tab RECIPES
    local recipesBg = (currentMode == "RECIPES") and colors.white or colors.lightGray
    local recipesFg = (currentMode == "RECIPES") and colors.black or colors.gray
    drawButton(tabWidth * 2 + 1, tabY, tabWidth, 1, "RECIPES", recipesBg, recipesFg)
    
    -- Status info
    if currentMode == "STORAGE" then
        term.setCursorPos(w - 25, 2)
        term.write("Chest: " .. #chests .. " | Items: " .. tablelength(inventory))
    elseif currentMode == "CRAFTING" then
        local status = Crafting.getStatus()
        term.setCursorPos(w - 30, 2)
        term.write("Turtle: " .. (status.turtleAvailable and "OK" or "NO") .. " | Coda: " .. status.queueLength)
    end
end

-- Funzione per disegnare il contenuto storage
local function drawStorageContent()
    if currentMode ~= "STORAGE" then return end
    
    -- Search box
    drawBox(2, 5, w-2, 1, colors.lightGray, colors.black)
    term.setCursorPos(2, 5)
    term.write("Cerca: " .. searchQuery .. "_")
    
    -- Item list
    local listY = 7
    local listHeight = h - 9
    local maxVisible = listHeight
    
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
        
        local icon, iconColor = getItemIcon(item.name)
        
        term.setCursorPos(3, y)
        if selectedItem == item.name then
            term.setBackgroundColor(colors.yellow)
        else
            term.setBackgroundColor(colors.gray)
        end
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
    
    -- Storage controls
    local controlsX = w - 9
    local controlsY = 7
    
    drawBox(controlsX, controlsY, 8, h - controlsY - 1, colors.lightBlue, colors.black)
    
    term.setCursorPos(controlsX + 1, controlsY + 1)
    term.write("CTRL")
    
    drawButton(controlsX + 1, controlsY + 3, 6, 1, "GET", colors.lime, colors.black)
    drawButton(controlsX + 1, controlsY + 5, 6, 1, "OUTPUT", colors.cyan, colors.white)
    drawButton(controlsX + 1, controlsY + 6, 6, 1, "REFRESH", colors.orange, colors.black)
    drawButton(controlsX + 1, controlsY + 7, 6, 1, "ORDINA", colors.pink, colors.black)
end

-- Funzione per disegnare il contenuto crafting
local function drawCraftingContent()
    if currentMode ~= "CRAFTING" then return end
    
    local startY = 5
    
    -- Sotto-tabs per crafting
    drawButton(2, startY, 10, 1, "RICETTE", (craftingMode == "LIST") and colors.yellow or colors.gray, colors.black)
    drawButton(13, startY, 8, 1, "CODA", (craftingMode == "QUEUE") and colors.yellow or colors.gray, colors.black)
    drawButton(22, startY, 8, 1, "STATUS", (craftingMode == "STATUS") and colors.yellow or colors.gray, colors.black)
    
    if craftingMode == "LIST" then
        -- Lista ricette per crafting
        drawBox(2, startY + 2, w-12, 1, colors.lightGray, colors.black)
        term.setCursorPos(3, startY + 2)
        term.write("RICETTE DISPONIBILI")
        
        for i, recipe in ipairs(Crafting.recipes) do
            local y = startY + 3 + i
            if y > h - 3 then break end
            
            local bg = (selectedRecipe == i) and colors.yellow or colors.gray
            local fg = (selectedRecipe == i) and colors.black or colors.white
            
            drawBox(2, y, w-12, 1, bg, fg)
            term.setCursorPos(3, y)
            
            local name = recipe.name
            if string.len(name) > w - 20 then
                name = string.sub(name, 1, w - 23) .. "..."
            end
            term.write(name)
            
            term.setCursorPos(w - 15, y)
            term.write(recipe.result.item .. " x" .. recipe.result.count)
        end
        
    elseif craftingMode == "QUEUE" then
        -- Coda di crafting
        drawBox(2, startY + 2, w-12, 1, colors.lightGray, colors.black)
        term.setCursorPos(3, startY + 2)
        term.write("CODA CRAFTING")
        
        if #Crafting.craftingQueue == 0 then
            term.setCursorPos(3, startY + 4)
            term.write("Coda vuota")
        else
            for i, job in ipairs(Crafting.craftingQueue) do
                local y = startY + 3 + i
                if y > h - 3 then break end
                
                drawBox(2, y, w-12, 1, colors.gray, colors.white)
                term.setCursorPos(3, y)
                term.write(job.recipe .. " x" .. job.quantity)
            end
        end
        
    elseif craftingMode == "STATUS" then
        -- Status sistema crafting
        local status = Crafting.getStatus()
        local y = startY + 2
        
        term.setCursorPos(2, y)
        term.write("Turtle disponibile: " .. (status.turtleAvailable and "SI" or "NO"))
        term.setCursorPos(2, y + 1)
        term.write("Crafting attivo: " .. (status.isCrafting and "SI" or "NO"))
        term.setCursorPos(2, y + 2)
        term.write("Job in coda: " .. status.queueLength)
        term.setCursorPos(2, y + 3)
        term.write("Ricette caricate: " .. status.recipesLoaded)
    end
    
    -- Controlli crafting
    local controlsX = w - 9
    local controlsY = 7
    
    drawBox(controlsX, controlsY, 8, h - controlsY - 1, colors.lightBlue, colors.black)
    
    if craftingMode == "LIST" then
        drawButton(controlsX + 1, controlsY + 1, 6, 1, "QTA: " .. craftQuantity, colors.white, colors.black, false)
        drawButton(controlsX + 1, controlsY + 2, 2, 1, "-", colors.red, colors.white)
        drawButton(controlsX + 4, controlsY + 2, 2, 1, "+", colors.green, colors.white)
        drawButton(controlsX + 1, controlsY + 4, 6, 1, "CRAFT", colors.lime, colors.black)
        drawButton(controlsX + 1, controlsY + 5, 6, 1, "ACCODA", colors.yellow, colors.black)
    elseif craftingMode == "QUEUE" then
        drawButton(controlsX + 1, controlsY + 1, 6, 1, "AVVIA", colors.green, colors.white)
        drawButton(controlsX + 1, controlsY + 2, 6, 1, "PULISCI", colors.red, colors.white)
    end
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
    drawStorageContent()
    drawCraftingContent()
    drawStatusBar()
end

-- Gestione click
local function handleClick(x, y, button)
    local tabWidth = math.floor(w / 3)
    
    -- Click su tabs
    if y == 3 then
        if x <= tabWidth then
            currentMode = "STORAGE"
            return
        elseif x <= tabWidth * 2 then
            currentMode = "CRAFTING"
            return
        else
            currentMode = "RECIPES"
            -- Avvia editor ricette
            Recipes.run()
            return
        end
    end
    
    if currentMode == "STORAGE" then
        -- Gestione click storage (come nel sistema precedente)
        if x >= 2 and x <= w-12 and y >= 8 then
            local listY = 7
            local clickIndex = scrollPos + (y - listY)
            
            if clickIndex >= 1 and clickIndex <= #filteredItems then
                selectedItem = filteredItems[clickIndex].name
                selectedQuantity = 1
                setStatus("Selezionato: " .. filteredItems[clickIndex].displayName, colors.lime)
            end
        end
        
        -- Click controlli storage
        local controlsX = w - 9
        local controlsY = 7
        
        if x >= controlsX then
            if y == controlsY + 3 then -- GET
                -- Logica trasferimento (come nel sistema precedente)
            elseif y == controlsY + 6 then -- REFRESH
                setStatus("Aggiornamento inventario...", colors.yellow)
                scanInventories()
                setStatus("Inventario aggiornato!", colors.lime)
            end
        end
        
    elseif currentMode == "CRAFTING" then
        local startY = 5
        
        -- Click su sotto-tabs crafting
        if y == startY then
            if x >= 2 and x <= 11 then
                craftingMode = "LIST"
            elseif x >= 13 and x <= 20 then
                craftingMode = "QUEUE"
            elseif x >= 22 and x <= 29 then
                craftingMode = "STATUS"
            end
        end
        
        -- Click su lista ricette
        if craftingMode == "LIST" and y > startY + 3 then
            local recipeIndex = y - startY - 3
            if recipeIndex >= 1 and recipeIndex <= #Crafting.recipes then
                selectedRecipe = recipeIndex
                setStatus("Selezionata ricetta: " .. Crafting.recipes[recipeIndex].name, colors.lime)
            end
        end
        
        -- Click controlli crafting
        local controlsX = w - 9
        local controlsY = 7
        
        if x >= controlsX then
            if craftingMode == "LIST" then
                if y == controlsY + 2 and x <= controlsX + 2 then -- -
                    if craftQuantity > 1 then craftQuantity = craftQuantity - 1 end
                elseif y == controlsY + 2 and x >= controlsX + 4 then -- +
                    craftQuantity = craftQuantity + 1
                elseif y == controlsY + 4 then -- CRAFT
                    if selectedRecipe then
                        local recipe = Crafting.recipes[selectedRecipe]
                        setStatus("Avvio crafting: " .. recipe.name, colors.yellow)
                        drawStatusBar()
                        
                        local success, message = Crafting.craftItem(recipe.name, craftQuantity, inventory, OUTPUT_SIDE)
                        if success then
                            setStatus(message, colors.lime)
                            scanInventories() -- Aggiorna inventario
                        else
                            setStatus("ERRORE: " .. message, colors.red)
                        end
                    else
                        setStatus("Seleziona una ricetta", colors.red)
                    end
                elseif y == controlsY + 5 then -- ACCODA
                    if selectedRecipe then
                        local recipe = Crafting.recipes[selectedRecipe]
                        local success, message = Crafting.queueCraft(recipe.name, craftQuantity)
                        setStatus(message, success and colors.lime or colors.red)
                    else
                        setStatus("Seleziona una ricetta", colors.red)
                    end
                end
            elseif craftingMode == "QUEUE" then
                if y == controlsY + 1 then -- AVVIA
                    setStatus("Processando coda crafting...", colors.yellow)
                    drawStatusBar()
                    
                    local success, message = Crafting.processCraftingQueue(inventory, OUTPUT_SIDE)
                    if success then
                        setStatus(message, colors.lime)
                        scanInventories()
                    else
                        setStatus("ERRORE: " .. message, colors.red)
                    end
                elseif y == controlsY + 2 then -- PULISCI
                    Crafting.clearQueue()
                    setStatus("Coda crafting svuotata", colors.yellow)
                end
            end
        end
    end
end

-- Gestione scroll
local function handleScroll(dir)
    if currentMode == "STORAGE" then
        local listHeight = h - 9
        local maxVisible = listHeight - 1
        local maxScroll = math.max(0, #filteredItems - maxVisible)
        
        scrollPos = scrollPos + (dir * 3)
        scrollPos = math.max(0, math.min(scrollPos, maxScroll))
    end
end

-- Gestione tastiera
local function handleKeyboard(key)
    if currentMode == "STORAGE" then
        if key == keys.backspace then
            if string.len(searchQuery) > 0 then
                searchQuery = string.sub(searchQuery, 1, -2)
                updateFilteredItems()
                scrollPos = 0
            end
        end
    end
end

-- Gestione caratteri
local function handleChar(char)
    if currentMode == "STORAGE" then
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
    
    print("=================================")
    print("  STORAGE SYSTEM AVANZATO v2.1  ")
    print("  Con Autocrafting               ")
    print("=================================")
    print("")
    print("Inizializzazione moduli...")
    
    -- Inizializza moduli
    initModules()
    
    OUTPUT_SIDE, _ = findOutputChest()
    findChests()
    
    if #chests > 0 then
        print("Scansione inventari...")
        scanInventories()
    else
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
    print("Grazie per aver usato Storage System v2.1!")
end

-- Avvia il programma
main()