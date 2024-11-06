-- Create a table to hold all our addon functions and variables
SlugglyTracker = {}
SlugglyTracker.trackedSpells = {}
SlugglyTracker.debugPrint = false
SlugglyTracker.buffFrames = {}
SlugglyTracker.iconPerRow = 4
SlugglyTracker.iconWidth = 30
SlugglyTracker.iconHeight = 30

function SlugglyTracker:print(s)
    if (SlugglyTracker.debugPrint) then
        print(s)
    end
end

-- Create a frame to handle events
local trackerFrame = CreateFrame("Frame")

-- Function to initialize the addon
function SlugglyTracker:Initialize()
    self:LoadSavedVariables()
    -- Check if trackedSpells is empty and fill it if needed
    if self:IsTrackedSpellsEmpty() then
        print("SlugglyTracker: Tracked spell list is empty. Loading hardcoded spell list.")
        self:FillTrackedSpells()
    end
    trackerFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    trackerFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    trackerFrame:RegisterEvent("UNIT_AURA")
    trackerFrame:SetScript("OnEvent", function(_, event, ...) self:OnEvent(event, ...) end)
end

function SlugglyTracker:LoadSavedVariables()
    if SlugglyTracker_SavedVariables then
        self.trackedSpells = SlugglyTracker_SavedVariables
        SlugglyTracker:print("SlugglyTracker: Loaded the tracked spells.")
    else
        self.trackedSpells = {}
        SlugglyTracker:print("SlugglyTracker: No saved spells found, starting fresh.")
    end
end

function SlugglyTracker:SaveVariables()
    SlugglyTracker_SavedVariables = self.trackedSpells
    SlugglyTracker:print("SlugglyTracker: Saved the tracked spells.")
end

function SlugglyTracker:OnEvent(event, ...)
    if event == "NAME_PLATE_UNIT_ADDED" or event == "UNIT_AURA" then
        local unitID = ...
        local guid = UnitGUID(unitID)
        if guid then
            self:CheckNameplateBuffs(unitID, guid)
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unitID = ...
        local guid = UnitGUID(unitID)
        if guid then
            self:RemoveBuffsFromNameplate(guid)
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        local unitID = "target"
        local guid = UnitGUID(unitID)
        if guid then
            self:CheckNameplateBuffs(unitID, guid)
        end
    end
end

function SlugglyTracker:RemoveBuffsFromNameplate(guid)
    if not self.buffFrames or not self.buffFrames[guid] then return end

    for spellID, buffIconFrame in pairs(self.buffFrames[guid]) do
        buffIconFrame:Hide()
        buffIconFrame:SetScript("OnUpdate", nil)
        self.buffFrames[guid][spellID] = nil
    end

    self.buffFrames[guid] = nil
end

function SlugglyTracker:RemoveBuffsFromNameplateByNameplate(nameplate)
    if not nameplate or not nameplate.SlugglyBuffIcons then return end

    for spellID, buffIconFrame in pairs(nameplate.SlugglyBuffIcons) do
        if buffIconFrame then
            buffIconFrame:Hide()
            buffIconFrame:SetScript("OnUpdate", nil)
            nameplate.SlugglyBuffIcons[spellID] = nil
        end
    end

    nameplate.SlugglyBuffIcons = nil
end

function SlugglyTracker:CheckNameplateBuffs(unitID, guid)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unitID)
    if not nameplate then return end

    local buffs = {}
    for i = 1, 1000 do
        local name, rank, icon, count, debuffType, duration, expirationTime, caster, isStealable, nameplateShowPersonal, spellID = UnitAura(unitID, i, "HELPFUL")
        if not name then break end

        if self.trackedSpells[spellID] then
            local remainingTime = expirationTime ~= 0 and expirationTime - GetTime() or nil
            table.insert(buffs, { spellID = spellID, icon = icon, remainingTime = remainingTime })
        end
    end
    self:ShowBuffOnNameplate(unitID, guid, buffs, nameplate)
end


