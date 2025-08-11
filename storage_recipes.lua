-- storage_recipes.lua - Interfaccia per creare e gestire ricette di crafting
-- Editor ricette integrato

local StorageRecipes = {}

-- Dipendenze
local Crafting = require("storage_crafting")

-- Variabili GUI ricette
StorageRecipes.selectedRecipe = nil
StorageRecipes.editMode = false
StorageRecipes.newRecipe = {
    name = "",
    result = {item = "", count = 1},
    ingredients = {},
    grid = {} -- 9 elementi per griglia 3x3
}
StorageRecipes.gridSelection = 1 -- Posizione attualmente selezionata nella griglia
StorageRecipes.inputMode = "" -- "name", "result_item", "result_count", "ingredient"

-- Funzione per inizializzare griglia vuota
local function initEmptyGrid()
    local grid = {}
    for i = 1, 9 do
        grid[i] = nil
    end
    return grid
end

-- Funzione per resettare la nuova ricetta
function StorageRecipes.resetNewRecipe()
    StorageRecipes.newRecipe = {
        name = "",
        result = {item = "", count = 1},
        ingredients = {},
        grid = initEmptyGrid()
    }
    StorageRecipes.gridSelection = 1
    StorageRecipes.inputMode = ""
end

-- Funzione per disegnare box
local function drawBox(x, y, width, height, bg, fg)
    term.setBackgroundColor(bg or colors.black)
    term.setTextColor(fg or colors.white)
    
    for row = y, y + height - 1 do
        term.setCursorPos(x, row)
        term.write(string.rep(" ", width))
    end
end

-- Funzione per disegnare bottone
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

