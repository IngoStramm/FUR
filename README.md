# FUR - Feral Uncrit Readout

FUR is a compact World of Warcraft addon for level 70 feral druid tanks on the Anniversary Burning Crusade client.

It shows whether your currently equipped gear is crit immune against level 73 boss mobs and level 72 dungeon mobs. The compact view shows how much Defense Rating or Resilience Rating you can lose, or how much you still need, to reach crit immunity.

The expanded view can also show Dodge, Miss, Avoidance, Armor, Hit, and Expertise cap information.

## Features

- Compact and expanded display modes.
- Crit immunity readout for level 73 and level 72 enemies.
- Defense and Resilience values shown as rating, matching item tooltips.
- Survival of the Fittest talent detection.
- Optional auto-hide or auto-minimize in combat.
- Movable window with lock option.
- Options panel under Game Options > AddOns > FUR.
- Standalone movable config window with `/fur config`.
- English and ptBR labels.

## Commands

```text
/fur
/fur expand
/fur compact
/fur toggle
/fur lock
/fur hide
/fur show
/fur reset
/fur debug
/fur options
/fur config
```

## Installation

Download `FUR.zip` from the latest GitHub Release and extract it into:

```text
World of Warcraft/_anniversary_/Interface/AddOns/
```

After extraction, the addon folder should be:

```text
World of Warcraft/_anniversary_/Interface/AddOns/FUR/
```

Restart the game or reload the UI.

Do not use GitHub's green **Code > Download ZIP** button for installation. That downloads the source repository snapshot, not the packaged addon.

## Compatibility

- Interface: `20505`
- Target client: World of Warcraft Anniversary / Burning Crusade Classic

## Notes

FUR uses in-game APIs such as `UnitDefense`, `GetCombatRating`, `GetCombatRatingBonus`, `GetDodgeChance`, and `GetExpertise` where available. Rating equivalents are rounded upward when fractional.
