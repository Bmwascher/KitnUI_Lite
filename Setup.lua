local _, ns = ...

------------------------------------------------------------
-- Details auto-run script (persisted via PLAYER_LOGOUT)
------------------------------------------------------------

local DETAILS_ZONE_SCRIPT = [[local function setup(id, segType, attr, subAttr, titleOverride)
    local i = Details:GetInstance(id)
    i:SetSegmentType(segType, true)
    i:SetDisplay(nil, attr, subAttr)
    if titleOverride then i.menu_attribute_string:SetText(titleOverride) end
end

if (Details.zone_type == "party") then
    setup(1, 1, DETAILS_ATTRIBUTE_DAMAGE, 1)
    setup(2, 0, DETAILS_ATTRIBUTE_DAMAGE, 1, "Damage Overall")
    setup(3, 1, DETAILS_ATTRIBUTE_MISC, 5)
end
if (Details.zone_type == "raid" or Details.zone_type == "none") then
    setup(1, 1, DETAILS_ATTRIBUTE_DAMAGE, 1)
    setup(2, 1, DETAILS_ATTRIBUTE_HEAL, 1)
    setup(3, 1, DETAILS_ATTRIBUTE_MISC, 5)
end]]

-- Re-writes our auto-run script to _detalhes_global on logout,
-- after Details has saved its own CodeTable.
local detailsLogoutFrame = CreateFrame("Frame")
detailsLogoutFrame:RegisterEvent("PLAYER_LOGOUT")
detailsLogoutFrame:SetScript("OnEvent", function()
    if ns.db and ns.db.detailsRunCode and _detalhes_global then
        _detalhes_global["run_code"] = _detalhes_global["run_code"] or {}
        _detalhes_global["run_code"]["on_zonechanged"] = DETAILS_ZONE_SCRIPT
    end
end)

------------------------------------------------------------
-- Setup dispatcher
------------------------------------------------------------

local setupFunctions = {}

function ns.SetupAddon(addonKey, import, ...)
    local fn = setupFunctions[addonKey]
    if not fn then
        print(ns.title .. ": No setup function for " .. addonKey)
        return
    end
    return fn(addonKey, import, ...)
end

-- Maps variant data keys to their base addon key for sidebar tracking and addon-enabled checks
local variantBase = {
    UnhaltedUnitFrames_Colored = "UnhaltedUnitFrames",
    UnhaltedUnitFrames_Dark = "UnhaltedUnitFrames",
    UnhaltedUnitFrames_HealerColored = "UnhaltedUnitFrames",
    UnhaltedUnitFrames_HealerDark = "UnhaltedUnitFrames",
    Ayije_CDM_CastEmphasized = "Ayije_CDM",
    Ayije_CDM_Healer = "Ayije_CDM",
    Ayije_CDM_HealerDualResource = "Ayije_CDM",
    Grid2_Colored = "Grid2",
    Grid2_Dark = "Grid2",
    Grid2_HealerColored = "Grid2",
    Grid2_HealerDark = "Grid2",
    BasicMinimap_Square = "BasicMinimap",
    BasicMinimap_Circle = "BasicMinimap",
    MinimapStats_Square = "MinimapStats",
    MinimapStats_Circle = "MinimapStats",
}
ns.variantBase = variantBase

-- Simple checksum of a data string/table for change detection
local function DataChecksum(addonKey)
    local d = ns.data[addonKey]
    if not d then return 0 end
    if type(d) == "string" then return #d end
    if type(d) == "table" then
        -- Sum lengths of all string values (e.g. BlizzardCDM per-spec tables)
        local sum = 0
        for _, v in pairs(d) do
            if type(v) == "string" then sum = sum + #v end
        end
        return sum
    end
    return 0
end

local function CompleteSetup(addonKey)
    ns.db.profiles = ns.db.profiles or {}
    ns.db.profiles[addonKey] = DataChecksum(addonKey)
    -- Also mark the base addon so sidebar shows green
    if variantBase[addonKey] then
        ns.db.profiles[variantBase[addonKey]] = DataChecksum(addonKey)
    end
    ns.db.version = ns.version
    ns.db.installedVersion = ns.version

    local charKey = UnitName("player") .. "-" .. GetRealmName()
    ns.db.perChar[charKey] = ns.db.perChar[charKey] or {}
    ns.db.perChar[charKey].loaded = true
end

local function HasData(addonKey)
    local d = ns.data[addonKey]
    if not d then return false end
    if type(d) == "string" and strtrim(d) == "" then return false end
    if type(d) == "table" and not next(d) then return false end
    return true
end

-- Check if a profile's data has changed since it was last installed
function ns:IsProfileUpdated(addonKey)
    if not self.db or not self.db.profiles then return false end
    local stored = self.db.profiles[addonKey]
    if not stored then return false end
    -- Details needs re-import if auto-run script wasn't set up (old installs)
    if addonKey == "Details" and not self.db.detailsRunCode then return true end
    -- Legacy entries stored as `true` are always considered updated
    if stored == true then return true end
    -- Per-spec tables (e.g. BlizzardCDM) don't support checksum comparison
    if type(stored) == "table" then return false end
    return HasData(addonKey) and DataChecksum(addonKey) ~= stored
end

