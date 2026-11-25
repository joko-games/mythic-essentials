# Architecture

The addon is one small window (`UI/Window.lua`) fed by three readers, each in its own file and tested outside the game. The window refreshes every half second while it is shown, and soon after the events that change its data.

## Group DPS: `Meter.lua`

Since Midnight (12.0) addons no longer receive the combat log. The only source of damage numbers is the game's own damage meter, through `C_DamageMeter`. The addon reads the **Overall** session of type **DamageDone** (`C_DamageMeter.GetCombatSessionFromType`): in a key, the whole run so far. The meter lists its sources best first; the addon keeps those with a class (players), five at most.

In combat the meter's numbers and names are **secret values**: the addon may hand them to the interface, which draws them, but cannot read, compare or compute with them. So:

- the bars take the amounts as they are (`StatusBar:SetMinMaxValues(0, best)`, `SetValue(amount)`), the best being the first source, as the meter sorts them;
- the DPS text goes through the game's formatter (`AbbreviateNumbers`) when the value is secret, the addon's own (`ns.FormatNumber`) otherwise;
- the class (`classFilename`) and `isLocalPlayer` are never secret: they colour the bars and mark the player's own row;
- every call given a value that may be secret is wrapped in `pcall`, so that a refused value leaves the bar as it was instead of breaking the refresh.

The meter's enum names changed during 12.0's development; `Meter.lua` looks each up under its known names, with the documented value as a fallback.

## Key: `Keystone.lua`

While `C_ChallengeMode.IsChallengeModeActive()`:

- the dungeon and its time limit from `C_ChallengeMode.GetMapUIInfo`, the level from `GetActiveKeystoneInfo`, deaths and time lost from `GetDeathCount`;
- the timer from `GetWorldElapsedTime(1)`, which already includes the death penalty;
- the scenario criteria (`C_ScenarioInfo`): the one with weighted progress is enemy forces, whose `quantityString` holds the raw count and `totalQuantity` the count needed; the others are the bosses. A boss's kill time is the timer when the addon first sees it dead (none after a `/reload` past the kill).

`ns.TimerView` turns the state into what the window shows: the time left before the next chest is lost, at 60 % (+3), 80 % (+2) and 100 % (+1) of the limit. A completed key stays shown, with its official time, until the next key starts or the player leaves the instance.

## Consumables: `Consumables.lua`

Out of combat only (in combat auras may be secret, and the check matters before the pull), on aura and group changes, the addon reads the buffs of the player and of each party member. A buff is a flask or food by its name, in the client's language (`Flask`/`Phial`, `Flacon`/`Fiole`, ...), and food also by the "Well Fed" icon, so that a new expansion's consumables count without a list of spell IDs. A member out of sight, offline, or whose buffs are secret is left out rather than counted as missing. The last result is kept through combat.

The window shows "No flask: n" and "No food: n" only when n is not zero; hovering lists the players in class colours.

## Window: `UI/Window.lua`, `UI/MinimapButton.lua`

The window lays out each part again on every refresh, from the top, and takes the height of what it shows: no key, no key part; nothing missing, no consumables line. Dragging anywhere on it moves it unless it is locked; its position and scale are saved in `MythicEssentialsDB`. `/mye demo` fills it with sample data, to place it outside a dungeon.

The minimap button follows LibDBIcon's look and geometry, as in Trading Essentials, without embedding the library: left click shows or hides the window, right click locks or unlocks it, dragging moves it around the minimap. The addon compartment (the addon list button by the minimap) shows or hides the window too.
