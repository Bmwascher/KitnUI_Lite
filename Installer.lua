local _, ns = ...

------------------------------------------------------------
-- Installer Frame (standalone, no ElvUI dependency)
------------------------------------------------------------

local FRAME_WIDTH = 560
local FRAME_HEIGHT = 528
local SIDEBAR_WIDTH = 195
local NAV_HEIGHT = 50

local installerFrame = nil
local currentPage = 1

-- Theme colors
local ACCENT = { 1.0, 0.0, 0.549 }       -- #FF008C (KitnUI pink)
local BG_MAIN = { 0.0627, 0.0627, 0.0627, 0.92 }
local BG_SIDEBAR = { 0.0314, 0.0314, 0.0314, 0.95 }
local BG_BUTTON = { 0.0902, 0.0902, 0.0902, 1 }
local BG_BUTTON_HOVER = { 0.1804, 0.1804, 0.1804, 1 }
local BG_PROGRESS = { 0.0627, 0.0627, 0.0627, 1 }
local TEXT_NORMAL = { 0.65, 0.65, 0.65 }
local TEXT_BRIGHT = { 0.902, 0.902, 0.902 }
local TEXT_DONE = { 0.30, 0.80, 0.40 }
local TEXT_UPDATED = { 1.0, 0.35, 0.35 }

-- Font sizes
local FONT = "Interface\\AddOns\\KitnUI_Lite\\Media\\Fonts\\Expressway.TTF"
local FONT_TITLE = 18
local FONT_SUBTITLE = 16
local FONT_BODY = 13
local FONT_BUTTON = 13
local FONT_SIDEBAR = 13
local FONT_SIDEBAR_HEADER = 15
local FONT_NAV = 14
local FONT_PROGRESS = 13
local FONT_STATUS = 15

-- Sound effect on install (built-in WoW quest complete ding)
local INSTALL_SOUND = SOUNDKIT.UI_QUEST_ROLLING_FORWARD_01

------------------------------------------------------------
-- Profile status helper
------------------------------------------------------------

-- Returns a colored status string for the import state of an addon
local function GetImportStatus(addonKey)
    if ns.db and ns.db.profiles and ns.db.profiles[addonKey] then
        return "|cff00ff00imported and active|r"
    else
        return "|cffff5555not imported|r"
    end
end

-- Returns a colored status string for a CDM spec based on data availability
local function GetCDMSpecStatus(specIndex)
    local _, _, classId = UnitClass("player")
    local classData = ns.data.BlizzardCDM and ns.data.BlizzardCDM[classId]
    local specData = classData and classData[specIndex]
    if specData and strtrim(specData) ~= "" then
        return "|cff00ff00available|r"
    else
        return "|cffff5555no data|r"
    end
end

-- Sets the desc2 line to show import status for an addon step
local function ShowImportStatus(content, addonKey)
    content.desc2:SetText("Your KitnUI profile is " .. GetImportStatus(addonKey) .. ".")
end

-- Play install sound
local function PlayInstallSound()
    PlaySound(INSTALL_SOUND, "Master")
end

------------------------------------------------------------
-- Forward declarations (used inside GetPages setup closures)
------------------------------------------------------------
local GetPages
local ShowOption2
local UpdateStepButtons

------------------------------------------------------------
-- Page setup helpers (reduce repetition across similar pages)
------------------------------------------------------------

-- Single install button page (Details, Plater, BigWigs, WarpDeplete, Chattynator, MRT)
local function SimpleInstallPage(subtitleText, descText, addonKey)
    return function(content)
        content.subtitle:SetText(subtitleText)
        content.desc1:SetText(descText)
        ShowImportStatus(content, addonKey)
        content.option1:Show()
        content.option1.text:SetText("Install")
        content.option1:SetScript("OnClick", function()
            ns.SetupAddon(addonKey, true)
            ShowImportStatus(content, addonKey)
            PlayInstallSound()
            content.status:SetText("|cff00ff00Installed!|r")
            UpdateStepButtons(GetPages())
        end)
    end
end

