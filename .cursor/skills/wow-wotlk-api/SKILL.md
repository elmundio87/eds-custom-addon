---
name: wow-wotlk-api
description: >-
  WotLK 3.3.5a (interface 30300) API quick-reference for Eds Custom Addon.
  Use when choosing events, group roster APIs, XP flags, or AzerothCore
  dot-commands, or when tempted to use retail/MoP APIs.
disable-model-invocation: true
---

# WotLK 3.3.5a API

Read the local cache before guessing an API:

- [docs/api/README.md](../../../docs/api/README.md)
- [docs/api/events.md](../../../docs/api/events.md)
- [docs/api/group-roster.md](../../../docs/api/group-roster.md)
- [docs/api/server-commands.md](../../../docs/api/server-commands.md)

## Does not exist in 3.3.5

`IsInGroup`, `IsInRaid`, `GetNumGroupMembers`, `GetNumSubgroupMembers`, `GROUP_ROSTER_UPDATE`, `C_Timer`, `C_PartyInfo`.

## Does exist (use these)

| Need | API |
|------|-----|
| Party size (excludes you) | `GetNumPartyMembers()` |
| Raid size (includes you) | `GetNumRaidMembers()` |
| Online? | `UnitIsConnected(unit)` |
| Same unit? | `UnitIsUnit(a, b)` |
| XP locked? | `IsXPUserDisabled()` |
| Roster events | `PARTY_MEMBERS_CHANGED`, `RAID_ROSTER_UPDATE` |
| Online/offline hints | `PARTY_MEMBER_DISABLE`, `PARTY_MEMBER_ENABLE` |
| Login/reload scan | `PLAYER_ENTERING_WORLD` |
| Rez / leave ghost | `PLAYER_ALIVE`, `PLAYER_UNGHOST` |
| Server XP toggle | `addon:SendServerCommand(db.xp.enable or db.xp.disable)` |

## Details

See [reference.md](reference.md) for a compact cheat sheet and links.
