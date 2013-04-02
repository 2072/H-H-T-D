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
    NamePlateRegistry.lua
-----

This component builds and keep a registry of all the name-plates and provide
callbacks as well as basic analysis of the name plates

TODO:

Make a GUID cache for players (not for NPCs which are not necessarily uniq)
which will keep only 200 names ecedent shall be cleaned on zonning
There will be two cache: friendly and not friendly

==========CALLBACKS
- Show event -- DONE
- Hide event -- DONE
- FoundGuid Event -- DONE for onTarget and onMouseover, enough?

==========METHODS

- GetReaction() (FRIEND, ENEMY, NEUTRAL,...) -- DONE
- IsUniq() -- (cleaned on zoning)
- GetByGUID() -- DONE
- GetByName() -- DONE
- GetName() -- DONE
- GetGUID() -- DONE

=====
-- check debug packager tags consistncy

--]=]

--  module framework {{{
local ERROR     = 1;
local WARNING   = 2;
local INFO      = 3;
local INFO2     = 4;


local ADDON_NAME, T = ...;
local HHTD = T.Healers_Have_To_Die;

-- register the module
HHTD.Name_Plate_Registry = HHTD.Name_Plate_Hooker:NewModule("NPR", "AceTimer-3.0")

local NPR = HHTD.Name_Plate_Registry;
local NPR_ENABLED = false;

-- upvalues {{{
local _G                    = _G;
local GetTime               = _G.GetTime;
local assert                = _G.assert;
local pairs                 = _G.pairs;
local ipairs                = _G.ipairs;
local select                = _G.select;
local unpack                = _G.unpack;
local setmetatable          = _G.setmetatable;
local GetMouseFocus         = _G.GetMouseFocus;
local UnitExists            = _G.UnitExists;
local UnitGUID              = _G.UnitGUID;
local UnitName              = _G.UnitName;

local WorldFrame            = _G.WorldFrame;
local tostring              = _G.tostring;
-- }}}

function NPR:OnInitialize() -- {{{
    self:Debug(INFO, "OnInitialize called!");
end -- }}}

function NPR:OnEnable() -- {{{
    NPR_ENABLED = true;
    self:Debug(INFO, "OnEnable", debugstack(2,1,1));

    self:RegisterEvent("PLAYER_ENTERING_WORLD");
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    --self:RegisterEvent("RAID_TARGET_UPDATE")

    self.PlateCheckTimer = self:ScheduleRepeatingTimer("LookForNewPlates", 0.1);

    --@alpha@
    self.DebugTestsTimer = self:ScheduleRepeatingTimer("DebugTests", 1);
    self.Debug_CheckHookSanityTimer = self:ScheduleRepeatingTimer("Debug_CheckHookSanity", 0.1);
    --@end-alpha@

    local success, errorm = pcall(self.LookForNewPlates, self); -- make sure we do it once as soon as possible to hook things first in order to detect baddons...

    if not success and not errorm:find("CFCache") then
        self:Debug(ERROR, errorm);
    end

end -- }}}

function NPR:OnDisable() -- {{{
    self:Debug(INFO2, "OnDisable");
    self:CancelTimer(self.PlateCheckTimer);
    self:CancelTimer(self.TargetCheckTimer);
    --@alpha@
    self:CancelTimer(self.DebugTestsTimer);
    self:CancelTimer(self.Debug_CheckHookSanityTimer);
    --@end-alpha@

    NPR_ENABLED = false;
end -- }}}


--  }}}

-- working set
local PlateRegistry_per_frame   = {};
local ActivePlates_per_frame    = {};

local CurrentTarget             = false;
local HasTarget                 = false;
local TargetCheckScannedAll     = false; -- useful when a target exists but it cannot be found (ie: not on screen)

-- frame children and regions cache

