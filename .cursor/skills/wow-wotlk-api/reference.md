# 3.3.5 API cheat sheet

Full write-ups live in `docs/api/`. This file is a one-page reminder.

## 3.3.5 vs MoP+

| Task | 3.3.5a | Do not use (MoP+) |
|------|--------|-------------------|
| In a group? | count > 0 | `IsInGroup()` |
| In a raid? | `GetNumRaidMembers() > 0` | `IsInRaid()` |
| Member count | `GetNumPartyMembers` / `GetNumRaidMembers` | `GetNumGroupMembers()` |
| Roster event | `PARTY_MEMBERS_CHANGED`, `RAID_ROSTER_UPDATE` | `GROUP_ROSTER_UPDATE` |
| Delayed call | `addon:Debounce` / OnUpdate | `C_Timer.After` |

## Events this addon uses

- `ADDON_LOADED` — Core only; SavedVariables ready when `arg1 == "Eds Custom Addon"`
- `PLAYER_ENTERING_WORLD` — initial + zone-in sync
- `PARTY_MEMBERS_CHANGED` — party roster
- `RAID_ROSTER_UPDATE` — raid roster
- `PARTY_MEMBER_DISABLE` / `PARTY_MEMBER_ENABLE` — reconnect; `arg1` is a **name**, re-scan anyway

## XP

ChromieCraft: `.xp on` / `.xp off` (free). Flag: `PLAYER_FLAGS_NO_XP_GAIN`. Client: `IsXPUserDisabled()`.

Other AC modules may use `.xp enable|disable`. This server uses **on/off**.

## External dumps

If the cache is silent, check [ClassicAPI 3.3.5](https://octowow.st/git/brues/ClassicAPI/raw/commit/6be25d78e0b1fdce9d778952b5c8040a604d3eda/docs/BlizzardScriptAPI_3.3.5.md) and add a short note to `docs/api/` rather than relying on retail wowpedia.