-- Two-option page (UUF, Grid2, BasicMinimap, MinimapStats)
local function TwoOptionPage(subtitleText, descText, baseAddon, opt1Label, opt1Key, opt1Status, opt2Label, opt2Key, opt2Status)
    return function(content)
        content.subtitle:SetText(subtitleText)
        content.desc1:SetText(descText)
        ShowImportStatus(content, baseAddon)
        content.option1:Show()
        content.option1.text:SetText(opt1Label)
        content.option1:SetScript("OnClick", function()
            ns.SetupAddon(opt1Key, true)
            ShowImportStatus(content, baseAddon)
            PlayInstallSound()
            content.status:SetText(opt1Status)
            UpdateStepButtons(GetPages())
        end)
        ShowOption2(content)
        content.option2.text:SetText(opt2Label)
        content.option2:SetScript("OnClick", function()
            ns.SetupAddon(opt2Key, true)
            ShowImportStatus(content, baseAddon)
            PlayInstallSound()
            content.status:SetText(opt2Status)
            UpdateStepButtons(GetPages())
        end)
    end
end

------------------------------------------------------------
-- Installer page definitions
------------------------------------------------------------

GetPages = function()
    return {
        {
            title = "Welcome",
            setup = function(content)
                content.subtitle:SetText("Welcome to " .. ns.title)

                local hasProfiles = ns.db.profiles and next(ns.db.profiles)
                local isLoaded = ns:IsCharLoaded()

                if hasProfiles and not isLoaded then
                    -- Alt character: profiles exist but haven't been loaded here
                    content.desc1:SetText("Profiles from a previous setup were detected. You can load them onto this character instantly, or step through each addon individually.")
                    content.desc2:SetText("Click |cff00ff00Load Profiles|r to apply all at once, or |cff00ff00Continue|r to install step by step.")
                    content.option1:Show()
                    content.option1.text:SetText("Load Profiles")
                    content.option1:SetScript("OnClick", function() ns:LoadProfiles() end)
                elseif hasProfiles and isLoaded then
                    -- Returning character: already set up
                    local updated = ns:GetUpdatedProfiles()
                    if #updated > 0 then
                        content.desc1:SetText("Profile updates are available! Look for |cffff5959red|r items in the sidebar.")
                        content.desc2:SetText("Click |cff00ff00Continue|r to review and re-install updated profiles.")
                    else
                        content.desc1:SetText("This character is already set up. You can re-install or update individual profiles by stepping through the pages.")
                        content.desc2:SetText("Click |cff00ff00Continue|r to review or update your profiles.")
                    end
                else
                    -- Fresh install: no profiles exist yet
                    content.desc1:SetText("This will walk you through setting up your UI addons with pre-configured profiles. Each step lets you install a profile for a specific addon.")
                    content.desc2:SetText("Click |cff00ff00Continue|r to begin.")
                end
            end,
        },
        {
            title = "Edit Mode",
            addon = "Blizzard_EditMode",
            alwaysAvailable = true,
            setup = function(content)
                content.subtitle:SetText("Blizzard Edit Mode")
                content.desc1:SetText("Import the KitnUI Edit Mode layout for your action bars, unit frames, and HUD positioning.")
                ShowImportStatus(content, "Blizzard_EditMode")
                content.option1:Show()
                content.option1.text:SetText("Install")
                content.option1:SetScript("OnClick", function()
                    local success = ns.SetupAddon("Blizzard_EditMode", true)
                    if success == false then
                        content.status:SetText("|cffff5555Layout limit reached (5). Delete a layout and try again.|r")
                    else
                        ShowImportStatus(content, "Blizzard_EditMode")
                        PlayInstallSound()
                        content.status:SetText("|cff00ff00Installed!|r")
                        UpdateStepButtons(GetPages())
                    end
                end)
            end,
        },
        {
            title = "Unit Frames",
            addon = "UnhaltedUnitFrames",
            setup = TwoOptionPage("Unhalted Unit Frames", "Choose a style for Unhalted Unit Frames.\nInstalls both DPS and Healer profiles with automatic spec switching.", "UnhaltedUnitFrames",
                "Colored", "UnhaltedUnitFrames_Colored", "|cff00ff00Colored style installed!|r",
                "Dark", "UnhaltedUnitFrames_Dark", "|cff00ff00Dark style installed!|r"),
        },
        {
            title = "Party/Raid Frames",
            addon = "Grid2",
            setup = TwoOptionPage("Grid2", "Choose a style for Grid2 party and raid frames.\nInstalls both DPS and Healer profiles with automatic spec switching.", "Grid2",
                "Colored", "Grid2_Colored", "|cff00ff00Colored style installed!|r",
                "Dark", "Grid2_Dark", "|cff00ff00Dark style installed!|r"),
        },
        {
            title = "Details",
            addon = "Details",
            setup = SimpleInstallPage("Details! Damage Meter", "Import the KitnUI profile for Details.", "Details"),
        },
        {
            title = "Plater",
            addon = "Plater",
            setup = SimpleInstallPage("Plater Nameplates", "Import the KitnUI profile for Plater.", "Plater"),
        },
        {
            title = "BigWigs",
            addon = "BigWigs",
            setup = SimpleInstallPage("BigWigs / LittleWigs", "Import the KitnUI profile for BigWigs boss timers.", "BigWigs"),
        },
        {
            title = "WarpDeplete",
            addon = "WarpDeplete",
            setup = SimpleInstallPage("WarpDeplete", "Import the KitnUI profile for the M+ timer.", "WarpDeplete"),
        },
        {
            title = "Ayije CDM",
            addon = "Ayije_CDM",
            setup = SimpleInstallPage("Ayije CDM", "Import Ayije CDM profiles for all specs.\nProfiles will auto-switch when you change spec.", "Ayije_CDM"),
        },
        {
            title = "Chattynator",
            addon = "Chattynator",
            setup = SimpleInstallPage("Chattynator", "Import the KitnUI profile for Chattynator chat frames.", "Chattynator"),
        },
        {
            title = "MRT",
            addon = "MRT",
            setup = SimpleInstallPage("Method Raid Tools", "Import the KitnUI profile for MRT.", "MRT"),
        },
        {
            title = "KitnEssentials",
            addon = "KitnEssentials",
            setup = SimpleInstallPage("KitnEssentials", "Import the KitnUI profile for KitnEssentials.", "KitnEssentials"),
        },
        {
            title = "BuffReminders",
            addon = "BuffReminders",
            setup = SimpleInstallPage("BuffReminders", "Import the KitnUI profile for BuffReminders.", "BuffReminders"),
        },
        {
            title = "BasicMinimap",
            addon = "BasicMinimap",
            setup = TwoOptionPage("BasicMinimap", "Choose a minimap shape for BasicMinimap.\n|cffff8800Reload UI (/reload) after installing for the shape to take effect.|r", "BasicMinimap",
                "Square", "BasicMinimap_Square", "|cff00ff00Square minimap installed!|r |cffff8800Reload to apply.|r",
                "Circle", "BasicMinimap_Circle", "|cff00ff00Circle minimap installed!|r |cffff8800Reload to apply.|r"),
        },
        {
            title = "Minimap Stats",
            addon = "MinimapStats",
            setup = TwoOptionPage("Minimap Stats", "Choose a minimap shape for Minimap Stats.", "MinimapStats",
                "Square", "MinimapStats_Square", "|cff00ff00Square stats installed!|r",
                "Circle", "MinimapStats_Circle", "|cff00ff00Circle stats installed!|r"),
        },
        {
            title = "Blizzard CDM",
            addon = "BlizzardCDM",
            alwaysAvailable = true,
            setup = function(content)
                content.subtitle:SetText("Blizzard Cooldown Manager")

                -- Check if CDM is enabled
                local cdmEnabled = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("cooldownViewerEnabled") == "1"
                if not cdmEnabled then
                    content.desc1:SetText("|cffff5555Cooldown Manager is disabled.|r")
                    content.desc2:SetText("Enable it in Settings > Gameplay > Combat > Cooldown Manager.")
                    return
                end

                local _, _, classId = UnitClass("player")
                local numSpecs = GetNumSpecializationsForClassID(classId)

                -- Check if we have data for this class
                local classData = ns.data.BlizzardCDM and ns.data.BlizzardCDM[classId]
                if not classData or not next(classData) then
                    content.desc1:SetText("No CDM layouts available for your class yet.")
                    content.desc2:SetText("Export your CDM layouts and add them to Data.lua.")
                    return
                end

                content.desc1:SetText("Import cooldown layouts for each spec. Click a spec to install its layout.")

                -- Build status text showing per-spec state
                local statusParts = {}
                for i = 1, numSpecs do
                    local _, specName, _, specIcon = GetSpecializationInfoForClassID(classId, i)
                    if specName then
                        statusParts[#statusParts + 1] = specName .. ": " .. GetCDMSpecStatus(i)
                    end
                end
                content.desc2:SetText(table.concat(statusParts, " | "))

                -- Show per-spec buttons
                if content.specBtns then
                    local btnWidth = numSpecs <= 3 and 150 or 120
                    local btnSpacing = 8
                    local totalWidth = numSpecs * btnWidth + (numSpecs - 1) * btnSpacing
                    local startX = -totalWidth / 2 + btnWidth / 2

                    for i = 1, numSpecs do
                        local btn = content.specBtns[i]
                        if btn then
                            local _, specName, _, specIcon = GetSpecializationInfoForClassID(classId, i)
                            local specData = classData[i]

                            btn:ClearAllPoints()
                            btn:SetPoint("BOTTOM", content, "BOTTOM", startX + (i - 1) * (btnWidth + btnSpacing), 15)
                            btn:SetSize(btnWidth, 30)

                            if specName and specIcon then
                                btn.text:SetText("|T" .. specIcon .. ":14:14:0:0|t " .. specName)
                            elseif specName then
                                btn.text:SetText(specName)
                            end

                            if specData and strtrim(specData) ~= "" then
                                btn:SetAlpha(1)
                                btn:SetScript("OnClick", function()
                                    local success = ns.SetupAddon("BlizzardCDM", true, i)
                                    -- Refresh status
                                    local parts = {}
                                    for j = 1, numSpecs do
                                        local _, sn = GetSpecializationInfoForClassID(classId, j)
                                        if sn then
                                            parts[#parts + 1] = sn .. ": " .. GetCDMSpecStatus(j)
                                        end
                                    end
                                    if success == false then
                                        content.desc2:SetText("|cffff5555Layout limit reached. Delete a layout and try again.|r")
                                        content.status:SetText("|cffff5555Layout limit reached!|r")
                                    else
                                        content.desc2:SetText(table.concat(parts, " | "))
                                        PlayInstallSound()
                                        content.status:SetText("|cff00ff00" .. (specName or "Spec") .. " layout installed!|r")
                                        UpdateStepButtons(GetPages())
                                    end
                                end)
                            else
                                btn:SetAlpha(0.35)
                                btn:SetScript("OnClick", function()
                                    content.status:SetText("|cffff5555No data for " .. (specName or "this spec") .. ".|r")
                                end)
                            end

                            btn:Show()
                        end
                    end
                end
            end,
        },
        {
            title = "Finish",
            setup = function(content)
                content.subtitle:SetText("Installation Complete")
                content.desc1:SetText("You have completed the KitnUI installation.")
                content.desc2:SetText("Click 'Reload UI' to apply all changes.")
                content.option1:Show()
                content.option1.text:SetText("Reload UI")
                content.option1:SetScript("OnClick", function() ReloadUI() end)
            end,
        },
    }
end

------------------------------------------------------------
-- Helpers
------------------------------------------------------------

local function ResetContent(content)
    content.subtitle:SetText("")
    content.desc1:SetText("")
    content.desc2:SetText("")
    content.status:SetText("")
    content.option1:Hide()
    content.option2:Hide()
    -- Reset option1 to centered (moves to left offset when option2 is shown)
    content.option1:ClearAllPoints()
    content.option1:SetPoint("BOTTOM", content, "BOTTOM", 0, 15)
    -- Reset option2 to default right position
    content.option2:ClearAllPoints()
    content.option2:SetPoint("BOTTOM", content, "BOTTOM", 95, 15)
    -- Hide and reset spec buttons
    if content.specBtns then
        for _, btn in ipairs(content.specBtns) do
            btn:SetSize(170, 30)
            btn:Hide()
        end
    end
end

-- Call after showing option2 to shift option1 left
ShowOption2 = function(content)
    content.option1:ClearAllPoints()
    content.option1:SetPoint("BOTTOM", content, "BOTTOM", -95, 15)
    content.option2:Show()
end

-- Create a flat dark button (no Blizzard template)
local function CreateDarkButton(parent, width, height)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1.1,
    })
    btn:SetBackdropColor(unpack(BG_BUTTON))
    btn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, FONT_BUTTON)
    text:SetPoint("CENTER")
    text:SetTextColor(unpack(TEXT_BRIGHT))
    btn.text = text

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(BG_BUTTON_HOVER))
        self:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.6)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(BG_BUTTON))
        self:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    end)

    return btn