local function abnormalNameplateManifest()

    local HHTDMaxTOC = tonumber(GetAddOnMetadata("Healers-Have-To-Die", "X-Max-Interface") or math.huge); -- once GetAddOnMetadata() was bugged and returned nil...

    NPR:OnDisable(); -- cancel all timers right now
    NPR:ScheduleTimer("SendMessage", 0.01, "NPR_FATAL_INCOMPATIBILITY", T._tocversion > HHTDMaxTOC); -- sending the message while the initisalisation is in progress is not working as expected
    --NPR:SendMessage("NPR_FATAL_INCOMPATIBILITY", T._tocversion > HHTDMaxTOC );
    
end



local FrameChildrenCache = setmetatable({}, {__index =
-- frame cache
function(t, frame)

    t[frame] = setmetatable({}, {__index =
            -- children per number cache
            function(t, childNum)

                t[childNum] = (select(childNum, frame:GetChildren())) or false;

                if not t[childNum] then
                    t[childNum] = nil;
                    abnormalNameplateManifest();
                    error("CFCache: Child" .. childNum .. " not found.");
                end

                --@alpha@
                NPR:Debug(INFO, 'cached a new frame child', childNum);
                --@end-alpha@
                return  t[childNum];

            end
        })
    
    return t[frame];
end

});

local FrameRegionsCache = setmetatable({}, {__index =
-- frame cache
function(t, frame)
    -- region cache
    t[frame] = setmetatable({}, {__index =
            -- children per number cache
            function(t, regionNum)

                t[regionNum] = (select(regionNum, frame:GetRegions())) or false;

                if not t[regionNum] then
                    t[regionNum] = nil;
                    abnormalNameplateManifest();
                    error( "CFCache: Region" .. regionNum .. " not found.");
                end

                --@alpha@
                NPR:Debug(INFO, 'cached a new frame region', regionNum);
                --@end-alpha@
                return t[regionNum];

            end
        })
        return t[frame];
    end
});


local PlatePartCache = setmetatable ({}, {__index =

function (t, plateFrame)
    t[plateFrame] = setmetatable({}, {__index =
        function (t, regionName)
            if regionName == 'name' then
                t[regionName] = FrameRegionsCache[  FrameChildrenCache[plateFrame][2]  ][1];
            elseif regionName == 'statusBar' then
                t[regionName] = FrameChildrenCache[  FrameChildrenCache[plateFrame][1]  ][1];
            elseif regionName == 'highlight' then
                t[regionName] = FrameRegionsCache[  FrameChildrenCache[plateFrame][1]  ][3];
            end
            --@alpha@
            NPR:Debug(INFO, 'cached a new plateFrame part:', regionName);
            --@end-alpha@
            return t[regionName];
        end
    })
    return t[plateFrame];
end
})

local ValidateCache, UpdateCache;

--Name to GUID cache for players (their GUID are constant)
local AddGUIDToCache, GetGUIDFromCache;
do
    local NameToGUID = {['FRIENDLY'] = {}, ['HOSTILE'] = {}, ["NEUTRAL"] = {}};
    local KnownNames = {};
    local data, oldName;
    local LIMIT = 200;
    local CurrentCacheIndex = 1;


    function AddGUIDToCache(data)

        if data.type ~= 'PLAYER' then
            return;
        end

        oldName = KnownNames[CurrentCacheIndex];

        if oldName then
            if NameToGUID['FRIENDLY'][oldName] then NameToGUID['FRIENDLY'][oldName] = nil; end
            if NameToGUID['HOSTILE'][oldName]  then NameToGUID['HOSTILE'] [oldName] = nil; end
            if NameToGUID['NEUTRAL'][oldName]  then NameToGUID['NEUTRAL'] [oldName] = nil; end
        end

        KnownNames[CurrentCacheIndex] = data.name;

        NameToGUID[data.reaction][data.name] = data.GUID;

        CurrentCacheIndex = (CurrentCacheIndex < LIMIT) and (CurrentCacheIndex + 1) or 1;
        NPR:Debug(INFO, 'AddGUIDToCache() CurrentCacheIndex=', CurrentCacheIndex);
    end


    function GetGUIDFromCache(frame)
        data = ActivePlates_per_frame[frame];

        if data.type ~= 'PLAYER' then
            return false;
        end

        return NameToGUID[data.reaction][data.name] or false;
    end

end

-- bits

