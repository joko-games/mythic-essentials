# Mythic Essentials

World of Warcraft addon (Retail, 12.1.5): a small Mythic+ window with the group's DPS in class colours, the key timer and progress, and who has no flask or no food. Only the essentials.

Status: v1.0.0. The logic is tested outside the game; what to check in the client is under [Check in game](#check-in-game).

## Installation

```powershell
.\install.ps1
```

The script copies `MythicEssentials.toc` and the files it lists into `Interface\AddOns\MythicEssentials`, and nothing else. After changing the code, run it again, then `/reload` in game. If the list of files in the `.toc` changed, restart WoW.

| Option | Effect |
| --- | --- |
| `-Clean` | Also deletes the saved data (window position and settings) on all accounts. You are asked to confirm, and WoW must be closed. |
| `-WowPath <folder>` | The WoW folder, the one containing `_retail_`, if it is not in the standard location. |
| `-WhatIf` | Shows what would be done, without changing anything. |

## Usage

The window shows, from the top:

- **During a key**: the level and dungeon; the time left for the next chest (+3, +2, +1, in its colour) with the elapsed time and the limit; a timer bar with the +3 and +2 marks; enemy forces in percent, with deaths and the time they cost; each boss, greyed out with the time it died once killed.
- **Group DPS**: one bar per player, five at most, best first, in class colours, with the DPS on the right and no names. Your own row has a `<` after its rank. **Hover** a bar: the player, their DPS and their damage. The numbers are the game's damage meter's, for the whole run (its Overall session).
- **Consumables**: "No flask: 2", "No food: 1". **Hover** the number to see who. Nothing is shown when everyone has them. Checked out of combat; players out of sight are left out.

Drag the window to move it. The minimap icon: left click shows or hides the window, right click locks or unlocks it, drag moves the icon.

| Command | Effect |
| --- | --- |
| `/mye` | Show or hide the window |
| `/mye lock` | Lock or unlock the window |
| `/mye scale 0.8` | Window size, from 0.5 to 2 |
| `/mye reset` | Window back to its first place and size |
| `/mye minimap` | Hide or show the minimap icon |
| `/mye demo` | Sample data, to place the window outside a dungeon |

## Check in game

What only the client can show:

1. `/mye demo`: the window, its bars, the chest marks, the tooltips on the bars and on the consumables numbers.
2. In a dungeon (even a normal one), the DPS bars fill in combat, in class colours, and their tooltips still work in combat. No Lua error with secret values.
3. In a key: timer, chest, forces, deaths, bosses and kill times; the completed key stays shown at the end.
4. Consumables: take off a flask or food out of combat, the count changes; with everyone ready, the line disappears.
5. The minimap icon, its clicks and dragging; the addon compartment entry.
