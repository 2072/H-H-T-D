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
    local L = LibStub("AceLocale-3.0"):NewLocale("HealersHaveToDie", "enUS", true);

    if L then
        --@localization(locale="enUS", format="lua_additive_table")@

    --@do-not-package@
    ---[==[
    -- Used for testing the addon without the packager
    L["VERSION"] = "version:"
    L["RELEASE_DATE"] = "Release Date:"
    L["ENABLED"] = "enabled! Type /hhtd for a list of options"
    L["DISABLED"] = "hhtd has been disabled!\nType /hhtd enable to re-enable it."


    L["YOU_GOT_HIM"] = "You got %shim|r!"
    L["YOU_GOT_HER"] = "You got %sher|r!"
    L["YOU_GOT_IT"] = "You got %sit|r!"
    
    L["IS_A_HEALER"] = "%s is a healer!"

    L["OPT_ON"] = "on"
    L["OPT_ON_DESC"] = "Enables HHTD"

    L["OPT_OFF"] = "off"
    L["OPT_OFF_DESC"] = "Disables HHTD"

    L["OPT_HEALER_FORGET_TIMER"] = "Healer Forget Timer"
    L["OPT_HEALER_FORGET_TIMER_DESC"] = "Set the Healer Forget Timer (the time in seconds an enemy will remain considered has a healer)"

    L["OPT_DEBUG"] = "debug"
    L["OPT_DEBUG_DESC"] = "Enables / disables debugging"

    L["OPT_VERSION"] = "version"
    L["OPT_VERSION_DESC"] = "Display version and release date"
    
    L["DEBUGGING_STATUS"] = "Debugging status is"

    L["OPT_ENABLE_GEHR"] = "Enable Graphical Reporter"
    L["OPT_ENABLE_GEHR_DESC"] = "Displays a graphical list of detected enemy healers with various features"

    L["OPT_ANNOUNCE"] = "Show messages"
    L["OPT_ANNOUNCE_DESC"] = "HHTD will display messages when you target or mouse-over an enemy healer."

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

