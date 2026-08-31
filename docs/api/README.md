# WotLK 3.3.5a API cache

Curated notes for this addon. Interface version: **30300**.

This is not a full Blizzard API dump. Use it for party/raid roster, XP flags, events, and AzerothCore dot-commands.

## Files

- [events.md](events.md) — party, raid, login, XP events
- [group-roster.md](group-roster.md) — `GetNum*`, unit tokens, `UnitIsConnected`
- [server-commands.md](server-commands.md) — `.xp on|off` via `SendChatMessage`

## Client rules

- Lua 5.1. No `C_Timer`. Debounce with an `OnUpdate` frame (see `Core/Util.lua`).
- MoP+ APIs do **not** exist: `IsInGroup`, `IsInRaid`, `GetNumGroupMembers`, `GROUP_ROSTER_UPDATE`.
- Addon folder name **is** the addon name. TOC filename must match the folder (`Eds Custom Addon.toc`).

## External references

- [ClassicAPI 3.3.5 dump](https://octowow.st/git/brues/ClassicAPI/raw/commit/6be25d78e0b1fdce9d778952b5c8040a604d3eda/docs/BlizzardScriptAPI_3.3.5.md)
- [Party events (AddOn Studio)](https://addonstudio.org/wiki/WoW:Events/Party)
- [ChromieCraft custom commands](https://chromiecraft.com/en/custom-server-commands/)