local function IsPlateTargeted (frame)
    if not HasTarget then
        return false;
    end

    if CurrentTarget == frame then -- we already told you
        NPR:Debug(WARNING, 'CurrentTarget == frame');
        return true;
    elseif CurrentTarget then -- we know it's not that one
        return false;
    end

    if not ActivePlates_per_frame[frame] or not ActivePlates_per_frame[frame].name then -- it's not even on the screen...
        return false;
    end

    CurrentTarget = frame:GetAlpha() == 1 and frame or false;

    return CurrentTarget == frame;
end

local function IsPlatMouseOvered (frame)
end

local function RawGetPlateName (frame)
    return PlatePartCache[frame].name:GetText();
end

local RawGetPlateType;

--@alpha@
local DiffColors = { ['r'] = {}, ['g'] = {}, ['b'] = {}, ['a'] = {} };
local DiffColors_ExpectedDiffs = 0;
--@end-alpha@

do

    local function TypeFromColor (r, g, b, a)

        --@alpha@
        DiffColors['r'][r] = true;
        DiffColors['g'][g] = true;
        DiffColors['b'][b] = true;
        DiffColors['a'][a] = true;
        --@end-alpha@


        -- the following block is borrowed from TidyPlates
        if r < .01 then 	-- Friendly
            if b < .01 and g > .99 then return "FRIENDLY", "NPC" 
            elseif b > .99 and g < .01 then return "FRIENDLY", "PLAYER"
            end
        elseif r > .99 then
            if b < .01 and g > .99 then return "NEUTRAL", "NPC"
            elseif b < .01 and g < .01 then return "HOSTILE", "NPC" 
            end
        elseif r > .53 then
            if g > .5 and g < .6 and b > .99 then return "TAPPED", "NPC" end 	-- .533, .533, .99	-- Tapped Mob
        end
        return "HOSTILE", "PLAYER" 

    end

    function RawGetPlateType (frame)
        --return ((select(2, frame:GetChildren())):GetRegions()):GetText();
        return TypeFromColor( PlatePartCache[frame].statusBar:GetStatusBarColor() );
    end
end

--@alpha@
local LastThrow = 0;
function NPR:Debug_CheckHookSanity()

    local count = 0;


    for frame, data in pairs(PlateRegistry_per_frame) do

        count = count + 1;

        if frame:IsShown()then
            if not ActivePlates_per_frame[frame] then
                if GetTime() - LastThrow > 4 then
                    LastThrow = GetTime();
                    error("Debug_CheckHookSanity(): OnShow hook failed");
                end
            end
        else
            if ActivePlates_per_frame[frame] then
                if GetTime() - LastThrow > 3 then
                    LastThrow = GetTime();
                    error("Debug_CheckHookSanity(): OnHide hook failed");
                end
            end
        end
    end

    -- self:Debug(INFO2, 'Debug_CheckHookSanity():', count, 'tests done');

end
--@end-alpha@

--@alpha@
local callbacks_consisistency_check = {};    
--@end-alpha@

