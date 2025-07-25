H.H.T.D.
========

*Change log*
------------

**version 2.4.25 (2025-07-21):**

- TOC updates


**version 2.4.24 (2025-03-14):**

- TOC updates


**version 2.4.23 (2025-01-06):**

- TOC updates


**version 2.4.22 (2024-10-04):**

- TOC updates


**version 2.4.21 (2024-08-07):**

- Compatible with The War Within

- Remove Penance from specialized healer spell


**version 2.4.20 (2024-05-26):**

- TOC updates for 10.2.7


**version 2.4.19 (2024-05-02):**

- TOC updates

- Cataclysm compatibility fix


**version 2.4.18 (2024-03-05):**

- Remove Soothing Mist, Renew and Holy Nova from the specialized healer spells list. (WoW 10.2.5 only)


**version 2.4.17 (2024-01-22):**

- TOC update for 10.2.5.


**version 2.4.16 (2023-11-22):**

- Fix ADDON_ACTION_BLOCKED error due to the now forbidden usage of
  CheckInteractDistance() while in combat. This was used to display an alert
  when a friendly nearby healer is being attacked. HHTD is now using
  UnitInRange() instead but this will only work for unit in the players party or
  raid so no longer for potential NPC healers...


**version 2.4.15 (2023-11-08):**

- TOC updates.


**version 2.4.14 (2023-10-22):**

- TOC updates.


**version 2.4.13 (2023-07-16):**

- TOC updates.


**version 2.4.12 (2023-05-29):**

- TOC update for 10.1.


**version 2.4.11 (2023-04-02):**

- TOC updates

- Fix for WoW 10.1 (PTR)


**version 2.4.10 (2023-01-07):**

- Update libNameplateRegistry to fix issue with object nameplates.

- Add support for Evoker Class


**version 2.4.9.14 (2022-11-28):**

- TOC update for retail.


**version 2.4.9.13 (2022-09-04):**

- TOC updates (+ for WotLK)


**version 2.4.9.12 (2022-06-12):**

- Fix /hhtdg option panel for retail (was crashing due to custom marks panel).

- TOC updates


**version 2.4.9.11 (2022-02-27):**

- Fix Binding Heal (missing spell ID in WoW 9.2.0)

- TOC update


**version 2.4.9.10 (2021-11-06):**

- TOC update


**version 2.4.9.9 (2021-07-03):**

- Do not generate a Decursive error report when no target is selected while
  using the Custom Mark UI. Print a message to the chat instead.

- TOC uodate


**version 2.4.9.8 (2021-03-21):**

- Fix WoW Classic detection


**version 2.4.9.7 (2021-03-21):**

- TOC update


**version 2.4.9.6 (2020-10-19):**

- Adjust specialization spells list.

- TOC to 90001


**version 2.4.9.5 (2020-02-27):**

- TOC to 80205


**version 2.4.9.4 (2019-10-28):**

- TOC to 80205


**version 2.4.9.3 (2019-09-03):**

- Compatible with WoW Classic
- Using BigWigs' packager, as a result -nolib packages are only available from
  Github.


**version 2.4.9.2 (2019-07-07):**

- Fix sound for WoW 8.2
- TOC update


**version 2.4.9.1 (2019-01-07):**

- TOC update


**version 2.4.9 (2018-08-12):**

- Remove `Vivify` and `Wild Growth` from the [specialized healer spell list][spelllist].
  (If you see any inconsistencies in this list please [open a new ticket][tickets])


**version 2.4.8 (2018-07-22):**

- Add a setting to set the maximum display distance of nameplates in both
  nameplate related modules.
  (This is a WoW setting only available through chat command)

- Homogenize nameplates settings between modules using them.


****
For older versions changes see version-oldnews.md


[spelllist]: https://www.wowace.com/projects/h-h-t-d/pages/specialized-healers-spells
[localization]: https://www.wowace.com/projects/h-h-t-d/localization
[tidyplates]: https://www.curseforge.com/wow/addons/tidy-plates
[LibNamePlateRegistry]: https://www.wowace.com/projects/libnameplateregistry-1-0
[tickets]: https://www.wowace.com/projects/h-h-t-d/issues
