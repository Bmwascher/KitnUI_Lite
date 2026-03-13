local addonName, ns = ...

ns.title = "|cffFF008CKitn|r|cffffffffUI|r"
ns.profileName = "KitnUI"
ns.version = C_AddOns.GetAddOnMetadata(addonName, "Version")

------------------------------------------------------------
-- Register media with LibSharedMedia (if available)
------------------------------------------------------------

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
if LSM then
    LSM:Register("font", "Expressway", "Interface\\AddOns\\KitnUI_Lite\\Media\\Fonts\\Expressway.TTF")
    LSM:Register("statusbar", "KitnUI", "Interface\\AddOns\\KitnUI_Lite\\Media\\Statusbars\\KitnUI")
end

-- Saved variables (initialized in ADDON_LOADED)
ns.db = nil

local defaults = {
    profiles = {},  -- tracks which addons have been installed
    version = nil,
    installedVersion = nil,  -- addon version when last installed
    perChar = {},   -- [charName] = { loaded = true/false }
}

local function GetCharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

-- Utility: check if an addon is enabled for this character
function ns:IsAddOnEnabled(addon)
    if not C_AddOns.DoesAddOnExist(addon) then return false end
    return C_AddOns.GetAddOnEnableState(addon, UnitName("player")) == 2
end

-- Addons that require manual selection (multi-variant or per-spec)
local manualSelectAddons = {
    Ayije_CDM = true,
    BlizzardCDM = true,
}

-- Built-in Blizzard features that don't have a real addon to check
local alwaysAvailableAddons = {
    Blizzard_EditMode = true,
}