-- Returns list of addon keys that have updated data since last install
function ns:GetUpdatedProfiles()
    local updated = {}
    if not self.db or not self.db.profiles then return updated end
    for addonKey in pairs(self.db.profiles) do
        if self:IsProfileUpdated(addonKey) then
            updated[#updated + 1] = addonKey
        end
    end
    return updated
end

------------------------------------------------------------
-- Blizzard Edit Mode
------------------------------------------------------------

setupFunctions["Blizzard_EditMode"] = function(addonKey, import)
    if import then
        if not HasData(addonKey) then
            print(ns.title .. ": No Edit Mode data found. Add your layout string to Data.lua.")
            return
        end

        local layouts = C_EditMode.GetLayouts()

        -- Remove existing KitnUI layout if present
        for i = #layouts.layouts, 1, -1 do
            if layouts.layouts[i].layoutName == ns.profileName then
                tremove(layouts.layouts, i)
            end
        end

        -- Check layout limit (Blizzard allows max 5 custom layouts)
        if #layouts.layouts >= 5 then
            print(ns.title .. ": Edit Mode layout limit reached (5). Delete a layout and try again.")
            return false
        end

        local info = C_EditMode.ConvertStringToLayoutInfo(ns.data[addonKey])
        info.layoutName = ns.profileName
        info.layoutType = Enum.EditModeLayoutType.Account

        tinsert(layouts.layouts, info)
        C_EditMode.SaveLayouts(layouts)

        local newIndex = Enum.EditModePresetLayoutsMeta.NumValues + #layouts.layouts
        C_EditMode.SetActiveLayout(newIndex)

        CompleteSetup(addonKey)
        return true
    end

    -- Load existing profile
    local layouts = C_EditMode.GetLayouts()
    for i, v in ipairs(layouts.layouts) do
        if v.layoutName == ns.profileName then
            C_EditMode.SetActiveLayout(Enum.EditModePresetLayoutsMeta.NumValues + i)
            return
        end
    end
end

------------------------------------------------------------
-- Unhalted Unit Frames (AceDB + AceSerializer + LibDeflate)
-- Uses UUF:ImportSavedVariables(encodedString, profileName)
-- Export string starts with "!UUF_"
------------------------------------------------------------

-- Stable profile names per UUF variant (so each variant can coexist)
local uufProfileNames = {
    UnhaltedUnitFrames_Colored = ns.profileName .. " Colored",
    UnhaltedUnitFrames_Dark = ns.profileName .. " Dark",
    UnhaltedUnitFrames_HealerColored = ns.profileName .. " Healer Colored",
    UnhaltedUnitFrames_HealerDark = ns.profileName .. " Healer Dark",
}

-- Maps a chosen style key to the DPS + Healer data keys
local uufStylePairs = {
    UnhaltedUnitFrames_Colored = { dps = "UnhaltedUnitFrames_Colored", healer = "UnhaltedUnitFrames_HealerColored" },
    UnhaltedUnitFrames_Dark    = { dps = "UnhaltedUnitFrames_Dark",    healer = "UnhaltedUnitFrames_HealerDark" },
}

-- Healer spec indices by class (same mapping as Grid2)
local uufHealerSpecs = {
    ["Druid"]    = { [4] = true },  -- Restoration
    ["Evoker"]   = { [2] = true },  -- Preservation
    ["Monk"]     = { [2] = true },  -- Mistweaver
    ["Paladin"]  = { [1] = true },  -- Holy
    ["Priest"]   = { [1] = true, [2] = true },  -- Discipline, Holy
    ["Shaman"]   = { [3] = true },  -- Restoration
}

-- Set up UUF's LibDualSpec spec profiles for auto-switching between DPS and healer
local function SetupUUFSpecProfiles()
    if not UUF or not UUF.db then return end

    -- Find which DPS and healer variants are installed
    local dpsProfile, healerProfile
    if ns.db.profiles and ns.db.profiles.UnhaltedUnitFrames_Colored then
        dpsProfile = uufProfileNames.UnhaltedUnitFrames_Colored
    elseif ns.db.profiles and ns.db.profiles.UnhaltedUnitFrames_Dark then
        dpsProfile = uufProfileNames.UnhaltedUnitFrames_Dark
    end
    if ns.db.profiles and ns.db.profiles.UnhaltedUnitFrames_HealerColored then
        healerProfile = uufProfileNames.UnhaltedUnitFrames_HealerColored
    elseif ns.db.profiles and ns.db.profiles.UnhaltedUnitFrames_HealerDark then
        healerProfile = uufProfileNames.UnhaltedUnitFrames_HealerDark
    end

    -- Only set up spec switching if both DPS and healer variants are installed
    if not dpsProfile or not healerProfile then return end

    local className = UnitClass("player")
    local healerSpecIndices = uufHealerSpecs[className]

    -- Classes with no healer specs just activate the DPS profile
    if not healerSpecIndices then
        if dpsProfile then
            UUF.db:SetProfile(dpsProfile)
        end
        return
    end

    local _, _, classId = UnitClass("player")
    local numSpecs = GetNumSpecializationsForClassID(classId)
    local currentSpec = GetSpecialization() or 1

    -- Switch to DPS profile first, then enable spec profiles
    UUF.db:SetProfile(dpsProfile)

    -- Write spec profiles to the LibDualSpec AceDB namespace (persists in SavedVariables)
    local charKey = UnitName("player") .. " - " .. GetRealmName()
    local ns_db = UUF.db:GetNamespace("LibDualSpec-1.0", true)
    if ns_db then
        local charData = ns_db.char
        charData.enabled = true
        for i = 1, numSpecs do
            charData[i] = healerSpecIndices[i] and healerProfile or dpsProfile
        end
        -- Trigger profile switch for current spec
        if UUF.db.CheckDualSpecState then
            UUF.db:CheckDualSpecState()
        end
    end
end

setupFunctions["UnhaltedUnitFrames"] = function(addonKey, import)
    if import then
        local pair = uufStylePairs[addonKey]
        if not pair then
            print(ns.title .. ": Unknown UUF style: " .. addonKey)
            return
        end

        -- Clear the opposite style's install tracking
        for styleKey, stylePair in pairs(uufStylePairs) do
            if styleKey ~= addonKey and ns.db.profiles then
                ns.db.profiles[stylePair.dps] = nil
                ns.db.profiles[stylePair.healer] = nil
            end
        end

        -- Import Healer first, then DPS — ImportUUF calls SetProfile internally,
        -- so DPS imported last means UUF defaults to the DPS profile
        for _, variantKey in ipairs({pair.healer, pair.dps}) do
            if HasData(variantKey) then
                local targetName = uufProfileNames[variantKey] or ns.profileName
                UUFG:ImportUUF(ns.data[variantKey], targetName)
                CompleteSetup(variantKey)
            end
        end

        SetupUUFSpecProfiles()
        return
    end

    -- Load path: activate the correct UUF profile for this character
    if not UUFDB or not UUFDB.profiles then return end

    -- Find which DPS and healer variants are installed
    local dpsName, healerName
    if ns.db.profiles and ns.db.profiles.UnhaltedUnitFrames_Colored then
        dpsName = uufProfileNames.UnhaltedUnitFrames_Colored
    elseif ns.db.profiles and ns.db.profiles.UnhaltedUnitFrames_Dark then
        dpsName = uufProfileNames.UnhaltedUnitFrames_Dark
    end
    if ns.db.profiles and ns.db.profiles.UnhaltedUnitFrames_HealerColored then
        healerName = uufProfileNames.UnhaltedUnitFrames_HealerColored
    elseif ns.db.profiles and ns.db.profiles.UnhaltedUnitFrames_HealerDark then
        healerName = uufProfileNames.UnhaltedUnitFrames_HealerDark
    end

    -- Determine which profile to activate based on current spec
    local className = UnitClass("player")
    local healerSpecs = uufHealerSpecs[className]
    local currentSpec = GetSpecialization() or 1
    local targetName = dpsName
    if healerSpecs and healerSpecs[currentSpec] and healerName then
        targetName = healerName
    end

    if not targetName or not UUFDB.profiles[targetName] then return end

    local db = LibStub("AceDB-3.0"):New(UUFDB)
    db:SetProfile(targetName)
end
setupFunctions["UnhaltedUnitFrames_Colored"] = setupFunctions["UnhaltedUnitFrames"]
setupFunctions["UnhaltedUnitFrames_Dark"] = setupFunctions["UnhaltedUnitFrames"]
setupFunctions["UnhaltedUnitFrames_HealerColored"] = setupFunctions["UnhaltedUnitFrames"]
setupFunctions["UnhaltedUnitFrames_HealerDark"] = setupFunctions["UnhaltedUnitFrames"]

------------------------------------------------------------
-- Grid2 (AceDB - uses Grid2Options:ImportCurrentProfile)
-- Export string is serialized+compressed via AceSerializer
------------------------------------------------------------

-- Stable profile names per Grid2 variant (so each variant can coexist)
local grid2ProfileNames = {
    Grid2_Colored = ns.profileName .. " Colored",
    Grid2_Dark = ns.profileName .. " Dark",
    Grid2_HealerColored = ns.profileName .. " Healer Colored",
    Grid2_HealerDark = ns.profileName .. " Healer Dark",
}

-- Healer spec indices by class (specs that should use the healer Grid2 profile)
local grid2HealerSpecs = {
    ["Druid"]    = { [4] = true },  -- Restoration
    ["Evoker"]   = { [2] = true },  -- Preservation
    ["Monk"]     = { [2] = true },  -- Mistweaver
    ["Paladin"]  = { [1] = true },  -- Holy
    ["Priest"]   = { [1] = true, [2] = true },  -- Discipline, Holy
    ["Shaman"]   = { [3] = true },  -- Restoration
}

-- Maps a chosen style key to the DPS + Healer data keys
local grid2StylePairs = {
    Grid2_Colored = { dps = "Grid2_Colored", healer = "Grid2_HealerColored" },
    Grid2_Dark    = { dps = "Grid2_Dark",    healer = "Grid2_HealerDark" },
}

-- Write Grid2's LibDualSpec-1.0 namespace so it auto-switches between DPS and healer profiles
local function SetupGrid2SpecProfiles()
    if not Grid2DB then return end

    -- Find which DPS and healer variants are installed
    local dpsProfile, healerProfile
    if ns.db.profiles and ns.db.profiles.Grid2_Colored then
        dpsProfile = grid2ProfileNames.Grid2_Colored
    elseif ns.db.profiles and ns.db.profiles.Grid2_Dark then
        dpsProfile = grid2ProfileNames.Grid2_Dark
    end
    if ns.db.profiles and ns.db.profiles.Grid2_HealerColored then
        healerProfile = grid2ProfileNames.Grid2_HealerColored
    elseif ns.db.profiles and ns.db.profiles.Grid2_HealerDark then
        healerProfile = grid2ProfileNames.Grid2_HealerDark
    end

    -- Only set up spec switching if both DPS and healer variants are installed
    if not dpsProfile or not healerProfile then return end

    local className = UnitClass("player")
    local healerSpecIndices = grid2HealerSpecs[className]

    local _, _, classId = UnitClass("player")
    local numSpecs = GetNumSpecializationsForClassID(classId)
    local currentSpec = GetSpecialization() or 1

    -- Classes with no healer specs just activate the DPS profile
    if not healerSpecIndices then
        if Grid2 and Grid2.db then
            Grid2.db:SetProfile(dpsProfile)
        end
        return
    end

    -- Enable spec profiles via Grid2's runtime API (toggles the checkbox and
    -- initializes the LibDualSpec-1.0 namespace with the current profile)
    if Grid2 and Grid2.EnableProfilesPerSpec then
        Grid2:EnableProfilesPerSpec(true)
    end

    -- Now write our per-spec profile assignments into the namespace
    if Grid2 and Grid2.profiles and Grid2.profiles.char then
        local specData = Grid2.profiles.char
        specData.enabled = true
        for i = 1, numSpecs do
            specData[i] = healerSpecIndices[i] and healerProfile or dpsProfile
        end
    end

    -- Activate the correct profile for current spec
    local targetProfile = (healerSpecIndices[currentSpec] and healerProfile) or dpsProfile
    if Grid2 and Grid2.db then
        Grid2.db:SetProfile(targetProfile)
    end
