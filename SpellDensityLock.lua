-- SpellDensityLock
-- Keeps a small set of graphics CVars at your chosen values.
-- The game is known to reset spellVisualDensityFilterSetting on its own
-- (the options menu keeps showing your choice while the live value changes),
-- so this addon re-applies your values after every loading screen, again a
-- few seconds later, and immediately if one of the managed CVars changes
-- to something else mid-session. A quiet safety sweep also re-checks every
-- 60 seconds, in case a value is ever changed without an announcement.
--
-- Managed CVars:
--   spellVisualDensityFilterSetting  (Ally Spell Visual Density: 1 Essential, 2 Reduced, 4 Everything)
--   spellClutter                     (sibling value the game also resets)
--   RAIDspellClutter                  (raid profile sibling, when present)
--   GxCompatOptionalGpuFeatures      (Optional GPU Features compatibility toggle)

local ADDON_NAME = ...

local GetCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
local SetCVar = (C_CVar and C_CVar.SetCVar) or SetCVar

local DEFAULTS = {
    filter = 1,          -- Essential
    clutter = 1,
    gpuManaged = true,   -- hold Optional GPU Features at gpuValue
    gpuValue = 0,        -- 0 = off (the community performance fix), 1 = on
    quiet = false,
    stats = { corrections = 0, lastCorrection = nil },
}

local db
local applying = false
local lastApply = 0

local function Print(msg)
    print("|cff66ccffSpellDensityLock:|r " .. msg)
end

local function ReadCVar(name)
    local ok, value = pcall(GetCVar, name)
    if ok then return value end
    return nil
end

-- The managed list is a static table, built once at load and never rebuilt.
-- Each entry names the db field holding its wanted value (key), so slash
-- commands can change values without touching the list. The GPU entry is
-- always present and is skipped unless db.gpuManaged is on.
local MANAGED = {
    { name = "spellVisualDensityFilterSetting", key = "filter", label = "Spell density filter" },
    { name = "spellClutter", key = "clutter", label = "Spell clutter" },
    { name = "RAIDspellClutter", key = "clutter", label = "Spell clutter (raid profile)" },
    { name = "GxCompatOptionalGpuFeatures", key = "gpuValue", label = "Optional GPU features", gpuOnly = true },
}

local function IsActive(item)
    return not item.gpuOnly or db.gpuManaged
end

local function ApplyAll(source)
    if applying then return end
    applying = true
    for _, item in ipairs(MANAGED) do
        if IsActive(item) then
            local current = ReadCVar(item.name)
            if current ~= nil then
                local want = tostring(db[item.key])
                if current ~= want then
                    SetCVar(item.name, want)
                    db.stats.corrections = db.stats.corrections + 1
                    db.stats.lastCorrection = date("%Y-%m-%d %H:%M:%S")
                    if not db.quiet then
                        Print(("%s was %s, restored to %s (%s). Correction #%d."):format(item.label, current, want, source, db.stats.corrections))
                    end
                end
            end
        end
    end
    lastApply = GetTime()
    applying = false
end

local function Status()
    Print("your chosen values vs the game's live values:")
    for _, item in ipairs(MANAGED) do
        if IsActive(item) then
            local current = ReadCVar(item.name)
            if current ~= nil then
                local want = tostring(db[item.key])
                local mark = (current == want) and "|cff66ff66match|r" or "|cffff6666DIFFERS|r"
                Print(("  %s: live %s, yours %s  %s"):format(item.label, current, want, mark))
            else
                Print(("  %s: not present on this client"):format(item.label))
            end
        end
    end
    if not db.gpuManaged then
        Print("  Optional GPU features: not managed (use /sdl gpu off or /sdl gpu on to manage it)")
    end
    Print(("  corrections so far: %d%s"):format(db.stats.corrections, db.stats.lastCorrection and (", last at " .. db.stats.lastCorrection) or ""))
end

local function Help()
    Print("commands:")
    Print("  /sdl status            show live values vs your chosen values")
    Print("  /sdl essential         spell density filter = Essential (1)")
    Print("  /sdl reduced           spell density filter = Reduced (2)")
    Print("  /sdl everything        spell density filter = Everything (4)")
    Print("  /sdl clutter <number>  spell clutter value to hold")
    Print("  /sdl gpu off           hold Optional GPU Features OFF")
    Print("  /sdl gpu on            hold Optional GPU Features ON")
    Print("  /sdl gpu ignore        stop managing Optional GPU Features")
    Print("  /sdl quiet             toggle correction messages")
end

local sweepStarted = false
local function StartSweep()
    if sweepStarted then return end
    sweepStarted = true
    local function tick()
        if db then ApplyAll("safety sweep") end
        C_Timer.After(60, tick)
    end
    C_Timer.After(60, tick)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CVAR_UPDATE")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        SpellDensityLockDB = SpellDensityLockDB or {}
        db = SpellDensityLockDB
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = v end
        end
        if type(db.stats) ~= "table" then db.stats = { corrections = 0, lastCorrection = nil } end
    elseif event == "PLAYER_LOGIN" then
        if db then ApplyAll("login"); StartSweep() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if db then
            ApplyAll("loading screen")
            C_Timer.After(3, function() ApplyAll("delayed check") end)
            C_Timer.After(8, function() ApplyAll("delayed check") end)
        end
    elseif event == "CVAR_UPDATE" then
        if db and not applying and (GetTime() - lastApply) > 1 then
            local changed = string.lower(arg1 or "")
            for _, item in ipairs(MANAGED) do
                if IsActive(item) and string.lower(item.name) == changed then
                    ApplyAll("the game changed a value")
                    break
                end
            end
        end
    end
end)

SLASH_SPELLDENSITYLOCK1 = "/sdl"
SLASH_SPELLDENSITYLOCK2 = "/spelldensitylock"
SlashCmdList["SPELLDENSITYLOCK"] = function(msg)
    if not db then return end
    local cmd, rest = string.split(" ", string.lower(msg or ""), 2)
    if cmd == "essential" then
        db.filter = 1; ApplyAll("your command"); Print("spell density filter set to Essential (1) and locked.")
    elseif cmd == "reduced" then
        db.filter = 2; ApplyAll("your command"); Print("spell density filter set to Reduced (2) and locked.")
    elseif cmd == "everything" then
        db.filter = 4; ApplyAll("your command"); Print("spell density filter set to Everything (4) and locked.")
    elseif cmd == "clutter" then
        local n = tonumber(rest)
        if n then db.clutter = n; ApplyAll("your command"); Print("spell clutter set to " .. n .. " and locked.")
        else Print("usage: /sdl clutter <number>") end
    elseif cmd == "gpu" then
        if rest == "off" then
            db.gpuManaged = true; db.gpuValue = 0; ApplyAll("your command")
            Print("Optional GPU Features will be held OFF. A /reload or relog may be needed before it takes effect.")
        elseif rest == "on" then
            db.gpuManaged = true; db.gpuValue = 1; ApplyAll("your command")
            Print("Optional GPU Features will be held ON. A /reload or relog may be needed before it takes effect.")
        elseif rest == "ignore" then
            db.gpuManaged = false; Print("Optional GPU Features is no longer managed.")
        else
            Print("usage: /sdl gpu off, /sdl gpu on, or /sdl gpu ignore")
        end
    elseif cmd == "quiet" then
        db.quiet = not db.quiet
        Print("correction messages " .. (db.quiet and "off." or "on."))
    elseif cmd == "status" or cmd == "" then
        Status()
    else
        Help()
    end
end