local PlateOnShow, PlateOnHide, PlateOnChange;
do -- {{{
    local PlateFrame, PlateData, PlateName;
        --@alpha@
    local testCase1 = false;
        --@end-alpha@

    function PlateOnShow (healthBar)
        --NPR:Debug(INFO, "PlateOnShow", healthBar.HHTDParentPlate:GetName());

        if not NPR_ENABLED then -- it can already have been hidden...
            return;
        end

        PlateFrame = healthBar.HHTDParentPlate;

        --@alpha@
        testCase1 = false;
        if ActivePlates_per_frame[PlateFrame] then -- test onHide hook
            testCase1 = true;
        end

        if not callbacks_consisistency_check[PlateFrame] then
            callbacks_consisistency_check[PlateFrame] = 1;
        else
            callbacks_consisistency_check[PlateFrame] = callbacks_consisistency_check[PlateFrame] + 1;
        end

        if callbacks_consisistency_check[PlateFrame] ~= 1 then
            NPR:Debug(ERROR, 'PlateOnShow/hide sync broken:', callbacks_consisistency_check[PlateFrame]);
        end

        --@end-alpha@

        PlateData = PlateRegistry_per_frame[PlateFrame];
        PlateName = RawGetPlateName(PlateFrame);

        ActivePlates_per_frame[PlateFrame] = PlateData;

        if CurrentTarget == PlateFrame then
            CurrentTarget = false; -- it can't be true --> recycling occured obviously
        end
        TargetCheckScannedAll = false;


        PlateData.name = PlateName;
        PlateData.reaction, PlateData.type = RawGetPlateType(PlateFrame);
        PlateData.GUID = GetGUIDFromCache(PlateFrame);

        --@debug@
        --if PlateData.GUID then
        --NPR:Debug(INFO, 'GUID was set during onshow for ', PlateData.name);
        --HHTD:Hickup(10);
        --end
        --@end-debug@

        NPR:SendMessage("NPR_ON_NEW_PLATE", PlateFrame, PlateData);

        --@alpha@
        if testCase1 then
            error('onHide() failed for ' .. tostring(RawGetPlateName(PlateFrame)));
        end
        --@end-alpha@
    end

    function PlateOnHide (healthBar)
        --NPR:Debug(INFO2, "PlateOnHide", healthBar.HHTDParentPlate:GetName());

        if not NPR_ENABLED then
            return;
        end

        PlateFrame = healthBar.HHTDParentPlate;

        --@alpha@

        if not callbacks_consisistency_check[PlateFrame] then
            callbacks_consisistency_check[PlateFrame] = 0;
        else
            callbacks_consisistency_check[PlateFrame] = callbacks_consisistency_check[PlateFrame] - 1;
        end

        local testCase1 = false
        if not ActivePlates_per_frame[PlateFrame] then
            testCase1 = true;
        end
        --@end-alpha@

        PlateData = PlateRegistry_per_frame[PlateFrame];
        PlateData.GUID = false;

        UpdateCache(PlateFrame); -- make sure everything is accurate
        NPR:SendMessage("NPR_ON_RECYCLE_PLATE", PlateFrame, PlateData);


        if PlateFrame == CurrentTarget then
            CurrentTarget = false;
            NPR:Debug(INFO2, 'Current Target\'s plate was hidden');
        end

        ActivePlates_per_frame[PlateFrame] = nil;

        --@alpha@
        if testCase1 then
            error('onShow() failed for ' .. tostring(RawGetPlateName(PlateFrame)));
        end
        --@end-alpha@
    end

    function PlateOnChange (healthBar)
        PlateFrame = healthBar.HHTDParentPlate;

        PlateData = ActivePlates_per_frame[PlateFrame];

        if not PlateData then
            return;
        end

        -- if the name has changed or the reaction is different then trigger a recycling
        if PlateData.name ~= RawGetPlateName(PlateFrame) or PlateData.reaction ~= (RawGetPlateType(PlateFrame)) then
            --@alpha@
            NPR:Debug(WARNING, "PlateOnChange for '", PlateData.name, "' rawName:'", RawGetPlateName(PlateFrame), 'r:', PlateData.reaction, PlateData.type, 'rawr:',  RawGetPlateType(PlateFrame));
            --@end-alpha@
            NPR:SendMessage("NPR_ON_RECYCLE_PLATE", PlateFrame, PlateData);

            UpdateCache(PlateFrame);

            NPR:SendMessage("NPR_ON_NEW_PLATE", PlateFrame, PlateData);
        end

    end
end -- }}}

--@alpha@
 local ShownPlateCount = 0;
 local DiffColorsCount = 0;
function NPR:DebugTests()
    if not HHTD.db.global.Debug then return end;

    -- check displayed plates
    local count = 0; local names = {};
    for frame in pairs(ActivePlates_per_frame) do
        count = count + 1;
        --table.insert(names, PlateRegistry_per_frame[frame].name);
        --table.insert(names, '['.. PlateRegistry_per_frame[frame].type .. ']' .. ', ');
    end

    if count ~= ShownPlateCount then
        ShownPlateCount = count;
        self:Debug(INFO2, DiffColorsCount, ' dCs - ', ShownPlateCount, 'plates are shown:', unpack(names));
    end

    -- check number of different health bars colors
    local counts = {['r'] = 0, ['g'] = 0, ['b'] = 0, ['a'] = 0};
    count = 0;
    for component,values in pairs(DiffColors) do
        for value in pairs(values) do
            counts[component] = counts[component] + 1;
            count = count + 1;
        end
    end

    if count ~= DiffColorsCount then

        DiffColorsCount = count;
        self:Debug(INFO2, DiffColorsCount, 'health colors:', 'r=', counts['r'], 'g=', counts['g'], 'b=', counts['b'], 'a=', counts['a']);