end

-- Internal: import a single Grid2 variant
local function ImportGrid2Variant(variantKey)
    if not HasData(variantKey) then return false end

    local targetName = grid2ProfileNames[variantKey] or ns.profileName

    -- Delete existing profile with our name so import won't deduplicate
    local currentProfile = Grid2.db:GetCurrentProfile()
    if currentProfile == targetName then
        Grid2.db:SetProfile("Default")
    end
    local profiles = Grid2.db:GetProfiles()
    for _, name in ipairs(profiles) do
        if name == targetName then
            Grid2.db:DeleteProfile(targetName)
            break
        end
    end

    -- Hook SetProfile to force our profile name
    local origSetProfile = Grid2.db.SetProfile
    Grid2.db.SetProfile = function(self, _name)
        Grid2.db.SetProfile = origSetProfile
        return origSetProfile(self, targetName)
    end

    local success = Grid2Options:ImportCurrentProfile(ns.data[variantKey], true)

    -- Restore hook in case import failed before SetProfile was called
    Grid2.db.SetProfile = origSetProfile

    if not success then
        print(ns.title .. ": Grid2 import failed for " .. targetName)
    end

    return success
end

setupFunctions["Grid2"] = function(addonKey, import)
    if import then
        local pair = grid2StylePairs[addonKey]
        if not pair then
            print(ns.title .. ": Unknown Grid2 style: " .. addonKey)
            return
        end

        -- Load Grid2Options to get the ImportCurrentProfile API
        if not C_AddOns.IsAddOnLoaded("Grid2Options") then
            C_AddOns.LoadAddOn("Grid2Options")
        end

        -- Clear the opposite style's install tracking so spec profiles resolve correctly
        -- (e.g. switching from Colored to Dark should forget Colored entries)
        for styleKey, stylePair in pairs(grid2StylePairs) do
            if styleKey ~= addonKey and ns.db.profiles then
                ns.db.profiles[stylePair.dps] = nil
                ns.db.profiles[stylePair.healer] = nil
            end
        end

        -- Import both DPS and Healer variants
        local dpsOk = ImportGrid2Variant(pair.dps)
        local healerOk = ImportGrid2Variant(pair.healer)

        if dpsOk then CompleteSetup(pair.dps) end
        if healerOk then CompleteSetup(pair.healer) end

        if dpsOk or healerOk then
            SetupGrid2SpecProfiles()
        end
        return
    end

    -- Load path: activate the correct profile for current spec
    local targetName = grid2ProfileNames[addonKey] or ns.profileName
    if not Grid2DB or not Grid2DB.profiles or not Grid2DB.profiles[targetName] then return end
    SetupGrid2SpecProfiles()
