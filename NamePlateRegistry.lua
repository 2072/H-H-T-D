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


-- upvalues {{{
local _G                    = _G;
local GetCVarBool           = _G.GetCVarBool;
local GetTime               = _G.GetTime;
local pairs                 = _G.pairs;
local ipairs                = _G.ipairs;
local select                = _G.select;
local CreateFrame           = _G.CreateFrame;
local GetTexCoordsForRole   = _G.GetTexCoordsForRole;
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
    self:Debug(INFO, "OnEnable");

    self:RegisterEvent("PLAYER_ENTERING_WORLD");
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    --self:RegisterEvent("RAID_TARGET_UPDATE")

    self.PlateCheckTimer = self:ScheduleRepeatingTimer("LookForNewPlates", 0.1);

    --@alpha@
    self.DebugTestsTimer = self:ScheduleRepeatingTimer("DebugTests", 1);
    self.Debug_CheckHookSanityTimer = self:ScheduleRepeatingTimer("Debug_CheckHookSanity", 0.1);
    --@end-alpha@

end -- }}}

function NPR:OnDisable() -- {{{
    self:Debug(INFO2, "OnDisable");
    self:CancelTimer(self.PlateCheckTimer);
    self:CancelTimer(self.TargetCheckTimer);
    --@alpha@
    self:CancelTimer(self.DebugTestsTimer);
    self:CancelTimer(self.Debug_CheckHookSanityTimer);
    --@end-alpha@
end -- }}}


--  }}}

-- working set
local PlateRegistry_per_frame   = {};
local ActivePlates_per_frame    = {};

local CurrentTarget             = false;
local HasTarget                 = false;
local TargetCheckScannedAll     = false; -- useful when a target exists but it cannot be found (ie: not on screen)

-- frame children and regions cache


local FrameChildrenCache = setmetatable({}, {__index =
-- frame cache
function(t, frame)

    t[frame] = setmetatable({}, {__index =
            -- children per number cache
            function(t, childNum)

                t[childNum] = (select(childNum, frame:GetChildren())) or false;
                --@alpha@
                assert(t[childNum], "CFCache: Child" .. childNum .. " not found.");
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
                --@alpha@
                assert(t[regionNum], "CFCache: Region" .. regionNum .. " not found.");
                NPR:Debug(INFO, 'cached a new frame region', regionNum);
                --@end-alpha@
                return t[regionNum];

            end
        })
        return t[frame];
    end
});

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
        data = PlateRegistry_per_frame[frame];

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
    --return ((select(2, frame:GetChildren())):GetRegions()):GetText();
    return FrameRegionsCache[  FrameChildrenCache[frame][2]  ][1]:GetText();
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
        return TypeFromColor( FrameChildrenCache[  FrameChildrenCache[frame][1]  ][1]:GetStatusBarColor() );

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

local function PlateOnShow (frame, delayed_previousName)
    --NPR:Debug(INFO, "PlateOnShow", frame:GetName());

    if delayed_previousName and not ActivePlates_per_frame[frame] then -- it can already have been hidden...
        return
    end;

    --@alpha@
    local testCase1 = false;
    if not delayed_previousName and ActivePlates_per_frame[frame] then -- test onHide hook
        testCase1 = true;
    end
    --@end-alpha@

    local data = PlateRegistry_per_frame[frame];
    local oldName = data.name;
    local newName = RawGetPlateName(frame);

    ActivePlates_per_frame[frame] = data;

    if newName ~= oldName then
        if CurrentTarget == frame then
            CurrentTarget = false; -- it can't be true --> recycling occuered
        end

        TargetCheckScannedAll = false;


        data.name = newName;
        data.reaction, data.type = RawGetPlateType(frame);


        -- it's not safe to test for plate attribute now because they are not accurate at this stage...
        data.GUID = GetGUIDFromCache(frame);

        --@debug@
        --if data.GUID then
            --NPR:Debug(INFO, 'GUID was set during onshow for ', data.name);
            --HHTD:Hickup(10);
        --end
        --@end-debug@

        NPR:SendMessage("NPR_ON_NEW_PLATE", frame, data);

        --@alpha@
        if delayed_previousName and delayed_previousName ~= newName then
            error('previousName('..tostring(delayed_previousName)..') ~= newName('..tostring(newName)..')');
        end
        --@end-alpha@

    else -- reschedule this onshow
        data.reaction, data.type, data.name = nil, nil, nil; -- clear the old datas, we delay only once...
        NPR:ScheduleTimer(PlateOnShow, 0.1, frame, newName);
        --NPR:Debug(WARNING, 'Name did not change, waiting before sending onshow event', newName);
    end

    --@alpha@
    if testCase1 then
        error('onHide() failed for ' .. tostring(RawGetPlateName(frame)));
    end
    --@end-alpha@
end

