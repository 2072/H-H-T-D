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

local _, _, _, tocversion = GetBuildInfo();
T._tocversion = tocversion;

-- === Add-on basics and variable declarations {{{
T.Healers_Have_To_Die = LibStub("AceAddon-3.0"):NewAddon("Healers Have To Die", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0");
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

-- The header for HHTD key bindings
BINDING_HEADER_HHTD = "Healers Have To Die";
BINDING_NAME_HHTDP = L["OPT_POST_ANNOUNCE_ENABLE"];



HHTD.Friendly_Healers_Attacked_by_GUID = {};

HHTD.LOGS = {
    [true] = {}, -- [guid] = healer_log_template
    [false] = {}, -- [guid] = healer_log_template
};


--[=[
local healer_template = {
    guid        = "",
    name        = "unknown",
    isUnique    = true,
    isTrueHeal  = false,
    isHuman     = true,
    healDone    = 0,
    rank        = -1,
    _lastSort    = 0,
};
--]=]

HHTD.Registry_by_GUID = {
    [true] = {}, -- [guid] = healer_template
    [false] = {}, -- [guid] = healer_template
}

HHTD.Registry_by_Name = {
    [true] = {}, -- [name] = healer_template
    [false] = {}, -- [name] = healer_template
}

function HHTD:HHTD_HEALER_GONE(selfevent, isFriend, healer)

    self.Friendly_Healers_Attacked_by_GUID[healer.guid] = nil;
    self.Registry_by_GUID[isFriend][healer.guid]        = nil;
    self.Registry_by_Name[isFriend][healer.name]        = nil;

    -- test if there are others with the same name... *sigh* this sucks
    for guid, healerRecord in pairs (self.Registry_by_GUID[isFriend]) do

        if healerRecord.name == healer.name then
            self.Registry_by_Name[isFriend][healer.name] = healerRecord;

            self:Debug(INFO, "replaced record for", healer.name);

            break;
        end

    end

end

local UnitInRaid                = _G.UnitInRaid;
local UnitInParty               = _G.UnitInParty;
local UnitSetRole               = _G.UnitSetRole;
local UnitGroupRolesAssigned    = _G.UnitGroupRolesAssigned;

function HHTD:HHTD_HEALER_BORN(selfevent, isFriend, healer)

    self:Debug(INFO, "HHTD:HHTD_HEALER_BORN()");

    HHTD.Registry_by_GUID[isFriend][healer.guid] = healer;
    HHTD.Registry_by_Name[isFriend][healer.name] = healer;

    -- if the player is human and friendly and is part of our group, set his/her role to HEALER
    if self.db.global.SetFriendlyHealersRole then

        if isFriend and healer.isHuman and (UnitInRaid(healer.fullName) or UnitInParty(healer.fullName)) and UnitGroupRolesAssigned(healer.fullName) == 'NONE' then
            if (select(2, GetRaidRosterInfo(UnitInRaid("player") or 1))) > 0 then
                self:Debug(INFO, "Setting role to HEALER for", healer.fullName);
                UnitSetRole(healer.fullName, 'HEALER');
            end
        end

    end 

end


-- local function REGISTER_HEALERS_ONLY_SPELLS_ONCE () -- {{{
local function REGISTER_HEALERS_ONLY_SPELLS_ONCE ()

    if HHTD_C.Healers_Only_Spells_ByName then
        return;
    end

    local Healers_Only_Spells_ByID = {

        -- Priests
        [47540] = "PRIEST", -- Penance
        [88625] = "PRIEST", -- Holy Word: Chastise
        [88684] = "PRIEST", -- Holy Word: Serenity
        [88685] = "PRIEST", -- Holy Word: Sanctuary
        [89485] = "PRIEST", -- Inner Focus
        [10060] = "PRIEST", -- Power Infusion
        [33206] = "PRIEST", -- Pain Suppression
        [62618] = "PRIEST", -- Power Word: Barrier
        [724]   = "PRIEST",   -- Lightwell
        [14751] = "PRIEST", -- Chakra
        [34861] = "PRIEST", -- Circle of Healing
        [47788] = "PRIEST", -- Guardian Spirit

        -- Druids
        [18562] = "DRUID", -- Swiftmend
        [17116] = "DRUID", -- Nature's Swiftness
        [48438] = "DRUID", -- Wild Growth
        [33891] = "DRUID", -- Tree of Life

        -- Shamans
        [974]   = "SHAMAN", -- Earth Shield
        [17116] = "SHAMAN", -- Nature's Swiftness
        [16190] = "SHAMAN", -- Mana Tide Totem
        [61295] = "SHAMAN", -- Riptide

        -- Paladins
        [20473] = "PALADIN", -- Holy Shock
        [31842] = "PALADIN", -- Divine Favor
        [53563] = "PALADIN", -- Beacon of Light
        [31821] = "PALADIN", -- Aura Mastery
        [85222] = "PALADIN", -- Light of Dawn
    };

    HHTD_C.Healers_Only_Spells_ByName = {};

    for spellID, class in pairs(Healers_Only_Spells_ByID) do

        if (GetSpellInfo(spellID)) then
            HHTD_C.Healers_Only_Spells_ByName[(GetSpellInfo(spellID))] = class;
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

    Error = function(self, m) HHTD.Error (self, m) end,

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
local GetTime           = _G.GetTime;
local PlaySoundFile     = _G.PlaySoundFile;
local pairs             = _G.pairs;
local ipairs            = _G.ipairs;
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

    local AceOptionAntiSupidity = 0;
    local FormattedLogs = "";

    local function FormatLogs()

        if GetTime() - AceOptionAntiSupidity < 0.1 then
            HHTD:Debug(INFO, "AceOption is stupid");
            return FormattedLogs;
        else
            AceOptionAntiSupidity = GetTime();
        end

        local output        = "";

        for _, isFriend in ipairs({false,true}) do

            local tmp           = {};

            for guid, log in HHTD:pairs_ordered(HHTD.LOGS[isFriend], true, 'healDone') do

                local isActive = HHTD.Registry_by_GUID[isFriend][guid];

                local spellsStats = {}
                local j = 1;

                for spell, spellcount in HHTD:pairs_ordered(log.spells, true) do
                    spellsStats[j] = ("    %s (|cFFAA0000%d|r)"):format(HHTD:ColorText(spell, HHTD_C.Healers_Only_Spells_ByName[spell] and "FFC000C0" or "FFC0C0C0"), spellcount);
                    j = j + 1;
                end

                tmp[#tmp + 1] = ("%s (|cff00dd00%s|r)%s [|cffbbbbbb%s|r]:  %s\n%s\n"):format(
                (HHTD:ColorText("#(%s)|r %q", log.isFriend and "FF00FF00" or "FFFF0000")):format(isActive and isActive.rank or '-', HHTD:ColorText(log.name, log.isTrueHeal and HHTD:GetClassHexColor(log.isTrueHeal) or "FFAAAAAA" )),
                tostring(log.healDone > 0 and log.healDone or L["NO_DATA"]),
                log.healDone > HHTD.HealThreshold and "" or L["LOG_BELOW_THRESHOLD"],
                log.isHuman and L["HUMAN"] or L["NPC"],
                HHTD:ColorText(isActive and L["LOG_ACTIVE"] or L["LOG_IDLE"], isActive and "FF00EE00" or "FFEE0000"),
                table.concat(spellsStats, '\n')
                );

            end

            output = output .. table.concat(tmp, '\n') .. '\n';

        end

        FormattedLogs = output;
        return output;
    end


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
                order = -5,
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
                    testOnTarget = {
                        type = 'execute',
                        name = L["OPT_TESTONTARGET"],
                        desc = L["OPT_TESTONTARGET_DESC"],
                        func = function ()
                            if (UnitGUID("target")) then
                                HHTD:MakeDummyEvent("target");
                            else
                                HHTD:Print( L["OPT_TESTONTARGET_ENOTARGET"] );
                            end

                        end,
                        order = 350,
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
                    SetFriendlyHealersRole = {
                        type = 'toggle',
                        name = L["OPT_SET_FRIENDLY_HEALERS_ROLE"],
                        desc = L["OPT_SET_FRIENDLY_HEALERS_ROLE_DESC"],
                        order = 660,
                    },
                    HealerUnderAttackAlerts = {
                        type = 'toggle',
                        name = L["OPT_HEALER_UNDER_ATTACK_ALERTS"],
                        desc = L["OPT_HEALER_UNDER_ATTACK_ALERTS_DESC"],
                        order = 670,
                    },
                    Log = {
                        type = 'toggle',
                        name = L["OPT_LOG"],
                        desc = L["OPT_LOG_DESC"],
                        disabled = false,
                        order = 700,
                    },
                    Header1000 = {
                        type = 'header',
                        name = '',
                        order = 999,
                    },
                },
            },
            Logs = {
                type = 'group',
                name =  L["OPT_LOGS"],
                desc = L["OPT_LOGS_DESC"],
                order = -1,
                hidden = function() return not HHTD.db.global.Log end,
                args = {
                    clear = {
                        type = 'execute',
                        name = L["OPT_CLEAR_LOGS"],
                        confirm = true,
                        func = function () 
                            HHTD.LOGS[true]  = {};
                            HHTD.LOGS[false] = {};
                        end,
                        order = 0,

                    },
                    AccusationFacts = { -- {{{
                        type = 'description',
                        name = FormatLogs,
                        order = 1,
                    }, -- }}}
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
        Log = false,
        Pve = true,
        PvpHSpecsOnly = true,
        UHMHAP = true,
        HMHAP = 0.05,
        SetFriendlyHealersRole = true,
        HealerUnderAttackAlerts = true,
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
    -- self:RegisterEvent("PARTY_MEMBER_DISABLE"); -- useless event, no argument...
    
    -- Subscribe to our own callbacks
    self:RegisterMessage("HHTD_HEALER_GONE");
    self:RegisterMessage("HHTD_HEALER_BORN");

    self:Print(L["ENABLED"]);

    self:SetModulesStates();

    PLAYER_FACTION = UnitFactionGroup("player");

    self:ScheduleRepeatingTimer(self.Undertaker,          10, self);
    self:ScheduleRepeatingTimer(self.UpdateHealThreshold, 50, self);

end

function HHTD:PLAYER_ALIVE()
    self:Debug("PLAYER_ALIVE");

    PLAYER_FACTION = UnitFactionGroup("player");

    self:UnregisterEvent("PLAYER_ALIVE");
end

function HHTD:PARTY_MEMBER_DISABLE(e, unit)
    self:Debug(INFO2, "PARTY_MEMBER_DISABLE:", unit);
end

function HHTD:OnDisable()

    self:Print(L["DISABLED"]);

end
-- }}}

HHTD.HealThreshold = 0;
function HHTD:UpdateHealThreshold()
    if not self.db.global.UHMHAP then return 0 end

    self.HealThreshold = math.ceil(self.db.global.HMHAP * UnitHealthMax('player'));

    return self.HealThreshold;
end


-- MouseOver and Target trigger {{{
do
    local LastDetectedGUID = "";
    function HHTD:TestUnit(eventName) -- XXX to check/rewrite

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
        local isFriend = UnitIsFriend(unit, 'player')==1 and true or false;

        --self:Debug(INFO, "HHTD:TestUnit()", unitGuid, isFriend);

        if not unitGuid then
            --self:Debug(WARNING, "No unit GUID");
            return;
        end

        local unitFirstName, unitRealm = UnitName(unit);

        if HHTD.Registry_by_GUID[isFriend][unitGuid] then

            -- remove dead units
            if UnitIsDead(unit) then
                self:Reap(unitGuid, isFriend, true);
                return;
            end

            if LastDetectedGUID == unitGuid and unit == "target" then
                self:SendMessage("HHTD_TARGET_LOCKED", isFriend, HHTD.Registry_by_GUID[isFriend][unitGuid]);
                --self:Debug("LastDetectedGUID == unitGuid and unit == \"target\""); -- XXX

                return;
            end

            -- Has the unit healed recently?
            if not UnitIsUnit("mouseover", "target") and unit == "mouseover" then
                -- Is this sitill true?

                self:SendMessage("HHTD_HEALER_MOUSE_OVER", isFriend, HHTD.Registry_by_GUID[isFriend][unitGuid]);
                --self:Debug("HHTD_HEALER_UNDER_MOUSE"); -- XXX
                LastDetectedGUID = unitGuid;
            end
        end
        
    end
end -- }}}


do

    --up values
    
    local str_match                 = _G.string.match;
    local GetTime                   = _G.GetTime;

    local pairs                     = _G.pairs;
    local ipairs                    = _G.ipairs;
    local TableWipe                 = _G.table.wipe;
    local TableSort                 = _G.table.sort;


    -- Healer management {{{


    local ReapSchedulers = {};

    local Private_registry_by_GUID = {
        [true] = {}, -- [guid] = healer_template
        [false] = {}, -- [guid] = healer_template
    }

    local Private_registry_by_Name = {
        [true] = {}, -- [name] = healer_template
        [false] = {}, -- [name] = healer_template
    }

    local HealerPool;
    local function sortHealerCallBack(a, b)
        if HealerPool[a].healDone > HealerPool[b].healDone then
            return true;
        else
            return false;
        end
    end

    local SortingTray = {};

    local function UpdateRanks(healerPool)

        HealerPool = healerPool;

        TableWipe(SortingTray);

        for guid in pairs (healerPool) do
            SortingTray[#SortingTray + 1] = guid;
        end

        TableSort(SortingTray, sortHealerCallBack);

        for i, guid in ipairs (SortingTray) do
            healerPool[guid].rank = i;
        end
    end


    local ReapFriend = {
        [true] = function(guid) HHTD:Reap(guid, true); end,
        [false] = function(guid) HHTD:Reap(guid, false); end,
    };

    local function ApointReaper(guid, isFriend, lifespan)
        if ReapSchedulers[guid] then
            HHTD:CancelTimer(ReapSchedulers[guid]);
        end

        -- Take an apointment with the reaper
        ReapSchedulers[guid] = HHTD:ScheduleTimer(ReapFriend[isFriend], lifespan, guid);
        HHTD:Debug(INFO, "A reap is scheduled in", lifespan, "seconds");
    end

    -- send them to oblivion
    function HHTD:Reap (guid, isFriend, force)

        local corpse = Private_registry_by_GUID[isFriend][guid]; -- keep it safe for autopsy

        if not corpse then
            self:Debug(ERROR, ":Reap() called on non-monitored unit:", guid, isFriend, force);
            return;
        end

        if force then
            HHTD:CancelTimer(ReapSchedulers[guid]);
        end

        if GetTime() - corpse.lastMove > self.db.global.HFT or force then

            -- remove the scheduler id that brought us here
            ReapSchedulers[guid]                            = nil;
            -- clean the mess
            Private_registry_by_GUID[isFriend][guid]        = nil;
            Private_registry_by_Name[isFriend][corpse.name] = nil;

            -- announce the (un)timely departure of this healer and expose the corpse for all to see
            self:SendMessage("HHTD_HEALER_GONE", isFriend, corpse);
            self:Debug(INFO2, corpse.name, "reaped");
        else
            ApointReaper(guid, isFriend, self.db.global.HFT - (GetTime() - corpse.lastMove) + 1);
            self:Debug(INFO2, corpse.name, "is still kicking");
        end
    end

    

    -- Neatly add them to our little registry and keep an eye on them
    local record, name;
    local function RegisterHealer (time, isFriend, guid, sourceName, isHuman, spellName, isHealSpell, healDone, configRef) -- {{{

        -- this is a new one, let's create a birth certificate
        if not Private_registry_by_GUID[isFriend][guid] then

            if sourceName then
                name = str_match(sourceName, "^[^-]+");
            else
                -- XXX fatal error out
                HHTD:Debug(WARNING, "RegisterHealer(): sourceName is missing and healer is new", guid);
                return;
            end

            local isUnique;

            if Private_registry_by_Name[isFriend][name] then
                isUnique = false;
            else
                isUnique = true;
            end

            record = {
                guid        = guid,
                name        = name,
                fullName    = sourceName,
                isUnique    = isUnique,
                isTrueHeal  = false, -- updated later
                isHuman     = isHuman,
                healDone    =  0, -- updated later
                rank        = -1, -- updated later
                _lastSort   =  0, -- updated later
                lastMove  =  0, -- updated later
            };

            Private_registry_by_GUID[isFriend][guid] = record;
            Private_registry_by_Name[isFriend][name] = record;

            ApointReaper(guid, isFriend, configRef.HFT);

        else
            -- fetch the existing record
            record = Private_registry_by_GUID[isFriend][guid];
        end

        if isHealSpell then
            -- set/update heal done
            record.healDone = record.healDone + healDone;
        end

        record.lastMove = time;

        -- detect a true healer
        if not record.isTrueHeal then
            record.isTrueHeal = HHTD_C.Healers_Only_Spells_ByName[spellName];
        end

        if configRef.Log then -- {{{
            -- also log and keep track of used spells here if option is set
            -- keep in mind that logging can be enabled once a healer has already been registered
            local log;

            if not HHTD.LOGS[isFriend][guid] then
                log = {
                    guid        = guid,
                    name        = name,
                    spells      = {},
                    healDone    = 0,
                    isTrueHeal  = false,
                    isFriend    = isFriend,
                    isHuman     = isHuman,
                };

                HHTD.LOGS[isFriend][guid] = log;
            else
                log = HHTD.LOGS[isFriend][guid];
            end

            if isHealSpell then
                log.healDone = log.healDone + healDone;
            end

            if not log.isTrueHeal then
                log.isTrueHeal  = record.isTrueHeal;
            end

            if not log.spells[spellName] then
                log.spells[spellName] = 1;
            else
                log.spells[spellName] = log.spells[spellName] + 1;
            end

        end -- }}}

        if configRef.UHMHAP and record.healDone < HHTD.HealThreshold then
            HHTD:Debug(INFO2, sourceName, "is below minimum healed amount:", record.healDone);
            return;
        end

        -- Time-consuming operations every 5 seconds minimum
        if time - record._lastSort > 5 then

            record._lastSort = time;

            -- update the ranks of this healer's side, good or evil
            UpdateRanks(Private_registry_by_GUID[isFriend]);

            if not HHTD.Registry_by_GUID[isFriend][guid] then
                -- Dispatch the news
                HHTD:Debug(INFO, "Healer detected:", sourceName);
                HHTD:SendMessage("HHTD_HEALER_BORN", isFriend, record);
            end

            HHTD:SendMessage("HHTD_HEALER_GROW", isFriend, record);
        end

    end -- }}}

    -- }}}



    -- Combat Event Listener (Main Healer Detection) {{{

    local band                      = _G.bit.band;
    local sub                       = _G.string.sub;
    local CheckInteractDistance     = _G.CheckInteractDistance;

    local HOSTILE_OUTSIDER          = bit.bor (COMBATLOG_OBJECT_AFFILIATION_OUTSIDER, COMBATLOG_OBJECT_REACTION_HOSTILE);
    local HOSTILE                   = COMBATLOG_OBJECT_REACTION_HOSTILE;
    local FRIENDLY                  = COMBATLOG_OBJECT_REACTION_FRIENDLY;

    local HOSTILE_OUTSIDER_NPC      = bit.bor (HOSTILE_OUTSIDER                     , COMBATLOG_OBJECT_TYPE_NPC);
    local FRIENDLY_NPC              = bit.bor (COMBATLOG_OBJECT_REACTION_FRIENDLY   , COMBATLOG_OBJECT_TYPE_NPC);
    local HOSTILE_OUTSIDER_PLAYER   = bit.bor (HOSTILE_OUTSIDER                     , COMBATLOG_OBJECT_TYPE_PLAYER);
    local FRIENDLY_PLAYER           = bit.bor (COMBATLOG_OBJECT_REACTION_FRIENDLY   , COMBATLOG_OBJECT_TYPE_PLAYER);

    local ACCEPTABLE_TARGETS = bit.bor (COMBATLOG_OBJECT_TYPE_PLAYER, COMBATLOG_OBJECT_TYPE_NPC);

    local Source_Is_NPC = false;
    local Source_Is_Human = false;
    local Source_Is_Friendly = false;

    local isHealSpell = false;

    local Registry_by_GUID = HHTD.Registry_by_GUID;


    local registered;


    function HHTD:MakeDummyEvent(unit)
        --local flags = 0, destName = 'TestUnit', destGUID = 'TestGuid', destFlags = 0;
        local flags, destName, destGUID  = 0, 'TestUnit', 'TestGuid';

        if UnitIsPlayer(unit) then
            if UnitIsFriend(unit, 'player') then
                self:Debug(INFO, "target is a friendly player");
                flags = FRIENDLY_PLAYER;
                --destName = (UnitName('player'));
                --destGUID = UnitGUID('player');
                --destFlags = FRIENDLY_PLAYER;
            else
                flags = HOSTILE_OUTSIDER_PLAYER;
                self:Debug(INFO, "target is a hostile player");
            end
        else
            if UnitIsFriend(unit, 'player') then
                self:Debug(INFO, "target is a friendly NPC");
                flags = FRIENDLY_NPC;
            else
                flags = HOSTILE_OUTSIDER_NPC;
                self:Debug(INFO, "target is a hostile NPC");
            end
        end

        self:COMBAT_LOG_EVENT_UNFILTERED(nil, 0, "DUMMY_HEAL", false, UnitGUID(unit), (UnitName(unit)), flags, 0, destGUID, destName, flags, 0, 0, (GetSpellInfo(33891)), "", HHTD.HealThreshold + 1);
    end

    -- http://www.wowpedia.org/API_COMBAT_LOG_EVENT
    function HHTD:COMBAT_LOG_EVENT_UNFILTERED(e, timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, _spellID, spellNAME, _spellSCHOOL, healAMOUNT)
 
        --@debug@
        if hideCaster then
            --self:Debug(e, timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, _spellID, spellNAME, _spellSCHOOL, healAMOUNT);
        end
        --@end-debug@


        -- escape if no source {{{
        -- untraceable events are useless
        if not sourceGUID or hideCaster then return end
        -- }}}

        -- Escape if bad target (not human nor npc) {{{
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

        local configRef = self.db.global; -- config shortcut

        Source_Is_NPC = false;
        Source_Is_Human = false;
        Source_Is_Friendly = false;

        if band(sourceFlags, HOSTILE_OUTSIDER_NPC) == HOSTILE_OUTSIDER_NPC then
            -- leave here if we don't care about pve healers | caveats: if a friendly healear is attacked by an NPC we won't know about it
            if not configRef.Pve then
                return;
            end
            Source_Is_NPC = true;
        elseif band (sourceFlags, HOSTILE_OUTSIDER_PLAYER) == HOSTILE_OUTSIDER_PLAYER then
            Source_Is_Human = true;
        elseif band (sourceFlags, FRIENDLY_PLAYER) == FRIENDLY_PLAYER then
            Source_Is_Human = true;
            Source_Is_Friendly = true;
        elseif band (sourceFlags, FRIENDLY_NPC) == FRIENDLY_NPC then
            -- leave here if we don't care about pve healers | caveats: none I can think of
            if not configRef.Pve then
                return;
            end
            Source_Is_NPC = true;
            Source_Is_Friendly = true;
        else
            -- not a player or an NPC, why are we even considering this comment?
            return;
        end


        -- check if a healer is under attack - broadcast the event and return {{{
        -- if the source is hostile AND if its target is a registered friendly healer
        if (not Source_Is_Friendly) and (configRef.HealerUnderAttackAlerts and (Source_Is_NPC or Source_Is_Human) and Registry_by_GUID[true][destGUID]) then

            if not self.Friendly_Healers_Attacked_by_GUID[destGUID] then
                if ( CheckInteractDistance(destName, 1) ) then

                    self:SendMessage("HHTD_HEALER_UNDER_ATTACK", sourceName, sourceGUID, destName, destGUID);

                    self.Friendly_Healers_Attacked_by_GUID[destGUID] = GetTime();

                end
            end

            -- it's certainly not a heal so no use to continue past this point.
            return;
        end -- }}}

        -- Escape if bad source (deprecated) {{{
        -- if the source is not a player and if while pve, the source is not an npc, then we don't care about this event
        -- ie: we care if the source is a human player or pve is enaled and the source is an npc.
        --      not (a or (b and c)) ==  !a and (not b or not c)

        ----------if not ( Source_Is_Human or (Source_Is_NPC and configRef.Pve)) then
            ---------return;
        ----------end -- }}}


        -- get a shortcut to the healer profile if it exists
        registered = Private_registry_by_GUID[Source_Is_Friendly][sourceGUID];

        -- Escape if Source_Is_Human and scanning for pure healing specs and the spell doesn't match and the healer is not known as a true healer {{{
        if Source_Is_Human and (configRef.PvpHSpecsOnly and not HHTD_C.Healers_Only_Spells_ByName[spellNAME] and (not registered or not registered.isTrueHeal)) then
            --@debug@
            --self:Debug(INFO2, "Spell", spellNAME, "is not a healer' spell");
            --@end-debug@
            return;
        end -- }}}

        -- a heal but not a self inflicted one
        if sourceGUID ~= destGUID and event:sub(-5) == "_HEAL" then
            isHealSpell = true;
        else
            isHealSpell = false;
        end

        -- Esacpe if it's a heal spell toward a unit hostile to the source
        if isHealSpell and ( Source_Is_Friendly and band(destFlags, HOSTILE)~=0 or not Source_Is_Friendly and band(destFlags, FRIENDLY)~=0 ) then
            --@debug@
            self:Debug(INFO2, "Spell", spellNAME, "source and destination awkwardness", sourceName, destName, 
                (Source_Is_Friendly and band(destFlags, HOSTILE)),
                (not Source_Is_Friendly and band(destFlags, FRIENDLY)));
            --@end-debug@
            return;
        end

         -- Escape if not a heal spell and (not checking for spec's spells or source is a NPC) {{{
         -- we look for healing spells directed to others
         if not isHealSpell and (Source_Is_NPC or not configRef.PvpHSpecsOnly or not HHTD_C.Healers_Only_Spells_ByName[spellNAME]) then
             return false;
         end -- }}}

         -- if we are still here it means that this is a HEAL toward another
         -- player or an ability available to specialized healers only


         if not sourceName then
             self:Debug(WARNING, "NO NAME for GUID:", sourceGUID);
             return;
         end

         RegisterHealer(GetTime(), Source_Is_Friendly, sourceGUID, sourceName, Source_Is_Human, spellNAME, isHealSpell, healAMOUNT, configRef);

     end -- }}}

 end

 -- Undertaker {{{
 -- The Undertaker will garbage collect healers who have not been healing recently (whatever the reason...)
 function HHTD:Undertaker()

     local Time = GetTime();

     local Registry_by_GUID = HHTD.Registry_by_GUID;
     --@debug@
     --self:Debug(INFO2, "cleaning...");
     --@end-debug@

     -- clean attacked healers {{{
     -- should also be cleaned when such healer dies or leave combat XXX -- no event for those...
     for guid, lastAttack in pairs(self.Friendly_Healers_Attacked_by_GUID) do
         -- if more than 30s elapsed since the last attack or if it's no longer a registered healer
         if Time - lastAttack > 30 or not Registry_by_GUID[true][guid] then
             self.Friendly_Healers_Attacked_by_GUID[guid] = nil;
             self:Debug(INFO2, "removed healer from attack table", guid);
         end
     end -- }}}

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
