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
    Announcer.lua
-----

This component plays alert sounds and display messages.


--]=]

local ERROR     = 1;
local WARNING   = 2;
local INFO      = 3;
local INFO2     = 4;


local ADDON_NAME, T = ...;
local HHTD = T.Healers_Have_To_Die;
local L = HHTD.Localized_Text;

-- Create module
HHTD.Announcer = HHTD:NewModule("Announcer")
local Announcer = HHTD.Announcer;

-- Up Values
local UnitGUID      = _G.UnitGUID;
local UnitName      = _G.UnitName;
local UnitClass     = _G.UnitClass;
local UnitSex       = _G.UnitSex;
local PlaySoundFile = _G.PlaySoundFile;
local select        = _G.select;

function Announcer:GetOptions ()
    return {
        [Announcer:GetName()] = {
            name = L[Announcer:GetName()],
            type = 'group',
            args = {
                Announce = {
                    type = 'toggle',
                    name = L["OPT_ANNOUNCE"],
                    desc = L["OPT_ANNOUNCE_DESC"],
                    set = function(info, v) HHTD.db.global[info[#info]] = v; return v; end,
                    get = function(info) return HHTD.db.global[info[#info]]; end,
                    order = 1,
                },
            },
        },
    };
end


function Announcer:OnEnable() -- {{{
    self:Debug(INFO, "OnEnable");

    -- Subscribe to HHTD callbacks
    self:RegisterMessage("HHTD_HEALER_UNDER_MOUSE");
    self:RegisterMessage("HHTD_TARGET_LOCKED");

end -- }}}

function Announcer:OnDisable() -- {{{
    self:Debug(INFO2 "OnDisable");

    self:UnregisterMessage("HHTD_HEALER_UNDER_MOUSE");
    self:UnregisterMessage("HHTD_TARGET_LOCKED");

end -- }}}


-- Internal CallBacks (HHTD_DROP_HEALER -- HHTD_HEALER_DETECTED) {{{
function Announcer:HHTD_HEALER_UNDER_MOUSE(selfevent, unit, previousUnitGuid)

    if previousUnitGuid ~= UnitGUID(unit) then
        self:Announce(
            "|cFFFF0000",
            (L["IS_A_HEALER"]):format(
                HHTD:ColorText(
                (UnitName(unit)),
                HHTD:GetClassHexColor(  select(2, UnitClass(unit)) )
                ),
            "|r"
            )
        );
    end

    PlaySoundFile("Sound\\interface\\AlarmClockWarning3.wav");
    -- self:Debug(INFO, "AlarmClockWarning3.wav played");
end

function Announcer:HHTD_TARGET_LOCKED (selfevent, unit)
    PlaySoundFile("Sound\\interface\\AuctionWindowOpen.wav");
    --self:Debug(INFO, "AuctionWindowOpen.wav played");

    local sex = UnitSex(unit);

    local what = (sex == 1 and L["YOU_GOT_IT"] or sex == 2 and L["YOU_GOT_HIM"] or L["YOU_GOT_HER"]);

    local localizedUnitClass, unitClass = UnitClass(unit);

    local subjectColor = HHTD:GetClassHexColor(unitClass);

    self:Announce(what:format("|c" .. subjectColor));

end
-- }}}


function Announcer:Announce(...)
    if HHTD.db.global.Announce then
        self:Print(...);
    end
end