-- Load profiles onto current character (just activates existing profiles, no data overwrite)
function ns:LoadProfiles()
    if not self.db.profiles then return end

    -- Collect base keys that have a variant installed (to skip the base-only entry)
    local baseHasVariant = {}
    for addonKey in pairs(self.db.profiles) do
        local base = ns.variantBase and ns.variantBase[addonKey]
        if base then
            baseHasVariant[base] = true
        end
    end

    local skipped = {}
    for addonKey in pairs(self.db.profiles) do
        -- Skip base keys when a variant is present (e.g. skip "Grid2" if "Grid2_Colored" exists)
        if baseHasVariant[addonKey] then
            -- no-op, the variant key will handle it
        elseif manualSelectAddons[addonKey] then
            skipped[addonKey] = true
        else
            -- Resolve variant key to real addon name for the enabled check
            local realAddon = ns.variantBase and ns.variantBase[addonKey] or addonKey
            if alwaysAvailableAddons[addonKey] or self:IsAddOnEnabled(realAddon) then
                ns.SetupAddon(addonKey)
            end
        end
    end

    local key = GetCharKey()
    self.db.perChar[key] = self.db.perChar[key] or {}
    self.db.perChar[key].loaded = true

    -- Store reminder for after reload (C_Timer won't survive ReloadUI)
    if next(skipped) then
        self.db.pendingReminder = skipped
    end

    ReloadUI()
end

function ns:IsCharLoaded()
    local key = GetCharKey()
    return self.db.perChar[key] and self.db.perChar[key].loaded
end

function ns:SetCharLoaded()
    local key = GetCharKey()
    self.db.perChar[key] = self.db.perChar[key] or {}
    self.db.perChar[key].loaded = true
end

-- Shared slash command dispatch table (other Kitn addons can register subcommands here)
KitnCommands = KitnCommands or {}

-- Register installer subcommands
KitnCommands["install"] = function()
    ns:ShowInstaller()
end

KitnCommands["load"] = function()
    if not ns.db.profiles or not next(ns.db.profiles) then
        print(ns.title .. ": No profiles installed yet. Run /kitn install first.")
        return
    end
    ns:LoadProfiles()
end

KitnCommands["reset"] = function()
    KitnUILiteDB = nil
    ReloadUI()
end

KitnCommands["version"] = function()
    print(string.format("|cffffffffKitnUI Lite version %s|r", ns.version or "?"))
end
KitnCommands["ver"] = KitnCommands["version"]
KitnCommands["v"] = KitnCommands["version"]

-- Slash commands
SLASH_KITN1 = "/kitn"
SLASH_KITN2 = "/kitnui"
SLASH_KITN3 = "/kui"
SlashCmdList["KITN"] = function(msg)
    msg = strlower(strtrim(msg))
    local cmd = KitnCommands[msg]
    if cmd then
        cmd()
    elseif msg == "" then
        print(ns.title .. " v" .. (ns.version or "?"))
        print("  /kitn install  - Open the installer to import profiles")
        print("   |cffff8800Warning: This will overwrite personal customizations|r")
        print("  /kitn load     - Apply installed profiles to this character")
        print("  /kitn reset    - Reset installer state (does not remove addon profiles)")
        print("  /kitn version  - Show addon version")
        -- Print help lines registered by other Kitn addons (e.g. KitnEssentials)
        if KitnHelpLines then
            for _, line in ipairs(KitnHelpLines) do
                print(line)
            end
        end
    else
        print(ns.title .. ": Unknown command '" .. msg .. "'. Type |cffFF008C/kitn|r for help.")
    end
end

-- Addon compartment button
function KitnUI_Lite_AddonCompartmentFunc()
    ns:ShowInstaller()
end

-- Event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Initialize saved variables
        if not KitnUILiteDB then
            KitnUILiteDB = CopyTable(defaults)
        end
        ns.db = KitnUILiteDB

        -- Ensure tables exist
        ns.db.profiles = ns.db.profiles or {}
        ns.db.perChar = ns.db.perChar or {}

        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")

        if not ns.db or InCombatLockdown() then return end

        local hasProfiles = ns.db.profiles and next(ns.db.profiles)

        -- Check for addon version update (only if previously installed)
        if hasProfiles and ns.db.installedVersion and ns.version and ns.db.installedVersion ~= ns.version then
            StaticPopupDialogs["KITNUI_UPDATE_AVAILABLE"] = {
                text = ns.title .. " has been updated (v" .. ns.db.installedVersion .. " -> v" .. ns.version .. "). Open the installer to apply changes?",
                button1 = "Open Installer",
                button2 = "Later",
                OnAccept = function() ns:ShowInstaller() end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
            }
            StaticPopup_Show("KITNUI_UPDATE_AVAILABLE")
        -- If profiles exist but this character hasn't loaded them yet, prompt
        elseif hasProfiles and not ns:IsCharLoaded() then
            StaticPopupDialogs["KITNUI_LOAD_PROFILES"] = {
                text = "KitnUI: Load your installed profiles onto this character? (You can also use /kitn load anytime)",
                button1 = "Yes",
                button2 = "No",
                OnAccept = function() ns:LoadProfiles() end,
                OnCancel = function() ns:SetCharLoaded() end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
            }
            StaticPopup_Show("KITNUI_LOAD_PROFILES")
        end

        -- Login message
        C_Timer.After(2, function()
            print(ns.title .. ": Type |cffFF008C/kitn|r for commands.")
        end)

        -- Show reminder for addons that need manual setup (saved before ReloadUI)
        if ns.db.pendingReminder then
            local skipped = ns.db.pendingReminder
            ns.db.pendingReminder = nil
            local reminders = {}
            if skipped.Ayije_CDM then
                reminders[#reminders + 1] = "Ayije CDM (pick Caster/Melee/Double Resource)"
            end
            if skipped.BlizzardCDM then
                reminders[#reminders + 1] = "Blizzard CDM (pick your spec layout)"
            end
            if #reminders > 0 then
                C_Timer.After(3, function()
                    print(ns.title .. ": Open the installer (/kitn install) to finish setup: " .. table.concat(reminders, ", "))
                end)
            end
        end
    end
end)
