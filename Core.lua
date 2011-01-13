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
--  globale                       == NAME__WORD2
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
        childGroups = 'tab',
        name = "Healers Have To Die",
        args = {
            core = {
                type = 'group',
                name =  L["OPT_CORE_OPTIONS"],
                order = 1,
                args = {
                    Version_Header = {
                        type = 'header',
                        name = L["VERSION"] .. ' @project-version@',
                        order = 1,
                    },
                    Release_Date_Header = {
                        type = 'header',
                        name = L["RELEASE_DATE"] .. ' @project-date-iso@',
                        order = 2,
                    },
                    On = {
                        type = 'toggle',
                        name = L["OPT_ON"],
                        desc = L["OPT_ON_DESC"],
                        set = function(info) HHTD.db.global.Enabled = HHTD:Enable(); return HHTD.db.global.Enabled; end,
                        get = function(info) return HHTD:IsEnabled(); end,
                        order = 10,
                    },
                    Off = {
                        type = 'toggle',
                        name = L["OPT_OFF"],
                        desc = L["OPT_OFF_DESC"],
                        set = function(info) HHTD.db.global.Enabled = not HHTD:Disable(); return not HHTD.db.global.Enabled; end,
                        get = function(info) return not HHTD:IsEnabled(); end,
                        order = 20,
                    },
                    Pve = {
                        type = 'toggle',
                        name = L["OPT_PVE"],
                        desc = L["OPT_PVE_DESC"],
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
                    },
                    Header1 = {
                        type = 'header',
                        name = '',
                        order = 25,
                    },
                    HFT = {
                        type = "range",
                        name = L["OPT_HEALER_FORGET_TIMER"],
                        desc = L["OPT_HEALER_FORGET_TIMER_DESC"],
                        min = 10,
                        max = 60 * 10,
                        step = 1,
                        bigStep = 5,
                        order = 30,
                    },
                    Header1000 = {
                        type = 'header',
                        name = '',
                        order = 999,
                    },
                    Debug = {
                        type = 'toggle',
                        name = L["OPT_DEBUG"],
                        desc = L["OPT_DEBUG_DESC"],
                        order = 1000,
                    },
                    Version = {
                        type = 'execute',
                        name = L["OPT_VERSION"],
                        desc = L["OPT_VERSION_DESC"],
                        guiHidden = true,
                        func = function () HHTD:Print(L["VERSION"], '@project-version@,', L["RELEASE_DATE"], '@project-date-iso@') end,
                        order = 1010,
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
    }
};
-- }}}

-- = Add-on Management functions {{{
function HHTD:OnInitialize()

    self.db = LibStub("AceDB-3.0"):New("Healers_Have_To_Die", DEFAULT__CONFIGURATION);

    LibStub("AceConfig-3.0"):RegisterOptionsTable(tostring(self), self.GetOptions, {"HealersHaveToDie", "hhtd"});
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(tostring(self));
    


    self:CreateClassColorTables();

    self:SetEnabledState(self.db.global.Enabled);

end

local PLAYER_FACTION = "";
function HHTD:OnEnable()

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


-- MouseOver and Target trigger {{{
do
    local LastDetectedGUID = "";
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

        local unitGuid = UnitGUID(unit);

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

        if not unitGuid then
            self:Debug(WARNING, "No unit GUID");
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
                self:Debug(INFO2, "did not heal");
                self:SendMessage("HHTD_MOUSE_OVER_OR_TARGET", unit, unitGuid, unitFirstName);
            end
        else
            -- self:Debug(WARNING, "Bad unit Class"); -- XXX
            self:SendMessage("HHTD_DROP_HEALER", unitFirstName, unitGuid);
            HHTD.Enemy_Healers_By_Name_Blacklist[unitFirstName] = GetTime();
        end

        HHTD:Undertaker();
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


    -- http://www.wowwiki.com/API_COMBAT_LOG_EVENT
    function HHTD:COMBAT_LOG_EVENT_UNFILTERED(e, timestamp, event, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, arg9, arg10, arg11, arg12)

        if not sourceGUID then return end


        -- Healers are only those caring for other players or NPC
        if band(destFlags, ACCEPTABLE_TARGETS) == 0 then
            if self.db.global.Debug and event:sub(-5) == "_HEAL" and sourceGUID ~= destGUID then
                self:Debug(INFO2, "Bad target", sourceName, destName);
            end
            return;
        end

        local pve = self.db.global.Pve;

        -- the healer is not a player or, if pve enabled a NPC
        if not pve and band (sourceFlags, HOSTILE_OUTSIDER_PLAYER) ~= HOSTILE_OUTSIDER_PLAYER or band(sourceFlags, HOSTILE_OUTSIDER_NPC) ~= HOSTILE_OUTSIDER_NPC then
            if  self.db.global.Debug and event:sub(-5) == "_HEAL" and sourceGUID ~= destGUID then
                self:Debug(INFO2, "Bad source", sourceName, destName, pve);
            end
            return;
        end

        -- we look for healing events directed to others
        if event:sub(-5) == "_HEAL" and sourceGUID ~= destGUID then


            FirstName = str_match(sourceName, "^[^-]+");

            -- Only if the unit class can heal
            if not self.Enemy_Healers_By_Name_Blacklist[FirstName] then
                time = GetTime();

                if self.Enemy_Healers[sourceGUID] and time - self.Enemy_Healers[sourceGUID] < 5 then
                    self:Debug(WARNING, "Throtelling heal events for", FirstName);
                    return
                end

                -- by GUID
                self.Enemy_Healers[sourceGUID] = time
                -- by Name
                self.Enemy_Healers_By_Name[FirstName] = self.Enemy_Healers[sourceGUID];
                -- update plate
                self:Debug(INFO, "Healer detected:", FirstName);
                self:SendMessage("HHTD_HEALER_DETECTED", FirstName, sourceGUID);

                HHTD:Undertaker();
                -- TODO for GEHR: make activity light blink

            end
        end
    end
end -- }}}

-- Undertaker {{{
local LastCleaned = 0;
local LastBlackListCleaned = 0;
local Time = 0;
-- The Undertaker will garbage collect healers who have not been healing recently (whatever the reason...)
function HHTD:Undertaker()

    Time = GetTime();
    if (Time - LastCleaned) < 60 then return end -- no need to run this cleaning more than once per minute

    self:Debug(INFO2, "cleaning...");

    -- clean enemy healers GUID
    for guid, lastHeal in pairs(HHTD.Enemy_Healers) do
        if (Time - lastHeal) > HHTD.db.global.HFT then
            HHTD.Enemy_Healers[guid] = nil;

            self:Debug(INFO2, guid, "removed");
        end
    end

    -- clean enemy healers Name
    for healerName, lastHeal in pairs(HHTD.Enemy_Healers_By_Name) do
        if (Time - lastHeal) > HHTD.db.global.HFT then
            HHTD.Enemy_Healers_By_Name[healerName] = nil;

            self:SendMessage("HHTD_DROP_HEALER", healerName)

            self:Debug(INFO2, healerName, "removed");
        end
    end

    LastCleaned = Time;

    -- clean player class blacklist
    if (Time - LastBlackListCleaned) < 3600 then return end

    for Name, LastSeen in pairs(HHTD.Enemy_Healers_By_Name_Blacklist) do

        if (Time - LastSeen) > HHTD.db.global.HFT then
            HHTD.Enemy_Healers_By_Name_Blacklist[Name] = nil;

            self:Debug(INFO2, Name, "removed from class blacklist");
        end
    end


    LastBlackListCleaned = Time;

end -- }}}


