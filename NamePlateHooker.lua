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
                Warning1 = {
                    type = 'description',
                    name = HHTD:ColorText(L["OPT_NPH_WARNING1"], "FFFF0000"),
                    hidden = function () return GetCVarBool("nameplateShowEnemies") end,
                    order = 0,
                },
                Warning2 = {
                    type = 'description',
                    name = HHTD:ColorText(L["OPT_NPH_WARNING2"], "FFFF0000"),
                    hidden = function () return GetCVarBool("nameplateShowFriends") end,
                    order = 1,
                },
                sPve = {
                    type = 'toggle',
                    name = L["OPT_STRICTGUIDPVE"],
                    desc = L["OPT_STRICTGUIDPVE_DESC"],
                    disabled = function() return not HHTD.db.global.Pve or not HHTD:IsEnabled(); end,
                    order = 10,
                },
            },
        },
    };
end -- }}}

-- Up values {{{
local CreateFrame = _G.CreateFrame;
local GetTexCoordsForRole = _G.GetTexCoordsForRole;
-- }}}


function NPH:OnEnable() -- {{{
    self:Debug(INFO, "OnEnable");

    if LibStub then
        if (select(2, LibStub:GetLibrary("LibNameplate-1.0"))) < 30 then
            message("The shared library |cFF00FF00LibNameplate-1.0|r is out-dated, version |cFF0077FF1.0.30 (revision 125)|r at least is required. HHTD won't add its symbols over name plates.|r\n");
            self:Debug("LibNameplate-1.0",  LibStub:GetLibrary("LibNameplate-1.0"));
            self:Disable();
            return;
        end
    end

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

    -- Add nameplates to known healers by GUID
    for healerGUID, lastHeal in pairs(HHTD.Friendly_Healers) do
        self:AddCrossToPlate (LNP:GetNameplateByGUID(healerGUID));
    end

    -- Add nameplates to known healers by NAME -- XXX
    for healerName, lastHeal in pairs(HHTD.Friendly_Healers_By_Name) do
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
NPH.Friendly_Healers_Plates_byName = {};

local Plate_Name_Count = { -- array by name so we have to make the difference between friends and foes
    [true] = {}, -- for Friendly healers
    [false] = {} -- for enemy healers
};
local NPC_Is_Not_Unique = { -- array by name so we have to make the difference between friends and foes
    [true] = {}, -- for Friendly healers
    [false] = {} -- for enemy healers
};

function NPH:PLAYER_ENTERING_WORLD() -- {{{
    self:Debug(INFO2, "Cleaning multi instanced healers data");
    Plate_Name_Count[true] = {};
    Plate_Name_Count[false] = {};
    NPC_Is_Not_Unique[true] = {};
    NPC_Is_Not_Unique[false] = {};
end


-- }}}

-- Internal CallBacks (HHTD_DROP_HEALER -- HHTD_HEALER_DETECTED -- ON_HEALER_PLATE_TOUCH -- HHTD_MOUSE_OVER_OR_TARGET) {{{
function NPH:HHTD_DROP_HEALER(selfevent, healerName, unitGuid, isFriend)

    if isFriend == nil then
        isFriend = false;
    end

    if not isFriend and not GetCVarBool("nameplateShowEnemies") or isFriend and not GetCVarBool("nameplateShowFriends") then
        return;
    end

    local plate = false;
    if not isFriend then
        plate = self.Enemy_Healers_Plates_byName[healerName]
    else
        plate = self.Friendly_Healers_Plates_byName[healerName]
    end

    if plate then
        -- if the name is not unique we cannot hide just any frame...
        if not NPC_Is_Not_Unique[isFriend][healerName] then -- XXX will crash if isFriend is nil
            --self:Debug("Must drop", healerName);
            self:HideCrossFromPlate(plate);
        elseif unitGuid and LNP:GetNameplateByGUID(unitGuid) then
            self:Debug(WARNING, "Dropping healer using its guid"); -- XXX
            self:HideCrossFromPlate(LNP:GetNameplateByGUID(unitGuid));
        end
    end
end

function NPH:HHTD_HEALER_DETECTED (selfevent, healerName, healerGuid, isFriend)

    if not isFriend and not GetCVarBool("nameplateShowEnemies") or isFriend and not GetCVarBool("nameplateShowFriends") then
        return;
    end

    if not isFriend and not self.Enemy_Healers_Plates_byName[healerName] or isFriend and not self.Friendly_Healers_Plates_byName[healerName] then
        local plateByName = LNP:GetNameplateByName(healerName);
        local plateByGuid = LNP:GetNameplateByGUID(healerGuid)

        local plate = plateByGuid or plateByName;

        -- local plateType = LNP:GetType(plate);

        -- we have have access to the correct plate through the unit's GUID or it's uniquely named.
        if plateByGuid or not NPC_Is_Not_Unique[isFriend][healerName] then
            self:Debug(INFO, "HHTD_HEALER_DETECTED(): GUID available or unique", NPC_Is_Not_Unique[isFriend][healerName]); -- XXX
            self:Debug(WARNING, healerName, NPC_Is_Not_Unique[isFriend][healerName]); -- XXX
            self:AddCrossToPlate (plate, isFriend);
        elseif plateByName and not self.db.global.sPve then -- we can only access through its name and we are not in strict pve mode -- when multi pop, it will add the cross on the first name plate...
            self:Debug(INFO, "HHTD_HEALER_DETECTED(): Using name only", healerName); -- XXX
            self:AddCrossToPlate (plate, isFriend);
        else
            -- if spve we won't do anything since thee is no way to know the right plate.
            self:Debug(WARNING, "not unique NPC and sPve!");
            return;
        end
    end
end

function NPH:ON_HEALER_PLATE_TOUCH(selfevent, unit, unitGuid, unitFirstName) -- mouseover or target (_known_ enemy healers only)

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

function NPH:HHTD_MOUSE_OVER_OR_TARGET(selfevent, unit, unitGuid, unitFirstName) -- last chance update, we have the GUID at this moment (Enemy healers only) XXX
    
    if not GetCVarBool("nameplateShowEnemies") then
        return;
    end

    local plate = LNP:GetNameplateByGUID(unitGuid);

    if not HHTD.Enemy_Healers[unitGuid] then
        --self:Debug("HHTD_MOUSE_OVER_OR_TARGET():", unitGuid);

        if plate then
            local isFriend = (LNP:GetReaction(plate) == "FRIENDLY") and true or false;
            -- only hide it if it's the only one or if we are in strict mode
            if not NPC_Is_Not_Unique[isFriend][unitFirstName] or self.db.global.sPve then
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

    local plateName = LNP:GetName(plate);
    local isFriend = (LNP:GetReaction(plate) == "FRIENDLY") and true or false;

    -- test for uniqueness of the NPC
    if not NPC_Is_Not_Unique[isFriend][plateName] then -- and self.db.global.sPve then
        if not Plate_Name_Count[isFriend][plateName] then
            Plate_Name_Count[isFriend][plateName] = 1;
        else
            Plate_Name_Count[isFriend][plateName] = Plate_Name_Count[isFriend][plateName] + 1;
            NPC_Is_Not_Unique[isFriend][plateName] = true;
            self:Debug(INFO, plateName, "is not unique:", Plate_Name_Count[isFriend][plateName]);
        end
    end

    -- Check if this name plate is of interest -- XXX
    if HHTD.Healer_Registry[isFriend].Healers_By_Name[plateName] and GetTime() - HHTD.Healer_Registry[isFriend].Healers_By_Name[plateName] < HHTD.db.global.HFT then

        
        -- If there are several plates with the same name and sPve is set then
        -- we do nothing since there is no way to be sure
        if NPC_Is_Not_Unique[isFriend][plateName] and self.db.global.sPve then
            self:Debug(INFO2, "new plate but sPve and not unique");
            return;
        end

        self:Debug("LibNameplate_NewNameplate --> AddCrossToPlate"); -- XXX
        self:AddCrossToPlate(plate);
    end
end

function NPH:LibNameplate_RecycleNameplate(selfevent, plate)
    local plateName = LNP:GetName(plate);


    -- We've modified the plate
    if plate.HHTD_EnemyHealer and plate.HHTD_EnemyHealer.IsShown then
        self:Debug(INFO2, "Hidding |cffff0000enemy|r texture for", plate.HHTD_EnemyHealer.PlateNam);
        plate.HHTD_EnemyHealer.texture:Hide()
        plate.HHTD_EnemyHealer.IsShown = false;
        self.Enemy_Healers_Plates_byName[plate.HHTD_EnemyHealer.PlateName] = false;
    end


    if plate.HHTD_FriendHealer and plate.HHTD_FriendHealer.IsShown then
        self:Debug(INFO2, "Hidding |cff00ff00friendly|r texture for", plate.HHTD_FriendHealer.PlateNam);
        plate.HHTD_FriendHealer.texture:Hide()
        plate.HHTD_FriendHealer.IsShown = false;
        self.Enemy_Healers_Plates_byName[plate.HHTD_FriendHealer.PlateName] = false;
    end

    local isFriend = (LNP:GetReaction(plate) == "FRIENDLY") and true or false;

    -- prevent uniqueness data from stacking
    if Plate_Name_Count[isFriend][plateName] then
        Plate_Name_Count[isFriend][plateName] = Plate_Name_Count[isFriend][plateName] - 1;
        if Plate_Name_Count[isFriend][plateName] == 0 then
            Plate_Name_Count[isFriend][plateName] = nil;
        end
    end
end

-- }}}


do

    local function MakeTexture(plate)
        --local f = CreateFrame("Frame", nil, plate)
        local t = plate:CreateTexture()
        t:SetWidth(64);
        t:SetHeight(64);
        t:SetPoint("BOTTOM", plate, "TOP", 0, -20);
                
        return t

    end

    local function RegisterAndShowTexture(where, texture, plateName)
        where.texture = texture;
        where.texture:Show()
        where.IsShown = true;
        where.PlateName = plateName;

    end

    function NPH:AddCrossToPlate (plate, isFriend) -- {{{

        if not plate then return false end

        if isFriend==nil then
            isFriend = (LNP:GetReaction(plate) == "FRIENDLY") and true or false;
        end

        local plateName = LNP:GetName(plate);

        if not isFriend then
            if not plate.HHTD_EnemyHealer then
                plate.HHTD_EnemyHealer = {};

                self:Debug(INFO, "Creating |cffff0000enemy|r texture for", plateName);

                local t = MakeTexture(plate)

                t:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady.blp");
                -- rotate it by Pi/2
                HHTD:RotateTexture(t, 90);

                RegisterAndShowTexture(plate.HHTD_EnemyHealer, t, plateName);


            elseif not plate.HHTD_EnemyHealer.IsShown then
                plate.HHTD_EnemyHealer.texture:Show()
                self:Debug(INFO, "Showing |cffff0000enemy|r texture for", plateName);
                plate.HHTD_EnemyHealer.IsShown = true;

            end
        else
            if not plate.HHTD_FriendHealer then
                plate.HHTD_FriendHealer = {};

                self:Debug(INFO, "Creating |cff00ff00friendly|r texture for", plateName);

                local t = MakeTexture(plate)

                t:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-RoleS");
                t:SetTexCoord(GetTexCoordsForRole("HEALER"));

                RegisterAndShowTexture(plate.HHTD_FriendHealer, t, plateName);

            elseif not plate.HHTD_FriendHealer.IsShown then
                plate.HHTD_FriendHealer.texture:Show()
                self:Debug(INFO, "Showing |cff00ff00friendly|r texture for", plateName);
                plate.HHTD_FriendHealer.IsShown = true;

            end
        end

        if not isFriend then
            -- our reference to this plate
            self.Enemy_Healers_Plates_byName[plateName] = plate;
        else
            self.Friendly_Healers_Plates_byName[plateName] = plate;
        end

        return true;

    end -- }}}
end

function NPH:HideCrossFromPlate(plate) -- {{{

    if plate and plate.HHTD_EnemyHealer and plate.HHTD_EnemyHealer.IsShown then

        plate.HHTD_EnemyHealer.texture:Hide();
        plate.HHTD_EnemyHealer.IsShown = false;
        self.Enemy_Healers_Plates_byName[plate.HHTD_EnemyHealer.PlateName] = nil;

        self:Debug(INFO2, "|cffff0000Enemy|c Cross hidden for", plate.HHTD_EnemyHealer.PlateNam);
    end

    if plate and plate.HHTD_FriendHealer and plate.HHTD_FriendHealer.IsShown then

        plate.HHTD_FriendHealer.texture:Hide();
        plate.HHTD_FriendHealer.IsShown = false;
        self.Enemy_Healers_Plates_byName[plate.HHTD_FriendHealer.PlateName] = nil;

        self:Debug(INFO2, "|cff00ff00Friendly|c Cross hidden for", plate.HHTD_FriendHealer.PlateNam);
    end




end -- }}}