end
setupFunctions["Grid2_Colored"] = setupFunctions["Grid2"]
setupFunctions["Grid2_Dark"] = setupFunctions["Grid2"]
setupFunctions["Grid2_HealerColored"] = setupFunctions["Grid2"]
setupFunctions["Grid2_HealerDark"] = setupFunctions["Grid2"]

------------------------------------------------------------
-- Details! Damage Meter
-- Uses Details:ImportProfile(data, profileName)
------------------------------------------------------------

setupFunctions["Details"] = function(addonKey, import)
    if import then
        if not HasData(addonKey) then
            print(ns.title .. ": No Details data found. Export your profile from Details and add it to Data.lua.")
            return
        end

        Details:EraseProfile(ns.profileName)
        -- Args: (string, name, bImportAutoRunCode, bIsFromImportPrompt, overwriteExisting)
        -- Both auto-run flags must be true for run_code scripts to be imported from the profile string.
        Details:ImportProfile(ns.data[addonKey], ns.profileName, true, true, true)

        -- Flag for PLAYER_LOGOUT handler to persist auto-run scripts.
        ns.db.detailsRunCode = true

        CompleteSetup(addonKey)
        return
    end

    if not Details:GetProfile(ns.profileName) then return end
    Details:ApplyProfile(ns.profileName)
