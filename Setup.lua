local _, ns = ...

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
    fn(addonKey, import, ...)
end

-- Maps variant data keys to their base addon key for sidebar tracking and addon-enabled checks
local variantBase = {
    UnhaltedUnitFrames_Colored = "UnhaltedUnitFrames",
    UnhaltedUnitFrames_Dark = "UnhaltedUnitFrames",
    Ayije_CDM_Caster = "Ayije_CDM",
    Ayije_CDM_Melee = "Ayije_CDM",
    Ayije_CDM_DoubleResource = "Ayije_CDM",
    Grid2_Colored = "Grid2",
    Grid2_Dark = "Grid2",
    BasicMinimap_Square = "BasicMinimap",
    BasicMinimap_Circle = "BasicMinimap",
    MinimapStats_Square = "MinimapStats",
    MinimapStats_Circle = "MinimapStats",
}
ns.variantBase = variantBase

local function CompleteSetup(addonKey)
    ns.db.profiles = ns.db.profiles or {}
    ns.db.profiles[addonKey] = true
    -- Also mark the base addon so sidebar shows green
    if variantBase[addonKey] then
        ns.db.profiles[variantBase[addonKey]] = true
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

        local info = C_EditMode.ConvertStringToLayoutInfo(ns.data[addonKey])
        info.layoutName = ns.profileName
        info.layoutType = Enum.EditModeLayoutType.Account

        tinsert(layouts.layouts, info)
        C_EditMode.SaveLayouts(layouts)

        local newIndex = Enum.EditModePresetLayoutsMeta.NumValues + #layouts.layouts
        C_EditMode.SetActiveLayout(newIndex)

        CompleteSetup(addonKey)
        return
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
}

setupFunctions["UnhaltedUnitFrames"] = function(addonKey, import)
    local targetName = uufProfileNames[addonKey] or ns.profileName

    if import then
        if not HasData(addonKey) then
            print(ns.title .. ": No UUF data found. Export your profile from UUF settings and add it to Data.lua.")
            return
        end

        UUFG:ImportUUF(ns.data[addonKey], targetName)

        CompleteSetup(addonKey)
        return
    end

    if not UUFDB or not UUFDB.profiles or not UUFDB.profiles[targetName] then return end
    -- When called from LoadProfiles, addonKey is the base "UnhaltedUnitFrames";
    -- find which variant was actually installed
    local data = ns.data[addonKey]
    if not data then
        for _, variant in ipairs({"UnhaltedUnitFrames_Colored", "UnhaltedUnitFrames_Dark"}) do
            if ns.db.profiles[variant] and ns.data[variant] then
                data = ns.data[variant]
                targetName = uufProfileNames[variant] or ns.profileName
                break
            end
        end
    end
    if not data then return end
    UUFG:ImportUUF(data, targetName)
end
setupFunctions["UnhaltedUnitFrames_Colored"] = setupFunctions["UnhaltedUnitFrames"]
setupFunctions["UnhaltedUnitFrames_Dark"] = setupFunctions["UnhaltedUnitFrames"]

------------------------------------------------------------
-- Grid2 (AceDB - uses Grid2Options:ImportCurrentProfile)
-- Export string is serialized+compressed via AceSerializer
------------------------------------------------------------

-- Stable profile names per Grid2 variant (so each variant can coexist)
local grid2ProfileNames = {
    Grid2_Colored = ns.profileName .. " Colored",
    Grid2_Dark = ns.profileName .. " Dark",
}

setupFunctions["Grid2"] = function(addonKey, import)
    local targetName = grid2ProfileNames[addonKey] or ns.profileName

    if import then
        if not HasData(addonKey) then
            print(ns.title .. ": No Grid2 data found. Export your profile from Grid2 Options and add it to Data.lua.")
            return
        end

        -- Load Grid2Options to get the ImportCurrentProfile API
        if not C_AddOns.IsAddOnLoaded("Grid2Options") then
            C_AddOns.LoadAddOn("Grid2Options")
        end

        -- Delete existing profile with our name so import won't deduplicate
        -- Must switch away first if it's the active profile
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

        -- Hook SetProfile to force our profile name instead of the one
        -- embedded in the export string
        local origSetProfile = Grid2.db.SetProfile
        Grid2.db.SetProfile = function(self, _name)
            Grid2.db.SetProfile = origSetProfile
            return origSetProfile(self, targetName)
        end

        local success = Grid2Options:ImportCurrentProfile(ns.data[addonKey], true)

        -- Restore hook in case import failed before SetProfile was called
        Grid2.db.SetProfile = origSetProfile

        if success then
            CompleteSetup(addonKey)
        else
            print(ns.title .. ": Grid2 import failed.")
        end
        return
    end

    if not Grid2DB or not Grid2DB.profiles or not Grid2DB.profiles[targetName] then return end
    Grid2.db:SetProfile(targetName)