local function PlateOnHide (frame)
    --NPR:Debug(INFO2, "PlateOnHide", frame:GetName());

    --@alpha@
    local testCase1 = false
    if not ActivePlates_per_frame[frame] then
        testCase1 = true;
    end
    --@end-alpha@

    local data;

    data = PlateRegistry_per_frame[frame];
    ActivePlates_per_frame[frame] = nil;
    data.GUID = false;

    if data.name then -- only trigger the recycling if we sent a NPR_ON_NEW_PLATE
        NPR:SendMessage("NPR_ON_RECYCLE_PLATE", frame, data);
    end

    if frame == CurrentTarget then
        CurrentTarget = false;
        NPR:Debug(INFO2, 'Current Target\'s plate was hidden');
    end
    --@alpha@
    if testCase1 then
        error('onShow() failed for ' .. tostring(RawGetPlateName(frame)));
    end
    --@end-alpha@
end

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
            if data.name and not data.GUID and FrameRegionsCache[  FrameChildrenCache[frame][1]  ][3]:IsShown() then -- test for highlight among shown plates

                data.GUID = UnitGUID('mouseover');
                unitName = UnitName('mouseover');

                if unitName == data.name then
                    AddGUIDToCache(data);
                    self:SendMessage("NPR_ON_GUID_FOUND", frame, data.GUID, 'mouseover');
                    --@debug@
                    self:Debug(INFO, 'Guid found for', data.name, 'mouseover');
                    --@end-debug@
                else
                    error('UMU: Nameplate inconsistency detected: un:' .. tostring(unitName) .. ' rpn:'..tostring(data.name) .. ' rawpn:' .. tostring(RawGetPlateName(frame)));
                    -- TODO recycle the nameplate if that happens
                end
                
                
                break; -- we found what we were looking for, no need to continue
            end
        end
    end
end

function NPR:RAID_TARGET_UPDATE(eventName)
end

-- }}}

do

    local WorldFrame = WorldFrame
    local WorldFrameChildrenNumber = 0;
    local temp = 0;
    local frameName;

    local NotPlateCache = {};


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
            -- hooks show and hide event
            worldChild:HookScript("OnShow", PlateOnShow);
            worldChild:HookScript("OnHide", PlateOnHide);

            -- since we're here it means the frame is already shown
            PlateOnShow(worldChild);



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
            if data.name and not data.GUID and IsPlateTargeted(frame) then
                data.GUID = UnitGUID('target');
                unitName = UnitName('target');
                if unitName == data.name then
                    AddGUIDToCache(data);
                    self:SendMessage("NPR_ON_GUID_FOUND", frame, data.GUID, 'target');
                    --@debug@
                    self:Debug(INFO, 'Guid found for', data.name, 'target');
                    --@end-debug@
                else
                    error('CPFT: Nameplate inconsistency detected: un:' .. tostring(unitName) .. ' rpn:'..tostring(data.name) .. ' rawpn:' .. tostring(RawGetPlateName(frame)));
                end

                break; -- there can be only one target
            end
        end

        TargetCheckScannedAll = true; -- no need to scan continuously if no new name plate are shown
    end

end

-- public meant methods

function NPR:GetName(plateFrame)

    --@alpha@
    if PlateRegistry_per_frame[plateFrame] and PlateRegistry_per_frame[plateFrame].name and PlateRegistry_per_frame[plateFrame].name ~= RawGetPlateName(plateFrame) then
        error('GN: Nameplate inconsistency detected: rpn:' .. tostring(PlateRegistry_per_frame[plateFrame].name) .. ' rawpn:' .. tostring(RawGetPlateName(plateFrame)));
    end
    --@end-alpha@

    return PlateRegistry_per_frame[plateFrame] and PlateRegistry_per_frame[plateFrame].name or nil;
end

function NPR:GetReaction (plateFrame)
    return PlateRegistry_per_frame[plateFrame] and PlateRegistry_per_frame[plateFrame].reaction or nil;
end

function NPR:GetType (plateFrame)
    return PlateRegistry_per_frame[plateFrame] and PlateRegistry_per_frame[plateFrame].type or nil;
end

function NPR:GetGUID (plateFrame)
    return PlateRegistry_per_frame[plateFrame] and PlateRegistry_per_frame[plateFrame].GUID or nil;
end

function NPR:GetByGUID (GUID)

    for frame, data in pairs(ActivePlates_per_frame) do
        if data.GUID == GUID and data.name then
            return frame, data;
        end
    end

    return nil;

end

do
    local CurrentPlate;
    local Data, Name;
    local function iter ()
        CurrentPlate, Data = next (ActivePlates_per_frame, CurrentPlate);

        if not CurrentPlate then
            return nil;
        end

        if Name == Data.name then
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

function NPR:GetByName (name) -- XXX returns just one if several name plates have the same name...

    --@alpha@
    assert(name, "name cannot be nil or false");
    --@end-alpha@

    for frame, data in pairs(ActivePlates_per_frame) do
        if data.name == name then
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
