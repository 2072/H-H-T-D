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
    utils.lua
-----


--]=]

local ERROR     = 1;
local WARNING   = 2;
local INFO      = 3;
local INFO2     = 4;


local ADDON_NAME, T = ...;
local HHTD = T.Healers_Have_To_Die;

local HHTD_C = T.Healers_Have_To_Die.Constants;

function HHTD:MakePlayerName (name) --{{{
    if not name then name = "NONAME" end
    return "|Hplayer:" .. name .. "|h" .. (name):upper() .. "|h";
end --}}}

function HHTD:ColorText (text, color) --{{{

    if type(text) ~= "string" then
        text = tostring(text)
    end

    return "|c".. color .. text .. "|r";
end --}}}


-- Class coloring related functions {{{
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS;

HHTD_C.ClassesColors = { };

local LC = _G.LOCALIZED_CLASS_NAMES_MALE;

function HHTD:GetClassColor (englishClass) -- {{{
    if not HHTD_C.ClassesColors[englishClass] then
        if RAID_CLASS_COLORS and RAID_CLASS_COLORS[englishClass] then
            HHTD_C.ClassesColors[englishClass] = { RAID_CLASS_COLORS[englishClass].r, RAID_CLASS_COLORS[englishClass].g, RAID_CLASS_COLORS[englishClass].b };
        else
            HHTD_C.ClassesColors[englishClass] = { 0.63, 0.63, 0.63 };
        end
    end
    return unpack(HHTD_C.ClassesColors[englishClass]);
end -- }}}

HHTD_C.HexClassColor = { };

function HHTD:GetClassHexColor(englishClass) -- {{{

    if not HHTD_C.HexClassColor[englishClass] then

        local r, g, b = self:GetClassColor(englishClass);

        HHTD_C.HexClassColor[englishClass] = ("FF%02x%02x%02x"):format( r * 255, g * 255, b * 255);

    end

    return HHTD_C.HexClassColor[englishClass];
end -- }}}

function HHTD:CreateClassColorTables () -- {{{
    if RAID_CLASS_COLORS then
        local class, colors;
        for class in pairs(RAID_CLASS_COLORS) do
            if LC[class] then -- thank to a wonderful add-on that adds the wrong translation "Death Knight" to the global RAID_CLASS_COLORS....
                HHTD:GetClassHexColor(class);
            else
                RAID_CLASS_COLORS[class] = nil; -- Eat that!
                print("HHTD: |cFFFF0000Stupid value found in _G.RAID_CLASS_COLORS table|r\nThis will cause many issues (tainting), HHTD will display this message until the culprit add-on is fixed or removed, the Stupid value is: '", class, "'");
            end
        end
    else
        HHTD:Debug(ERROR, "global RAID_CLASS_COLORS does not exist...");
    end
end -- }}}
-- }}}

function HHTD:Error(message)
    UIErrorsFrame:AddMessage("HHTD: " .. message, 1, 0, 0, 1, UIERRORS_HOLD_TIME);
    self:Print(HHTD:ColorText(message, 'FFFF3030'));
    return message;
end

-- function HHTD:UnitName(Unit) {{{
local UnitName = _G.UnitName;
function HHTD:UnitName(Unit)
    local name, server = UnitName(Unit);
        if ( server and server ~= "" ) then
            return name.."-"..server;
        else
            return name;
        end 
end
-- }}}

-- function HHTD:RotateTexture(self, degrees) {{{
local mrad = _G.math.rad;
local mcos = _G.math.cos;
local msin = _G.math.sin;
-- inspired from http://www.wowwiki.com/SetTexCoord_Transformations#Simple_rotation_of_square_textures_around_the_center
function HHTD:RotateTexture(self, degrees)
	local angle = mrad(degrees)
	local cos, sin = mcos(angle), msin(angle)
        self:SetTexCoord(
        0.5-sin, 0.5+cos,
        0.5+cos, 0.5+sin,
        0.5-cos, 0.5-sin,
        0.5+sin, 0.5-cos
        );
end -- }}}

--  function HHTD:Debug(...) {{{
do
    local Debug_Templates = {
        [ERROR]     = "|cFFFF2222Debug:|cFFCC4444[%s.%3d]:|r|cFFFF5555",
        [WARNING]   = "|cFFFF2222Debug:|cFFCC4444[%s.%3d]:|r|cFF55FF55",
        [INFO]      = "|cFFFF2222Debug:|cFFCC4444[%s.%3d]:|r|cFF9999FF",
        [INFO2]     = "|cFFFF2222Debug:|cFFCC4444[%s.%3d]:|r|cFFFF9922",
        [false]     = "|cFFFF2222Debug:|cFFCC4444[%s.%3d]:|r",
    }
    local select, type = _G.select, _G.type;
    function HHTD:Debug(...)
        if not HHTD.db.global.Debug then return end;

        local template = type((select(1,...))) == "number" and (select(1, ...)) or false;

        local DebugHeader = (Debug_Templates[template]):format(date("%S"), (GetTime() % 1) * 1000);

        if template then
            self:Print(DebugHeader, select(2, ...));
        else
            self:Print(DebugHeader, ...);
        end
    end
end -- }}}

-- function HHTD:GetOPtionPath(info) {{{
function HHTD:GetOPtionPath(info)
    return table.concat(info, "->");
end -- }}}