end

-- Create a flat dark nav button (Previous/Continue)
local function CreateNavButton(parent, width, height)
    local btn = CreateDarkButton(parent, width, height)
    btn.text:SetFont(FONT, FONT_NAV)
    return btn
end

------------------------------------------------------------
-- Step sidebar & progress bar
------------------------------------------------------------

UpdateStepButtons = function(pages)
    if not installerFrame then return end
    for i, btn in ipairs(installerFrame.stepButtons) do
        local addonKey = pages[i] and pages[i].addon
        if i == currentPage then
            btn.text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
            btn.indicator:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3])
            btn.indicator:Show()
        elseif addonKey and ns:IsProfileUpdated(addonKey) then
            btn.text:SetTextColor(unpack(TEXT_UPDATED))
            btn.indicator:Hide()
        elseif ns.db.profiles and ns.db.profiles[addonKey] then
            btn.text:SetTextColor(unpack(TEXT_DONE))
            btn.indicator:Hide()
        else
            btn.text:SetTextColor(unpack(TEXT_NORMAL))
            btn.indicator:Hide()
        end
    end
end

local function UpdateProgressBar()
    if not installerFrame then return end
    local pages = GetPages()
    local pct = currentPage / #pages
    installerFrame.progressFill:SetWidth(math.max(1, (installerFrame.progressBar:GetWidth()) * pct))
    installerFrame.progressText:SetText(currentPage .. " / " .. #pages)
end

local function SetPage(page)
    local pages = GetPages()
    if page < 1 or page > #pages then return end

    currentPage = page
    local content = installerFrame.content
    ResetContent(content)

    local pageData = pages[page]

    if pageData.addon and not pageData.alwaysAvailable and not ns:IsAddOnEnabled(pageData.addon) then
        content.subtitle:SetText(pageData.title)
        content.desc1:SetText("|cffff5555" .. pageData.addon .. " is not enabled.|r")
        content.desc2:SetText("Enable it in your addon list and reload to unlock this step.")
    else
        pageData.setup(content)
    end

    -- Nav buttons
    installerFrame.prevBtn:SetEnabled(page > 1)
    installerFrame.prevBtn:SetAlpha(page > 1 and 1 or 0.35)
    installerFrame.nextBtn:SetEnabled(page < #pages)
    installerFrame.nextBtn:SetAlpha(page < #pages and 1 or 0.35)

    UpdateStepButtons(pages)
    UpdateProgressBar()
end

------------------------------------------------------------
-- Build the installer frame
------------------------------------------------------------

local function CreateInstallerFrame()
    -- Main frame
    local f = CreateFrame("Frame", "KitnUILiteFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH + SIDEBAR_WIDTH, FRAME_HEIGHT)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    f:SetBackdropColor(unpack(BG_MAIN))

    -- Thin top accent line
    local topLine = f:CreateTexture(nil, "OVERLAY")
    topLine:SetHeight(2)
    topLine:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    topLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    topLine:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)

    -- Close button (custom X)
    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
    closeTxt:SetFont(FONT, 16)
    closeTxt:SetPoint("CENTER")
    closeTxt:SetText("x")
    closeTxt:SetTextColor(0.5, 0.5, 0.5)
    closeBtn:SetScript("OnEnter", function() closeTxt:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3]) end)
    closeBtn:SetScript("OnLeave", function() closeTxt:SetTextColor(0.5, 0.5, 0.5) end)

    -- Title (centered over the content area, not the full frame)
    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, FONT_TITLE)
    title:SetPoint("TOP", SIDEBAR_WIDTH / 2, -14)
    title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
    title:SetText(ns.title .. " |cffffffffInstaller|r")

    -- Sidebar (full height behind title bar and nav)
    local sidebar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(SIDEBAR_WIDTH)
    sidebar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    sidebar:SetBackdropColor(unpack(BG_SIDEBAR))

    -- Sidebar brand logo (256x256 canvas, content is 256x126 centered)
    local brandLogo = sidebar:CreateTexture(nil, "ARTWORK")
    brandLogo:SetSize(70, 30)
    brandLogo:SetPoint("TOP", 0, -8)
    brandLogo:SetTexture("Interface\\AddOns\\KitnUI_Lite\\Media\\Textures\\KitnUI_Text")
    brandLogo:SetTexCoord(0, 1, 0.254, 0.746)

    -- Sidebar header
    local stepsHeader = sidebar:CreateFontString(nil, "OVERLAY")
    stepsHeader:SetFont(FONT, FONT_SIDEBAR_HEADER)
    stepsHeader:SetPoint("TOPLEFT", 14, -48)
    stepsHeader:SetText("PROFILES")
    stepsHeader:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.7)

    -- Step buttons
    local pages = GetPages()
    f.stepButtons = {}
    for i, page in ipairs(pages) do
        local btn = CreateFrame("Button", nil, sidebar)
        btn:SetSize(SIDEBAR_WIDTH - 10, 22)
        btn:SetPoint("TOPLEFT", 5, -68 - (i - 1) * 24)

        -- Active indicator (left accent bar)
        local indicator = btn:CreateTexture(nil, "OVERLAY")
        indicator:SetSize(2, 18)
        indicator:SetPoint("LEFT", 0, 0)
        indicator:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3])
        indicator:Hide()
        btn.indicator = indicator

        local text = btn:CreateFontString(nil, "OVERLAY")
        text:SetFont(FONT, FONT_SIDEBAR)
        text:SetPoint("LEFT", 10, 0)
        text:SetText(page.title)
        text:SetTextColor(unpack(TEXT_NORMAL))
        text:SetJustifyH("LEFT")
        btn.text = text

        btn:SetScript("OnClick", function() SetPage(i) end)
        btn:SetScript("OnEnter", function()
            if i ~= currentPage then
                text:SetTextColor(unpack(TEXT_BRIGHT))
            end
        end)
        btn:SetScript("OnLeave", function()
            if i ~= currentPage then
                local key = pages[i] and pages[i].addon
                if key and ns:IsProfileUpdated(key) then
                    text:SetTextColor(unpack(TEXT_UPDATED))
                elseif ns.db.profiles and ns.db.profiles[key] then
                    text:SetTextColor(unpack(TEXT_DONE))
                else
                    text:SetTextColor(unpack(TEXT_NORMAL))
                end
            end
        end)

        f.stepButtons[i] = btn
    end

    -- Sidebar horizontal divider (above nav area)
    local sidebarNavLine = sidebar:CreateTexture(nil, "OVERLAY")
    sidebarNavLine:SetHeight(1)
    sidebarNavLine:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 10, NAV_HEIGHT)
    sidebarNavLine:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -5, NAV_HEIGHT)
    sidebarNavLine:SetColorTexture(0.5, 0.5, 0.5, 0.35)

    -- Content area
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, -38)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, NAV_HEIGHT)

    -- Logo (always visible, above buttons)
    local logo = content:CreateTexture(nil, "ARTWORK")
    logo:SetSize(220, 220)
    logo:SetPoint("BOTTOM", content, "BOTTOM", 0, 78)
    logo:SetTexture("Interface\\AddOns\\KitnUI_Lite\\Media\\Textures\\KitnUI")
    content.logo = logo

    local subtitle = content:CreateFontString(nil, "OVERLAY")
    subtitle:SetFont(FONT, FONT_SUBTITLE)
    subtitle:SetPoint("TOP", 0, -10)
    subtitle:SetTextColor(unpack(TEXT_BRIGHT))
    content.subtitle = subtitle

    local desc1 = content:CreateFontString(nil, "OVERLAY")
    desc1:SetFont(FONT, FONT_BODY)
    desc1:SetPoint("TOP", subtitle, "BOTTOM", 0, -10)
    desc1:SetWidth(FRAME_WIDTH - SIDEBAR_WIDTH - 40)
    desc1:SetJustifyH("CENTER")
    desc1:SetTextColor(unpack(TEXT_NORMAL))
    content.desc1 = desc1

    local desc2 = content:CreateFontString(nil, "OVERLAY")
    desc2:SetFont(FONT, FONT_BODY)
    desc2:SetPoint("TOP", desc1, "BOTTOM", 0, -12)
    desc2:SetWidth(FRAME_WIDTH - SIDEBAR_WIDTH - 40)
    desc2:SetJustifyH("CENTER")
    desc2:SetTextColor(unpack(TEXT_NORMAL))
    content.desc2 = desc2

    local status = content:CreateFontString(nil, "OVERLAY")
    status:SetFont(FONT, FONT_STATUS)
    status:SetPoint("BOTTOM", content, "BOTTOM", 0, 48)
    content.status = status

    -- Action buttons (dark flat style, matching nav button height)
    -- option1 defaults to centered; repositioned when option2 is also shown
    local option1 = CreateDarkButton(content, 170, 30)
    option1:SetPoint("BOTTOM", content, "BOTTOM", 0, 15)
    option1:Hide()
    content.option1 = option1

    local option2 = CreateDarkButton(content, 170, 30)
    option2:SetPoint("BOTTOM", content, "BOTTOM", 95, 15)
    option2:Hide()
    content.option2 = option2

    -- Spec buttons pool (max 4 specs)
    content.specBtns = {}
    for i = 1, 4 do
        local specBtn = CreateDarkButton(content, 170, 30)
        specBtn:Hide()
        content.specBtns[i] = specBtn
    end

    f.content = content

    -- Bottom navigation bar
    local navBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    navBar:SetPoint("BOTTOMLEFT", SIDEBAR_WIDTH, 0)
    navBar:SetPoint("BOTTOMRIGHT", 0, 0)
    navBar:SetHeight(NAV_HEIGHT)
    navBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    navBar:SetBackdropColor(0.04, 0.04, 0.04, 1)

    -- Version number in bottom-left (parented to sidebar so it draws above navBar backdrop)
    local versionText = sidebar:CreateFontString(nil, "OVERLAY")
    versionText:SetFont(FONT, 14)
    versionText:SetPoint("CENTER", sidebar, "BOTTOM", 0, NAV_HEIGHT / 2)
    versionText:SetTextColor(0.5, 0.5, 0.5, 0.75)
    versionText:SetText("KUI v" .. (ns.version or "?"))

    -- Vertical divider (between version and nav buttons)
    local sidebarVertLine = navBar:CreateTexture(nil, "OVERLAY")
    sidebarVertLine:SetWidth(1)
    sidebarVertLine:SetPoint("TOP", navBar, "TOPLEFT", 0, -8)
    sidebarVertLine:SetPoint("BOTTOM", navBar, "BOTTOMLEFT", 0, 8)
    sidebarVertLine:SetColorTexture(0.5, 0.5, 0.5, 0.35)

    local prevBtn = CreateNavButton(navBar, 100, 30)
    prevBtn:SetPoint("LEFT", 10, 0)
    prevBtn.text:SetText("Previous")
    prevBtn:SetScript("OnClick", function() SetPage(currentPage - 1) end)
    f.prevBtn = prevBtn

    local nextBtn = CreateNavButton(navBar, 100, 30)
    nextBtn:SetPoint("RIGHT", -10, 0)
    nextBtn.text:SetText("Continue")
    nextBtn:SetScript("OnClick", function() SetPage(currentPage + 1) end)
    f.nextBtn = nextBtn

    -- Progress bar (centered between prev/next)
    local progressBar = CreateFrame("Frame", nil, navBar, "BackdropTemplate")
    progressBar:SetHeight(22)
    progressBar:SetPoint("LEFT", prevBtn, "RIGHT", 12, 0)
    progressBar:SetPoint("RIGHT", nextBtn, "LEFT", -12, 0)
    progressBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    progressBar:SetBackdropColor(unpack(BG_PROGRESS))
    f.progressBar = progressBar

    local progressFill = progressBar:CreateTexture(nil, "ARTWORK")
    progressFill:SetPoint("TOPLEFT", 0, 0)
    progressFill:SetPoint("BOTTOMLEFT", 0, 0)
    progressFill:SetWidth(1)
    progressFill:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.85)
    f.progressFill = progressFill

    local progressText = progressBar:CreateFontString(nil, "OVERLAY")
    progressText:SetFont(FONT, FONT_PROGRESS, "THINOUTLINE")
    progressText:SetPoint("CENTER")
    progressText:SetTextColor(unpack(TEXT_BRIGHT))
    f.progressText = progressText

    -- ESC to close
    tinsert(UISpecialFrames, "KitnUILiteFrame")

    return f
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------

function ns:ShowInstaller(targetAddon)
    if InCombatLockdown() then
        print(ns.title .. ": Cannot open installer during combat.")
        return
    end

    if not installerFrame then
        installerFrame = CreateInstallerFrame()
    end

    local startPage = 1
    if targetAddon then
        local pages = GetPages()
        for i, page in ipairs(pages) do
            if page.addon == targetAddon then
                startPage = i
                break
            end
        end
    end

    currentPage = startPage
    installerFrame:Show()
    SetPage(startPage)
end
