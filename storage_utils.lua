-- storage_utils.lua - Funzioni di utilità
-- Helper functions e utilities

local StorageUtils = {}

-- Funzione per contare elementi tabella
function StorageUtils.tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

-- Funzione per ottenere icona e colore di un item
function StorageUtils.getItemIcon(itemName)
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
function StorageUtils.cleanItemName(itemName)
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

-- Funzione helper per stampare con colori
function StorageUtils.printColored(text, color)
    if color then
        term.setTextColor(color)
    end
    print(text)
    term.setTextColor(colors.white)
end

-- Funzione per disegnare box colorati
function StorageUtils.drawBox(x, y, width, height, bg, fg)
    term.setBackgroundColor(bg or colors.black)
    term.setTextColor(fg or colors.white)
    
    for row = y, y + height - 1 do
        term.setCursorPos(x, row)
        term.write(string.rep(" ", width))
    end
end

-- Funzione per disegnare bottoni
function StorageUtils.drawButton(x, y, width, height, text, bg, fg, centered)
    StorageUtils.drawBox(x, y, width, height, bg, fg)
    
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

-- Funzione per validare input numerico
function StorageUtils.isValidNumber(str)
    local num = tonumber(str)
    return num and num > 0
end

-- Funzione per formattare numeri grandi
function StorageUtils.formatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(num)
    end
end

-- Funzione per calcolare percentuale con colore
function StorageUtils.getUsageColor(used, total)
    if total == 0 then return colors.gray end
    
    local percent = (used / total) * 100
    if percent > 80 then
        return colors.red
    elseif percent > 60 then
        return colors.orange
    elseif percent > 40 then
        return colors.yellow
    else
        return colors.lime
    end
end

-- Funzione debug per stampare tabelle
function StorageUtils.printTable(t, indent)
    indent = indent or 0
    local spacing = string.rep("  ", indent)
    
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(spacing .. k .. ":")
            StorageUtils.printTable(v, indent + 1)
        else
            print(spacing .. k .. ": " .. tostring(v))
        end
    end
end

return StorageUtils
