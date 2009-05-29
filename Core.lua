--[=[
HealersHaveToDie World of Warcraft Add-on
Copyright (c) 2009 by John Wellesz (Archarodim@teaser.fr)
All rights reserved

Version 0.1

--]=]

-- [=[ Add-on basics and variable declarations {{{
hhtd = LibStub("AceAddon-3.0"):NewAddon("Healers Have To Die", "AceConsole-3.0", "AceEvent-3.0");

local hhtd = hhtd;

--hhtd.BC	= LibStub("LibBabble-Class-3.0"):GetLookupTable();

-- Constants values holder
local HHTD_C = {};

HHTD_C.HealingClasses = {
    ["PRIEST"]	= true,
    ["PALADIN"]	= true,
    ["DRUID"]	= true,
    ["SHAMAN"]	= true,
};

hhtd.EnemyHealers = {};


-- upvalues
local UnitFactionGroup	= _G.UnitFactionGroup;
local UnitIsPlayer	= _G.UnitIsPlayer;
local UnitGUID		= _G.UnitGUID;
local UnitClass		= _G.UnitClass;
local UnitFactionGroup	= _G.UnitFactionGroup;
local GetTime		= _G.GetTime;
local PlaySoundFile	= _G.PlaySoundFile;

-- }}} ]=]

-- [=[ options and defaults {{{
local options = {
    name = "Healers Have To Die",
    handler = hhtd,
    type = 'group',
    args = {
        on = {
            type = 'toggle',
            name = 'on',
            desc = 'Enables HHTD',
	    set = function(info) hhtd.db.global.Enabled = hhtd:Enable(); return hhtd.db.global.Enabled; end,
            get = function(info) return hhtd:IsEnabled(); end,
	    order = 10,
        },
	off = {
            type = 'toggle',
            name = 'off',
            desc = 'Disables HHTD',
	    set = function(info) hhtd.db.global.Enabled = not hhtd:Disable(); return not hhtd.db.global.Enabled; end,
            get = function(info) return not hhtd:IsEnabled(); end,
	    order = 20,
        },
	Header1 = {
	    type = 'header',
	    name = '',
	    order = 25,
	},
	HFT = {
	    type = "range",
	    name = "Healer Forget Timer",
	    desc = "Set the Healer Forget Timer (the time in seconds an enemy will remain considered has a healer)",
	    min = 10,
	    max = 60 * 10,
	    step = 1,
	    bigStep = 5,
	    set = function(info, value) hhtd.db.global.HFT = value; return value; end,
	    get = function(info) return hhtd.db.global.HFT; end,
	    order = 30,
	},
	Header1000 = {
	    type = 'header',
	    name = '',
	    order = 999,
	},
	debug = {
            type = 'toggle',
            name = 'debug',
            desc = 'Enables / disables debugging',
	    set = function(info, value) hhtd.db.global.debug = value; hhtd:Print("Debugging status is", value); return value; end,
            get = function(info) return hhtd.db.global.debug end,
	    order = 1000,
        },
    },
}

local defaults = {
  global = {
      HFT = 60,
      Enabled = true,
      Debug = false,
  }
};
-- }}} ]=]

-- [=[ Add-on Management functions {{{
function hhtd:OnInitialize()

  self.db = LibStub("AceDB-3.0"):New("HealersHaveToDieDB", defaults);

  --options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db);

  LibStub("AceConfig-3.0"):RegisterOptionsTable("Healers Have To Die", options, {"HealersHaveToDie", "hhtd"});
  LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Healers Have To Die");

  -- register slash command handler
  --self:RegisterChatCommand("hhtd", "CLIhandler");
  
  self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
  self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", "TestUnit");
  self:RegisterEvent("PLAYER_TARGET_CHANGED", "TestUnit");

  self:SetEnabledState(self.db.global.Enabled);

end

local PlayerFaction = "";
function hhtd:OnEnable()
    self:Print("enabled! Type /hhtd for a list of options");

    PlayerFaction = UnitFactionGroup("player");

end

function hhtd:OnDisable()
    self:Print("hhtd has been disabled!\nType /hhtd enable to re-enable it.");
end

function hhtd:Debug(...)
    if not self.db.global.Debug then return end;

    self:Print("|cFFFF2222Debug:|r", ...);
end

-- }}} ]=]


