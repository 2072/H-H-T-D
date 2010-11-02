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

local ERROR     = 1;
local WARNING   = 2;
local INFO      = 3;
local INFO2     = 4;


local ADDON_NAME, T = ...;
local HHTD = T.Healers_Have_To_Die;
local L = HHTD.Localized_Text;
local LNP = LibStub("LibNameplate-1.0");


-- Create module
HHTD.Name_Plate_Hooker = HHTD:NewModule("NPH")
local NPH = HHTD.Name_Plate_Hooker;

NPH.Enemy_Healers_Plates = {};

-- Up values {{{
local CreateFrame = _G.CreateFrame;
-- }}}


function NPH:OnEnable() -- {{{
    self:Debug(INFO, "OnEnable");

    -- Subscribe to callbacks
    LNP.RegisterCallback(self, "LibNameplate_NewNameplate");
    LNP.RegisterCallback(self, "LibNameplate_RecycleNameplate");
    --LNP.RegisterCallback(self, "LibNameplate_FoundGUID");
    
    -- Subscribe to HHTD callbacks
    self:RegisterMessage("HHTD_DROP_HEALER");
    self:RegisterMessage("HHTD_HEALER_DETECTED");

    -- Add nameplates to known healers
    for healerName, lastHeal in pairs(HHTD.Enemy_Healers_By_Name) do
        self:AddCrossToPlate (LNP:GetNameplateByName(healerName));
    end

end -- }}}

function NPH:OnDisable() -- {{{
    self:Debug(INFO, "OnDisable");

    LNP.UnregisterCallback(self, "LibNameplate_NewNameplate");
    LNP.UnregisterCallback(self, "LibNameplate_RecycleNameplate");
    --LNP.UnregisterCallback(self, "LibNameplate_FoundGUID");
    
    self:UnregisterMessage("HHTD_DROP_HEALER");
    self:UnregisterMessage("HHTD_HEALER_DETECTED");

    -- clean all nameplates
    for plateName, plate in pairs(self.Enemy_Healers_Plates) do
        self:HideCrossFromPlate(plateName);
    end
end -- }}}


-- Internal CallBacks (HHTD_DROP_HEALER -- HHTD_HEALER_DETECTED) {{{
function NPH:HHTD_DROP_HEALER(healerName)
    self:HideCrossFromPlate(healerName);
end

function NPH:HHTD_HEALER_DETECTED (healerName, healerGuid)
    if not self.Enemy_Healers_Plates[healerName] then
        self:AddCrossToPlate (LNP:GetNameplateByName(healerName));
    end
end
-- }}}

-- Lib Name Plates CallBacks {{{
function NPH:LibNameplate_NewNameplate(event, plate)

    local plateName     = LNP:GetName(plate);
    --local plateReaction = LNP:GetReaction(plate);
    --local plateType     = LNP:GetType(plate);
    --local plateClass    = LNP:GetClass(plate);

    --self:Debug(plateName, "is on screen and is a", plateReaction, plateType, plateClass);

    -- Check if this name plate is of interest
    if HHTD.Enemy_Healers_By_Name[plateName] then
        self:AddCrossToPlate(plate);
    end
end

function NPH:LibNameplate_RecycleNameplate(event, plate)
    if plate.HHTD_Private then
        plate.HHTD_Private.frame:Hide()
        self.Enemy_Healers_Plates[plate.HHTD_Private.PlateName] = false;
    end
end
-- }}}




function NPH:AddCrossToPlate (plate) -- {{{

    if not plate then return false end

    local plateName = LNP:GetName(plate);

    if not plate.HHTD_Private then
        plate.HHTD_Private = {};
        self:Debug(INFO, "Creating texture for", plateName);
        local f = CreateFrame("Frame", nil, plate)
        f:SetWidth(64);
        f:SetHeight(64);
        f:SetPoint("BOTTOM", plate, "TOP", 0, -20);

        f.tex1 = f:CreateTexture(nil, "BACKGROUND");
        f.tex1:SetPoint("CENTER",f ,"CENTER",0,0)
        f.tex1:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady.blp");
        -- rotate it by Pi/2
        HHTD:RotateTexture(f.tex1, 90);

        plate.HHTD_Private.frame = f;
        plate.HHTD_Private.frame:Show()
        plate.HHTD_Private.PlateName = plateName;

    else
        plate.HHTD_Private.frame:Show()

    end

    self.Enemy_Healers_Plates[plateName] = plate;

    return true;

end -- }}}

function NPH:HideCrossFromPlate(plateName) -- {{{
    if self.Enemy_Healers_Plates[plateName] then

        self.Enemy_Healers_Plates[plateName].HHTD_Private.frame:Hide();
        self.Enemy_Healers_Plates[plateName] = nil;

        self:Debug(INFO2, "Cross hidden for", plateName);
    end
end -- }}}

