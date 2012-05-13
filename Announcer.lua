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
    Announcer.lua
-----

This component plays alert sounds and display messages.


--]=]

local ERROR     = 1;
local WARNING   = 2;
local INFO      = 3;
local INFO2     = 4;


local ADDON_NAME, T = ...;
local HHTD = T.Healers_Have_To_Die;
local L = HHTD.Localized_Text;

-- Create module
HHTD.Announcer = HHTD:NewModule("Announcer", "AceConsole-3.0"); --, "AceTimer-3.0");
local Announcer = HHTD.Announcer;

-- Up Values
local UnitGUID      = _G.UnitGUID;
local UnitName      = _G.UnitName;
local UnitClass     = _G.UnitClass;
local UnitSex       = _G.UnitSex;
local PlaySoundFile = _G.PlaySoundFile;
local select        = _G.select;

function Announcer:OnInitialize() -- {{{
    self:Debug(INFO, "OnInitialize called!");
    self.db = HHTD.db:RegisterNamespace('Announcer', {
        global = {
            ChatMessages = false,
            Sounds = true,

            PostToChat = false,
            PostToChatThrottle = 2 * 60,
            PostHealersNumber = 4,
            PostHumansOnly = true,
            ProtectMessage = false,
            KillMessage = false,
            PostChannel = 'AUTO',
        },
    });

    

end -- }}}

