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
    GraphicalReporter.lua
-----

This component displays a list of known healers with a proximity sensor, the list is click-able and will run a targeting macro
- it may also focus them
- trigger a chosen spell
- should not ring when target through macro

--]=]


local addonName, T = ...;
local hhtd = T.hhtd;
local L = hhtd.L;

hhtd.GEH = {};

local GEH = hhtd.GEH;
GEH.prototype = {};
GEH.metatable ={ __index = GEH.prototype };

GEH.EHo_count = 0;
GEH.Initialized = false;


function GEH:new(...)
    local instance = setmetatable({}, self.metatable);
    instance:init(...);
    return instance;
end

function GEH:Create_GEH_list_anchor() -- {{{
    self.Anchor = {};
    self.Anchor.frame = CreateFrame ("Frame", nil, UIParent);
    local frame = self.Anchor.frame;

    frame:EnableMouse(true);
    frame:RegisterForDrag("LeftButton");

    frame:SetScript("OnDragStart", frame.StartMoving);
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing);

    frame:SetPoint("CENTER"); frame:SetWidth(263); frame:SetHeight(33);

    -- create a beautiful texture for the anchor.
    local AnchorTexture = frame:CreateTexture("ARTWORK");
    AnchorTexture:SetAllPoints();
    AnchorTexture:SetTexture(0.275, 0.765, 0.222);
    AnchorTexture:SetAlpha(0.85);

    frame:Hide();

end -- }}}


function GEH:Enable()
    hhtd.db.global.GEHDEnabled = true;
    -- start roaming updater code here

    if not GEH.Initialized then




        GEH.Initialized = true;
    end

end

function GEH:Disable()
    hhtd.db.global.GEHDEnabled = false;
    -- stop roaming update here and hide evrything
end

function GEH.prototype:init(EH_name)

    if not hhtd.initOK then
        hhtd:Debug("Initializing EH object for", EH_name, "failed, initialization incomplete");
        return;
    end

    hhtd:Debug("Initializing EH object for", EH_name);


    GEH.EHo_count = GEH.EHo_count + 1;

    self.Shown = false;
    self.ProximitySensor = false;

    -- create the frame
    self.Frame  = CreateFrame ("Button", nil, UIParent, "SecureUnitButtonTemplate");

    -- global texture
    self.Texture = self.Frame:CreateTexture(nil, "ARTWORK");
    self.Texture:SetPoint("CENTER", self.Frame, "CENTER", 0, 0)

    self.Texture:SetHeight(16);
    self.Texture:SetWidth(160);

-- name (class colored)
-- proximity light
-- targetable indicator

end

-- === ROADMAP === --

-- name (class colored)
-- proximity light
-- targetable indicator
-- heal amount indicator
-- anchoring function
-- update mechanism
-- -- Roaming or not roaming?
-- -- -- needed for proximity light and macro update
-- -- -- needed for deletion (grey out unseen healers - make them disappear completely in some event)
-- -- -- leave combat trigger