function hhtd:TestUnit(EventName)

    local Unit="";

    if EventName=="UPDATE_MOUSEOVER_UNIT" then
	Unit = "mouseover";
    elseif EventName=="PLAYER_TARGET_CHANGED" then
	Unit = "target";
    else
	self:Print("called on unvalid event");
	return;
    end

    if not UnitIsPlayer(Unit) then
	return;
    end

    local UnitFaction = UnitFactionGroup(Unit);

    if UnitFaction == PlayerFaction then
	--self:Debug("friendly");
	return;
    end

    if UnitIsUnit("mouseover", "target") then
	self:Debug("mouseover is target");
	return;
    end

    local TheUG = UnitGUID(Unit);

    if not TheUG then
	self:Debug("No unit GUID");
	return;
    end

    local TheUnitClass_loc, TheUnitClass =UnitClass(Unit);

    if not TheUnitClass then
	self:Debug("No unit Class");
	return;
    end

    -- is the unit class able to heal?
    if HHTD_C.HealingClasses[TheUnitClass] then

	if hhtd.EnemyHealers[TheUG] then
	    if GetTime() - hhtd.EnemyHealers[TheUG] > hhtd.db.global.HFT then
		self:Debug((UnitName(Unit)), " did not heal for more than 180s, removed.");
		hhtd.EnemyHealers[TheUG] = nil;
	    else
		self:Print("|cFFFF0000", (UnitName(Unit)), "a", TheUnitClass_loc, "is a healer!", "|r");
		PlaySoundFile("Sound\\interface\\AlarmClockWarning3.wav");
	    end
	    
	end

    end

    hhtd:CleanHealers();

end

local LastCleaned = 0;
local Time = 0;
function hhtd:CleanHealers()

    Time = GetTime();
    if Time - LastCleaned < 60 then return end

    self:Debug("cleaning...");

    for GUID, LastHeal in pairs(hhtd.EnemyHealers) do
	if Time - LastHeal > hhtd.db.global.HFT then
	    hhtd.EnemyHealers[GUID] = nil;
	    self:Debug(GUID, "removed");
	end
    end

    LastCleaned = Time;

end

-- TODO add auto clean old healers

do
    local bit	    = _G.bit;
    local band	    = _G.bit.band;
    local bor	    = _G.bit.bor;
    local UnitGUID  = _G.UnitGUID;
    local sub	    = _G.string.sub;
    local GetTime   = _G.GetTime;
    
    local PET			= COMBATLOG_OBJECT_TYPE_PET;

    local OUTSIDER		= COMBATLOG_OBJECT_AFFILIATION_OUTSIDER;
    local HOSTILE_OUTSIDER	= bit.bor (COMBATLOG_OBJECT_AFFILIATION_OUTSIDER, COMBATLOG_OBJECT_REACTION_HOSTILE);
    local FRIENDLY_TARGET	= bit.bor (COMBATLOG_OBJECT_TARGET, COMBATLOG_OBJECT_REACTION_FRIENDLY);

    -- http://www.wowwiki.com/API_COMBAT_LOG_EVENT
    function hhtd:COMBAT_LOG_EVENT_UNFILTERED(e, timestamp, event, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, arg9, arg10, arg11, arg12)

	if not sourceGUID then return end

	if band (sourceFlags, HOSTILE_OUTSIDER) ~= HOSTILE_OUTSIDER or band(destFlags, PET) == PET then
	    --self:Print(sourceName, " is kind, its GUID is ", sourceGUID, " the event is ", event);
	    return;
	end

	if event:sub(-5) == "_HEAL" and sourceGUID ~= destGUID then
	    hhtd.EnemyHealers[sourceGUID] = GetTime();
	end

    end
end


