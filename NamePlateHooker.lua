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

local PLATES__NPH_NAMES = {
    [true] = 'HHTD_FriendHealer',
    [false] = 'HHTD_EnemyHealer'
};

local LAST_TEXTURE_UPDATE = 0;

-- upvalues {{{
local GetCVarBool           = _G.GetCVarBool;
local GetTime               = _G.GetTime;
local pairs                 = _G.pairs;
local ipairs                = _G.ipairs;
local CreateFrame           = _G.CreateFrame;
local GetTexCoordsForRole   = _G.GetTexCoordsForRole;
-- }}}

function NPH:OnInitialize() -- {{{
    self:Debug(INFO, "OnInitialize called!");
    self.db = HHTD.db:RegisterNamespace('NPH', {
        global = {
            sPve = false,
            marker_Scale = 1,
            marker_Xoffset = 0,
            marker_Yoffset = 0,
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
                Header100 = {
                        type = 'header',
                        name = L["OPT_NPH_MARKER_SETTINGS"],
                        order = 15,
                    },
                marker_Scale = {
                        type = "range",
                        name = L["OPT_NPH_MARKER_SCALE"],
                        desc = L["OPT_NPH_MARKER_SCALE_DESC"],
                        min = 0.45,
                        max = 3,
                        softMax = 2,
                        step = 0.01,
                        bigStep = 0.03,
                        order = 20,
                        isPercent = true,

                        set = function (info, value)
                            HHTD:SetHandler(self, info, value);
                            NPH:UpdateTextures();
                        end,
                    },
                    marker_Xoffset = {
                        type = "range",
                        name = L["OPT_NPH_MARKER_X_OFFSET"],
                        desc = L["OPT_NPH_MARKER_X_OFFSET_DESC"],
                        min = -100,
                        max = 100,
                        softMin = -60,
                        softMax = 60,
                        step = 0.01,
                        bigStep = 1,
                        order = 30,

                        set = function (info, value)
                            HHTD:SetHandler(self, info, value);
                            NPH:UpdateTextures();
                        end,
                    },
                    marker_Yoffset = {
                        type = "range",
                        name = L["OPT_NPH_MARKER_Y_OFFSET"],
                        desc = L["OPT_NPH_MARKER_Y_OFFSET_DESC"],
                        min = -100,
                        max = 100,
                        softMin = -60,
                        softMax = 60,
                        step = 0.01,
                        bigStep = 1,
                        order = 30,

                        set = function (info, value)
                            HHTD:SetHandler(self, info, value);
                            NPH:UpdateTextures();
                        end,
                    },
            },
        },
    };
end -- }}}

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
    LNP.RegisterCallback(self, "LibNameplate_FoundGUID");
    
    -- Subscribe to HHTD callbacks
    self:RegisterMessage("HHTD_HEALER_GONE");
    self:RegisterMessage("HHTD_HEALER_BORN");

    self:RegisterEvent("PLAYER_ENTERING_WORLD");

    local plate;
    for i, isFriend in ipairs({true,false}) do
        -- Add nameplates to known healers by GUID
        for healerGUID, healer in pairs(HHTD.Registry_by_GUID[isFriend]) do

            plate = LNP:GetNameplateByGUID(healerGUID) or LNP:GetNameplateByName(healer.name);

            if plate then
                self:AddCrossToPlate (plate, isFriend, healer.name);
            end

        end
    end

end -- }}}

function NPH:OnDisable() -- {{{
    self:Debug(INFO2, "OnDisable");

    LNP.UnregisterCallback(self, "LibNameplate_NewNameplate");
    LNP.UnregisterCallback(self, "LibNameplate_RecycleNameplate");
    LNP.UnregisterCallback(self, "LibNameplate_FoundGUID");

    -- clean all nameplates
    for i, isFriend in ipairs({true,false}) do
        for plateTID, plate in pairs(self.DisplayedPlates_byFrameTID[isFriend]) do
            self:HideCrossFromPlate(plate, isFriend);
        end
    end
end -- }}}
-- }}}



