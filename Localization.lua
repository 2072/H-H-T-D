--[=[
HealersHaveToDie World of Warcraft Add-on
Copyright (c) 2009-2011 by John Wellesz (Archarodim@teaser.fr)
All rights reserved

Version @project-version@

This is a very simple and light add-on that rings when you hover or target a
unit of the opposite faction who healed someone during the last 60 seconds (can
be configured).
Now you can spot those nasty healers instantly and help them to accomplish their destiny!

This add-on uses the Ace3 framework.

type /hhtd to get a list of existing options.

-----
    Localization.lua
-----


--]=]


--[=[
--                      YOUR ATTENTION PLEASE
--
--         !!!!!!! TRANSLATORS TRANSLATORS TRANSLATORS !!!!!!!
--
--    Thank you very much for your interest in translating Healers Have To Die.
--    Do not edit this file. Use the localization interface available at the following address:
--
--      ##########################################################################
--      #  http://wow.curseforge.com/projects/healers-have-to-die/localization/  #
--      ##########################################################################
--
--    Your translations made using this interface will be automatically included in the next release.
--
--]=]


do
    local L = LibStub("AceLocale-3.0"):NewLocale("HealersHaveToDie", "enUS", true, true);

    if L then
        --@localization(locale="enUS", format="lua_additive_table")@

        --@do-not-package@
        ---[==[
        -- Used for testing the addon without the packager
        L["ACTIVE"] = "Active!"
        L["Announcer"] = "Announcer"
        L["Announcer_DESC"] = "This module allows you to manage chat and sound alerts"
        L["CHAT_POST_ANNOUNCE_FEATURE_NOT_CONFIGURED"] = "The announce to raid messages are not configured. Type /HHTDG"
        L["CHAT_POST_ANNOUNCE_TOO_SOON_WAIT"] = "It's too soon (see the announce throttle setting)."
        L["CHAT_POST_NO_HEALERS"] = "No healers on either sides :/ (yet)"
        L["DESCRIPTION"] = "Spot those bloody healers instantly and help them accomplish their destiny! (PVP and PVE)"
        L["DISABLED"] = [=[hhtd has been disabled!
        Type '/hhtd on' to re-enable it.]=]
        L["ENABLED"] = "enabled! Type /HHTDG for a list of options"
        L["HEALER_UNDER_ATTACK"] = "Healer friend %s is being attacked by %s"
        L["HUMAN"] = "Human"
        L["IDLE"] = "Idle"
        L["IS_A_HEALER"] = "%s is a healer!"
        L["NO_DATA"] = "No data"
        L["NPC"] = "NPC"
        L["NPH"] = "Name Plate Hooker"
        L["NPH_DESC"] = "This module adds a red cross to enemy healers' name plates"
        L["OPT_ANNOUNCE"] = "Show messages"
        L["OPT_ANNOUNCE_DESC"] = "HHTD will display messages when you target or mouse-over an enemy healer."
        L["OPT_CLEAR_LOGS"] = "Clear logs"
        L["OPT_CORE_OPTIONS"] = "Core options"
        L["OPT_DEBUGLEVEL_DESC"] = "debug level: 1=all, 2=warnings, 3=errors"
        L["OPT_DEBUGLEVEL"] = "debugging level"
        L["OPT_DEBUG"] = "debugging logs"
        L["OPT_DEBUG_DESC"] = "Enables / disables debugging"
        L["OPT_ENABLE_GEHR"] = "Enable Graphical Reporter"
        L["OPT_ENABLE_GEHR_DESC"] = "Displays a graphical list of detected enemy healers with various features"
        L["OPT_HEALER_FORGET_TIMER"] = "Healer Forget Timer"
        L["OPT_HEALER_FORGET_TIMER_DESC"] = "Set the Healer Forget Timer (the time in seconds an enemy will remain considered has a healer)"
        L["OPT_HEALER_MINIMUM_HEAL_AMOUNT"] = "Heal amount (|cff00dd00%u|r) threshold"
        L["OPT_HEALER_MINIMUM_HEAL_AMOUNT_DESC"] = "Healers won't be detected until they reach this cumulative amount of healing based on a percentage of your own maximum health."
        L["OPT_HEALER_UNDER_ATTACK_ALERTS"] = "Protect friendly healers"
        L["OPT_HEALER_UNDER_ATTACK_ALERTS_DESC"] = "Display an alert when a nearby friendly healers is attacked"
        L["OPT_LOG"] = "Logging"
        L["OPT_LOGS"] = "Logs"
        L["OPT_LOGS_DESC"] = "Display HHTD detected healers and statistics"
        L["OPT_LOG_DESC"] = "Enables logging and adds a new 'Logs' tab to HHTD's option panel"
        L["OPT_MODULES"] = "Modules"
        L["OPT_NPH_WARNING1"] = [=[WARNING: Enemies' name-plates are currently disabled. HHTD cannot add its red cross symbol.
        You can enable name-plates display through the WoW UI's options or by using the assigned key-stroke.]=]
        L["OPT_NPH_WARNING2"] = [=[WARNING: Allies' name-plates are currently disabled. HHTD cannot add its healer symbol.
        You can enable name-plates display through the WoW UI's options or by using the assigned key-stroke.]=]
        L["OPT_OFF"] = "off"
        L["OPT_OFF_DESC"] = "Disables HHTD"
        L["OPT_ON"] = "on"
        L["OPT_ON_DESC"] = "Enables HHTD"
        L["OPT_POST_ANNOUNCE_CHANNEL"] = "Post channel"
        L["OPT_POST_ANNOUNCE_CHANNEL_DESC"] = "Decide where your announce will be posted"
        L["OPT_POST_ANNOUNCE_DESCRIPTION"] = [=[|cFFFF0000IMPORTANT:|r Type |cff40ff40/hhtdp|r or bind a key to announce friendly healers to protect and enemy healers to focus.

        (see World of Warcraft escape menu binding interface to bind a key)
        ]=]
        L["OPT_POST_ANNOUNCE_ENABLE"] = "Chat announces"
        L["OPT_POST_ANNOUNCE_ENABLE_DESC"] = "Enable announce to raid features."
        L["OPT_POST_ANNOUNCE_HUMAMNS_ONLY"] = "Humans only"
        L["OPT_POST_ANNOUNCE_HUMAMNS_ONLY_DESC"] = "Do not include NPCs in the announce."
        L["OPT_POST_ANNOUNCE_KILL_MESSAGE"] = "Text for enemy healers"
        L["OPT_POST_ANNOUNCE_KILL_MESSAGE_DESC"] = [=[Type a message inciting your team to focus enemy healers.

        You must use the [HEALERS] keyword somewhere which will be automatically replaced by the names of the currently active healers.]=]
        L["OPT_POST_ANNOUNCE_MESSAGES_EQUAL"] = "There is one message for friends and one for foes, they cannot be the same."
        L["OPT_POST_ANNOUNCE_MESSAGE_TOO_SHORT"] = "Your message is too short!"
        L["OPT_POST_ANNOUNCE_MISSING_KEYWORD"] = "The [HEALERS] keyword is missing!"
        L["OPT_POST_ANNOUNCE_NUMBER"] = "Healers number"
        L["OPT_POST_ANNOUNCE_NUMBER_DESC"] = "Set how many healers to include in each announce."
        L["OPT_POST_ANNOUNCE_POST_MESSAGE_ISSUE"] = "There is something wrong with one of the announce text."
        L["OPT_POST_ANNOUNCE_PROTECT_MESSAGE"] = "Text for friendly healers"
        L["OPT_POST_ANNOUNCE_PROTECT_MESSAGE_DESC"] = [=[Type a message inciting your team to protect their healers.

        You must use the [HEALERS] keyword somewhere which will be automatically replaced by the names of the currently active healers.]=]
        L["OPT_POST_ANNOUNCE_SETTINGS"] = "Announce to raid settings"
        L["OPT_POST_ANNOUNCE_THROTTLE"] = "Announce throttle"
        L["OPT_POST_ANNOUNCE_THROTTLE_DESC"] = "Set the minimum time in seconds between each possible announce."
        L["OPT_PVE"] = "Enable for PVE"
        L["OPT_PVE_DESC"] = "HHTD will also work for NPCs."
        L["OPT_PVPHEALERSSPECSONLY"] = "Healer specialization detection"
        L["OPT_PVPHEALERSSPECSONLY_DESC"] = "Only detect players specialized in healing. (this disables minimum heal amount filter for PVP)"
        L["OPT_SET_FRIENDLY_HEALERS_ROLE"] = "Set friendly healers role"
        L["OPT_SET_FRIENDLY_HEALERS_ROLE_DESC"] = "Will automatically set the raid HEALER role to friendly healers upon detection (if possible)"
        L["OPT_SOUNDS"] = "Sound alerts"
        L["OPT_SOUNDS_DESC"] = "HHTD will play a specific sound when you hover or target an enemy healer"
        L["OPT_STRICTGUIDPVE"] = "Accurate PVE detection"
        L["OPT_STRICTGUIDPVE_DESC"] = "When several NPCs share the same name, HHTD will only add a cross over those who actually healed instead of adding a cross to all of them. Note that most of the time, you'll need to target or mouse-over the unit for the cross to appear."
        L["OPT_USE_HEALER_MINIMUM_HEAL_AMOUNT"] = "Use minimum heal amount filter"
        L["OPT_USE_HEALER_MINIMUM_HEAL_AMOUNT_DESC"] = "Healers will have to heal for a specified amount before being tagged as such."
        L["OPT_VERSION"] = "version"
        L["OPT_VERSION_DESC"] = "Display version and release date"
        L["PARTY"] = "Party"
        L["AUTO_RAID_PARTY_INSTANCE"] = "Auto: Raid/Party/Instance"
        L["RELEASE_DATE"] = "Release Date:"
        L["SAY"] = "Say"
        L["VERSION"] = "version:"
        L["YELL"] = "Yell"
        L["YOU_GOT_HER"] = "You got %sher|r!"
        L["YOU_GOT_HIM"] = "You got %shim|r!"
        L["YOU_GOT_IT"] = "You got %sit|r!"
        
        L["OPT_TESTONTARGET"] = "Test HHTD's behavior on current target"
        L["OPT_TESTONTARGET_DESC"] = "Will mark your current target as a healer so you can test what happens."
        L["OPT_TESTONTARGET_ENOTARGET"] = "You need to target something"

        L["LOG_BELOW_THRESHOLD"] = " (below threshold)"
        L["LOG_ACTIVE"] = "Active!"
        L["LOG_IDLE"] = "Idle"


        L["OPT_NPH_MARKER_SETTINGS"]         = "Markers' settings"

        L["OPT_NPH_MARKER_SCALE"]           = "Markers' scaling"
        L["OPT_NPH_MARKER_SCALE_DESC"]      = "Change markers' size"
        L["OPT_NPH_MARKER_X_OFFSET"]        = "Horizontal offset"
        L["OPT_NPH_MARKER_X_OFFSET_DESC"]   = "Move markers horizontally"
        L["OPT_NPH_MARKER_Y_OFFSET"]        = "Vertical offset"
        L["OPT_NPH_MARKER_Y_OFFSET_DESC"]   = "Move markers vertically"

        L["INSTANCE_CHAT"]                  = "Instance chat"

        --]==]
        --@end-do-not-package@

    end

end

do
    local L = LibStub("AceLocale-3.0"):NewLocale("HealersHaveToDie", "frFR");

    if L then
        --@localization(locale="frFR", format="lua_additive_table")@
    end
end

do
    local L = LibStub("AceLocale-3.0"):NewLocale("HealersHaveToDie", "deDE");

    if L then
        --@localization(locale="deDE", format="lua_additive_table")@
    end
end

do
    local L = LibStub("AceLocale-3.0"):NewLocale("HealersHaveToDie", "esES");

    if L then
        --@localization(locale="esES", format="lua_additive_table")@
    end
end

do
    local L = LibStub("AceLocale-3.0"):NewLocale("HealersHaveToDie", "esMX");

    if L then
        --@localization(locale="esMX", format="lua_additive_table")@
    end
end

do
    local L = LibStub("AceLocale-3.0"):NewLocale("HealersHaveToDie", "koKR");

    if L then
        --@localization(locale="koKR", format="lua_additive_table")@
    end
end

do
    local L = LibStub("AceLocale-3.0"):NewLocale("HealersHaveToDie", "zhCN");

    if L then
        --@localization(locale="zhCN", format="lua_additive_table")@
    end
end

do
    local L = LibStub("AceLocale-3.0"):NewLocale("HealersHaveToDie", "zhTW");

    if L then
        --@localization(locale="zhTW", format="lua_additive_table")@
    end
end

do
    local L = LibStub("AceLocale-3.0"):NewLocale("HealersHaveToDie", "ruRU");

    if L then
        --@localization(locale="ruRU", format="lua_additive_table")@
    end
end

do
    local L = LibStub("AceLocale-3.0"):NewLocale("HealersHaveToDie", "itIT");

    if L then
        --@localization(locale="itIT", format="lua_additive_table")@
    end
end