end

end
--@end-alpha@

-- Event handlers {{{

function NPR:PLAYER_ENTERING_WORLD(eventName)
end

function NPR:PLAYER_TARGET_CHANGED()

    --self:Debug(INFO, 'Target Changed');
    if UnitExists('target') then
        CurrentTarget = (self:GetByGUID(UnitGUID('target'))) or false;
        HasTarget = true;
        TargetCheckScannedAll = false;
        if not self.TargetCheckTimer then
            self.TargetCheckTimer = self:ScheduleRepeatingTimer("CheckPlatesForTarget", 0.3);
        end
    else
        CurrentTarget = false; -- we don't know anymore
        HasTarget = false;
        self:CancelTimer(self.TargetCheckTimer);
        self.TargetCheckTimer = false;
    end

end

function NPR:UPDATE_MOUSEOVER_UNIT()

    local unitName = "";
    if GetMouseFocus() == WorldFrame then -- the cursor is either on a name plate or on a 3d model (ie: not on a unit-frame)
        --self:Debug(INFO, "UPDATE_MOUSEOVER_UNIT");

        for frame, data in pairs(ActivePlates_per_frame) do
            if not data.GUID and PlatePartCache[frame].highlight:IsShown() then -- test for highlight among shown plates

                data.GUID = UnitGUID('mouseover');
                unitName = UnitName('mouseover');

                if unitName == data.name and ValidateCache(frame, 'name') == 0 then
                    AddGUIDToCache(data);
                    self:SendMessage("NPR_ON_GUID_FOUND", frame, data.GUID, 'mouseover');
                    --@debug@
                    self:Debug(INFO, 'Guid found for', data.name, 'mouseover');
                    --@end-debug@

                    break; -- we found what we were looking for, no need to continue
               end
                
                
            end
        end
    end
end

function NPR:RAID_TARGET_UPDATE(eventName)
end

-- }}}

