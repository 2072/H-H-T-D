--[=[
HealersHaveToDie World of Warcraft Add-on
Copyright (c) 2009-2010 by John Wellesz (Archarodim@teaser.fr)
All rights reserved

Version @project-version@

This is a very simple and light add-on that rings when you hover or target a
unit of the opposite faction who healed someone during the last 60 seconds (can
be configured).
Now you can spot those nasty healers instantly and help them to accomplish their destiny!

This add-on uses the Ace3 framework.

type /hhtd to get a list of existing options.

-----
    Core.lua
-----


--]=]

--========= NAMING Convention ==========
--      VARIABLES AND FUNCTIONS (upvalues excluded)
-- global variable                == _NAME_WORD2 (underscore + full uppercase)
-- semi-global (file locals)      == NAME_WORD2 (full uppercase)
-- locals to closures or members  == NameWord2
-- locals to functions            == nameWord2
--
--      TABLES
--  globals                       == NAME__WORD2
--  locals                        == name_word2
--  members                       == Name_Word2

-- Debug templates
local ERROR     = 1;
local WARNING   = 2;
local INFO      = 3;
local INFO2     = 4;

local ADDON_NAME, T = ...;

-- === Add-on basics and variable declarations {{{
T.Healers_Have_To_Die = LibStub("AceAddon-3.0"):NewAddon("Healers Have To Die", "AceConsole-3.0", "AceEvent-3.0");
local HHTD = T.Healers_Have_To_Die;

--@debug@
_HHTD_DEBUG = HHTD;
--@end-debug@

HHTD.Localized_Text = LibStub("AceLocale-3.0"):GetLocale("HealersHaveToDie", true);

local L = HHTD.Localized_Text;

HHTD.Constants = {};
local HHTD_C = HHTD.Constants;

HHTD_C.Healing_Classes = {
    ["PRIEST"]  = true,
    ["PALADIN"] = true,
    ["DRUID"]   = true,
    ["SHAMAN"]  = true,
};

HHTD.Enemy_Healers = {};
HHTD.Enemy_Healers_By_Name = {};
HHTD.Enemy_Healers_By_Name_Blacklist = {};
HHTD.Total_Heal_By_Name = {};

-- local function REGISTER_HEALERS_ONLY_SPELLS_ONCE () -- {{{
local function REGISTER_HEALERS_ONLY_SPELLS_ONCE ()

    if HHTD_C.Healers_Only_Spells_ByName then
        return;
    end

    local Healers_Only_Spells = {

        -- Priests
        47540, -- Penance
        88625, -- Holy Word: Chastise
        88684, -- Holy Word: Serenity
        88685, -- Holy Word: Sanctuary
        89485, -- Inner Focus
        10060, -- Power Infusion
        33206, -- Pain Suppression
        62618, -- Power Word: Barrier
        724,   -- Lightwell
        14751, -- Chakra
        34861, -- Circle of Healing
        47788, -- Guardian Spirit

        -- Druids
        18562, -- Swiftmend
        17116, -- Nature's Swiftness
        48438, -- Wild Growth
        33891, -- Tree of Life

        -- Shamans
        974, -- Earth Shield
        17116, -- Nature's Swiftness
        16190, -- Mana Tide Totem
        61295, -- Riptide

        -- Paladins
        20473, -- Holy Shock
        31842, -- Divine Favor
        53563, -- Beacon of Light
        31821, -- Aura Mastery
        85222, -- Light of Dawn
    };

    HHTD_C.Healers_Only_Spells_ByName = {};

    for i, spellID in ipairs(Healers_Only_Spells) do
        if (GetSpellInfo(spellID)) then
            HHTD_C.Healers_Only_Spells_ByName[(GetSpellInfo(spellID))] = true;
        else
            HHTD:Debug(ERROR, "Missing spell:", spellID);
        end
    end
    HHTD:Debug(INFO, "Spells registered!");
end -- }}}

-- Modules standards configurations {{{

-- Configure default libraries for modules
HHTD:SetDefaultModuleLibraries( "AceConsole-3.0", "AceEvent-3.0")

-- Set the default prototype for modules
HHTD:SetDefaultModulePrototype( {
    OnEnable = function(self) self:Debug(INFO, "prototype OnEnable called!") end,

    OnDisable = function(self) self:Debug(INFO, "prototype OnDisable called!") end,

    OnInitialize = function(self)
        self:Debug(INFO, "prototype OnInitialize called!");
    end,

    Debug = function(self, ...) HHTD.Debug(self, ...) end,
} )

-- Set modules' default state to "false"
HHTD:SetDefaultModuleState( false )
-- }}}

-- upvalues {{{
local UnitIsPlayer      = _G.UnitIsPlayer;
local UnitIsDead        = _G.UnitIsDead;
local UnitFactionGroup  = _G.UnitFactionGroup;
local UnitGUID          = _G.UnitGUID;
local UnitIsUnit        = _G.UnitIsUnit;
local UnitSex           = _G.UnitSex;
local UnitClass         = _G.UnitClass;
local UnitName          = _G.UnitName;
local UnitFactionGroup  = _G.UnitFactionGroup;
local GetTime           = _G.GetTime;
local PlaySoundFile     = _G.PlaySoundFile;
local pairs             = _G.pairs;
-- }}}

-- }}}