function SlugglyTracker:ShowBuffOnNameplate(unitID, guid, buffs, nameplate)
    self.RemoveBuffsFromNameplateByNameplate(nameplate)
    nameplate.SlugglyBuffIcons = {}
    if next(buffs) == nil then return end
    SlugglyTracker:print("Showing buff on " .. unitID)

    if not self.buffFrames[guid] then
        self.buffFrames[guid] = {}
    end

    for _, buff in ipairs(buffs) do
        local spellID, icon, remainingTime = buff.spellID, buff.icon, buff.remainingTime
        local buffIconFrame = self.buffFrames[guid][spellID]

        if not buffIconFrame then
            buffIconFrame = CreateFrame("Frame", nil, nameplate)
            buffIconFrame:SetSize(self.iconWidth, self.iconHeight)
            buffIconFrame.icon = buffIconFrame:CreateTexture(nil, "OVERLAY")
            buffIconFrame.icon:SetAllPoints()
            buffIconFrame.cooldown = buffIconFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            buffIconFrame.cooldown:SetPoint("TOP", buffIconFrame, "BOTTOM", 0, -2)
            self.buffFrames[guid][spellID] = buffIconFrame
            nameplate.SlugglyBuffIcons[spellID] = buffIconFrame
            -- SlugglyTracker:print("Created buff icon frame for spell ID " .. spellID)
        end
        buffIconFrame.icon:SetTexture(icon)
        if (remainingTime ~= nil) then
            buffIconFrame.remainingTime = remainingTime
            buffIconFrame:SetScript("OnUpdate", function(self, elapsed)
                self.remainingTime = self.remainingTime - elapsed
                if self.remainingTime > 0 then
                    self.cooldown:SetText(string.format("%.1f", self.remainingTime))
                else
                    self:Hide()
                end
            end)
        else
            buffIconFrame.remainingTime = 9999
        end
        nameplate.SlugglyBuffIcons[spellID] = buffIconFrame
    end

     -- Organize buffs by remaining time
     local sortedBuffs = {}
     for spellID, frame in pairs(nameplate.SlugglyBuffIcons) do
        table.insert(sortedBuffs, frame)
        -- SlugglyTracker:print("Inserted buff frame for spell ID " .. spellID .. " into sortedBuffs")
    end
     table.sort(sortedBuffs, function(a, b)
         return a.remainingTime < b.remainingTime
     end)
 
     -- Arrange icons in rows and columns
     local row, col = 0, 0
     for index, frame in ipairs(sortedBuffs) do
         col = (index - 1) % SlugglyTracker.iconPerRow
         row = math.floor((index - 1) / SlugglyTracker.iconPerRow)
         frame:SetPoint("TOPLEFT", nameplate, "TOPLEFT", col * (SlugglyTracker.iconWidth+5), -row * (SlugglyTracker.iconHeight+5)+5)  -- Adjust spacing as needed
         frame:Show()
         -- SlugglyTracker:print("Set position for buff icon frame at row " .. row .. ", col " .. col)
     end
end


-- Initialize the addon when the player logs in
trackerFrame:RegisterEvent("PLAYER_LOGIN")
trackerFrame:RegisterEvent("PLAYER_LOGOUT")

trackerFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        SlugglyTracker:Initialize()
    elseif event == "PLAYER_LOGOUT" then
        SlugglyTracker:SaveVariables()
    end
end)





SLASH_SLUGGLYTRACKER1 = '/slugglytracker'
SLASH_SLUGGLYTRACKER2 = '/st'

function SlugglyTracker:ChatCommand(msg)
    local cmd, spellID = strsplit(" ", msg, 2)
    spellID = tonumber(spellID)

    if cmd == "add" and spellID then
        self.trackedSpells[spellID] = true
        print("SlugglyTracker: Added spell ID " .. spellID .. " to tracking list.")
    elseif cmd == "remove" and spellID then
        self.trackedSpells[spellID] = nil
        print("SlugglyTracker: Removed spell ID " .. spellID .. " from tracking list.")
    else
        print("Usage: /st add [spellID] or /st remove [spellID]")
    end

    -- Save the updated list
    self:SaveVariables()
end

SlashCmdList["SLUGGLYTRACKER"] = function(msg) SlugglyTracker:ChatCommand(msg) end

SLASH_SLUGGLYTRACKERLIST1 = '/stlist'

function SlugglyTracker:ListTrackedSpells()
    print("Currently tracked spells:")

    local count = 0
    for spellID in pairs(self.trackedSpells) do
        local spellName = GetSpellInfo(spellID)
        if spellName then
            print(string.format(" - Spell ID: %d, Spell Name: %s", spellID, spellName))
        else
            print(string.format(" - Spell ID: %d, Spell Name: [Unknown]", spellID))
        end
        count = count + 1
    end

    if count == 0 then
        print(" - No spells are currently being tracked.")
    end
