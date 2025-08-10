-- Storage System Installer v2.0
-- Installer per il sistema storage modulare CC:Tweaked
-- Uso: wget run https://raw.githubusercontent.com/[YOUR_REPO]/main/installer.lua

local baseUrl = "https://raw.githubusercontent.com/[USER]/[REPO]/main/"
local files = {
    "storage_main.lua",
    "storage_core.lua", 
    "storage_utils.lua",
    "storage_gui.lua"
}

-- File opzionali
local optionalFiles = {
    "startup.lua",
    "README.md"
}

print("=================================")
print("  STORAGE SYSTEM v2.0 INSTALLER  ")
print("    CC:Tweaked Modular Edition   ")
print("=================================")
print("")

-- Funzione per scaricare un file
local function downloadFile(filename)
    print("Scaricando " .. filename .. "...")
    
    local url = baseUrl .. filename
    local response = http.get(url)
    
    if not response then
        print("ERRORE: Impossibile scaricare " .. filename)
        return false
    end
    
    local content = response.readAll()
    response.close()
    
    if not content or content == "" then
        print("ERRORE: File " .. filename .. " vuoto o corrotto")
        return false
    end
    
    -- Salva il file
    local file = fs.open(filename, "w")
    if not file then
        print("ERRORE: Impossibile creare " .. filename)
        return false
    end
    
    file.write(content)
    file.close()
    
    print("✓ " .. filename .. " installato")
    return true
end

-- Controlla se HTTP è abilitato
if not http then
    print("ERRORE: HTTP non abilitato!")
    print("Aggiungi 'http_enable=true' in computercraft.cfg")
    return
end

print("Installazione in corso...")
print("")

local success = true
for _, filename in ipairs(files) do
    if not downloadFile(filename) then
        success = false
        break
    end
    sleep(0.5) -- Evita rate limiting
end

-- Download file opzionali
print("")
print("Download file opzionali...")
for _, filename in ipairs(optionalFiles) do
    downloadFile(filename) -- Non blocca se fallisce
    sleep(0.5)
end

print("")
if success then
    print("✓ Installazione completata con successo!")
    print("")
    print("Per avviare il sistema storage:")
    print("  storage_main")
    print("")
    print("Oppure:")
    print("  lua storage_main.lua")
    print("")
    print("CONTROLLI:")
    print("- Mouse: Clicca sugli item per trasferirli") 
    print("- Scroll: Scorri la lista degli item")
    print("- Q: Esci dal programma")
    print("")
    print("REQUISITI:")
    print("- Advanced Computer o Computer normale")
    print("- Almeno una chest connessa")
    print("- Modem per reti wireless (opzionale)")
    print("")
    print("AVVIO AUTOMATICO:")
    print("Il file startup.lua è stato installato.")
    print("Riavvia il computer per avvio automatico.")
else
    print("✗ Installazione fallita!")
    print("Verifica la connessione internet e riprova.")
end