end
setupFunctions["Grid2_Colored"] = setupFunctions["Grid2"]
setupFunctions["Grid2_Dark"] = setupFunctions["Grid2"]

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
        Details:ImportProfile(ns.data[addonKey], ns.profileName, false, false, true)

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

        Plater.ImportAndSwitchProfile(ns.profileName, data, false, false, true)

        C_Timer.After(0.5, function()
            Plater.ImportScriptsFromLibrary()
            Plater.ApplyPatches()
            Plater.CompileAllScripts("script")
            Plater.CompileAllScripts("hook")
            Plater:RefreshConfig()
            Plater.UpdatePlateClickSpace()
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

        WarpDepleteDB.profiles[ns.profileName] = ns.data[addonKey]
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
------------------------------------------------------------

-- Stable profile names per CDM variant (so each variant can coexist)
local cdmProfileNames = {
    Ayije_CDM_Caster = ns.profileName .. " Caster",
    Ayije_CDM_Melee = ns.profileName .. " Melee",
    Ayije_CDM_DoubleResource = ns.profileName .. " DoubleResource",
}

setupFunctions["Ayije_CDM"] = function(addonKey, import)
    if import then
        if not HasData(addonKey) then
            print(ns.title .. ": No AyijeCDM data found. Export your profile from AyijeCDM and add it to Data.lua.")
            return
        end

        -- Load the Options addon to get the full ImportProfile (handles !ACDM: prefix)
        if not C_AddOns.IsAddOnLoaded("Ayije_CDM_Options") then
            C_AddOns.LoadAddOn("Ayije_CDM_Options")
        end

        local CDM_Addon = _G["Ayije_CDM"]
        local targetName = cdmProfileNames[addonKey] or ns.profileName

        -- Suppress the config frame that RebuildConfigFrame auto-opens during import
        local origRebuild = CDM_Addon.RebuildConfigFrame
        CDM_Addon.RebuildConfigFrame = function() end

        -- Hook ImportProfileData to force our profile name instead of the one
        -- embedded in the export string (prevents CDM's name de-duplication)
        local origImportProfileData = CDM_Addon.ImportProfileData
        CDM_Addon.ImportProfileData = function(self, _name, profileData)
            return origImportProfileData(self, targetName, profileData)
        end

        local success, msg = CDM_Addon.API:ImportProfile(ns.data[addonKey])

        -- Restore hooks
        CDM_Addon.ImportProfileData = origImportProfileData
        CDM_Addon.RebuildConfigFrame = origRebuild

        if success then
            CompleteSetup(addonKey)
        else
            print(ns.title .. ": AyijeCDM import failed - " .. (msg or "unknown error"))
        end

        if _G["Ayije_CDMConfigFrame"] then
            _G["Ayije_CDMConfigFrame"]:Hide()
        end
        return
    end

    if not Ayije_CDMDB or not Ayije_CDMDB.profiles then return end
    local targetName = cdmProfileNames[addonKey] or ns.profileName
    if not Ayije_CDMDB.profiles[targetName] then return end
    local CDM_Addon = _G["Ayije_CDM"]
    CDM_Addon.API:SetProfile(targetName)
end
setupFunctions["Ayije_CDM_Caster"] = setupFunctions["Ayije_CDM"]
setupFunctions["Ayije_CDM_Melee"] = setupFunctions["Ayije_CDM"]
setupFunctions["Ayije_CDM_DoubleResource"] = setupFunctions["Ayije_CDM"]

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

        -- If KitnEssentials is loaded, use its API for a live import
        if KitnEssentialsAPI and KitnEssentialsAPI.ImportProfile then
            KitnEssentialsAPI:ImportProfile(ns.data[addonKey], ns.profileName)
        else
            -- Write directly to SavedVariables for next reload
            KitnEssentialsDB = KitnEssentialsDB or { profiles = {} }
            KitnEssentialsDB.profiles = KitnEssentialsDB.profiles or {}
            KitnEssentialsDB.profiles[ns.profileName] = ns.data[addonKey]
        end

        CompleteSetup(addonKey)
        return
    end

    -- Load: activate the profile if it exists
    if KitnEssentialsAPI and KitnEssentialsAPI.SetProfile then
        KitnEssentialsAPI:SetProfile(ns.profileName)
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
        local _, layouts = lm:EnumerateLayouts()
        if layouts then
            local specName = select(2, GetSpecializationInfoForClassID(classId, specIndex)) or ("Spec" .. specIndex)
            local layoutName = "KUI - " .. specName
            for layoutID, layout in pairs(layouts) do
                if layout and layout.layoutName == layoutName then
                    lm:RemoveLayout(layoutID)
                    break
                end
            end
        end

        local layoutIDs = lm:CreateLayoutsFromSerializedData(specString)
        if layoutIDs and layoutIDs[1] then
            local importedID = layoutIDs[1]

            -- Rename the imported layout to "KUI - SpecName"
            local _, importedLayouts = lm:EnumerateLayouts()
            if importedLayouts and importedLayouts[importedID] then
                local specName = select(2, GetSpecializationInfoForClassID(classId, specIndex)) or ("Spec" .. specIndex)
                importedLayouts[importedID].layoutName = "KUI - " .. specName
            end

            lm:SaveLayouts()

            -- Activate if this is the player's current spec
            local currentSpec = GetSpecialization()
            if currentSpec == specIndex then
                if lm.SetActiveLayoutByID then
                    lm:SetActiveLayoutByID(importedID)
                end
                if CooldownViewerSettings.RefreshLayout then
                    pcall(function() CooldownViewerSettings:RefreshLayout() end)
                end
                lm:SaveLayouts()
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
        else
            print(ns.title .. ": Failed to import CDM layout.")
        end
        return
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