do

    local hooksecurefunc = _G.hooksecurefunc;
    local WorldFrame = WorldFrame
    local WorldFrameChildrenNumber = 0;
    local temp = 0;
    local frameName;

    local NotPlateCache = {};
    local DidSnitched = false;
    local HealthBar;

    local function SetParentAlert (frame)

        if DidSnitched then
            return;
        end

        local baddon = HHTD:GetBAddon(2);

        if baddon then
            DidSnitched = true;

            local alertMessage = "|cFFFF0000WARNING:|r Apparently the add-on |cffee2222" .. baddon:upper() .. "|r is reparenting Blizzard's nameplates elements. This prevent any other add-on from reading or modifying nameplates. You should contact |cffee2222" .. baddon:upper() .. "|r's author about this. FYI HHTD is compatible with TidyPlates...";

            NPR:Print(alertMessage);
            HHTD:FatalError(alertMessage);
        end

    end

    local function SetScriptAlert(frame, script, func)

        -- re-apply our hooks then...
        if script == "OnShow" then
            frame:HookScript("OnShow", PlateOnShow);
        elseif script == "OnHide" then
            frame:HookScript("OnHide", PlateOnHide);
        elseif script == "OnMinMaxChanged" then
            frame:HookScript("OnMinMaxChanged", PlateOnChange);
        end

        --@alpha@
        --NPR:Debug(WARNING, "SetScript(OnSHow/Onhide) detected", frame, frame:GetName(), script);
        --@end-alpha@

        if not DidSnitched then
            local baddon = HHTD:GetBAddon(2);
            -- try to identify and report the add-on doing this selfish and stupid thing
            if baddon then
                DidSnitched = true;
                NPR:Print("|cFFFF0000WARNING:|r Apparently the add-on|cffee2222", baddon:upper(), "|ris using |cFFFFAA55:SetScript()|r instead of |cFF00DD00:HookScript()|r on Blizzard's nameplates. This will cause many issues with other add-ons relying on nameplates. You should contact|cffee2222", baddon:upper(), "|r's author about this.");
            end
        end
    end

    local function IsPlate (frame)

        if NotPlateCache[frame] then
            --@debug@
            NPR:Debug(INFO, 'not plate cache used');
            --@end-debug@
            return false
        end

        frameName = frame:GetName();
        if frameName and frameName:sub(1,9) == 'NamePlate' then
            return true;
        end

        NotPlateCache[frame] = true;

        return false;
    end

    local function RegisterNewPlates (worldChild, ...)

        if not worldChild then
            --@alpha@
            NPR:Debug(INFO, 'No more children', temp, 'frames checked');
            --@end-alpha@
            return;
        end

        --@alpha@
        temp = temp + 1;
        --@end-alpha@

        if not PlateRegistry_per_frame[worldChild] and worldChild:IsShown() and IsPlate(worldChild) then
            --@alpha@
            NPR:Debug(INFO, 'New plate frame (fname: ', worldChild:GetName() , ')');
            --@end-alpha@

            -- keep a reference
            PlateRegistry_per_frame[worldChild] = {};

            HealthBar = FrameChildrenCache[ FrameChildrenCache[worldChild][1] ][1];
            HealthBar.HHTDParentPlate = worldChild;

            -- hooks show and hide event
            HealthBar:HookScript("OnShow", PlateOnShow);
            HealthBar:HookScript("OnHide", PlateOnHide);
            HealthBar:HookScript("OnMinMaxChanged", PlateOnChange);
            hooksecurefunc(HealthBar, 'SetScript', SetScriptAlert);
            hooksecurefunc(HealthBar, 'SetParent', SetParentAlert);

            -- since we're here it means the frame is already shown
            PlateOnShow(HealthBar);



            --@alpha@
        elseif PlateRegistry_per_frame[worldChild] then

            assert(not ActivePlates_per_frame[worldChild] == not worldChild:IsShown(), 'OnHide/Show hook failure: ' .. tostring(ActivePlates_per_frame[worldChild]).." != "..tostring(worldChild:IsShown()));
            
            --@end-alpha@
        end

        RegisterNewPlates(...);

    end

    function NPR:LookForNewPlates()
        temp =  WorldFrame:GetNumChildren();

        if temp ~= WorldFrameChildrenNumber then

            --@alpha@
            self:Debug(INFO, "WorldFrame gave birth to", temp - WorldFrameChildrenNumber);
            --@end-alpha@

            WorldFrameChildrenNumber = temp;

            --@alpha@
            temp = 0; -- used to count the number of checked frame for profiling purposes
            --@end-alpha@
            RegisterNewPlates(WorldFrame:GetChildren());
        end
    end


    function NPR:CheckPlatesForTarget() -- run by a timer, only active when a target exists
        local unitName = "";

        if CurrentTarget or TargetCheckScannedAll or not HasTarget then return; end

        --@debug@
        self:Debug(INFO, 'looking for targeted plate');
        --@end-debug@

        for frame, data in pairs(ActivePlates_per_frame) do
            if not data.GUID and IsPlateTargeted(frame) then

                data.GUID = UnitGUID('target');
                unitName = UnitName('target');

                if unitName == data.name and ValidateCache(frame, 'name') == 0 then
                    AddGUIDToCache(data);
                    self:SendMessage("NPR_ON_GUID_FOUND", frame, data.GUID, 'target');
                    --@debug@
                    self:Debug(INFO, 'Guid found for', data.name, 'target');
                    --@end-debug@
                end

                break; -- there can be only one target
            end
        end

        TargetCheckScannedAll = true; -- no need to scan continuously if no new name plate are shown
    end

end

