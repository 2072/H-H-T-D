--[=[
HealersHaveToDie World of Warcraft Add-on
Copyright (c) 2009-2013 by John Wellesz (Archarodim@teaser.fr)
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
local NPR;


HHTD.Name_Plate_Hooker = HHTD:NewModule("NPH")

local NPH = HHTD.Name_Plate_Hooker;

NPH:SetDefaultModulePrototype( HHTD.MODULE_PROTOTYPE );
NPH:SetDefaultModuleLibraries( "AceConsole-3.0", "AceEvent-3.0");
NPH:SetDefaultModuleState( false );


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

    -- Subscribe to HHTD callbacks
    self:RegisterMessage("HHTD_HEALER_GONE");
    self:RegisterMessage("HHTD_HEALER_BORN");
    self:RegisterMessage("HHTD_HEALER_GROW");

    self:RegisterEvent("PLAYER_ENTERING_WORLD");


    -- Subscribe to callbacks
    self:RegisterMessage("NPR_ON_NEW_PLATE");
    self:RegisterMessage("NPR_ON_RECYCLE_PLATE");
    self:RegisterMessage("NPR_ON_GUID_FOUND");
    self:RegisterMessage("NPR_FATAL_INCOMPATIBILITY");

    NPR = self:GetModule("NPR");
    NPR:Enable();

    local plate;
    for i, isFriend in ipairs({true,false}) do
        -- Add nameplates to known healers by GUID
        for healerGUID, healer in pairs(HHTD.Registry_by_GUID[isFriend]) do

            plate = NPR:GetByGUID(healerGUID);

            if plate then
                self:AddCrossToPlate (plate, isFriend, healer.name);
            end

        end
    end

end -- }}}

function NPH:OnDisable() -- {{{
    self:Debug(INFO2, "OnDisable");

    -- clean all nameplates
    for i, isFriend in ipairs({true,false}) do
        for plateTID, plate in pairs(self.DisplayedPlates_byFrameTID[isFriend]) do
            self:HideCrossFromPlate(plate, isFriend, false, "OnDisable");
        end
    end
end -- }}}
-- }}}



NPH.DisplayedPlates_byFrameTID = { -- used for updating plates dipslay attributes
    [true] = {}, -- for Friendly healers
    [false] = {} -- for enemy healers
};

local Plate_Name_Count = { -- array by name so we have to make the difference between friends and foes
};
local NP_Is_Not_Unique = { -- array by name so we have to make the difference between friends and foes
};


function NPH:PLAYER_ENTERING_WORLD() -- {{{
    self:Debug(INFO2, "Cleaning multi instanced healers data");
    Plate_Name_Count = {};
    NP_Is_Not_Unique = {};
end


-- }}}

-- Internal CallBacks (HHTD_HEALER_GONE -- HHTD_HEALER_BORN -- ON_HEALER_PLATE_TOUCH -- HHTD_MOUSE_OVER_OR_TARGET) {{{
function NPH:HHTD_HEALER_GONE(selfevent, isFriend, healer)
    self:Debug(INFO2, "NPH:HHTD_HEALER_GONE", healer.name, healer.guid, isFriend);

    if not isFriend and not GetCVarBool("nameplateShowEnemies") or isFriend and not GetCVarBool("nameplateShowFriends") then
        self:Debug(INFO2, "NPH:HHTD_HEALER_GONE(): bad state, nameplates disabled",  healer.name, healer.guid, isFriend);
        return;
    end

    
    local plateByGuid;
    if self.db.global.sPve then
        plateByGuid = NPR:GetByGUID(healer.guid);
    end

    for frame, data in NPR:EachByName(healer.name) do
        local plate = plateByGuid or frame;

        --self:Debug(INFO, "Must drop", healer.name);
        self:HideCrossFromPlate(plate, isFriend, healer.name, "HHTD_HEALER_GONE");

        if plateByGuid then
            break;
        end
    end
end

function NPH:HHTD_HEALER_GROW (selfevent, isFriend, healer)
    self:Debug(INFO, 'Updating displayed ranks');
    self:UpdateRanks();
end

function NPH:HHTD_HEALER_BORN (selfevent, isFriend, healer)

    if not isFriend and not GetCVarBool("nameplateShowEnemies") or isFriend and not GetCVarBool("nameplateShowFriends") then
        return;
    end


    local plateByGuid;
    if self.db.global.sPve then
        plateByGuid = NPR:GetByGUID(healer.guid);
    end

    for frame, data in NPR:EachByName(healer.name) do

        local plate = plateByGuid or frame;

        -- we have have access to the correct plate through the unit's GUID or it's uniquely named.
        if plateByGuid or not self.db.global.sPve then
            self:AddCrossToPlate (plate, isFriend, healer.name, healer.guid);

            self:Debug(INFO, "HHTD_HEALER_BORN(): GUID available or unique", NP_Is_Not_Unique[healer.name]);
        else
            self:Debug(WARNING, "HHTD_HEALER_BORN: multi and sPVE and noguid :'( ", healer.name);
        end

        if plateByGuid then
            break;
        end

    end
end

-- }}}