NPH.DisplayedPlates_byFrameTID = { -- used for updating plates dipslay attributes
    [true] = {}, -- for Friendly healers
    [false] = {} -- for enemy healers
};

local Plate_Name_Count = { -- array by name so we have to make the difference between friends and foes
    [true] = {}, -- for Friendly healers
    [false] = {} -- for enemy healers
};
local NP_Is_Not_Unique = { -- array by name so we have to make the difference between friends and foes
    [true] = {}, -- for Friendly healers
    [false] = {} -- for enemy healers
};

local Multi_Plates_byName = {
    [true] = {}, -- for Friendly healers
    [false] = {} -- for enemy healers
};

function NPH:PLAYER_ENTERING_WORLD() -- {{{
    self:Debug(INFO2, "Cleaning multi instanced healers data");
    Plate_Name_Count[true] = {};
    Plate_Name_Count[false] = {};
    NP_Is_Not_Unique[true] = {};
    NP_Is_Not_Unique[false] = {};
    Multi_Plates_byName[true] = {};
    Multi_Plates_byName[false] = {};
end


-- }}}

-- Internal CallBacks (HHTD_HEALER_GONE -- HHTD_HEALER_BORN -- ON_HEALER_PLATE_TOUCH -- HHTD_MOUSE_OVER_OR_TARGET) {{{
function NPH:HHTD_HEALER_GONE(selfevent, isFriend, healer)
    self:Debug(INFO2, "NPH:HHTD_HEALER_GONE", healer.name, healer.guid, isFriend);

    if not isFriend and not GetCVarBool("nameplateShowEnemies") or isFriend and not GetCVarBool("nameplateShowFriends") then
        self:Debug(INFO2, "NPH:HHTD_HEALER_GONE(): bad state, nameplates disabled",  healer.name, healer.guid, isFriend);
        return;
    end

    local plateByName = LNP:GetNameplateByName(healer.name);
    local plateByGuid;
    if self.db.global.sPve then
        plateByGuid = LNP:GetNameplateByGUID(healer.guid);
    end

    local plate = plateByGuid or plateByName;


    if plate then

        -- if we can acces to the plate using its guid or if it's unique
        if plateByGuid or not NP_Is_Not_Unique[isFriend][healer.name] then
            --self:Debug("Must drop", healer.name);
            self:HideCrossFromPlate(plate, isFriend, healer.name);

        elseif not self.db.global.sPve then -- Just hide all the symbols on the plates with that name

            for plate, plate in pairs (Multi_Plates_byName[isFriend][healer.name]) do
                self:HideCrossFromPlate(plate, isFriend, healer.name);
            end
        end
    else
        self:Debug(INFO2, "HHTD_HEALER_GONE: no plate for", healer.name);
    end
end

function NPH:HHTD_HEALER_BORN (selfevent, isFriend, healer)

    if not isFriend and not GetCVarBool("nameplateShowEnemies") or isFriend and not GetCVarBool("nameplateShowFriends") then
        return;
    end


    local plateByName = LNP:GetNameplateByName(healer.name);
    local plateByGuid;
    if self.db.global.sPve then
        plateByGuid = LNP:GetNameplateByGUID(healer.guid);
    end

    local plate = plateByGuid or plateByName;

    -- local plateType = LNP:GetType(plate);

    if plate then
        -- we have have access to the correct plate through the unit's GUID or it's uniquely named.
        if plateByGuid or not NP_Is_Not_Unique[isFriend][healer.name] then
            self:AddCrossToPlate (plate, isFriend, healer.name);

            self:Debug(INFO, "HHTD_HEALER_BORN(): GUID available or unique", NP_Is_Not_Unique[isFriend][healer.name]);
            self:Debug(WARNING, healer.name, NP_Is_Not_Unique[isFriend][healer.name]);

        elseif not self.db.global.sPve then -- we can only access through its name and we are not in strict pve mode -- when multi pop, it will add the cross to all plates

            for plate, plate in pairs (Multi_Plates_byName[isFriend][healer.name]) do
                self:AddCrossToPlate (plate, isFriend, healer.name);

                self:Debug(INFO, "HHTD_HEALER_BORN(): Using name only", healer.name);
            end
        else
            self:Debug(WARNING, "HHTD_HEALER_BORN: multi and sPVE and noguid :'( ", healer.name);
        end
    else
        -- if spve we won't do anything since thee is no way to know the right plate.
        self:Debug(WARNING, "HHTD_HEALER_BORN: no plate for ", healer.name);
        return;
    end
end

-- }}}

