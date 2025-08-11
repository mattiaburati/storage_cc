-- storage_crafting.lua - Modulo autocrafting per sistema storage
-- Gestisce crafting automatico tramite turtle

local StorageCrafting = {}

-- Configurazione
StorageCrafting.TURTLE_NAME = "turtle_1"
StorageCrafting.RECIPES_FILE = "recipes.json"

-- Variabili globali
StorageCrafting.recipes = {}
StorageCrafting.craftingQueue = {}
StorageCrafting.isCrafting = false

-- Funzione per verificare se la turtle e disponibile
function StorageCrafting.isTurtleAvailable()
    if not peripheral.isPresent(StorageCrafting.TURTLE_NAME) then
        return false, "Turtle non trovata: " .. StorageCrafting.TURTLE_NAME
    end
    
    local turtle = peripheral.wrap(StorageCrafting.TURTLE_NAME)
    if not turtle then
        return false, "Impossibile connettersi alla turtle"
    end
    
    return true, turtle
end

-- Funzione per caricare le ricette da file
function StorageCrafting.loadRecipes()
    StorageCrafting.recipes = {}
    
    if fs.exists(StorageCrafting.RECIPES_FILE) then
        local file = fs.open(StorageCrafting.RECIPES_FILE, "r")
        if file then
            local content = file.readAll()
            file.close()
            
            local success, data = pcall(textutils.unserializeJSON, content)
            if success and data then
                StorageCrafting.recipes = data
                return true, "Caricate " .. #StorageCrafting.recipes .. " ricette"
            else
                return false, "Errore nel parsing delle ricette"
            end
        end
    end
    
    return true, "Nessun file ricette trovato - inizializzato vuoto"
end

-- Funzione per salvare le ricette su file
function StorageCrafting.saveRecipes()
    local file = fs.open(StorageCrafting.RECIPES_FILE, "w")
    if file then
        local content = textutils.serializeJSON(StorageCrafting.recipes)
        file.write(content)
        file.close()
        return true, "Ricette salvate"
    else
        return false, "Errore nel salvare le ricette"
    end
end

-- Funzione per aggiungere una nuova ricetta
function StorageCrafting.addRecipe(name, result, ingredients, craftingGrid)
    local recipe = {
        name = name,
        result = {
            item = result.item,
            count = result.count or 1
        },
        ingredients = ingredients, -- Lista degli ingredienti necessari
        grid = craftingGrid -- Griglia 3x3 con disposizione ingredienti
    }
    
    table.insert(StorageCrafting.recipes, recipe)
    StorageCrafting.saveRecipes()
    
    return true, "Ricetta '" .. name .. "' aggiunta"
end

-- Funzione per rimuovere una ricetta
function StorageCrafting.removeRecipe(index)
    if index >= 1 and index <= #StorageCrafting.recipes then
        local recipeName = StorageCrafting.recipes[index].name
        table.remove(StorageCrafting.recipes, index)
        StorageCrafting.saveRecipes()
        return true, "Ricetta '" .. recipeName .. "' rimossa"
    else
        return false, "Indice ricetta non valido"
    end
end

-- Funzione per ottenere una ricetta per nome
function StorageCrafting.getRecipe(name)
    for i, recipe in ipairs(StorageCrafting.recipes) do
        if recipe.name == name then
            return recipe, i
        end
    end
    return nil, nil
end

-- Funzione per verificare se abbiamo abbastanza materiali per una ricetta
function StorageCrafting.checkMaterials(recipe, quantity, inventory)
    local needed = {}
    
    -- Calcola materiali necessari
    for _, ingredient in pairs(recipe.ingredients) do
        local totalNeeded = ingredient.count * quantity
        needed[ingredient.item] = (needed[ingredient.item] or 0) + totalNeeded
    end
    
    -- Verifica disponibilita nell'inventario
    for item, count in pairs(needed) do
        if not inventory[item] or inventory[item].total < count then
            return false, "Materiali insufficienti: " .. item .. " (serve: " .. count .. ", disponibili: " .. (inventory[item] and inventory[item].total or 0) .. ")"
        end
    end
    
    return true, needed
end

-- Funzione per trasferire materiali alla turtle
function StorageCrafting.transferMaterials(turtle, needed, inventory)
    local transferred = {}
    
    for item, count in pairs(needed) do
        local remaining = count
        
        if inventory[item] then
            for _, location in ipairs(inventory[item].locations) do
                if remaining <= 0 then break end
                
                local sourceChest = peripheral.wrap(location.chest)
                if sourceChest then
                    local toTransfer = math.min(remaining, location.count)
                    
                    -- Trova slot libero nella turtle
                    local turtleSlot = nil
                    for slot = 1, 16 do
                        local slotData = turtle.getItemDetail(slot)
                        if not slotData then
                            turtleSlot = slot
                            break
                        elseif slotData.name == item then
                            local space = slotData.maxCount - slotData.count
                            if space > 0 then
                                turtleSlot = slot
                                toTransfer = math.min(toTransfer, space)
                                break
                            end
                        end
                    end
                    
                    if turtleSlot then
                        local moved = sourceChest.pushItems(StorageCrafting.TURTLE_NAME, location.slot, toTransfer, turtleSlot)
                        if moved > 0 then
                            transferred[item] = (transferred[item] or 0) + moved
                            remaining = remaining - moved
                        end
                    else
                        return false, "Turtle piena - non posso trasferire " .. item
                    end
                end
            end
        end
        
        if remaining > 0 then
            return false, "Non sono riuscito a trasferire abbastanza " .. item .. " (mancano: " .. remaining .. ")"
        end
    end
    
    return true, transferred
