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
    NamePlateHooker.lua
-----

This component hooks the name plates above characters and adds a sign on top to identifie them as healers


--]=]


local addonName, T = ...;
local hhtd = T.hhtd;
local L = hhtd.L;
local LibNameplate = LibStub("LibNameplate-1.0");

local ERROR     = 1;
local WARNING   = 2;
local INFO      = 3;
local INFO2     = 4;

local CreateFrame = _G.CreateFrame;

function hhtd:AddCrossToPlate (plate)

    if not plate then return false end

    local plateName     = LibNameplate:GetName(plate);

    if not plate.HHTD then
        plate.HHTD = {};
        self:Debug(INFO, "Creating texture for", plateName);
        local f = CreateFrame("Frame", nil, plate)
        f:SetWidth(64);
        f:SetHeight(64);
        f:SetPoint("BOTTOM", plate, "TOP", 0, -20);

        f.tex1 = f:CreateTexture(nil, "BACKGROUND");
        f.tex1:SetPoint("CENTER",f ,"CENTER",0,0)
        f.tex1:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady.blp");
        -- rotate it by Pi/2
        self:RotateTexture(f.tex1, 90);

        plate.HHTD.frame = f;
        plate.HHTD.frame:Show()
        plate.HHTD.plateName = plateName;

    else
        plate.HHTD.frame:Show()

    end

    self.EnemyHealersPlates[plateName] = plate;

    return true;

end


function hhtd:LibNameplate_NewNameplate(event, plate)

    local plateName     = LibNameplate:GetName(plate);
    --local plateReaction = LibNameplate:GetReaction(plate);
    --local plateType     = LibNameplate:GetType(plate);
    --local plateClass    = LibNameplate:GetClass(plate);

    --self:Debug(plateName, "is on screen and is a", plateReaction, plateType, plateClass);

    -- Check if this name plate is of interest
    if self.EnemyHealersByName[plateName] then
        self:AddCrossToPlate(plate);
    end
end

function hhtd:LibNameplate_RecycleNameplate(event, plate)
    if plate.HHTD then
        plate.HHTD.frame:Hide()
        self.EnemyHealersPlates[plate.HHTD.plateName] = false;
    end
end

function hhtd:HideCross(plateName)
    if self.EnemyHealersPlates[plateName] then

        self.EnemyHealersPlates[plateName].HHTD.frame:Hide();
        self.EnemyHealersPlates[plateName] = nil;

        self:Debug(INFO2, "Cross hidden for", plateName);
    end
end

--[=[
function hhtd:LibNameplate_FoundGUID(event, plate, GUID, UnitID)
    local plateName = LibNameplate:GetName(plate);
    self:Debug("Found a GUID for ", plateName, "(", UnitID, "):", GUID);
end
--]=]