-- Lib Name Plates CallBacks {{{
function NPH:LibNameplate_NewNameplate(selfevent, plate)

    local plateName = LNP:GetName(plate);
    local isFriend = (LNP:GetReaction(plate) == "FRIENDLY") and true or false;

    -- test for uniqueness of the nameplate

    if not Plate_Name_Count[isFriend][plateName] then
        Plate_Name_Count[isFriend][plateName] = 1;
    else
        Plate_Name_Count[isFriend][plateName] = Plate_Name_Count[isFriend][plateName] + 1;
        if not NP_Is_Not_Unique[isFriend][plateName] then
            NP_Is_Not_Unique[isFriend][plateName] = true;
            self:Debug(INFO, plateName, "is not unique");
        end
    end

    if not Multi_Plates_byName[isFriend][plateName] then
        Multi_Plates_byName[isFriend][plateName] = {};
    end

    Multi_Plates_byName[isFriend][plateName][plate] = plate;

    -- Check if this name plate is of interest -- XXX
    if HHTD.Registry_by_Name[isFriend][plateName] then
        
        -- If there are several plates with the same name and sPve is set then
        -- we do nothing since there is no way to be sure
        if NP_Is_Not_Unique[isFriend][plateName] and self.db.global.sPve then
            self:Debug(INFO2, "new plate but sPve and not unique");
            return;
        end

        self:AddCrossToPlate(plate, isFriend, plateName);
    end
end

function NPH:LibNameplate_RecycleNameplate(selfevent, plate)

    local plateName = LNP:GetName(plate);

    local plateCross;

    for i, isFriend in ipairs({true,false}) do

        self:HideCrossFromPlate(plate, isFriend, plateName);


        -- prevent uniqueness data from stacking
        if Plate_Name_Count[isFriend][plateName] then

            Multi_Plates_byName[isFriend][plateName][plate] = nil;

            Plate_Name_Count[isFriend][plateName] = Plate_Name_Count[isFriend][plateName] - 1;
            if Plate_Name_Count[isFriend][plateName] == 0 then
                Plate_Name_Count[isFriend][plateName] = nil;
            end
        end
    end
end

function NPH:LibNameplate_FoundGUID(selfevent, plate, guid, unitID)

    if self.db.global.sPve then
        if HHTD.Registry_by_GUID[true][guid] or HHTD.Registry_by_GUID[false][guid] then
            self:Debug(INFO, "GUID found");
            self:AddCrossToPlate(plate, nil, LNP:GetName(plate));
        end
    end

end

-- }}}


