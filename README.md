# SpellDensityLock

A small World of Warcraft addon that keeps your spell density and GPU feature settings at the values you chose, even when the game resets them on its own.

## Why this exists

Since patch 11.2, the Ally Spell Visual Density setting (Everything / Reduced / Essential) has a persistence bug: the options menu keeps showing your choice while the live console variable quietly resets, so the game renders other players' spell effects at full density anyway. Blizzard acknowledged the bug in August 2025 and announced a fix in September 2025, but players kept reporting the reset afterwards. The sibling values (spell clutter) get reset too, and the Optional GPU Features compatibility toggle is another setting players often want held in one position, because turning it off removes stutter and frame loss in Midnight content on many machines.

SpellDensityLock does one job: it watches a short list of console variables and restores your chosen values after every loading screen, again a few seconds later, and immediately if the game changes one mid-session, plus a quiet safety sweep every 60 seconds that catches any change the game made without announcing it. When it catches the game resetting a value, it says so in chat and keeps a running correction count, which doubles as dated evidence if you ever file or update a bug report.

## What it manages

| Setting | Console variable | Default held value |
| --- | --- | --- |
| Spell density filter | spellVisualDensityFilterSetting | 1 (Essential) |
| Spell clutter | spellClutter | 1 |
| Spell clutter, raid profile | RAIDspellClutter | 1 |
| Optional GPU features | GxCompatOptionalGpuFeatures | 0 (off) |

Values that do not exist on your client are skipped automatically.

## Install

1. Download this repository (Code button, Download ZIP) or clone it.
2. Put the files in a folder named `SpellDensityLock` inside `World of Warcraft\_retail_\Interface\AddOns\`.
3. The folder must contain `SpellDensityLock.toc` and `SpellDensityLock.lua`.
4. Launch the game. The addon has no window; it works silently unless it catches a reset.

## Commands

- `/sdl status` shows each live value next to your chosen value, plus the correction count.
- `/sdl essential`, `/sdl reduced`, `/sdl everything` set the spell density filter to hold.
- `/sdl clutter <number>` sets the spell clutter value to hold.
- `/sdl gpu off` holds Optional GPU Features off, `/sdl gpu on` holds it on, `/sdl gpu ignore` stops managing it. A /reload or relog may be needed before a GPU features change takes effect.
- `/sdl quiet` toggles the chat messages printed when a correction happens.

## Notes

- The addon only sets standard console variables. It modifies no game files and needs no libraries.
- It cannot remove spell visuals beyond what the Essential setting already does. No addon can; the client exposes no API for that.
- The correction counter and the date of the last correction are stored in the addon's saved variables.

## License

MIT