--@alpha@
local callbacks_consisistency_check = {};    
--@end-alpha@


-- Name Plates CallBacks {{{
function NPH:NPR_ON_NEW_PLATE(selfevent, plate, data)

    local plateName = data.name;
    local isFriend = (data.reaction == "FRIENDLY") and true or false;

    --@alpha@

    if not callbacks_consisistency_check[plate] then
        callbacks_consisistency_check[plate] = 1;
    else
        callbacks_consisistency_check[plate] = callbacks_consisistency_check[plate] + 1;
    end

    if self.DisplayedPlates_byFrameTID[true][plate] then
        self:Debug(ERROR, 'NPR_ON_NEW_PLATE() called but no recycling occured for friendly plate, ccc:', callbacks_consisistency_check[plate]);
        error('NPR_ON_NEW_PLATE() called but no recycling occured for _FRIENDLY_ plate' .. callbacks_consisistency_check[plate]);
    elseif self.DisplayedPlates_byFrameTID[false][plate] then
        self:Debug(ERROR, 'NPR_ON_NEW_PLATE() called but no recycling occured for _ENEMY_ plate, ccc:', callbacks_consisistency_check[plate]);
        error('NPR_ON_NEW_PLATE() called but no recycling occured for enemy plate' .. callbacks_consisistency_check[plate]);
    end
    --@end-alpha@

    --@debug@
    -- self:Debug(INFO2, "new plate LNP:IsTarget()?|cff00ff00", LNP:IsTarget(plate) , "|rname:", plateName, 'isFriend?', isFriend, 'alpha:', plate:GetAlpha(),'plate.alpha:', plate.alpha, "plate.unit.alpha:", plate.unit and plate.unit.alpha or nil);
    --@end-debug@

    -- test for uniqueness of the nameplate
    if not Plate_Name_Count[plateName] then
        Plate_Name_Count[plateName] = 1;
    else
        Plate_Name_Count[plateName] = Plate_Name_Count[plateName] + 1;
        if not NP_Is_Not_Unique[plateName] then
            NP_Is_Not_Unique[plateName] = true;
            self:Debug(INFO2, plateName, "is not unique");
        end
    end

    -- Check if this name plate is of interest -- XXX
    if HHTD.Registry_by_Name[isFriend][plateName] then
        
        -- If there are several plates with the same name and sPve is set then
        -- we do nothing since there is no way to be sure
        if NP_Is_Not_Unique[plateName] and self.db.global.sPve then
            self:Debug(INFO2, "new plate but sPve and not unique");
            return;
        end

        self:AddCrossToPlate(plate, isFriend, plateName, data.guid);
        --@alpha@
    else -- it's not a healer
        for i, isFriend in ipairs({true,false}) do
            local plateAdditions = plate[PLATES__NPH_NAMES[isFriend]];

            if plateAdditions and (plateAdditions.IsShown or plateAdditions.texture:IsShown() or plateAdditions.rankFont:IsShown()) then -- check if the plate appeared with our additions shown
                self:Debug(ERROR, "Plate prev-recycling hiding failed: ", plateAdditions.IsShown, plateName, isFriend, data.reaction);
                error("Plate prev-recycling hiding failed: "..tostring(plateAdditions.IsShown).." for " .. plateName .. ' friend:' .. tostring(isFriend) .. '-' .. tostring(data.reaction)); -- seems to trigger when plateadditions are hidden while the plate are being recycled
                -- this means:
                --  New_plate fires before the cross was hidden
                --  New_plate fires before recycle
                --  HideCross fails
            end
        end
        --@end-alpha@
    end
end

function NPH:NPR_ON_RECYCLE_PLATE(selfevent, plate, data)

   --x if LNP.fakePlate[plate] then
        --@debug@
        --self:Debug(INFO2, "NPR_ON_RECYCLE_PLATE(): unused frame received for:", NPR:GetName(plate));
        --@end-debug@
      --x  return;
    --x end

    local plateName = data.name;
    -- local isFriend = (data.reaction == 'FRIENDLY') and true or false;


    --@alpha@
    if not callbacks_consisistency_check[plate] then
        callbacks_consisistency_check[plate] = 0;
    else
        callbacks_consisistency_check[plate] = callbacks_consisistency_check[plate] - 1;
    end
    --@end-alpha@

    --@debug@
    -- self:Debug(INFO, "NPR_ON_RECYCLE_PLATE():", plateName);
    --@end-debug@

    -- unfortunately a plate can change of faction without being hidden first (if a unit gets mind controlled)
    -- so we have to check both sides
    self:HideCrossFromPlate(plate, true,  plateName, "NPR_ON_RECYCLE_PLATE");
    self:HideCrossFromPlate(plate, false, plateName, "NPR_ON_RECYCLE_PLATE");


    -- prevent uniqueness data from stacking
    if Plate_Name_Count[plateName] then

        Plate_Name_Count[plateName] = Plate_Name_Count[plateName] - 1;
        if Plate_Name_Count[plateName] == 0 then
            Plate_Name_Count[plateName] = nil;
        end
    end
end

function NPH:NPR_ON_GUID_FOUND(selfevent, plate, guid)

    if HHTD.Registry_by_GUID[true][guid] or HHTD.Registry_by_GUID[false][guid] then
        self:Debug(INFO, "GUID found");
        self:AddCrossToPlate(plate, HHTD.Registry_by_GUID[true][guid] and true or false, NPR:GetName(plate), guid);
    else
        self:Debug(INFO2, "GUID found but not a healer");
    end

end

function NPH:NPR_FATAL_INCOMPATIBILITY(selfevent, outdated)

    if outdated then
        self:Print("|cFFFF0000ERROR:|rHHTD is outdated and no longer compatible with this version of WoW, you need to update HHTD from Curse.com. The Nameplate Hooker module is now disabled.");
    else
        self:Print("|cFFFF0000ERROR:|rAn add-on is unduly modifying Blizzard's nameplates in a way preventing other add-ons from using them. HHTD is not compatible with such selfish add-ons. The Nameplate Hooker module is now disabled.");
    end

    HHTD:FatalError("The Nameplate Hooker module had to be disabled due to an incompatibility.\nSee the chat window for more details.");

    self:Disable();
end

-- }}}