do

    local function SetTextureParams(plate, t)
        local profile = NPH.db.global;

        t:SetSize(64 * profile.marker_Scale, 64 * profile.marker_Scale);
        t:SetPoint("BOTTOM", plate, "TOP", 0 + profile.marker_Xoffset, -20 + profile.marker_Yoffset);
    end

    local function MakeTexture(plate, isFriend)
        local t = plate:CreateTexture();

        SetTextureParams(plate, t);

        if isFriend then
            t:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-RoleS");
            t:SetTexCoord(GetTexCoordsForRole("HEALER"));
        else
            t:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady.blp");
            -- rotate it by Pi/2
            HHTD:RotateTexture(t, 90);
        end

        return t;

    end

    local SmallFontName = _G.NumberFont_Shadow_Small:GetFont();

    local function MakeFontString(plate, symbol)
        local f = plate:CreateFontString();
        f:SetFont(SmallFontName, 12.2, "THICKOUTLINE, MONOCHROME");
        
        f:SetTextColor(1, 1, 1, 1);
        
        f:SetPoint("CENTER", symbol, "CENTER", 0, 0);

        return f;
    end

    local function AddElements (plate, isFriend, plateName)
        local texture  = MakeTexture(plate, isFriend);
        local rankFont = MakeFontString(plate, texture);

        local holder = plate[PLATES__NPH_NAMES[isFriend]];

        holder.texture = texture;
        holder.texture:Show();

        holder.rankFont = rankFont;
        holder.rankFont:SetText(HHTD.Registry_by_Name[isFriend][plateName].rank);
        holder.rankFont:Show();

        holder.IsShown = true;

    end

    local function UpdateTexture (plate, holder)

        if not holder.textureUpdate or holder.textureUpdate < LAST_TEXTURE_UPDATE then
            --self:Debug('Updating texture');

            SetTextureParams(plate, holder.texture);

            holder.textureUpdate = GetTime();
        end

    end

    function NPH:UpdateTextures ()

        LAST_TEXTURE_UPDATE = GetTime();

        for i, isFriend in ipairs({true,false}) do
            -- Add nameplates to known healers by GUID
            for plate in pairs(self.DisplayedPlates_byFrameTID[isFriend]) do

                UpdateTexture(plate, plate[PLATES__NPH_NAMES[isFriend]]);

            end
        end

    end
    

    local PlateAdditions;
    function NPH:AddCrossToPlate (plate, isFriend, plateName) -- {{{

        if not plate then
            self:Debug(ERROR, "AddCrossToPlate(), plate is not defined");
            return false;
        end

        if not plateName then
            self:Debug(ERROR, "AddCrossToPlate(), plateName is not defined");
            return false;
        end

        if isFriend==nil then
            isFriend = (LNP:GetReaction(plate) == "FRIENDLY") and true or false;
            self:Debug(ERROR, "AddCrossToPlate(), isFriend was not defined", isFriend);
        end

        PlateAdditions = plate[PLATES__NPH_NAMES[isFriend]];

        if not PlateAdditions then
            plate[PLATES__NPH_NAMES[isFriend]] = {};
            plate[PLATES__NPH_NAMES[isFriend]].isFriend = isFriend;

            AddElements(plate, isFriend, plateName);

            -- self:Debug(INFO, isFriend and "|cff00ff00friendly|r" or "|cffff0000enemy|r", "texture created for", plateName);

        elseif not PlateAdditions.IsShown then

            UpdateTexture(plate, PlateAdditions);
            PlateAdditions.texture:Show();
            PlateAdditions.rankFont:SetText(HHTD.Registry_by_Name[isFriend][plateName].rank);
            PlateAdditions.rankFont:Show();
            PlateAdditions.IsShown = true;


            -- self:Debug(INFO, isFriend and "|cff00ff00friendly|r" or "|cffff0000enemy|r", "texture shown for", plateName);
        end

        plate[PLATES__NPH_NAMES[isFriend]].plateName = plateName;

        self.DisplayedPlates_byFrameTID[isFriend][plate] = plate;

        return true;

    end -- }}}
end

function NPH:HideCrossFromPlate(plate, isFriend, plateName) -- {{{

    if not plate then
        self:Debug(ERROR, "HideCrossFromPlate(), plate is not defined");
        return;
    end

    local plateCross = plate[PLATES__NPH_NAMES[isFriend]];

    if plateCross and plateCross.IsShown then

        --@debug@
        if plateName and plateName ~= plateCross.plateName then
            self:Debug(ERROR, "plateCross.plateName ~= plateName:", plateCross.plateName, plateName);
        end
        --@end-debug@

        plateCross.texture:Hide();
        plateCross.rankFont:Hide();
        plateCross.IsShown = false;

        plateCross.plateName = nil;
        -- self:Debug(INFO2, isFriend and "|cff00ff00Friendly|r" or "|cffff0000Enemy|r", "cross hidden for", plateName);
    end

    self.DisplayedPlates_byFrameTID[isFriend][plate] = nil;

end -- }}}

