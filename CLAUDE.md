# CLAUDE.md

Memory of the Mythic Essentials repository (`https://github.com/joko-games/mythic-essentials`): project context, standing rules and current status. The
global rules are in `~/.claude/CLAUDE.md` (versioned in `primo-ideas/claude/CLAUDE.md`); technical
documentation is in `docs/` (index: `docs/README.md`).

## What it is

Mythic Essentials, a World of Warcraft addon (Retail, 12.1.5), the third of the Essentials after Trading
Essentials (`../trading-essentials`) and World Quest Essentials (`../world-quest-essentials`): a small
Mythic+ window with the group's DPS (class-coloured bars, names only on hover), the key timer and
progress in the spirit of WarpDeplete but smaller, and the number of players without flask or food
(who, on hover; nothing shown when everyone is ready).

## Layout

The addon is at the repository root (`MythicEssentials.toc`, the `.lua` files it lists, `UI/`,
`Locales/`, `Media/`); `install.ps1` copies only those into a local WoW install. `tests/` holds the test
suite (Lua 5.1 through lupa, against a small fake client). `art/` holds the icon sources.

## Build, test, release

```powershell
py -V:3.12 -m pip install "lupa>=2.0"
py -V:3.12 tests/run.py
.\install.ps1                        # then /reload in game
```

CI (`.github/workflows/ci.yml`, every push to `main`) runs the tests; it deploys nothing. Pushing a tag
releases on CurseForge (webhook): the user pushes, not Claude.

## Decisions

- 2026-11-25: v1.0.0 shows DPS only (no healing, no other meters). The damage comes from the game's
  damage meter (`C_DamageMeter`, Overall session), the only source since Midnight; its values are secret
  in combat (docs/architecture.md).
- 2026-11-25: consumables are flask and food, recognised by buff name in the client's language (and the
  "Well Fed" icon), not by spell IDs, and checked out of combat only.
- 2026-11-25: the icon is a violet keystone with a plus inside a gold timer ring, drawn for the project and
  dedicated to CC0 (`art/icon.svg`); `Media/Icon.tga` is built from it and is also the minimap icon.
  `art/icon.png` is the CurseForge project icon.
- 2026-11-25: history: the first commit, "Initial commit" (the `LICENSE` file alone), is the user's own and
  stays so; everything after it is Claude's, without trailer.

## Working rules

- **Language:** everything in the repository is in English, except translations (`Locales/`). Talk to
  the user in French.
- The logic is tested outside the game; what only the client can show is checked in game by the user
  (README, "Check in game").

## Status

- 2026-11-25: v1.0.0 written and tagged `v1.0.0` locally, tests green; not yet seen in game. Nothing
  pushed: the user pushes `main` and the tag to `origin` (the tag releases on CurseForge).
  The CurseForge summary and description are in `docs/curseforge.md`.
- Unverified in game, to watch first: the `C_DamageMeter` field and enum names (taken from community
  documentation), the forces' `quantityString` format, and the flask buff names of Midnight.
