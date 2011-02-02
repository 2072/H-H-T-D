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

--  module framework {{{
local ERROR     = 1;
local WARNING   = 2;
local INFO      = 3;
local INFO2     = 4;


local ADDON_NAME, T = ...;
local HHTD = T.Healers_Have_To_Die;
local L = HHTD.Localized_Text;
local LNP = LibStub("LibNameplate-1.0");


HHTD.Name_Plate_Hooker = HHTD:NewModule("NPH")
local NPH = HHTD.Name_Plate_Hooker;


-- upvalues {{{
local GetCVarBool     = _G.GetCVarBool;
local GetTime         = _G.GetTime;
local pairs           = _G.pairs;
-- }}}

function NPH:OnInitialize() -- {{{
    self:Debug(INFO, "OnInitialize called!");
    self.db = HHTD.db:RegisterNamespace('NPH', {
        global = {
            sPve = false,
        },
    })
end -- }}}

function NPH:GetOptions () -- {{{
    return {
        [NPH:GetName()] = {
            name = L[NPH:GetName()],
            type = 'group',
            get = function (info) return NPH.db.global[info[#info]]; end,
            set = function (info, value) HHTD:SetHandler(self, info, value) end,
            args = {
                sPve = {
                    type = 'toggle',
                    name = L["OPT_STRICTGUIDPVE"],
                    desc = L["OPT_STRICTGUIDPVE_DESC"],
                    disabled = function() return not HHTD.db.global.Pve or not HHTD:IsEnabled(); end,
                    order = 1,
                },
            },
        },
    };
end -- }}}

-- Up values {{{
local CreateFrame = _G.CreateFrame;
-- }}}


function NPH:OnEnable() -- {{{
    self:Debug(INFO, "OnEnable");

    -- Subscribe to callbacks
    LNP.RegisterCallback(self, "LibNameplate_NewNameplate");
    LNP.RegisterCallback(self, "LibNameplate_RecycleNameplate");
    
    -- Subscribe to HHTD callbacks
    self:RegisterMessage("HHTD_DROP_HEALER");
    self:RegisterMessage("HHTD_HEALER_DETECTED");
    self:RegisterMessage("HHTD_TARGET_LOCKED", "ON_HEALER_PLATE_TOUCH");
    self:RegisterMessage("HHTD_HEALER_UNDER_MOUSE", "ON_HEALER_PLATE_TOUCH");
    self:RegisterMessage("HHTD_MOUSE_OVER_OR_TARGET");

    self:RegisterEvent("PLAYER_ENTERING_WORLD");

    -- Add nameplates to known healers by GUID
    for healerGUID, lastHeal in pairs(HHTD.Enemy_Healers) do
        self:AddCrossToPlate (LNP:GetNameplateByGUID(healerGUID));
    end

    -- Add nameplates to known healers by NAME -- XXX
    for healerName, lastHeal in pairs(HHTD.Enemy_Healers_By_Name) do
        self:AddCrossToPlate (LNP:GetNameplateByName(healerName));
    end

end -- }}}

function NPH:OnDisable() -- {{{
    self:Debug(INFO2, "OnDisable");

    LNP.UnregisterCallback(self, "LibNameplate_NewNameplate");
    LNP.UnregisterCallback(self, "LibNameplate_RecycleNameplate");

    -- clean all nameplates
    for plateName, plate in pairs(self.Enemy_Healers_Plates_byName) do
        self:HideCrossFromPlate(plate);
    end
end -- }}}
-- }}}

NPH.Enemy_Healers_Plates_byName = {};

local Not_Unique_Enemy_Healers = {};
local Healer_Is_Not_Unique = {};

function NPH:PLAYER_ENTERING_WORLD() -- {{{
    self:Debug(INFO2, "Cleaning multi instanced healers data");
    Not_Unique_Enemy_Healers = {};
    Healer_Is_Not_Unique = {};
end


-- }}}

-- Internal CallBacks (HHTD_DROP_HEALER -- HHTD_HEALER_DETECTED -- ON_HEALER_PLATE_TOUCH -- HHTD_MOUSE_OVER_OR_TARGET) {{{
function NPH:HHTD_DROP_HEALER(selfevent, healerName, unitGuid) -- XXX add guid and test with it if not unique unit

    if not GetCVarBool("nameplateShowEnemies") then
        return;
    end

    local plate = self.Enemy_Healers_Plates_byName[healerName]

    if plate then
        -- if the name is not unique we cannot hide just any frame...
        if not Healer_Is_Not_Unique[healerName] then
            --self:Debug("Must drop", healerName);
            self:HideCrossFromPlate(plate);
        elseif unitGuid and LNP:GetNameplateByGUID(healerGuid) then
            self:Debug(WARNING, "Dropping healer using its guid"); -- XXX
            self:HideCrossFromPlate(LNP:GetNameplateByGUID(healerGuid));
        end
    end
end

function NPH:HHTD_HEALER_DETECTED (selfevent, healerName, healerGuid)

    if not GetCVarBool("nameplateShowEnemies") then
        return;
    end

    if not self.Enemy_Healers_Plates_byName[healerName] then
        local plateByName = LNP:GetNameplateByName(healerName);
        local plateByGuid = LNP:GetNameplateByGUID(healerGuid)

        local plate = plateByGuid or plateByName;

        -- local plateType = LNP:GetType(plate);

        -- we have have access to the correct plate through the unit's GUID or it's uniquely named.
        if plateByGuid or not Healer_Is_Not_Unique[healerName] then
            self:Debug(INFO, "HHTD_HEALER_DETECTED(): GUID available or unique", Healer_Is_Not_Unique[healerName]); -- XXX
            self:Debug(WARNING, healerName, Healer_Is_Not_Unique[healerName]); -- XXX
            self:AddCrossToPlate (plate);
        elseif plateByName and not self.db.global.sPve then -- we can only access through it's name and we are not in strict pve mode -- when multi pop, it will add the cross on the first name plate...
            self:Debug(INFO, "HHTD_HEALER_DETECTED(): Using name only", healerName); -- XXX
            self:AddCrossToPlate (plate);
        else
            -- if spve we won't do anything since thee is no way to know the right plate.
            self:Debug(WARNING, "not unique NPC and sPve!");
            return;
        end
    end
end

function NPH:ON_HEALER_PLATE_TOUCH(selfevent, unit, unitGuid, unitFirstName)

    if not GetCVarBool("nameplateShowEnemies") then
        return;
    end

    local plate = LNP:GetNameplateByGUID(unitGuid);

    if plate then
        self:AddCrossToPlate(plate);
    else
        self:Debug(ERROR, "ON_HEALER_PLATE_TOUCH(): LNP:GetNameplateByGUID(unitGuid)==nil", unitGuid);
    end

end

function NPH:HHTD_MOUSE_OVER_OR_TARGET(selfevent, unit, unitGuid, unitFirstName)
    
    if not GetCVarBool("nameplateShowEnemies") then
        return;
    end

    local plate = LNP:GetNameplateByGUID(unitGuid);

    if not HHTD.Enemy_Healers[unitGuid] then
        --self:Debug("HHTD_MOUSE_OVER_OR_TARGET():", unitGuid);

        if plate then
            -- only hide it if it's the only one or if we are in strict mode
            if not Healer_Is_Not_Unique[unitFirstName] or self.db.global.sPve then
                self:HideCrossFromPlate(plate); -- The name plate should be identifiable by the unit guid
            end
        --else
          --  self:Debug(ERROR, "HHTD_MOUSE_OVER_OR_TARGET(): LNP:GetNameplateByGUID(unitGuid)==nil", unitGuid);
        end

    elseif GetTime() - HHTD.Enemy_Healers[unitGuid] < HHTD.db.global.HFT then
        self:AddCrossToPlate(plate);
    end

end

-- }}}

-- Lib Name Plates CallBacks {{{
function NPH:LibNameplate_NewNameplate(selfevent, plate)

    local plateName     = LNP:GetName(plate);

    -- test for uniqueness of the NPC
    if not Healer_Is_Not_Unique[plateName] then -- and self.db.global.sPve then
        if not Not_Unique_Enemy_Healers[plateName] then
            Not_Unique_Enemy_Healers[plateName] = 1;
        else
            Not_Unique_Enemy_Healers[plateName] = Not_Unique_Enemy_Healers[plateName] + 1;
            Healer_Is_Not_Unique[plateName] = true;
            self:Debug(INFO, plateName, "is not unique");
        end
    end

    -- Check if this name plate is of interest
    if HHTD.Enemy_Healers_By_Name[plateName] and GetTime() - HHTD.Enemy_Healers_By_Name[plateName] < HHTD.db.global.HFT then

        
        -- If there are several plates with the same name and sPve is set then
        -- we do nothing since there is no way to be sure
        if Healer_Is_Not_Unique[plateName] and self.db.global.sPve then
            self:Debug(INFO2, "new plate but sPve and not unique");
            return;
        end

        self:Debug("LibNameplate_NewNameplate --> AddCrossToPlate"); -- XXX
        self:AddCrossToPlate(plate);
    end
end

function NPH:LibNameplate_RecycleNameplate(selfevent, plate)
    local plateName     = LNP:GetName(plate);

    -- We've modeified the plate
    if plate.HHTD_Private and plate.HHTD_Private.IsShown then
        self:Debug(INFO2, "Hidding texture for", plate.HHTD_Private.PlateNam);
        plate.HHTD_Private.frame:Hide()
        plate.HHTD_Private.IsShown = false;
        self.Enemy_Healers_Plates_byName[plate.HHTD_Private.PlateName] = false;
    end

    -- prevent uniqueness data from stacking
    if Not_Unique_Enemy_Healers[plateName] then
        Not_Unique_Enemy_Healers[plateName] = Not_Unique_Enemy_Healers[plateName] - 1;
        if Not_Unique_Enemy_Healers[plateName] == 0 then
            Not_Unique_Enemy_Healers[plateName] = nil;
        end
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
        plate.HHTD_Private.IsShown = true;
        plate.HHTD_Private.PlateName = plateName;

    elseif not plate.HHTD_Private.IsShown then
        plate.HHTD_Private.frame:Show()
        self:Debug(INFO, "Showing texture for", plateName);
        plate.HHTD_Private.IsShown = true;

    end

    -- our reference to this plate
    self.Enemy_Healers_Plates_byName[plateName] = plate;

    return true;

end -- }}}

function NPH:HideCrossFromPlate(plate) -- {{{

    if plate and plate.HHTD_Private and plate.HHTD_Private.IsShown then

        plate.HHTD_Private.frame:Hide();
        plate.HHTD_Private.IsShown = false;
        self.Enemy_Healers_Plates_byName[plate.HHTD_Private.PlateName] = nil;

        self:Debug(INFO2, "Cross hidden for", plate.HHTD_Private.PlateNam);
    end
end -- }}}