do
    local SmallFontName = _G.NumberFont_Shadow_Small:GetFont();

    local IsFriend;
    local Plate;
    local PlateAdditions;
    local PlateName;
    local Guid;

    local assert = _G.assert;

    local function SetTextureParams(t) -- MUL XXX
        local profile = NPH.db.global;

        t:SetSize(64 * profile.marker_Scale, 64 * profile.marker_Scale);
        t:SetPoint("BOTTOM", Plate, "TOP", 0 + profile.marker_Xoffset, -20 + profile.marker_Yoffset);
    end

    local function MakeTexture() -- ONCE
        local t = Plate:CreateTexture();

        SetTextureParams(t);

        if IsFriend then
            t:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-RoleS");
            t:SetTexCoord(GetTexCoordsForRole("HEALER"));
        else
            t:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady.blp");
            -- rotate it by Pi/2
            HHTD:RotateTexture(t, 90);
        end

        return t;

    end

    local function MakeFontString(symbol) -- ONCE
        local f = Plate:CreateFontString();
        f:SetFont(SmallFontName, 12.2, "THICKOUTLINE, MONOCHROME");
        
        f:SetTextColor(1, 1, 1, 1);
        
        f:SetPoint("CENTER", symbol, "CENTER", 0, 0);

        return f;
    end

    local function SetRank ()  -- ONCE
        --@alpha@
        assert(PlateAdditions, 'PlateAdditions is not defined'); -- to diagnose issue repoted on 2012-09-07
        assert(PlateAdditions.rankFont, "rankFont is invalid"); -- to diagnose issue repoted on 2012-09-07
        assert(PlateAdditions.rankFont.SetText, "rankFont.SetText is invalid"); -- to diagnose issue repoted on 2012-10-17
        assert(IsFriend == true or IsFriend == false, "IsFriend is invalid"); -- to diagnose issue repoted on 2012-09-07
        --@end-alpha@

         if not Guid then

             if not HHTD.Registry_by_Name[IsFriend][PlateName] then
                 NPH:Debug(ERROR, "HHTD.Registry_by_Name[IsFriend][PlateName] is invalid for plate:", PlateName, "isfriend:", IsFriend, "PlateAdditions.plateName:", PlateAdditions.plateName);
                 --assert(HHTD.Registry_by_Name[IsFriend][PlateName], "HHTD.Registry_by_Name[IsFriend][PlateName] is invalid for plate:" .. tostring(PlateName).. " isfriend:"..tostring(IsFriend).."  PlateAdditions.plateName:" .. tostring(PlateAdditions.plateName)); -- to diagnose issue repoted on 2012-09-07 and 2013-03-11 - and now on 2013-03-19 when player is mind controlled...
             end
             PlateAdditions.rankFont:SetText(NP_Is_Not_Unique[PlateName] and '?' or HHTD.Registry_by_Name[IsFriend][PlateName].rank);
         else
             if not HHTD.Registry_by_GUID[IsFriend][Guid] then
                 NPH:Debug(ERROR, "HHTD.Registry_by_GUID[IsFriend][Guid] is not defined for plate:", PlateName, "isfriend:", IsFriend, "Found with Name:", HHTD.Registry_by_Name[IsFriend][PlateName] and true or false);
                 --assert(HHTD.Registry_by_GUID[IsFriend][Guid], "HHTD.Registry_by_GUID[IsFriend][Guid] is not defined for plate:" .. tostring(PlateName).. " isfriend:"..tostring(IsFriend) .. " Found with Name:"..tostring(HHTD.Registry_by_Name[IsFriend][PlateName] and true or false)); -- to diagnose issue repoted on 2012-10-17 and 2013-03-08
             end
            PlateAdditions.rankFont:SetText(HHTD.Registry_by_GUID[IsFriend][Guid].rank);
        end
    end

    local function UpdateTexture () -- MUL XXX

        if not PlateAdditions.textureUpdate or PlateAdditions.textureUpdate < LAST_TEXTURE_UPDATE then
            --self:Debug(INFO, 'Updating texture');

            SetTextureParams(PlateAdditions.texture);

            PlateAdditions.textureUpdate = GetTime();
        end

    end

    local function AddElements () -- ONCEx
        local texture  = MakeTexture();
        local rankFont = MakeFontString(texture);
        assert(rankFont, "rankFont could not be created"); -- to diagnose issue repoted on 2012-09-07

        PlateAdditions.texture = texture;
        PlateAdditions.texture:Show();
        PlateAdditions.IsShown = true; -- set it as soon as we show something

        PlateAdditions.rankFont = rankFont;
        SetRank();
       
        PlateAdditions.rankFont:Show();


    end

    function NPH:AddCrossToPlate (plate, isFriend, plateName, guid) -- {{{

        if not plate then
            self:Debug(ERROR, "AddCrossToPlate(), plate is not defined");
            return false;
        end

        if not plateName then
            self:Debug(ERROR, "AddCrossToPlate(), plateName is not defined");
            return false;
        end

        if isFriend==nil then
            isFriend = (NPR:GetReaction(plate) == "FRIENDLY") and true or false;
            self:Debug(ERROR, "AddCrossToPlate(), isFriend was not defined", isFriend);
        end

        --@alpha@
        if plateName ~= NPR:GetName(plate) then
            self:Debug(ERROR, 'AddCrossToPlate(): plateName ~= NPR:GetName(plate):', plateName, '-_-', NPR:GetName(plate));
            error('AddCrossToPlate(): plateName ~= NPR:GetName(plate)');
        end
        --@end-alpha@

        -- export useful data
        IsFriend        = isFriend;
        Guid            = guid or NPR:GetGUID(plate);
        Guid            = HHTD.Registry_by_GUID[IsFriend][Guid] and Guid or nil; -- make sure the Guid is actually usable.
        Plate           = plate;
        PlateName       = plateName;
        PlateAdditions  = plate[PLATES__NPH_NAMES[isFriend]];

        if not PlateAdditions then
            plate[PLATES__NPH_NAMES[isFriend]] = {};
            plate[PLATES__NPH_NAMES[isFriend]].isFriend = isFriend;

            PlateAdditions  = plate[PLATES__NPH_NAMES[isFriend]];

            AddElements();

        elseif not PlateAdditions.IsShown then

            UpdateTexture();
            PlateAdditions.texture:Show();
            PlateAdditions.IsShown = true;

            SetRank();

            PlateAdditions.rankFont:Show();

        elseif guid and NP_Is_Not_Unique[plateName] then
            SetRank();
        end

        PlateAdditions.plateName = plateName;

        self.DisplayedPlates_byFrameTID[isFriend][plate] = plate; -- used later to update what was created above

        --@alpha@
        -- IsFriend        = nil;
        -- Guid            = nil;
        -- Plate           = nil;
        -- PlateName       = nil;
        -- PlateAdditions  = nil;
        --@end-alpha@

    end -- }}}

    function NPH:UpdateTextures ()

        LAST_TEXTURE_UPDATE = GetTime();

        for i, isFriend in ipairs({true,false}) do
            for plate in pairs(self.DisplayedPlates_byFrameTID[isFriend]) do

                PlateAdditions  = plate[PLATES__NPH_NAMES[isFriend]];
                Plate           = plate;

                UpdateTexture();

            end
        end

        --@alpha@
        PlateAdditions  = nil;
        PlateName       = nil;
        --@end-alpha@
    end

    function NPH:UpdateRanks ()

        for i, isFriend in ipairs({true,false}) do
            for plate in pairs(self.DisplayedPlates_byFrameTID[isFriend]) do

                IsFriend        = isFriend;
                Plate           = plate;
                PlateAdditions  = plate[PLATES__NPH_NAMES[isFriend]];
                PlateName       = NPR:GetName(plate);
                Guid            = NPR:GetGUID(plate);
                Guid            = HHTD.Registry_by_GUID[IsFriend][Guid] and Guid or nil;

                SetRank();

            end
        end

        --@alpha@
        IsFriend        = nil;
        Plate           = nil;
        PlateName       = nil;
        PlateAdditions  = nil;
        --@end-alpha@
    end