end

------------------------------------------------------------
-- Plater Nameplates
-- Uses Plater.DecompressData() + Plater.ImportAndSwitchProfile()
------------------------------------------------------------

setupFunctions["Plater"] = function(addonKey, import)
    if import then
        if not HasData(addonKey) then
            print(ns.title .. ": No Plater data found. Export your profile from Plater and add it to Data.lua.")
            return
        end

        local data = Plater.DecompressData(ns.data[addonKey], "print")

        -- Write profile data directly to SavedVariables, bypassing
        -- ImportAndSwitchProfile which resets-then-copies and recalculates scale
        PlaterDB.profiles = PlaterDB.profiles or {}
        PlaterDB.profiles[ns.profileName] = CopyTable(data)
        Plater.db:SetProfile(ns.profileName)

        -- Restore CVars saved in the profile
        if Plater.RestoreProfileCVars then
            Plater.RestoreProfileCVars()
        end

        C_Timer.After(0.5, function()
            Plater.ImportScriptsFromLibrary()
            Plater.ApplyPatches()
            Plater.CompileAllScripts("script")
            Plater.CompileAllScripts("hook")
            Plater.RefreshDBUpvalues()
            Plater:RefreshConfig()
            Plater.UpdatePlateClickSpace()
            Plater.UpdateAllPlates()
        end)

        CompleteSetup(addonKey)
        return
    end

    if not PlaterDB or not PlaterDB.profiles or not PlaterDB.profiles[ns.profileName] then return end
    Plater.db:SetProfile(ns.profileName)
end

------------------------------------------------------------
-- BigWigs
-- Uses BigWigsAPI.RegisterProfile(title, data, profileName, callback)
------------------------------------------------------------

setupFunctions["BigWigs"] = function(addonKey, import)
    if import then
        if not HasData(addonKey) then
            print(ns.title .. ": No BigWigs data found. Add your profile data to Data.lua.")
            return
        end

        BigWigsAPI.RegisterProfile(ns.title, ns.data[addonKey], ns.profileName, function(success)
            if success then
                CompleteSetup(addonKey)
            end
        end)
        return
    end

    if not BigWigs3DB or not BigWigs3DB.profiles or not BigWigs3DB.profiles[ns.profileName] then return end
    local db = LibStub("AceDB-3.0"):New(BigWigs3DB)
    db:SetProfile(ns.profileName)
end

------------------------------------------------------------
-- WarpDeplete (AceDB - direct profile table write)
------------------------------------------------------------

setupFunctions["WarpDeplete"] = function(addonKey, import)
    if import then
        if not HasData(addonKey) then
            print(ns.title .. ": No WarpDeplete data found. Add your profile table to Data.lua.")
            return
        end

        WarpDepleteDB.profiles[ns.profileName] = CopyTable(ns.data[addonKey])
        WarpDeplete.db:SetProfile(ns.profileName)

        CompleteSetup(addonKey)
        return
    end

    if not WarpDepleteDB or not WarpDepleteDB.profiles or not WarpDepleteDB.profiles[ns.profileName] then return end
    WarpDeplete.db:SetProfile(ns.profileName)
end

------------------------------------------------------------
-- AyijeCDM (custom DB)
-- _G["Ayije_CDM_API"] (WagoUI.lua) is a DIFFERENT object from _G["Ayije_CDM"].API (Init.lua).
-- The Options addon redefines ImportProfile on CDM.API (the Init.lua one), not the WagoUI global.
-- We must load Options first, then call CDM.API:ImportProfile().
--
-- 1-click import: imports all 4 variants, then writes AceDB specProfiles
-- so CDM auto-switches profiles when the player changes spec.
------------------------------------------------------------

-- Profile names written to Ayije_CDMDB for each variant
local cdmProfileNames = {
    Ayije_CDM                    = ns.profileName,
    Ayije_CDM_CastEmphasized     = ns.profileName .. " CastEmphasized",
    Ayije_CDM_Healer             = ns.profileName .. " Healer",
    Ayije_CDM_HealerDualResource = ns.profileName .. " Healer DualResource",
}

-- All variant data keys to import
local cdmVariants = {
    "Ayije_CDM",
    "Ayije_CDM_CastEmphasized",
    "Ayije_CDM_Healer",
    "Ayije_CDM_HealerDualResource",
}