function Announcer:GetOptions () -- {{{


    local validatePostChatMessage = function (info, v)

        local counterpartMessage = info[#info] == 'ProtectMessage' and 'KillMessage' or 'ProtectMessage';
        Announcer:Debug('counterpartMessage:', counterpartMessage);
      
        if not v:find('%[HEALERS%]') then
            return self:Error(L["OPT_POST_ANNOUNCE_MISSING_KEYWORD"]);
        end

        if v:len() < ("%[HEALERS%]"):len() + 10 then
            return self:Error(L["OPT_POST_ANNOUNCE_MESSAGE_TOO_SHORT"]);
        end

        if v == Announcer.db.global[counterpartMessage] then
            return self:Error(L["OPT_POST_ANNOUNCE_MESSAGES_EQUAL"]);
        end

        return 0, v;

    end

    return {
        [Announcer:GetName()] = {
            name = L[Announcer:GetName()],
            type = 'group',
            get = function (info) return Announcer.db.global[info[#info]]; end,
            set = function (info, value) HHTD:SetHandler(self, info, value) end,
            args = {
                ChatMessages = {
                    type = 'toggle',
                    name = L["OPT_ANNOUNCE"],
                    desc = L["OPT_ANNOUNCE_DESC"],
                    order = 1,
                },
                Sounds = {
                    type = 'toggle',
                    name = L["OPT_SOUNDS"],
                    desc = L["OPT_SOUNDS_DESC"],
                    order = 10,
                },
                -- enable
                PostToChat = {
                    type = 'toggle',
                    name = L["OPT_POST_ANNOUNCE_ENABLE"],
                    desc = L["OPT_POST_ANNOUNCE_ENABLE_DESC"],
                    set = function (info, v)
                        Announcer.db.global.PostToChat = v;
                    end,
                    order = 30,
                },
                PostToChatOptions = {
                    type = 'group',
                    inline = true,
                    name = L['OPT_POST_ANNOUNCE_SETTINGS'],
                    hidden = function() return Announcer.db.global.PostToChat == false end,
                    order = 40,
                    args = {
                        Description = {
                            type = 'description',
                            order = 0,
                            name = L["OPT_POST_ANNOUNCE_DESCRIPTION"],
                        },
                        PostChannel = {
                            type = 'select',
                            name = L['OPT_POST_ANNOUNCE_CHANNEL'],
                            desc = L['OPT_POST_ANNOUNCE_CHANNEL_DESC'],
                            values = { ['AUTO'] = L['RAID_OR_BATTLEGROUND'], ['PARTY'] = L['PARTY'], ['SAY'] = L['SAY'], ['YELL'] = L['YELL'] },
                            order = 30,
                        },
                        -- throttle
                        PostToChatThrottle = {
                            type = 'range',
                            min = 60,
                            max = 10 * 60,
                            step = 1,
                            bigStep = 5,
                            name = L["OPT_POST_ANNOUNCE_THROTTLE"],
                            desc = L["OPT_POST_ANNOUNCE_THROTTLE_DESC"],
                            order = 40,
                        },
                        PostHealersNumber = {
                            type = 'range',
                            min = 2,
                            max = 10,
                            step = 1,
                            name = L["OPT_POST_ANNOUNCE_NUMBER"],
                            desc = L["OPT_POST_ANNOUNCE_NUMBER_DESC"],
                            order = 42,
                        },
                        PostHumansOnly = {
                            type = 'toggle',
                            order = 43,
                            name = L["OPT_POST_ANNOUNCE_HUMAMNS_ONLY"],
                            desc = L["OPT_POST_ANNOUNCE_HUMAMNS_ONLY_DESC"],

                        },
                        ValidityCheck = {
                            type = 'description',
                            order = 45,
                            name = HHTD:ColorText(L["OPT_POST_ANNOUNCE_POST_MESSAGE_ISSUE"],'FFFF4040'),
                            hidden = function ()
                                if Announcer.db.global.PostToChat == false
                                    or (Announcer.db.global.ProtectMessage and Announcer.db.global.KillMessage) then

                                    return true;
                                else
                                    return false;
                                end
                            end
                        },
                        ProtectMessage = {
                            type = 'input',
                            width = 'full',
                            name = L["OPT_POST_ANNOUNCE_PROTECT_MESSAGE"],
                            desc = L["OPT_POST_ANNOUNCE_PROTECT_MESSAGE_DESC"],
                            get = function (info)
                                return Announcer.db.global[info[#info]] or '[HEALERS]';
                            end,
                            validate = validatePostChatMessage,
                            order = 50,
                        },
                        KillMessage = {
                            type = 'input',
                            width = 'full',
                            name = L["OPT_POST_ANNOUNCE_KILL_MESSAGE"],
                            desc = L["OPT_POST_ANNOUNCE_KILL_MESSAGE_DESC"],
                            get = function (info)
                                return Announcer.db.global[info[#info]] or '[HEALERS]';
                            end,
                            validate = validatePostChatMessage,
                            order = 60,
                        },
                    },
                },
                -- auto raid mark friendly healers
            },
        },
    };
end -- }}}


function Announcer:OnEnable() -- {{{
    self:Debug(INFO, "OnEnable");

    -- Subscribe to HHTD callbacks
    self:RegisterMessage("HHTD_HEALER_MOUSE_OVER");
    self:RegisterMessage("HHTD_TARGET_LOCKED");
    self:RegisterMessage("HHTD_HEALER_UNDER_ATTACK");

    self:RegisterChatCommand("hhtdp", function() self:ChatPlacard() end);

end -- }}}

function Announcer:OnDisable() -- {{{
    self:Debug(INFO2, "OnDisable");
    self:UnregisterChatCommand("hhtdp");
end -- }}}


-- Internal CallBacks (HHTD_HEALER_MOUSE_OVER - HHTD_TARGET_LOCKED - HHTD_HEALER_UNDER_ATTACK) {{{
local previousUnitGuid;
function Announcer:HHTD_HEALER_MOUSE_OVER(selfevent, isFriend, healerProfile)

    if isFriend then
        return; -- XXX
    end

    if previousUnitGuid ~= healerProfile.guid then
        self:Announce(
            "|cFFFF0000",
            (L["IS_A_HEALER"]):format(
                HHTD:ColorText(
                healerProfile.name,
                HHTD:GetClassHexColor(  select(2, UnitClass("mouseover")) )
                ),
            "|r"
            )
        );
        previousUnitGuid = healerProfile.guid;
    end

    self:PlaySoundFile("Sound\\interface\\AlarmClockWarning3.wav");
    -- self:Debug(INFO, "AlarmClockWarning3.wav played");
end

function Announcer:HHTD_TARGET_LOCKED (selfevent, isFriend, healerProfile)

    if isFriend then
        return; -- XXX
    end

    self:PlaySoundFile("Sound\\interface\\AuctionWindowOpen.wav");
    --self:Debug(INFO, "AuctionWindowOpen.wav played");

    local sex = UnitSex("target");

    local what = (sex == 1 and L["YOU_GOT_IT"] or sex == 2 and L["YOU_GOT_HIM"] or L["YOU_GOT_HER"]);

    local localizedUnitClass, unitClass = UnitClass("target");

    local subjectColor = HHTD:GetClassHexColor(unitClass);

    self:Announce(what:format("|c" .. subjectColor));

end

function Announcer:HHTD_HEALER_UNDER_ATTACK (selfevent, sourceName, sourceGUID, destName, destGUID)
    local message = HHTD:ColorText("HHTD: ", '88555555') .. (L["HEALER_UNDER_ATTACK"]):format(HHTD:ColorText(HHTD:MakePlayerName(destName), 'FF00DD00'), HHTD:ColorText(HHTD:MakePlayerName(sourceName), 'FFDD0000'));

    RaidNotice_AddMessage( RaidWarningFrame, message, ChatTypeInfo["RAID_WARNING"] );

    self:Print(message);
end

-- }}}


function Announcer:Announce(...) -- {{{
    if self.db.global.ChatMessages then
        HHTD:Print(...);
    end
end -- }}}

do
    local function SortHealers(a, b)
        if a.healDone > b.healDone then
            return true;
        else
            return false;
        end
    end

    local function GetDistributionChanel()
        local channel = Announcer.db.global.PostChannel;

        if channel ~= 'AUTO' then
            return channel;
        end

        local inInstance, InstanceType = IsInInstance();

        if InstanceType == "pvp" then
            return "BATTLEGROUND";
        end

        if (select(2, GetRaidRosterInfo(UnitInRaid("player") or 1))) > 0 then
            return "RAID_WARNING";
        end

        if GetNumRaidMembers() ~= 0 then
            return "RAID";
        elseif GetNumPartyMembers() ~= 0 then
            return "PARTY";
        end

        return "WHISPER";
    end

    local function Post(text)
        local channelType = GetDistributionChanel();

        --  SendChatMessage("msg" [,"type" [,"lang" [,"channel"] ] ]).
        SendChatMessage("HHTD: " .. text, channelType, nil, channelType == 'WHISPER' and (UnitName('player')) or nil);
    end

    local LastAnnounce = 0;
    local FriendsFoes = {
        [true] = {},
        [false] = {}
    };
    function Announcer:ChatPlacard()
        -- first check config
        if not (self.db.global.PostToChat and self.db.global.ProtectMessage and self.db.global.KillMessage) then
            self:Error(L["CHAT_POST_ANNOUNCE_FEATURE_NOT_CONFIGURED"]);
            return false;
        end
        local config = self.db.global;

        -- then check throttle
        if GetTime() - LastAnnounce < config.PostToChatThrottle then
            self:Error(L["CHAT_POST_ANNOUNCE_TOO_SOON_WAIT"]);
            return false;
        end


        for i, isFriend in ipairs({true, false}) do

            table.wipe(FriendsFoes[isFriend]);

            for healerGUID, healerProfile in pairs(HHTD.Registry_by_GUID[isFriend]) do

                if not (config.PostHumansOnly and not healerProfile.isHuman) and #FriendsFoes[isFriend] <= config.PostHealersNumber then
                    table.insert(FriendsFoes[isFriend], healerProfile);
                else
                    break;
                end

            end

            -- we need to sort those before display...
            table.sort(FriendsFoes[isFriend], SortHealers);

            for i, healer in ipairs(FriendsFoes[isFriend]) do
                -- XXX also add raidmarkers for friends
                FriendsFoes[isFriend][i] = ("(%d) %s"):format(healer.rank, healer.name);
            end

            --self:Debug(INFO, "Found", #FriendsFoes[isFriend], isFriend and "friends" or "foes");

        end


        -- send to chat
        if #FriendsFoes[true] > 0 then
            local FriendsText = ( config.ProtectMessage:gsub('%[HEALERS%]', table.concat(FriendsFoes[true],  ' - ')) );
            self:Debug("HHTD:", FriendsText);
            Post(FriendsText);
        end
        if #FriendsFoes[false] > 0 then
            local FoesText    = ( config.KillMessage:gsub('%[HEALERS%]', table.concat(FriendsFoes[false], ' - ')) );
            self:Debug("HHTD:", FoesText);
            Post(FoesText);
        end

        if #FriendsFoes[true] > 0 or #FriendsFoes[false] > 0 then
            -- log the time to prevent spam
            LastAnnounce = GetTime();
        else
            self:Error(L["CHAT_POST_NO_HEALERS"]);
            --@debug@
            Post(L["CHAT_POST_NO_HEALERS"]);
            LastAnnounce = GetTime();
            --@end-debug@
        end

        return true;
    end
end

function Announcer:PlaySoundFile(...) -- {{{
    if self.db.global.Sounds then
        PlaySoundFile(...);
    end
end -- }}}
