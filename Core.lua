--[=[
HealersHaveToDie World of Warcraft Add-on
Copyright (c) 2009 by John Wellesz (Archarodim@teaser.fr)
All rights reserved

Version 0.1

--]=]


-- TODO: add an option to disable it and to set the expire timer



hhtd	= LibStub("AceAddon-3.0"):NewAddon("hhtd", "AceConsole-3.0", "AceEvent-3.0");
hhtd.BC	= LibStub("LibBabble-Class-3.0"):GetLookupTable();
--hhtd.TQ = LibStub:GetLibrary("LibTalentQuery-1.0");

local HHTD_C = {};

HHTD_C.HealingClasses = {
    ["PRIEST"]	= true,
    ["PALADIN"]	= true,
    ["DRUID"]	= true,
    ["SHAMAN"]	= true,
};

hhtd.EnemyHealers = {};

--hhtd.IsInspecting = false;

function hhtd:OnInitialize()
  -- Code that you want to run when the addon is first loaded goes here.
  self.db = LibStub("AceDB-3.0"):New("HealersHaveToDieDB");

  --self.TQ.RegisterCallback(self, "TalentQuery_Ready");
  
  self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");

  self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", "TestUnit");
  self:RegisterEvent("PLAYER_TARGET_CHANGED", "TestUnit");

end

function hhtd:OnEnable()
    self:Print("HealersHaveToDie enabled!");
    -- Called when the addon is enabled
end

function hhtd:OnDisable()
    self:Print("HealersHaveToDie has been disabled!\nType /hhtd standby to re-enable it.");
    -- Called when the addon is disabled
end

local UnitFactionGroup = _G.UnitFactionGroup;
local UnitIsPlayer = _G.UnitIsPlayer;
local UnitGUID = _G.UnitGUID;
local UnitClass = _G.UnitClass;
local UnitFactionGroup = _G.UnitFactionGroup;
local GetTime	    = _G.GetTime;
local PlaySoundFile	    = _G.PlaySoundFile;


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


    local UnitFaction = UnitFactionGroup(Unit);

    if UnitFaction ~= "Horde" then
	--self:Print("No unit faction");
	return;
    end

    if not UnitIsPlayer(Unit) then
	return;
    end

    local TheUG = UnitGUID(Unit);

    if not TheUG then
	self:Print("No unit GUID");
	return;
    end

    local TheUnitClass = (select(2, UnitClass(Unit)));

    if not TheUnitClass then
	self:Print("No unit Class");
	return;
    end

    -- is the unit class able to heal?
    if HHTD_C.HealingClasses[TheUnitClass] then

	--self:Print(TheUnitClass);

	if hhtd.EnemyHealers[TheUG] then
	    if GetTime() - hhtd.EnemyHealers[TheUG] > 180 then
		self:Print((UnitName(Unit)), " did not heal for more than 180s, removed.");
		hhtd.EnemyHealers[TheUG] = nil;
	    else
		self:Print("|cFFFF0000", (UnitName(Unit)), "a", TheUnitClass, "is a healer!", "|r");
		PlaySoundFile("Sound\\interface\\AlarmClockWarning3.wav");
	    end
	    
	end

	--[==[ query its talents if we don't have them
	if not hhtd.IsInspecting and not self.EnemiesTalent[TheUG] then
	    self:Print("Querring talent");
	    self.TQ:Query(Unit);
	    hhtd.IsInspecting = true;
	elseif self.EnemiesTalent[TheUG] then
	    self:Print((UnitName(Unit)), unpack(self.EnemiesTalent[TheUG]));
	end
	--]==]

    end
end



do

    local bit = _G.bit;
    local band = bit.band;
    local bor = bit.bor;
    local UnitGUID = _G.UnitGUID;
    local sub	= _G.string.sub;
    local GetTime	    = _G.GetTime;
    
    local PET			= COMBATLOG_OBJECT_TYPE_PET;

    local OUTSIDER		= COMBATLOG_OBJECT_AFFILIATION_OUTSIDER;
    local HOSTILE_OUTSIDER	= bit.bor (COMBATLOG_OBJECT_AFFILIATION_OUTSIDER, COMBATLOG_OBJECT_REACTION_HOSTILE);
    local FRIENDLY_TARGET	= bit.bor (COMBATLOG_OBJECT_TARGET, COMBATLOG_OBJECT_REACTION_FRIENDLY);
    local ME

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















--[==[ useless things {{{
function hhtd:TalentQuery_Ready(e, name, realm, unitid)

    hhtd.IsInspecting = false;
    local isnotplayer = not UnitIsUnit(unitid, "player")
    local spec = {};
    local HasTalent = 0;
	self:Print("getting talents: ", e, name, realm, unitid);
    for tab = 1, GetNumTalentTabs(isnotplayer) do
	local treename, _, pointsspent = GetTalentTabInfo(tab, isnotplayer)
	tinsert(spec, pointsspent)
	HasTalent = HasTalent + pointsspent;
    end
    local TheUG = UnitGUID(unitid);
    if TheUG and HasTalent > 0 then
	self:Print("setting talents: ", e, name, realm, unitid, TheUG);
	self.EnemiesTalent[TheUG] = spec;
    else
	self:Print("Error: ", TheUG, HasTalent);
    end

end

function hhtd:INSPECT_TALENT_READY()
    hhtd.IsInspecting = false;
end


-- functions inspired from AceConsole-2.0
local function tostring_args(a1, ...)
	if select('#', ...) < 1 then
		return tostring(a1)
	end
	return tostring(a1), tostring_args(...)
end

local function tostring_args(a1, ...)
	if select('#', ...) < 1 then
		return tostring(a1)
	end
	return tostring(a1), tostring_args(...)
end

function hhtd:Printf(s, ... ) --{{{

if tostring(a1):find("%%") and select('#', ...) >= 1 then
    local success, text = pcall(string.format, tostring_args(a1, ...))
    if success then
	return self:Print(text)
    end
    return self:Print((", "):join(tostring_args(a1, ...)));
end

return self:Print((", "):join(tostring_args(a1, ...)), self, r, g, b, frame or self.printFrame, delay)


end --}}}


}}} --]==]