-- Class → spec profile mapping (AceDB specProfiles format)
-- Indices match WoW spec order from GetSpecializationInfoForClassID
local P = cdmProfileNames
local cdmSpecMapping = {
    ["Death Knight"]  = { P.Ayije_CDM, P.Ayije_CDM, P.Ayije_CDM, ["enabled"] = true },                                              -- Blood, Frost, Unholy
    ["Demon Hunter"]  = { P.Ayije_CDM_CastEmphasized, P.Ayije_CDM, P.Ayije_CDM_CastEmphasized, ["enabled"] = true },                -- Havoc, Vengeance, Devourer
    ["Druid"]         = { P.Ayije_CDM_CastEmphasized, P.Ayije_CDM, P.Ayije_CDM, P.Ayije_CDM_Healer, ["enabled"] = true },           -- Balance, Feral, Guardian, Restoration
    ["Evoker"]        = { P.Ayije_CDM_CastEmphasized, P.Ayije_CDM_HealerDualResource, P.Ayije_CDM_CastEmphasized, ["enabled"] = true }, -- Devastation, Preservation, Augmentation
    ["Hunter"]        = { P.Ayije_CDM, P.Ayije_CDM, P.Ayije_CDM, ["enabled"] = true },                                              -- Beast Mastery, Marksmanship, Survival
    ["Mage"]          = { P.Ayije_CDM_CastEmphasized, P.Ayije_CDM_CastEmphasized, P.Ayije_CDM_CastEmphasized, ["enabled"] = true },  -- Arcane, Fire, Frost
    ["Monk"]          = { P.Ayije_CDM, P.Ayije_CDM_Healer, P.Ayije_CDM, ["enabled"] = true },                                       -- Brewmaster, Mistweaver, Windwalker
    ["Paladin"]       = { P.Ayije_CDM_HealerDualResource, P.Ayije_CDM, P.Ayije_CDM, ["enabled"] = true },                           -- Holy, Protection, Retribution
    ["Priest"]        = { P.Ayije_CDM_Healer, P.Ayije_CDM_Healer, P.Ayije_CDM_CastEmphasized, ["enabled"] = true },                  -- Discipline, Holy, Shadow
    ["Rogue"]         = { P.Ayije_CDM, P.Ayije_CDM, P.Ayije_CDM, ["enabled"] = true },                                              -- Assassination, Outlaw, Subtlety
    ["Shaman"]        = { P.Ayije_CDM_CastEmphasized, P.Ayije_CDM, P.Ayije_CDM_Healer, ["enabled"] = true },                        -- Elemental, Enhancement, Restoration
    ["Warlock"]       = { P.Ayije_CDM_CastEmphasized, P.Ayije_CDM_CastEmphasized, P.Ayije_CDM_CastEmphasized, ["enabled"] = true },  -- Affliction, Demonology, Destruction
    ["Warrior"]       = { P.Ayije_CDM, P.Ayije_CDM, P.Ayije_CDM, ["enabled"] = true },                                              -- Arms, Fury, Protection
}

