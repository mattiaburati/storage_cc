-- storage_core.lua - Funzioni principali del sistema storage
-- Modulo core con logica principale

local StorageCore = {}

-- Configurazione
StorageCore.config = {
    OUTPUT_SIDE = nil,
    SCAN_DELAY = 1
}

-- Variabili globali del modulo
StorageCore.chests = {}
StorageCore.inventory = {}
StorageCore.totalSlots = 0
StorageCore.usedSlots = 0

-- Funzione per rilevare se siamo in modalità rete
function StorageCore.hasModem()
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
function StorageCore.findOutputChest()
    local peripherals = peripheral.getNames()
    local networkMode = StorageCore.hasModem()
    
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
function StorageCore.findChests()
    StorageCore.chests = {}
    local peripherals = peripheral.getNames()
    local networkMode = StorageCore.hasModem()
    
    for _, name in ipairs(peripherals) do
        local pType = peripheral.getType(name)
        if string.find(pType, "chest") or string.find(pType, "barrel") or 
           string.find(pType, "shulker") or pType == "minecraft:chest" then
            
            if networkMode then
                if string.find(name, "minecraft:") and name ~= StorageCore.config.OUTPUT_SIDE then
                    table.insert(StorageCore.chests, name)
                end
            else
                if name ~= StorageCore.config.OUTPUT_SIDE then
                    table.insert(StorageCore.chests, name)
                end
            end
        end
    end
    
    return #StorageCore.chests
end

-- Funzione per calcolare spazio storage
function StorageCore.calculateStorageSpace()
    StorageCore.totalSlots = 0
    StorageCore.usedSlots = 0
    
    for _, chestName in ipairs(StorageCore.chests) do
        local chest = peripheral.wrap(chestName)
        if chest and chest.size then
            local chestSize = chest.size()
            StorageCore.totalSlots = StorageCore.totalSlots + chestSize
            
            if chest.list then
                local items = chest.list()
                for slot, item in pairs(items) do
                    if item and item.count > 0 then
                        StorageCore.usedSlots = StorageCore.usedSlots + 1
                    end
                end
            end
        end
    end
end

-- Funzione per scansionare tutti gli inventari
function StorageCore.scanInventories()
    local Utils = require("storage_utils")
    StorageCore.inventory = {}
    
    for _, chestName in ipairs(StorageCore.chests) do
        local chest = peripheral.wrap(chestName)
        if chest and chest.list then
            local items = chest.list()
            
            for slot, item in pairs(items) do
                local itemName = item.name
                local itemCount = item.count
                local cleanDisplayName = item.displayName and Utils.cleanItemName(item.displayName) or Utils.cleanItemName(itemName)
                
                if not StorageCore.inventory[itemName] then
                    StorageCore.inventory[itemName] = {
                        total = 0,
                        locations = {}
                    }
                end
                
                StorageCore.inventory[itemName].total = StorageCore.inventory[itemName].total + itemCount
                
                table.insert(StorageCore.inventory[itemName].locations, {
                    chest = chestName,
                    slot = slot,
                    count = itemCount,
                    displayName = cleanDisplayName
                })
            end
        end
    end
    
    -- Calcola spazio storage
    StorageCore.calculateStorageSpace()
end

-- Funzione per trasferire item
function StorageCore.transferItem(itemName, quantity)
    if not StorageCore.inventory[itemName] then
        return false, "Item non trovato"
    end
    
    if not StorageCore.config.OUTPUT_SIDE then
        return false, "Chest di output non configurata"
    end
    
    local outputChest = peripheral.wrap(StorageCore.config.OUTPUT_SIDE)
    if not outputChest then
        return false, "Chest di output non accessibile"
    end
    
    local remaining = quantity
    local transferred = 0
    
    for _, location in ipairs(StorageCore.inventory[itemName].locations) do
        if remaining <= 0 then break end
        
        local sourceChest = peripheral.wrap(location.chest)
        if sourceChest then
            local toTransfer = math.min(remaining, location.count)
            local moved = sourceChest.pushItems(StorageCore.config.OUTPUT_SIDE, location.slot, toTransfer)
            
            if moved > 0 then
                transferred = transferred + moved
                remaining = remaining - moved
            end
        end
    end
    
    return transferred > 0, "Trasferiti " .. transferred .. "/" .. quantity .. " item"
end

-- Funzione per ordinare e consolidare gli oggetti nelle chest
function StorageCore.organizeStorage()
    local Utils = require("storage_utils")
    
    if #StorageCore.chests == 0 then
        return false, "Nessuna chest trovata"
    end
    
    -- Prima scansiona tutto
    local itemMap = {}
    local totalMoved = 0
    
    -- Mappa tutti gli oggetti e le loro posizioni
    for _, chestName in ipairs(StorageCore.chests) do
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
        if #locations > 1 then -- Solo se l'oggetto è in più chest
            -- Ordina per quantità (prima le chest più piene)
            table.sort(locations, function(a, b)
                return a.count > b.count
            end)
            
            local targetChest = locations[1].chest -- Chest con più oggetti di questo tipo
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

return StorageCore