end

function NPH:HideCrossFromPlate(plate, isFriend, plateName, caller) -- {{{

    --@alpha@
    if not plate then
        self:Debug(ERROR, "HideCrossFromPlate(), plate is not defined");
        error("'Plate' is not defined");
        return;
    end
    --@end-alpha@

    local plateAdditions = plate[PLATES__NPH_NAMES[isFriend]];

    --@alpha@
    local testCase1 = false;
    --@end-alpha@

    if plateAdditions and plateAdditions.IsShown then

        --@alpha@
        if plateName and plateName ~= plateAdditions.plateName then
            testCase1 = true;
        end
        --@end-alpha@

        plateAdditions.texture:Hide();
        plateAdditions.rankFont:Hide();
        plateAdditions.IsShown = false;

        plateAdditions.plateName = nil;
        -- self:Debug(INFO2, isFriend and "|cff00ff00Friendly|r" or "|cffff0000Enemy|r", "cross hidden for", plateName);
    end

    self.DisplayedPlates_byFrameTID[isFriend][plate] = nil;

    --@alpha@
    if testCase1 then
        self:Debug(ERROR, "plateAdditions.plateName ~= plateName:", plateAdditions.plateName, "-__-",  plateName, 'CALLER:', caller);
        --error("plateAdditions.plateName ~= plateName, caller:" .. caller);
    end
    --@end-alpha@

end -- }}}