-- Funzione per disegnare l'header dell'editor ricette
function StorageRecipes.drawHeader()
    local w, h = term.getSize()
    
    drawBox(1, 1, w, 3, colors.blue, colors.white)
    
    term.setCursorPos(2, 2)
    term.write("EDITOR RICETTE - " .. (StorageRecipes.editMode and "MODIFICA" or "LISTA"))
    
    -- Info ricette
    term.setCursorPos(w - 20, 2)
    term.write("Ricette: " .. #Crafting.recipes)
end

-- Funzione per disegnare la lista delle ricette
function StorageRecipes.drawRecipeList()
    local w, h = term.getSize()
    local startY = 5
    local endY = h - 3
    
    if StorageRecipes.editMode then
        return -- Non mostrare lista se siamo in modalita edit
    end
    
    -- Header lista
    drawBox(2, startY, w-2, 1, colors.lightGray, colors.black)
    term.setCursorPos(3, startY)
    term.write("NOME RICETTA")
    term.setCursorPos(w-20, startY)
    term.write("RISULTATO")
    
    -- Lista ricette
    for i, recipe in ipairs(Crafting.recipes) do
        local y = startY + i
        if y > endY then break end
        
        local bg = (StorageRecipes.selectedRecipe == i) and colors.yellow or colors.gray
        local fg = (StorageRecipes.selectedRecipe == i) and colors.black or colors.white
        
        drawBox(2, y, w-2, 1, bg, fg)
        
        term.setCursorPos(3, y)
        local name = recipe.name
        if string.len(name) > 25 then
            name = string.sub(name, 1, 22) .. "..."
        end
        term.write(name)
        
        term.setCursorPos(w-20, y)
        local result = recipe.result.item .. " x" .. recipe.result.count
        if string.len(result) > 18 then
            result = string.sub(result, 1, 15) .. "..."
        end
        term.write(result)
    end
end

-- Funzione per disegnare l'editor ricette
function StorageRecipes.drawRecipeEditor()
    local w, h = term.getSize()
    
    if not StorageRecipes.editMode then
        return
    end
    
    local startY = 5
    
    -- Nome ricetta
    drawBox(2, startY, 30, 1, colors.white, colors.black)
    term.setCursorPos(2, startY)
    term.write("Nome: " .. StorageRecipes.newRecipe.name)
    if StorageRecipes.inputMode == "name" then
        term.write("_")
    end
    
    -- Risultato
    drawBox(2, startY + 2, 30, 1, colors.white, colors.black)
    term.setCursorPos(2, startY + 2)
    term.write("Risultato: " .. StorageRecipes.newRecipe.result.item .. " x" .. StorageRecipes.newRecipe.result.count)
    if StorageRecipes.inputMode == "result_item" or StorageRecipes.inputMode == "result_count" then
        term.write("_")
    end
    
    -- Griglia crafting 3x3
    local gridStartX = 2
    local gridStartY = startY + 4
    
    drawBox(gridStartX, gridStartY - 1, 20, 1, colors.lightGray, colors.black)
    term.setCursorPos(gridStartX, gridStartY - 1)
    term.write("GRIGLIA CRAFTING 3x3:")
    
    for row = 1, 3 do
        for col = 1, 3 do
            local gridPos = (row - 1) * 3 + col
            local x = gridStartX + (col - 1) * 6
            local y = gridStartY + row - 1
            
            local bg = (StorageRecipes.gridSelection == gridPos) and colors.yellow or colors.lightGray
            local fg = colors.black
            
            drawBox(x, y, 5, 1, bg, fg)
            
            local ingredient = StorageRecipes.newRecipe.grid[gridPos]
            local text = ingredient and string.sub(ingredient.item, 1, 4) or "----"
            
            term.setCursorPos(x, y)
            term.write(" " .. text)
        end
    end
    
    -- Info ingrediente selezionato
    local selectedIngredient = StorageRecipes.newRecipe.grid[StorageRecipes.gridSelection]
    if selectedIngredient then
        drawBox(2, gridStartY + 4, 30, 2, colors.cyan, colors.black)
        term.setCursorPos(2, gridStartY + 4)
        term.write("Slot " .. StorageRecipes.gridSelection .. ": " .. selectedIngredient.item)
        term.setCursorPos(2, gridStartY + 5)
        term.write("Quantita: " .. selectedIngredient.count)
    else
        drawBox(2, gridStartY + 4, 30, 2, colors.red, colors.white)
        term.setCursorPos(2, gridStartY + 4)
        term.write("Slot " .. StorageRecipes.gridSelection .. ": VUOTO")
        term.setCursorPos(2, gridStartY + 5)
        term.write("Premi I per inserire")
    end
end

-- Funzione per disegnare i controlli
function StorageRecipes.drawControls()
    local w, h = term.getSize()
    local controlsX = w - 15
    local startY = 5
    
    if StorageRecipes.editMode then
        -- Controlli modalita edit
        drawButton(controlsX, startY, 12, 1, "SALVA", colors.green, colors.white)
        drawButton(controlsX, startY + 1, 12, 1, "ANNULLA", colors.red, colors.white)
        drawButton(controlsX, startY + 3, 12, 1, "NOME (N)", colors.cyan, colors.white)
        drawButton(controlsX, startY + 4, 12, 1, "RISULTATO (R)", colors.cyan, colors.white)
        drawButton(controlsX, startY + 6, 12, 1, "INSERISCI (I)", colors.orange, colors.white)
        drawButton(controlsX, startY + 7, 12, 1, "RIMUOVI (X)", colors.pink, colors.white)
    else
        -- Controlli modalita lista
        drawButton(controlsX, startY, 12, 1, "NUOVA", colors.green, colors.white)
        drawButton(controlsX, startY + 1, 12, 1, "MODIFICA", colors.yellow, colors.black)
        drawButton(controlsX, startY + 2, 12, 1, "ELIMINA", colors.red, colors.white)
        drawButton(controlsX, startY + 4, 12, 1, "TORNA (Q)", colors.gray, colors.white)
    end
end

-- Funzione per disegnare la barra di stato
function StorageRecipes.drawStatusBar()
    local w, h = term.getSize()
    
    drawBox(1, h, w, 1, colors.black, colors.white)
    term.setCursorPos(2, h)
    
    if StorageRecipes.editMode then
        if StorageRecipes.inputMode ~= "" then
            term.write("Modalita input: " .. StorageRecipes.inputMode .. " - ESC per annullare")
        else
            term.write("Editor ricette - Usa frecce per navigare griglia")
        end
    else
        term.write("Seleziona ricetta con mouse o frecce - Q per uscire")
    end
end

-- Funzione principale per disegnare l'interfaccia
function StorageRecipes.drawGUI()
    term.clear()
    StorageRecipes.drawHeader()
    StorageRecipes.drawRecipeList()
    StorageRecipes.drawRecipeEditor()
    StorageRecipes.drawControls()
    StorageRecipes.drawStatusBar()
end

-- Gestione click
function StorageRecipes.handleClick(x, y, button)
    local w, h = term.getSize()
    local controlsX = w - 15
    local startY = 5
    
    if StorageRecipes.editMode then
        -- Click in modalita edit
        
        -- Controlli
        if x >= controlsX and x <= controlsX + 11 then
            if y == startY then -- SALVA
                StorageRecipes.saveCurrentRecipe()
            elseif y == startY + 1 then -- ANNULLA
                StorageRecipes.cancelEdit()
            elseif y == startY + 3 then -- NOME
                StorageRecipes.inputMode = "name"
            elseif y == startY + 4 then -- RISULTATO
                StorageRecipes.inputMode = "result_item"
            elseif y == startY + 6 then -- INSERISCI
                StorageRecipes.inputMode = "ingredient"
            elseif y == startY + 7 then -- RIMUOVI
                StorageRecipes.removeIngredient()
            end
        end
        
        -- Click su griglia
        local gridStartX = 2
        local gridStartY = startY + 4
        
        if y >= gridStartY and y <= gridStartY + 2 then
            for col = 1, 3 do
                local cellX = gridStartX + (col - 1) * 6
                if x >= cellX and x <= cellX + 4 then
                    local row = y - gridStartY + 1
                    StorageRecipes.gridSelection = (row - 1) * 3 + col
                    break
                end
            end
        end
        
        -- Click su nome ricetta
        if y == startY and x >= 2 and x <= 30 then
            StorageRecipes.inputMode = "name"
        end
        
        -- Click su risultato
        if y == startY + 2 and x >= 2 and x <= 30 then
            StorageRecipes.inputMode = "result_item"
        end
        
    else
        -- Click in modalita lista
        
        -- Click su ricetta
        if x >= 2 and x <= w-2 and y >= 6 then
            local recipeIndex = y - 5
            if recipeIndex >= 1 and recipeIndex <= #Crafting.recipes then
                StorageRecipes.selectedRecipe = recipeIndex
            end
        end
        
        -- Click su controlli
        if x >= controlsX and x <= controlsX + 11 then
            if y == startY then -- NUOVA
                StorageRecipes.startNewRecipe()
            elseif y == startY + 1 then -- MODIFICA
                StorageRecipes.editSelectedRecipe()
            elseif y == startY + 2 then -- ELIMINA
                StorageRecipes.deleteSelectedRecipe()
            end
        end
    end
end

-- Gestione tastiera
function StorageRecipes.handleKeyboard(key)
    if StorageRecipes.editMode then
        if StorageRecipes.inputMode == "" then
            -- Navigazione griglia
            if key == keys.up and StorageRecipes.gridSelection > 3 then
                StorageRecipes.gridSelection = StorageRecipes.gridSelection - 3
            elseif key == keys.down and StorageRecipes.gridSelection <= 6 then
                StorageRecipes.gridSelection = StorageRecipes.gridSelection + 3
            elseif key == keys.left and StorageRecipes.gridSelection % 3 ~= 1 then
                StorageRecipes.gridSelection = StorageRecipes.gridSelection - 1
            elseif key == keys.right and StorageRecipes.gridSelection % 3 ~= 0 then
                StorageRecipes.gridSelection = StorageRecipes.gridSelection + 1
            elseif key == keys.n then
                StorageRecipes.inputMode = "name"
            elseif key == keys.r then
                StorageRecipes.inputMode = "result_item"
            elseif key == keys.i then
                StorageRecipes.inputMode = "ingredient"
            elseif key == keys.x then
                StorageRecipes.removeIngredient()
            end
        else
            -- Modalita input
            if key == keys.escape then
                StorageRecipes.inputMode = ""
            elseif key == keys.enter then
                StorageRecipes.confirmInput()
            end
        end
    else
        -- Navigazione lista
        if key == keys.up and StorageRecipes.selectedRecipe and StorageRecipes.selectedRecipe > 1 then
            StorageRecipes.selectedRecipe = StorageRecipes.selectedRecipe - 1
        elseif key == keys.down and StorageRecipes.selectedRecipe and StorageRecipes.selectedRecipe < #Crafting.recipes then
            StorageRecipes.selectedRecipe = StorageRecipes.selectedRecipe + 1
        elseif key == keys.enter then
            StorageRecipes.editSelectedRecipe()
        elseif key == keys.delete then
            StorageRecipes.deleteSelectedRecipe()
        end
    end
    
    if key == keys.q then
        return true -- Esci
    end
    
    return false
end

-- Gestione caratteri
function StorageRecipes.handleChar(char)
    if StorageRecipes.inputMode == "name" then
        if string.len(StorageRecipes.newRecipe.name) < 30 then
            StorageRecipes.newRecipe.name = StorageRecipes.newRecipe.name .. char
        end
    elseif StorageRecipes.inputMode == "result_item" then
        if string.len(StorageRecipes.newRecipe.result.item) < 50 then
            StorageRecipes.newRecipe.result.item = StorageRecipes.newRecipe.result.item .. char
        end
    elseif StorageRecipes.inputMode == "ingredient" then
        -- Gestito in modo speciale - vedi handleIngredientInput
        StorageRecipes.handleIngredientInput(char)
    end
end

-- Funzioni di gestione ricette
function StorageRecipes.startNewRecipe()
    StorageRecipes.resetNewRecipe()
    StorageRecipes.editMode = true
    StorageRecipes.inputMode = "name"
end

function StorageRecipes.editSelectedRecipe()
    if StorageRecipes.selectedRecipe then
        local recipe = Crafting.recipes[StorageRecipes.selectedRecipe]
        StorageRecipes.newRecipe = {
            name = recipe.name,
            result = {item = recipe.result.item, count = recipe.result.count},
            ingredients = recipe.ingredients,
            grid = recipe.grid
        }
        StorageRecipes.editMode = true
    end
end

function StorageRecipes.saveCurrentRecipe()
    if StorageRecipes.newRecipe.name == "" or StorageRecipes.newRecipe.result.item == "" then
        return -- Nome o risultato mancante
    end
    
    -- Calcola ingredienti dalla griglia
    StorageRecipes.newRecipe.ingredients = {}
    for _, ingredient in pairs(StorageRecipes.newRecipe.grid) do
        if ingredient then
            local found = false
            for _, existing in ipairs(StorageRecipes.newRecipe.ingredients) do
                if existing.item == ingredient.item then
                    existing.count = existing.count + ingredient.count
                    found = true
                    break
                end
            end
            if not found then
                table.insert(StorageRecipes.newRecipe.ingredients, {
                    item = ingredient.item,
                    count = ingredient.count
                })
            end
        end
    end
    
    if StorageRecipes.selectedRecipe then
        -- Modifica ricetta esistente
        Crafting.recipes[StorageRecipes.selectedRecipe] = {
            name = StorageRecipes.newRecipe.name,
            result = StorageRecipes.newRecipe.result,
            ingredients = StorageRecipes.newRecipe.ingredients,
            grid = StorageRecipes.newRecipe.grid
        }
    else
        -- Nuova ricetta
        Crafting.addRecipe(
            StorageRecipes.newRecipe.name,
            StorageRecipes.newRecipe.result,
            StorageRecipes.newRecipe.ingredients,
            StorageRecipes.newRecipe.grid
        )
    end
    
    Crafting.saveRecipes()
    StorageRecipes.editMode = false
    StorageRecipes.selectedRecipe = nil
end

function StorageRecipes.cancelEdit()
    StorageRecipes.editMode = false
    StorageRecipes.inputMode = ""
    StorageRecipes.resetNewRecipe()
end

function StorageRecipes.deleteSelectedRecipe()
    if StorageRecipes.selectedRecipe then
        Crafting.removeRecipe(StorageRecipes.selectedRecipe)
        StorageRecipes.selectedRecipe = nil
    end
end

function StorageRecipes.removeIngredient()
    StorageRecipes.newRecipe.grid[StorageRecipes.gridSelection] = nil
end

function StorageRecipes.handleIngredientInput(char)
    -- Implementazione semplificata - in un caso reale potresti voler
    -- mostrare una lista degli item disponibili dal sistema storage
end

function StorageRecipes.confirmInput()
    if StorageRecipes.inputMode == "ingredient" then
        -- Qui potresti aprire un dialogo per selezionare item e quantita
        -- Per ora uso un input semplice
        term.setCursorPos(2, term.getSize() - 1)
        term.write("Item: ")
        local item = read()
        term.write("Quantita: ")
        local count = tonumber(read()) or 1
        
        if item ~= "" then
            StorageRecipes.newRecipe.grid[StorageRecipes.gridSelection] = {
                item = item,
                count = count
            }
        end
    end
    
    StorageRecipes.inputMode = ""
end

-- Loop principale dell'editor ricette
function StorageRecipes.run()
    Crafting.init()
    
    while true do
        StorageRecipes.drawGUI()
        
        local event, param1, param2, param3 = os.pullEvent()
        
        if event == "mouse_click" then
            StorageRecipes.handleClick(param2, param3, param1)
        elseif event == "key" then
            if StorageRecipes.handleKeyboard(param1) then
                break -- Esci
            end
        elseif event == "char" then
            StorageRecipes.handleChar(param1)
        end
    end
end

return StorageRecipes