do

    local PlateData;

    function UpdateCache (plateFrame)
        PlateData = ActivePlates_per_frame[plateFrame];

        PlateData.name = RawGetPlateName(plateFrame);
        PlateData.reaction, PlateData.type = RawGetPlateType(plateFrame);
        PlateData.GUID = GetGUIDFromCache(plateFrame);
    end

    local function IsGUIDValid (plateFrame)
        if ActivePlates_per_frame[plateFrame].GUID and ActivePlates_per_frame[plateFrame].name == RawGetPlateName(plateFrame) then
            return ActivePlates_per_frame[plateFrame].GUID;
        else
            ActivePlates_per_frame[plateFrame].GUID = false;
            return false;
        end
    end

    local Getters = {
        ['name'] = RawGetPlateName,
        ['reaction'] = RawGetPlateType, -- 1st
        ['type'] = function (plateFrame) return select(2, RawGetPlateType(plateFrame)); end, -- 2nd
        ['GUID'] = IsGUIDValid,
    };
    function ValidateCache (plateFrame, entry)
        PlateData = ActivePlates_per_frame[plateFrame];

        if not PlateData then
            return -1;
        end

        if not PlateData[entry] then
            return -2;
        end

        if PlateData[entry] == (Getters[entry](plateFrame)) then
            return 0;
        else
            NPR:Debug(WARNING, 'Cache validation failed for entry', entry, 'on plate named', PlateData.name);
            UpdateCache(plateFrame);
            return 1;
        end
    end
end

-- public meant methods

function NPR:GetName(plateFrame)

    --@alpha@
    if ActivePlates_per_frame[plateFrame] and ActivePlates_per_frame[plateFrame].name and ActivePlates_per_frame[plateFrame].name ~= RawGetPlateName(plateFrame) then
        error('GN: Nameplate inconsistency detected: rpn:' .. tostring(ActivePlates_per_frame[plateFrame].name) .. ' rawpn:' .. tostring(RawGetPlateName(plateFrame)));
    end
    --@end-alpha@

    return ActivePlates_per_frame[plateFrame] and ActivePlates_per_frame[plateFrame].name or nil;
end

function NPR:GetReaction (plateFrame)
    return ActivePlates_per_frame[plateFrame] and ActivePlates_per_frame[plateFrame].reaction or nil;
end

function NPR:GetType (plateFrame)
    return ActivePlates_per_frame[plateFrame] and ActivePlates_per_frame[plateFrame].type or nil;
end

function NPR:GetGUID (plateFrame)
    return ActivePlates_per_frame[plateFrame] and ActivePlates_per_frame[plateFrame].GUID or nil;
end

function NPR:GetByGUID (GUID)

    if GUID then
        for frame, data in pairs(ActivePlates_per_frame) do
            if data.GUID == GUID and ValidateCache(frame, 'GUID') == 0 then
                return frame, data;
            end
        end
    end

    return nil;

end

do
    local CurrentPlate;
    local Data, Name;
    local next = _G.next;
    local function iter ()
        CurrentPlate, Data = next (ActivePlates_per_frame, CurrentPlate);

        if not CurrentPlate then
            return nil;
        end

        if Name == Data.name and ValidateCache(CurrentPlate, 'name') == 0 then -- ValidateCache() will fail only rarely (upon mind controll events) so it's not a big deal if we miss a few frames then... (to keep in mind)
            return CurrentPlate, Data;
        else
            return iter();
        end

    end
    function NPR:EachByName (name)
        CurrentPlate = nil;
        Name = name;

        return iter;
    end
end











--[=============[
function NPR:GetByName (name) -- XXX returns just one if several name plates have the same name...

    --@alpha@
    assert(name, "name cannot be nil or false");
    --@end-alpha@

    for frame, data in pairs(ActivePlates_per_frame) do
        if data.name == name and ValidateCache(frame, 'name') == 0 then
            --@alpha@
            if RawGetPlateName(frame) ~= name then
                error('GBN: Nameplate inconsistency detected: n:' .. tostring(name) ..  ' rawpn:' .. tostring(RawGetPlateName(frame)) );
            end
            --@end-alpha@
            return frame, data;
        end
    end

    return nil;

end
--]=============]