-- Internal: import a single CDM variant export string
local function ImportCDMVariant(CDM_Addon, variantKey)
    if not HasData(variantKey) then return false end

    local targetName = cdmProfileNames[variantKey] or ns.profileName

    -- Hook ImportProfileData to force our profile name instead of the one
    -- embedded in the export string (prevents CDM's name de-duplication)
    local origImportProfileData = CDM_Addon.ImportProfileData
    CDM_Addon.ImportProfileData = function(self, _name, profileData)
        return origImportProfileData(self, targetName, profileData)
    end

    local success, msg = CDM_Addon.API:ImportProfile(ns.data[variantKey])

    CDM_Addon.ImportProfileData = origImportProfileData

    if not success then
        print(ns.title .. ": AyijeCDM import failed for " .. targetName .. " - " .. (msg or "unknown error"))
    end

    return success
end

-- Write AceDB specProfiles so CDM auto-switches on spec change
local function SetupCDMSpecProfiles()
    if not Ayije_CDMDB then return end

    local className = UnitClass("player")
    local specMapping = cdmSpecMapping[className]
    if not specMapping then return end

    local charKey = UnitName("player") .. " - " .. GetRealmName()

    Ayije_CDMDB.specProfiles = Ayije_CDMDB.specProfiles or {}
    Ayije_CDMDB.specProfiles[charKey] = CopyTable(specMapping)

    Ayije_CDMDB.profileKeys = Ayije_CDMDB.profileKeys or {}
    local currentSpec = GetSpecialization() or 1
    Ayije_CDMDB.profileKeys[charKey] = specMapping[currentSpec] or ns.profileName

    -- Immediately activate the correct profile
    local CDM_Addon = _G["Ayije_CDM"]
    if CDM_Addon and CDM_Addon.API and CDM_Addon.API.SetProfile then
        CDM_Addon.API:SetProfile(Ayije_CDMDB.profileKeys[charKey])
    end
end

setupFunctions["Ayije_CDM"] = function(addonKey, import)
    if import then
        -- Load the Options addon to get the full ImportProfile (handles !ACDM: prefix)
        if not C_AddOns.IsAddOnLoaded("Ayije_CDM_Options") then
            C_AddOns.LoadAddOn("Ayije_CDM_Options")
        end

        local CDM_Addon = _G["Ayije_CDM"]

        -- Suppress the config frame for the entire import + spec setup
        local origRebuild = CDM_Addon.RebuildConfigFrame
        CDM_Addon.RebuildConfigFrame = function() end

        -- Import all variants
        local anySuccess = false
        for _, vk in ipairs(cdmVariants) do
            if ImportCDMVariant(CDM_Addon, vk) then
                anySuccess = true
            end
        end

        if anySuccess then
            CompleteSetup("Ayije_CDM")
            SetupCDMSpecProfiles()
        else
            print(ns.title .. ": No AyijeCDM profiles were imported.")
        end

        -- Restore and hide after everything is done
        CDM_Addon.RebuildConfigFrame = origRebuild
        if _G["Ayije_CDMConfigFrame"] then
            _G["Ayije_CDMConfigFrame"]:Hide()
        end
        return
    end

    -- Load path: set up spec auto-switching for this character
    SetupCDMSpecProfiles()
end

------------------------------------------------------------
-- Chattynator (custom DB, direct table manipulation)
-- No built-in import/export - write directly to CHATTYNATOR_CONFIG.Profiles
------------------------------------------------------------

setupFunctions["Chattynator"] = function(addonKey, import)
    if import then
        if not HasData(addonKey) then
            print(ns.title .. ": No Chattynator data found. Add your profile table to Data.lua.")
            return
        end

        CHATTYNATOR_CONFIG.Profiles[ns.profileName] = CopyTable(ns.data[addonKey])
        CHATTYNATOR_CURRENT_PROFILE = ns.profileName

        CompleteSetup(addonKey)
        return
    end

    if not CHATTYNATOR_CONFIG or not CHATTYNATOR_CONFIG.Profiles or not CHATTYNATOR_CONFIG.Profiles[ns.profileName] then return end
    CHATTYNATOR_CURRENT_PROFILE = ns.profileName
end

------------------------------------------------------------
-- MRT / Method Raid Tools (custom DB - direct table write to VMRT.Profiles)
-- Data is stored as a Lua table (extracted from SavedVariables)
------------------------------------------------------------

setupFunctions["MRT"] = function(addonKey, import)
    if import then
        if not HasData(addonKey) then
            print(ns.title .. ": No MRT data found. Run extract_profiles.py and add your MRT table to Data.lua.")
            return
        end

        VMRT.Profiles = VMRT.Profiles or {}
        VMRT.Profiles[ns.profileName] = CopyTable(ns.data[addonKey])

        -- Set ProfileKeys for this character so MRT's own ReselectProfileOnLoad
        -- detects the mismatch and swaps on next reload.
        -- MRT strips spaces from realm name (core.lua:84)
        VMRT.ProfileKeys = VMRT.ProfileKeys or {}
        local realmKey = GetRealmName():gsub(" ", "")
        local charKey = UnitName("player") .. "-" .. realmKey
        VMRT.ProfileKeys[charKey] = ns.profileName
        -- Intentionally do NOT set VMRT.Profile here — the mismatch between
        -- ProfileKeys[charKey] and VMRT.Profile is what triggers the swap on reload.

        CompleteSetup(addonKey)
        print(ns.title .. ": MRT profile saved. Reload UI (/reload) to activate it.")
        return
    end

    -- Alt loading: same approach — set ProfileKeys and let MRT swap on next reload
    if not VMRT or not VMRT.Profiles or not VMRT.Profiles[ns.profileName] then return end
    VMRT.ProfileKeys = VMRT.ProfileKeys or {}
    local realmKey = GetRealmName():gsub(" ", "")
    local charKey = UnitName("player") .. "-" .. realmKey
    VMRT.ProfileKeys[charKey] = ns.profileName
end

------------------------------------------------------------
-- KitnEssentials (AceDB - direct profile table write)
-- Uses KitnEssentialsAPI:ImportProfile() if addon is loaded,
-- otherwise writes directly to KitnEssentialsDB.profiles
------------------------------------------------------------

setupFunctions["KitnEssentials"] = function(addonKey, import)
    if import then
        if not HasData(addonKey) then
            print(ns.title .. ": No KitnEssentials data found. Add your profile string to Data.lua.")
            return
        end

        local API = _G.KitnEssentialsAPI
        if not API or not API.DecodeProfileString then
            print(ns.title .. ": KitnEssentials API not available.")
            return
        end

        -- Decode the string, then write directly to the SavedVariable to avoid duplication
        local profileData = API:DecodeProfileString(ns.data[addonKey])
        if not profileData or not next(profileData) then
            print(ns.title .. ": KitnEssentials decode failed.")
            return
        end

        KitnEssentialsDB = KitnEssentialsDB or {}
        KitnEssentialsDB.profiles = KitnEssentialsDB.profiles or {}
        KitnEssentialsDB.profiles[ns.profileName] = profileData

        -- Set profileKey for this character
        local charKey = UnitName("player") .. " - " .. GetRealmName()
        KitnEssentialsDB.profileKeys = KitnEssentialsDB.profileKeys or {}
        KitnEssentialsDB.profileKeys[charKey] = ns.profileName

        -- Activate the profile via AceDB
        local KE_addon = _G.KitnEssentials
        if KE_addon and KE_addon.db then
            KE_addon.db:SetProfile(ns.profileName)
        end

        CompleteSetup(addonKey)
        return
    end

    -- Load: activate existing profile
    local API = _G.KitnEssentialsAPI
    if API and API.SetProfile then
        API:SetProfile(ns.profileName)
    end
end

------------------------------------------------------------
-- BuffReminders (AceDB - uses BR:Import/SetProfile API)
-- Export string starts with "!BR_"
------------------------------------------------------------

setupFunctions["BuffReminders"] = function(addonKey, import)
    if import then
        if not HasData(addonKey) then
            print(ns.title .. ": No BuffReminders data found. Add your export string to Data.lua.")
            return
        end

        if not C_AddOns.IsAddOnLoaded("BuffReminders") then
            print(ns.title .. ": BuffReminders is not loaded.")
            return
        end

        local BR = _G.BuffReminders
        if not BR or not BR.Import then
            print(ns.title .. ": BuffReminders API not available.")
            return
        end

        local success, err = BR:Import(ns.data[addonKey], ns.profileName)
        if success then
            BR:SetProfile(ns.profileName)
            CompleteSetup(addonKey)
        else
            print(ns.title .. ": BuffReminders import failed - " .. (err or "unknown error"))
        end
        return
    end

    -- Load: activate existing profile
    local BR = _G.BuffReminders
    if BR and BR.SetProfile then
        BR:SetProfile(ns.profileName)
    end
end

------------------------------------------------------------
-- BasicMinimap (AceDB - direct profile table write)
------------------------------------------------------------

setupFunctions["BasicMinimap"] = function(addonKey, import)
    if import then
        if not HasData(addonKey) then
            print(ns.title .. ": No BasicMinimap data found. Add your profile table to Data.lua.")
            return
        end

        BasicMinimapSV.profiles[ns.profileName] = CopyTable(ns.data[addonKey])
        local db = LibStub("AceDB-3.0"):New(BasicMinimapSV)
        db:SetProfile(ns.profileName)

        CompleteSetup(addonKey)
        print(ns.title .. ": BasicMinimap profile saved. Reload UI (/reload) for the shape to take effect.")
        return
    end

    if not BasicMinimapSV or not BasicMinimapSV.profiles or not BasicMinimapSV.profiles[ns.profileName] then return end
    local db = LibStub("AceDB-3.0"):New(BasicMinimapSV)
    db:SetProfile(ns.profileName)
end
setupFunctions["BasicMinimap_Square"] = setupFunctions["BasicMinimap"]
setupFunctions["BasicMinimap_Circle"] = setupFunctions["BasicMinimap"]

------------------------------------------------------------
-- Blizzard Cooldown Manager (per-spec serialized layout strings)
-- Uses CooldownViewerSettings:GetLayoutManager():CreateLayoutsFromSerializedData()
------------------------------------------------------------

setupFunctions["BlizzardCDM"] = function(addonKey, import, specIndex)
    if import then
        local _, _, classId = UnitClass("player")
        local classData = ns.data.BlizzardCDM and ns.data.BlizzardCDM[classId]
        local specString = classData and classData[specIndex]

        if not specString or strtrim(specString) == "" then
            print(ns.title .. ": No CDM data for this spec. Add your layout string to Data.lua.")
            return
        end

        if not CooldownViewerSettings or not CooldownViewerSettings.GetLayoutManager then
            print(ns.title .. ": Blizzard Cooldown Manager is not available. Enable it in Settings > Gameplay > Combat.")
            return
        end

        local lm = CooldownViewerSettings:GetLayoutManager()
        if not lm then
            print(ns.title .. ": Could not get CDM Layout Manager.")
            return
        end

        -- Remove existing layout with our profile name if present
        local specName = select(2, GetSpecializationInfoForClassID(classId, specIndex)) or ("Spec" .. specIndex)
        local layoutName = "KUI - " .. specName
        local removedExisting = false
        local _, layouts = lm:EnumerateLayouts()
        if layouts then
            for layoutID, layout in pairs(layouts) do
                if layout and layout.layoutName == layoutName then
                    lm:RemoveLayout(layoutID)
                    removedExisting = true
                    break
                end
            end
        end

        -- Check layout limit if we didn't free a slot
        if not removedExisting and lm.AreLayoutsFullyMaxed and lm:AreLayoutsFullyMaxed() then
            print(ns.title .. ": CDM layout limit reached. Delete a layout and try again.")
            return false
        end

        local layoutIDs = lm:CreateLayoutsFromSerializedData(specString)
        if layoutIDs and layoutIDs[1] then
            local importedID = layoutIDs[1]

            -- Verify the layout was actually created
            local _, postLayouts = lm:EnumerateLayouts()
            if not postLayouts or not postLayouts[importedID] then
                print(ns.title .. ": CDM layout limit reached. Delete a layout and try again.")
                return false
            end

            -- Rename the imported layout
            postLayouts[importedID].layoutName = layoutName

            lm:SaveLayouts()

            -- Activate if this is the player's current spec
            local currentSpec = GetSpecialization()
            if currentSpec == specIndex then
                if lm.SetActiveLayoutByID then
                    lm:SetActiveLayoutByID(importedID)
                end
                lm:SaveLayouts()

                -- Deferred re-activation for safety
                C_Timer.After(0, function()
                    if not InCombatLockdown() and lm.SetActiveLayoutByID then
                        lm:SetActiveLayoutByID(importedID)
                        lm:SaveLayouts()
                    end
                end)
            end

            -- Track per-spec install state
            ns.db.profiles = ns.db.profiles or {}
            ns.db.profiles["BlizzardCDM"] = ns.db.profiles["BlizzardCDM"] or {}
            ns.db.profiles["BlizzardCDM"][specIndex] = true
            ns.db.version = ns.version
            ns.db.installedVersion = ns.version

            local charKey = UnitName("player") .. "-" .. GetRealmName()
            ns.db.perChar[charKey] = ns.db.perChar[charKey] or {}
            ns.db.perChar[charKey].loaded = true
            return true
        else
            print(ns.title .. ": Failed to import CDM layout.")
        end
        return false
    end
end

------------------------------------------------------------
-- Minimap Stats (global is MSG, not MS; uses MSG:ImportSavedVariables)
-- Export string starts with "!MS"
------------------------------------------------------------

setupFunctions["MinimapStats"] = function(addonKey, import)
    if import then
        if not HasData(addonKey) then
            print(ns.title .. ": No MinimapStats data found. Export from MinimapStats settings and add it to Data.lua.")
            return
        end

        MSG:ImportSavedVariables(ns.data[addonKey])

        CompleteSetup(addonKey)
        return
    end
end
setupFunctions["MinimapStats_Square"] = setupFunctions["MinimapStats"]
setupFunctions["MinimapStats_Circle"] = setupFunctions["MinimapStats"]