-- modules handling functions {{{

function HHTD:SetModulesStates ()
    for moduleName, module in self:IterateModules() do
        module:SetEnabledState(self.db.global.Modules[moduleName].Enabled);
    end
end

-- }}}

-- 03 Ghosts I

-- == Options and defaults {{{
do

    local function GetCoreOptions() -- {{{
    return {
        type = 'group',
        get = function (info) return HHTD.db.global[info[#info]]; end,
        set = function (info, value) HHTD:SetHandler(HHTD, info, value) end,
        disabled = function () return not HHTD:IsEnabled(); end,
        childGroups = 'tab',
        name = "Healers Have To Die",
        args = {
            Description = {
                type = 'description',
                name = L["DESCRIPTION"],
                order = 0,
            },
            On = {
                type = 'toggle',
                name = L["OPT_ON"],
                desc = L["OPT_ON_DESC"],
                set = function(info) HHTD.db.global.Enabled = HHTD:Enable(); return HHTD.db.global.Enabled; end,
                get = function(info) return HHTD:IsEnabled(); end,
                hidden = function() return HHTD:IsEnabled(); end, 

                disabled = false,
                order = 1,
            },
            Off = {
                type = 'toggle',
                name = L["OPT_OFF"],
                desc = L["OPT_OFF_DESC"],
                set = function(info) HHTD.db.global.Enabled = not HHTD:Disable(); return not HHTD.db.global.Enabled; end,
                get = function(info) return not HHTD:IsEnabled(); end,
                guiHidden = true,
                hidden = function() return not HHTD:IsEnabled(); end, 
                order = -1,
            },
            Debug = {
                type = 'toggle',
                name = L["OPT_DEBUG"],
                desc = L["OPT_DEBUG_DESC"],
                guiHidden = true,
                disabled = false,
                order = -2,
            },
            Version = {
                type = 'execute',
                name = L["OPT_VERSION"],
                desc = L["OPT_VERSION_DESC"],
                guiHidden = true,
                func = function () HHTD:Print(L["VERSION"], '@project-version@,', L["RELEASE_DATE"], '@project-date-iso@') end,
                order = -3,
            },
            core = {
                type = 'group',
                name =  L["OPT_CORE_OPTIONS"],
                order = 1,
                args = {
                    Info_Header = {
                        type = 'header',
                        name = L["VERSION"] .. ' @project-version@ -- ' .. L["RELEASE_DATE"] .. ' @project-date-iso@',
                        order = 1,
                    },
                    Pve = {
                        type = 'toggle',
                        name = L["OPT_PVE"],
                        desc = L["OPT_PVE_DESC"],
                        order = 200,
                    },
                    PvpHSpecsOnly = {
                        type = 'toggle',
                        name = L["OPT_PVPHEALERSSPECSONLY"],
                        desc = L["OPT_PVPHEALERSSPECSONLY_DESC"],
                        order = 300,
                    },
                    Modules = {
                        type = 'group',
                        name = L["OPT_MODULES"],
                        inline = true,
                        handler = {
                            ["hidden"]   = function () return not HHTD:IsEnabled(); end,
                            ["disabled"] = function () return not HHTD:IsEnabled(); end,

                            ["get"] = function (handler, info) return (HHTD:GetModule(info[#info])):IsEnabled(); end,
                            ["set"] = function (handler, info, value) 

                                HHTD.db.global.Modules[info[#info]].Enabled = value;
                                local result;

                                if value then
                                    result = HHTD:EnableModule(info[#info]);
                                    if result then
                                        HHTD:Print(info[#info], HHTD:ColorText(L["OPT_ON"], "FF00FF00"));
                                    end
                                else
                                    result = HHTD:DisableModule(info[#info]);
                                    if result then
                                        HHTD:Print(info[#info], HHTD:ColorText(L["OPT_OFF"], "FFFF0000"));
                                    end
                                end

                                return result;
                            end,
                        },
                        -- Enable-modules-check-boxes (filled by modules)
                        args = {},
                        order = 900,
                    },
                    Header1 = {
                        type = 'header',
                        name = '',
                        order = 400,
                    },
                    HFT = {
                        type = "range",
                        name = L["OPT_HEALER_FORGET_TIMER"],
                        desc = L["OPT_HEALER_FORGET_TIMER_DESC"],
                        min = 10,
                        max = 60 * 10,
                        step = 1,
                        bigStep = 5,
                        order = 500,
                    },
                    UHMHAP = {
                        type = "toggle",
                        name = L["OPT_USE_HEALER_MINIMUM_HEAL_AMOUNT"],
                        desc = L["OPT_USE_HEALER_MINIMUM_HEAL_AMOUNT_DESC"],
                        order = 600,
                    },
                    HMHAP = {
                        type = "range",
                        disabled = function() return not HHTD.db.global.UHMHAP or not HHTD:IsEnabled(); end,
                        name = function() return (L["OPT_HEALER_MINIMUM_HEAL_AMOUNT"]):format(HHTD:UpdateHealThreshold()) end,
                        desc = L["OPT_HEALER_MINIMUM_HEAL_AMOUNT_DESC"],
                        min = 0.01,
                        max = 3,
                        softMax = 1,
                        step = 0.01,
                        bigStep = 0.03,
                        order = 650,
                        isPercent = true,

                        set = function (info, value)
                            HHTD:SetHandler(HHTD, info, value);
                            HHTD:UpdateHealThreshold();
                        end,
                    },
                    Header1000 = {
                        type = 'header',
                        name = '',
                        order = 999,
                    },
                },
            },
        },
    };
    end -- }}}

    -- Used in Ace3 option table to get feedback when setting options through command line
    function HHTD:SetHandler (module, info, value)

        module.db.global[info[#info]] = value;

        if info["uiType"] == "cmd" then

            if value == true then
                value = L["OPT_ON"];
            elseif value == false then
                value = L["OPT_OFF"];
            end

            self:Print(HHTD:ColorText(HHTD:GetOPtionPath(info), "FF00DD00"), "=>", HHTD:ColorText(value, "FF3399EE"));
        end
    end
    

    local Enable_Module_CheckBox = {
        type = 'toggle',
        name = function (info) return L[info[#info]] end, -- it should be the localized module name
        desc = function (info) return L[info[#info] .. "_DESC"] end, 
        get = "get",
        set = "set",
        disabled = "disabled",
    };

    -- get the option tables feeding it with the core options and adding modules options
    function HHTD.GetOptions()
        local options = GetCoreOptions();

        -- Add modules enable/disable checkboxes
        for moduleName, module in HHTD:IterateModules() do
            if not options.args.core.args.Modules.args[moduleName] then
                options.args.core.args.Modules.args[moduleName] = Enable_Module_CheckBox;
            else
                error("HHTD: module name collision!");
            end
            -- Add modules specific options
            if module.GetOptions then
                if module:IsEnabled() then
                    if not options.plugins then options.plugins = {} end;
                    options.plugins[moduleName] = module:GetOptions();
                end
            end
        end

        return options;
    end
end


local DEFAULT__CONFIGURATION = {
    global = {
        Modules = {
            ['**'] = {
                Enabled = true, -- Modules are enabled by default
            },
        },
        HFT = 60,
        Enabled = true,
        Debug = false,
        Pve = true,
        PvpHSpecsOnly = true,
        UHMHAP = true,
        HMHAP = 0.05,
    },
};
-- }}}

-- = Add-on Management functions {{{
function HHTD:OnInitialize()

    self.db = LibStub("AceDB-3.0"):New("Healers_Have_To_Die", DEFAULT__CONFIGURATION);

    LibStub("AceConfig-3.0"):RegisterOptionsTable(tostring(self), self.GetOptions, {"HealersHaveToDie", "hhtd"});
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(tostring(self));
    
    self:RegisterChatCommand('hhtdg', function() LibStub("AceConfigDialog-3.0"):Open(tostring(self)) end, true);


    self:CreateClassColorTables();

    self:SetEnabledState(self.db.global.Enabled);

end

local PLAYER_FACTION = "";
function HHTD:OnEnable()

    REGISTER_HEALERS_ONLY_SPELLS_ONCE ();

    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", "TestUnit");
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "TestUnit");
    self:RegisterEvent("PLAYER_ALIVE"); -- talents SHOULD be available
    

    self:Print(L["ENABLED"]);

    self:SetModulesStates();

    PLAYER_FACTION = UnitFactionGroup("player");

end

function HHTD:PLAYER_ALIVE()
    self:Debug("PLAYER_ALIVE");

    PLAYER_FACTION = UnitFactionGroup("player");

    self:UnregisterEvent("PLAYER_ALIVE");
end

function HHTD:OnDisable()

    self:Print(L["DISABLED"]);

end
-- }}}

HHTD.HealThreshold = 0;
function HHTD:UpdateHealThreshold()
    if not self.db.global.UHMHAP then return end

    HHTD.HealThreshold = math.ceil(self.db.global.HMHAP * UnitHealthMax('player'));

    return HHTD.HealThreshold;
end


-- MouseOver and Target trigger {{{
do
    local LastDetectedGUID = "";
    local LastTasksRunTime = 0;
    function HHTD:TestUnit(eventName)

        local unit="";
        local pve = HHTD.db.global.Pve;

        if eventName=="UPDATE_MOUSEOVER_UNIT" then
            unit = "mouseover";
        elseif eventName=="PLAYER_TARGET_CHANGED" then
            unit = "target";
        else
            self:Print("called on invalid event");
            return;
        end

        local unitGuid = UnitGUID(unit);

        if not unitGuid then
            --self:Debug(WARNING, "No unit GUID");
            return;
        end

        local unitFirstName =  (UnitName(unit));

        if not pve and not UnitIsPlayer(unit) or UnitIsDead(unit) then
            self:SendMessage("HHTD_DROP_HEALER", unitFirstName)
            --self:Debug("not pve and not UnitIsPlayer(unit) or UnitIsDead(unit)"); -- XXX
            return;
        end

        if UnitFactionGroup(unit) == PLAYER_FACTION then
            self:SendMessage("HHTD_DROP_HEALER", unitFirstName)
            --self:Debug("UnitFactionGroup(unit) == PLAYER_FACTION"); -- XXX
            return;
        end

        if UnitIsUnit("mouseover", "target") then
            --self:Debug("UnitIsUnit(\"mouseover\", \"target\")"); -- XXX

            if self.Enemy_Healers[unitGuid] then
                self:SendMessage("HHTD_MOUSE_OVER_OR_TARGET", unit, unitGuid, unitFirstName);
            end

            return;
        elseif LastDetectedGUID == unitGuid and unit == "target" then
            self:SendMessage("HHTD_TARGET_LOCKED", unit, unitGuid, unitFirstName)
            --self:Debug("LastDetectedGUID == unitGuid and unit == \"target\""); -- XXX

            return;
        end

        local localizedUnitClass, unitClass = UnitClass(unit);

        if not unitClass then
            self:SendMessage("HHTD_DROP_HEALER", unitFirstName)
            self:Debug(WARNING, "No unit Class");
            return;
        end

        -- Is the unit class able to heal?
        if HHTD_C.Healing_Classes[unitClass] then

            -- Has the unit healed recently?
            if HHTD.Enemy_Healers[unitGuid] then
                -- Is this sitill true?
                if (GetTime() - HHTD.Enemy_Healers[unitGuid]) > HHTD.db.global.HFT then
                    -- else CLEANING

                    self:Debug(INFO2, self:UnitName(unit), " did not heal for more than", HHTD.db.global.HFT, ", removed.");

                    HHTD.Enemy_Healers[unitGuid] = nil;
                    HHTD.Enemy_Healers_By_Name[unitFirstName] = nil;

                    self:SendMessage("HHTD_DROP_HEALER", unitFirstName, unitGuid);
                else
                    self:SendMessage("HHTD_HEALER_UNDER_MOUSE", unit, unitGuid, unitFirstName, LastDetectedGUID);
                    --self:Debug("HHTD_HEALER_UNDER_MOUSE"); -- XXX
                    LastDetectedGUID = unitGuid;
                end
            else
                --self:Debug(INFO2, "did not heal");
                self:SendMessage("HHTD_MOUSE_OVER_OR_TARGET", unit, unitGuid, unitFirstName);
            end
        else
            -- self:Debug(WARNING, "Bad unit Class"); -- XXX
            self:SendMessage("HHTD_DROP_HEALER", unitFirstName, unitGuid);
            HHTD.Enemy_Healers_By_Name_Blacklist[unitFirstName] = GetTime();
        end


        if GetTime() - LastTasksRunTime > 60 then
            HHTD:Undertaker();
            HHTD:UpdateHealThreshold();
        end

    end
end -- }}}


-- Combat Event Listener (Main Healer Detection) {{{
do

    local bit       = _G.bit;
    local band      = _G.bit.band;
    local bor       = _G.bit.bor;
    local UnitGUID  = _G.UnitGUID;
    local sub       = _G.string.sub;
    local GetTime   = _G.GetTime;
    local str_match = _G.string.match;

    local FirstName = "";
    local time = 0;

    local NPC                   = COMBATLOG_OBJECT_CONTROL_NPC;
    local PET                   = COMBATLOG_OBJECT_TYPE_PET;
    local PLAYER                = COMBATLOG_OBJECT_TYPE_PLAYER;

--    local OUTSIDER              = COMBATLOG_OBJECT_AFFILIATION_OUTSIDER;
    local HOSTILE_OUTSIDER      = bit.bor (COMBATLOG_OBJECT_AFFILIATION_OUTSIDER, COMBATLOG_OBJECT_REACTION_HOSTILE);
--    local FRIENDLY_TARGET       = bit.bor (COMBATLOG_OBJECT_TARGET, COMBATLOG_OBJECT_REACTION_FRIENDLY);

    local HOSTILE_OUTSIDER_NPC  =  bit.bor (HOSTILE_OUTSIDER, COMBATLOG_OBJECT_TYPE_NPC);
    local HOSTILE_OUTSIDER_PLAYER = bit.bor (HOSTILE_OUTSIDER, COMBATLOG_OBJECT_TYPE_PLAYER);

    local ACCEPTABLE_TARGETS = bit.bor (PLAYER, NPC);

    local Source_Is_Hostile_NPC = false;
    local Source_Is_Hostile_Human = false;

    local isHealSpell = false;

    -- http://www.wowpedia.org/API_COMBAT_LOG_EVENT
    function HHTD:COMBAT_LOG_EVENT_UNFILTERED(e, timestamp, event, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, arg9, arg10 --[[ spellName --]], arg11, arg12 --[[ amount --]])

        -- escape if no source {{{
        -- untraceable events are useless
        if not sourceGUID then return end
        -- }}}

        local configRef = self.db.global; -- config shortcut

        -- Escape if bad target {{{
        -- Healers are only those caring for other players or NPC
        if band(destFlags, ACCEPTABLE_TARGETS) == 0 then
            --@debug@
            --[[
            if self.db.global.Debug and event:sub(-5) == "_HEAL" and sourceGUID ~= destGUID then
                self:Debug(INFO2, "Bad target", sourceName, destName);
            end
            --]]
            --@end-debug@
            return;
        end -- }}}

        Source_Is_Hostile_NPC = false;
        Source_Is_Hostile_Human = false;

        if band(sourceFlags, HOSTILE_OUTSIDER_NPC) == HOSTILE_OUTSIDER_NPC then
            Source_Is_Hostile_NPC = true;
        elseif band (sourceFlags, HOSTILE_OUTSIDER_PLAYER) == HOSTILE_OUTSIDER_PLAYER then
            Source_Is_Hostile_Human = true;
        end


        -- Escape if bad source {{{
        -- if the source is not a player and if while pve, the source is not an npc, then we don't care about this event
        -- ie we care if the source is a human player or pve is enaled and the source is an npc.
        --      not (a or (b and c)) ==  !a and (not b or not c)
        if not ( Source_Is_Hostile_Human or (configRef.Pve and Source_Is_Hostile_NPC)) then


            --@debug@
            --[[
            if  self.db.global.Debug then
                if  event:sub(-5) == "_HEAL" and sourceGUID ~= destGUID then
                    self:Debug(INFO2, "Bad heal source:", sourceName, "Dest:", destName, "pve:", configRef.Pve,
                    "HOSTILE_OUTSIDER_PLAYER:", band (sourceFlags, HOSTILE_OUTSIDER_PLAYER) == HOSTILE_OUTSIDER_PLAYER,
                    "HOSTILE_OUTSIDER_NPC:", band(sourceFlags, HOSTILE_OUTSIDER_NPC) == HOSTILE_OUTSIDER_NPC);
                end

                self:Debug(INFO2, "Bad source", sourceName, "Dest:", destName, "pve:", configRef.Pve,
                "HOSTILE_OUTSIDER_PLAYER:", band (sourceFlags, HOSTILE_OUTSIDER_PLAYER) == HOSTILE_OUTSIDER_PLAYER,
                "HOSTILE_OUTSIDER_NPC:", band(sourceFlags, HOSTILE_OUTSIDER_NPC) == HOSTILE_OUTSIDER_NPC);
            end
            --]]
            --@end-debug@

            return;
        end -- }}}

        -- Escape if Source_Is_Hostile_Human and scanning for pure healing specs and the spell doesn't match {{{
        if Source_Is_Hostile_Human and configRef.PvpHSpecsOnly and not HHTD_C.Healers_Only_Spells_ByName[arg10] then
            --@debug@
            self:Debug(INFO2, "Spell", arg10, "is not a healer' spell");
            --@end-debug@
            return;
        end -- }}}

        if event:sub(-5) == "_HEAL" and sourceGUID ~= destGUID then
            isHealSpell = true;
        else
            isHealSpell = false;
        end

         -- Escape if not a heal spell and (not checking for spec's spells or source is a NPC) {{{
         -- we look for healing spells directed to others
         if not isHealSpell and (not configRef.PvpHSpecsOnly or Source_Is_Hostile_NPC) then
             return false;
         end -- }}}

         -- if we are still here it means that this is a HEAL toward another
         -- player or an ability available to specialized healers only

         -- get source name
         if sourceName then
             FirstName = str_match(sourceName, "^[^-]+"); -- sourceName may be nil??
         else
             self:Print("|cFFFF0000NO NAME for GUID:", sourceGUID);
             return;
         end

        -- Escape if player got blacklisted has not a healer {{{
        -- Only if the unit class can heal - not post-blacklisted
        if self.Enemy_Healers_By_Name_Blacklist[FirstName] then
            self:Debug(INFO2, FirstName, " was blacklisted");
            return;
        end -- }}}

         -- If checking for minimum heal amount
         if isHealSpell and configRef.UHMHAP then
             -- store Heal score
             if not self.Total_Heal_By_Name[FirstName] then
                 self.Total_Heal_By_Name[FirstName] = 0;
             end
             self.Total_Heal_By_Name[FirstName] = self.Total_Heal_By_Name[FirstName] + arg12;

             -- Escape if below minimum healing {{{
             if self.Total_Heal_By_Name[FirstName] < HHTD.HealThreshold then
                 self:Debug(INFO2, FirstName, "is below minimum healing amount:", self.Total_Heal_By_Name[FirstName]);
                 return;
             end -- }}}
         end

         time = GetTime();

         -- useless to continue past this point if we just saw the healer
         if self.Enemy_Healers[sourceGUID] and time - self.Enemy_Healers[sourceGUID] < 5 then
             self:Debug(INFO2, "Throtelling heal events for", FirstName);
             return
         end

         -- by GUID
         self.Enemy_Healers[sourceGUID] = time
         -- by Name
         self.Enemy_Healers_By_Name[FirstName] = self.Enemy_Healers[sourceGUID];
         -- update plate
         self:Debug(INFO, "Healer detected:", FirstName);
         self:SendMessage("HHTD_HEALER_DETECTED", FirstName, sourceGUID);

         self:Undertaker();
         -- TODO for GEHR: make activity light blink

     end
 end -- }}}

 -- Undertaker {{{
 local LastCleaned = 0;
 local LastBlackListCleaned = 0;
 local Time = 0;
 -- The Undertaker will garbage collect healers who have not been healing recently (whatever the reason...)
 function HHTD:Undertaker()

     Time = GetTime();
     -- if (Time - LastCleaned) < 60 then return end -- no need to run this cleaning more than once per minute

     self:Debug(INFO2, "cleaning...");

     -- clean enemy healers GUID
     for guid, lastHeal in pairs(self.Enemy_Healers) do
         if (Time - lastHeal) > self.db.global.HFT then
             self.Enemy_Healers[guid] = nil;

             self:Debug(INFO2, guid, "removed");
         end
     end

     -- clean enemy healers Name
     for healerName, lastHeal in pairs(self.Enemy_Healers_By_Name) do
         if (Time - lastHeal) > self.db.global.HFT then
             self.Enemy_Healers_By_Name[healerName] = nil;
             self.Total_Heal_By_Name[healerName] = nil;

             self:SendMessage("HHTD_DROP_HEALER", healerName)

             self:Debug(INFO2, healerName, "removed");
         end
     end

     LastCleaned = Time;

     -- clean player class blacklist
     if (Time - LastBlackListCleaned) < 3600 then return end

     for Name, LastSeen in pairs(self.Enemy_Healers_By_Name_Blacklist) do

         if (Time - LastSeen) > self.db.global.HFT then
             self.Enemy_Healers_By_Name_Blacklist[Name] = nil;

             self:Debug(INFO2, Name, "removed from class blacklist");
         end
     end


     LastBlackListCleaned = Time;

 end -- }}}

 --[=[
 (post by zalgorr on HHTD curse.com' comments page (2011-01-24)


 =============For priests:

 -Penance : HEAL : http://www.wowhead.com/spell=47540
 -Holy Word: Chastise -- http://www.wowhead.com/spell=88625  (damage spell)
 -Holy Word: Serenity -- HEAL : http://www.wowhead.com/spell=88684
 -Holy Word: Sanctuary -- MASS HEAL : http://www.wowhead.com/spell=88685
 -Inner Focus -- (not heal but increases heal) : http://www.wowhead.com/spell=89485
 -Power Infusion -- target enhancer : http://www.wowhead.com/spell=10060
 -Pain Suppression -- target enhancer : http://www.wowhead.com/spell=33206
 -Power Word: Barrier -- mass target enhancer : http://www.wowhead.com/spell=62618
 -Lightwell -- mass target enhancer : http://www.wowhead.com/spell=724
 -Chakra -- heal increase : http://www.wowhead.com/spell=14751
 -Circle of Healing -- mass heal : http://www.wowhead.com/spell=34861
 -Guardian Spirit -- target heal enhancer : http://www.wowhead.com/spell=47788

 =================For a druid:
 -Swiftmend           : HEAL : http://www.wowhead.com/spell=18562
 -Nature's Swiftness  : HEAL : http://www.wowhead.com/spell=17116
 -Wild Growth         : MASS HEAL : http://www.wowhead.com/spell=48438
 -Tree of Life        : not an actual spell (shape shift) : http://www.wowhead.com/spell=33891

 ====================Shaman:
 Earth Shield : enhancer, heals on target actions : http://www.wowhead.com/spell=974
 Nature's Swiftness : healer helper : http://www.wowhead.com/spell=17116
 Mana Tide Totem : healer helper (spirit) : http://www.wowhead.com/spell=16190
 Riptide : HEAL : http://www.wowhead.com/spell=61295

 ====================Paladin:
 Holy Shock : HEAL/DAMMAGE : http://www.wowhead.com/spell=20473
 Divine Favor : healer helper : http://www.wowhead.com/spell=31842
 Beacon of Light : heal : http://www.wowhead.com/spell=53563
 Aura Mastery : friends enhancer : http://www.wowhead.com/spell=31821
 Light of Dawn : mass heal : http://www.wowhead.com/spell=85222


 --]=]
