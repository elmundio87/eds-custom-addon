---
name: wow-lua-standards
description: >-
  Lua 5.1 / WotLK 3.3.5a coding standards for Eds Custom Addon.
  Use when writing or reviewing .lua files, slash handlers, event frames,
  debounce timers, or SendChatMessage server commands in this repo.
disable-model-invocation: true
---

# Lua standards (3.3.5a)

## Scope

- Lua 5.1 only. No `C_Timer`, no `bit32` (use `bit` if needed), no `IsInGroup`.
- One global: `EdsCustomAddon`. Everything else is `local`.
- Match existing style: 4-space indent, no tabs, `function addon:Method()` for public API.

## Rules

1. **Locals first.** File-scope `local addon = EdsCustomAddon`. Do not pollute `_G`.
2. **Event-driven.** Do not poll roster or XP on `OnUpdate`. `OnUpdate` is allowed only for debounce in `Core/Util.lua`.
3. **Debounce bursts.** `PARTY_MEMBERS_CHANGED` can fire several times. Use `addon:Debounce(key, 0.2, fn)`.
4. **Server commands are dots.** `addon:SendServerCommand(addon.db.xp.disable)` (whisper-self). Never `SendChatMessage("/xp ...")`, never SAY from modules, never `.xp on|off` on `mod-individual-xp` (use `enable`/`disable`).
5. **Idempotent side effects.** Compare desired state to `IsXPUserDisabled()` (or equivalent) before sending a command.
6. **Skip self in raids.** `GetNumRaidMembers()` includes the player; `GetNumPartyMembers()` does not. Use `UnitIsUnit(unit, "player")`.
7. **Truthiness.** Many APIs return `1` or `nil`. Prefer `if UnitIsConnected(unit) then` or `and true or false` when storing a boolean.
8. **Comments.** Only for 3.3.5 traps (missing APIs, raid-includes-player, dot vs slash).

## Print vs debug

```lua
addon:Print("user-visible")
addon:Debug("only when /eca debug")
```

## Do not

- Introduce Ace3/LibStub unless the user asks.
- Use MoP+ APIs (`GROUP_ROSTER_UPDATE`, `C_Timer.After`, `IsInGroup`).
- Register a second slash command for a module; route through `/eca`.
- Catch errors with empty `pcall` around the whole module.

See [reference.md](reference.md) for debounce usage, unit-token loops, and a short anti-pattern list.