end

-- Funzione per impostare la griglia di crafting nella turtle
function StorageCrafting.setupCraftingGrid(turtle, recipe)
    -- Prima svuota la griglia di crafting
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.getItemCount(slot) > 0 then
            -- Trova uno slot vuoto per spostare gli item
            for emptySlot = 1, 16 do
                if turtle.getItemCount(emptySlot) == 0 then
                    turtle.transferTo(emptySlot)
                    break
                end
            end
        end
    end
    
    -- Imposta la griglia secondo la ricetta
    for gridPos = 1, 9 do
        local gridSlot = gridPos + 16 -- Slots 17-25 sono la crafting grid
        local ingredient = recipe.grid[gridPos]
        
        if ingredient then
            -- Trova l'ingrediente nell'inventario turtle
            local sourceSlot = nil
            for slot = 1, 16 do
                local item = turtle.getItemDetail(slot)
                if item and item.name == ingredient.item and item.count >= ingredient.count then
                    sourceSlot = slot
                    break
                end
            end
            
            if sourceSlot then
                turtle.select(sourceSlot)
                turtle.transferTo(gridSlot, ingredient.count)
            else
                return false, "Ingrediente mancante nella turtle: " .. ingredient.item
            end
        end
    end
    
    return true, "Griglia di crafting impostata"
end

-- Funzione per eseguire il crafting
function StorageCrafting.executeCraft(turtle, quantity)
    local crafted = 0
    
    for i = 1, quantity do
        if turtle.craft() then
            crafted = crafted + 1
        else
            break
        end
    end
    
    return crafted > 0, crafted .. " item craftati"
end

-- Funzione per restituire i risultati al sistema storage
function StorageCrafting.returnResults(turtle, outputChest)
    local returned = {}
    
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item then
            local moved = turtle.pushItems(outputChest, slot)
            if moved > 0 then
                returned[item.name] = (returned[item.name] or 0) + moved
            end
        end
    end
    
    return returned
end

-- Funzione principale per craftare un item
function StorageCrafting.craftItem(recipeName, quantity, inventory, outputChest)
    if StorageCrafting.isCrafting then
        return false, "Crafting gia in corso"
    end
    
    local recipe, recipeIndex = StorageCrafting.getRecipe(recipeName)
    if not recipe then
        return false, "Ricetta non trovata: " .. recipeName
    end
    
    local turtleOk, turtle = StorageCrafting.isTurtleAvailable()
    if not turtleOk then
        return false, turtle -- turtle contiene il messaggio di errore
    end
    
    -- Verifica materiali
    local materialsOk, needed = StorageCrafting.checkMaterials(recipe, quantity, inventory)
    if not materialsOk then
        return false, needed -- needed contiene il messaggio di errore
    end
    
    StorageCrafting.isCrafting = true
    
    -- Trasferisci materiali alla turtle
    local transferOk, transferred = StorageCrafting.transferMaterials(turtle, needed, inventory)
    if not transferOk then
        StorageCrafting.isCrafting = false
        return false, transferred -- transferred contiene il messaggio di errore
    end
    
    -- Imposta griglia di crafting
    local gridOk, gridMsg = StorageCrafting.setupCraftingGrid(turtle, recipe)
    if not gridOk then
        StorageCrafting.isCrafting = false
        return false, gridMsg
    end
    
    -- Esegui crafting
    local craftOk, craftMsg = StorageCrafting.executeCraft(turtle, quantity)
    if not craftOk then
        StorageCrafting.isCrafting = false
        return false, craftMsg
    end
    
    -- Restituisci risultati
    local results = StorageCrafting.returnResults(turtle, outputChest)
    
    StorageCrafting.isCrafting = false
    
    return true, "Crafting completato: " .. craftMsg .. " - Risultati restituiti al storage"
end

-- Funzione per aggiungere item alla coda di crafting
function StorageCrafting.queueCraft(recipeName, quantity)
    table.insert(StorageCrafting.craftingQueue, {
        recipe = recipeName,
        quantity = quantity,
        timestamp = os.clock()
    })
    
    return true, "Aggiunto alla coda: " .. recipeName .. " x" .. quantity
end

-- Funzione per processare la coda di crafting
function StorageCrafting.processCraftingQueue(inventory, outputChest)
    if StorageCrafting.isCrafting or #StorageCrafting.craftingQueue == 0 then
        return false, "Coda vuota o crafting in corso"
    end
    
    local job = table.remove(StorageCrafting.craftingQueue, 1)
    return StorageCrafting.craftItem(job.recipe, job.quantity, inventory, outputChest)
end

-- Funzione per ottenere lo stato del sistema crafting
function StorageCrafting.getStatus()
    return {
        isCrafting = StorageCrafting.isCrafting,
        queueLength = #StorageCrafting.craftingQueue,
        recipesLoaded = #StorageCrafting.recipes,
        turtleAvailable = StorageCrafting.isTurtleAvailable()
    }
end

-- Funzione per cancellare la coda di crafting
function StorageCrafting.clearQueue()
    StorageCrafting.craftingQueue = {}
    return true, "Coda di crafting svuotata"
end

-- Inizializzazione del modulo
function StorageCrafting.init()
    local success, message = StorageCrafting.loadRecipes()
    return success, message
end

return StorageCrafting