end

SlashCmdList["SLUGGLYTRACKERLIST"] = function() SlugglyTracker:ListTrackedSpells() end

SLASH_SLUGGLYTRACKERSAVE1 = '/stsave'
SlashCmdList["SLUGGLYTRACKERSAVE"] = function() SlugglyTracker:SaveVariables() end

SLASH_SLUGGLYTRACKERLOAD1 = '/stload'
SlashCmdList["SLUGGLYTRACKERLOAD"] = function() SlugglyTracker:LoadSavedVariables() end

SLASH_SLUGGLYTRACKERRESET1 = '/streset'

function SlugglyTracker:ResetVariables()
    self.trackedSpells = {}
    SlugglyTracker:SaveVariables()
    print("SlugglyTracker: All tracked spells have been reset.")
end

SlashCmdList["SLUGGLYTRACKERRESET"] = function() SlugglyTracker:ResetVariables() end

function SlugglyTracker:ChangeDebug()
    self.debugPrint =  not self.debugPrint
end

SLASH_SLUGGLYTRACKERCONSOLE1 = '/stconsole'
SlashCmdList["SLUGGLYTRACKERCONSOLE"] = function() SlugglyTracker:ChangeDebug() end

SlugglyTracker.hardcodedSpells = {
    -- Defensives
    86401,  -- Alter Time
    22812,  -- Barkskin
    19574,  -- Bestial Wrath
    954516,  -- Blood Horror -- Not Verified
    31224,  -- Cloak of Shadows
    86378,  -- Combat Readiness
    19263,  -- Deterrence
    47585,  -- Dispersion
    286266, -- Divine Infusion
    498,    -- Divine Protection
    642,    -- Divine Shield
    26669,   -- Evasion
    47788,   -- Guardian Spirit
    1044,   -- Hand of Freedom -- Not Verified
    1022,   -- Hand of Protection -- Not Verified
    45438,  -- Ice Block
    12976,  -- Last Stand
    16689,  -- Nature's Grasp
    33206,  -- Pain Suppression -- Not Verified
    20230,  -- Retaliation
    273990, -- Shadow Counter -- Not Verified
    2565,    -- Shield Block
    871,    -- Shield Wall
    954533, -- Smoke Bomb
    23920,  -- Spell Reflection -- Not Verified
    11305,  -- Sprint
    27239,  -- Master Soulstone
    61336,  -- Survival Instinct -- Not Verified
    283386, -- Temporal Shield
    954512, -- Unending Resolve

    -- Offensives
    13750, -- Adrenaline Rush
    954831, -- Air Ascendance -- Not Verified
    12042, -- Arcane Power
    886380, -- Avatar
    31884, -- Avenging Wrath -- Not Verified
    901026, -- Bloodbath
    28682, -- Combustion
    812292, -- Death Wish -- Not Verified
    760000, -- Flame Ascendance -- Not Verified
    14204, -- Enrage Talent
    275915, -- Gurubashi Rage
    63848, -- Hunger for Blood
    12472, -- Icy Veins
    31666, -- Master of Subtlety Talent
    10060, -- Power Infusion -- Not Verified
    3045, -- Rapid Fire
    1719, -- Recklessness -- Not Verified
    51713, -- Shadow Dance
    86395, -- Soul Harvest -- Not Verified

    -- Stances
    25780, -- Righteous Fury
    --, -- Defensive Stance
    --, -- Manaforged-Barrier
    275585 -- Dark Apotheosis
    9634, -- Bear Form

    -- Main Stats
    ---1, -- Strength
    ---1, -- Agility
    ---1, -- Intelligence
    ---1, -- Spirit

    -- Crowd Controls

}

SLASH_SLUGGLYTRACKERFILL1 = '/stfill'
SlashCmdList["SLUGGLYTRACKERFILL"] = function() SlugglyTracker:FillTrackedSpells() end

function SlugglyTracker:FillTrackedSpells()
    for _, spellID in ipairs(self.hardcodedSpells) do
        self.trackedSpells[spellID] = true
    end
    self:SaveVariables()
    print("SlugglyTracker: Filled tracked spells with predefined spell IDs.")
end

function SlugglyTracker:IsTrackedSpellsEmpty()
    return next(self.trackedSpells) == nil
end