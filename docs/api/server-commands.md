# Server commands (AzerothCore / ChromieCraft)

Server GM/player commands are **dot-commands**. The client has no `SlashCmdList` entry for them. The server intercepts outgoing chat that starts with `.`.

## Sending a command

Use `addon:SendServerCommand(command)`. It whispers the player so AzerothCore still sees the leading `.` when `/say` is blocked (ghost). Nearby players do not see the command.

```lua
addon:SendServerCommand(addon.db.xp.disable)
addon:SendServerCommand(addon.db.xp.enable)
```

Fallback if `UnitName("player")` is empty: `RAID`, then `PARTY`, then `SAY` only while alive (`UnitIsDeadOrGhost` is false).

Do **not** send `SendChatMessage("/xp off")`. A leading slash is a client command, not a server command.

Do **not** send server commands with `"SAY"` from feature modules. Ghosts cannot `/say`; the line never reaches the server.

## This server: `mod-individual-xp`

The live realm answers unknown `.xp` args with a usage dump (`default`, `disable`, `enable`, `set`, `view`). **`.xp on` / `.xp off` are not valid here** — they print help and do not change the XP flag.

| Command | Effect |
|---------|--------|
| `.xp enable` | Re-enable XP gain |
| `.xp disable` | Disable XP gain |
| `.xp view` | Show current rate |
| `.xp set <n>` | Set personal multiplier |
| `.xp default` | Reset to server default |

Defaults live in `EdsCustomAddonDB.xp`:

```lua
xp = { enable = ".xp enable", disable = ".xp disable" }
```

If a realm uses ChromieCraft-style `.xp on` / `.xp off`, change those two strings. Do not leave `on`/`off` on a `mod-individual-xp` server.

Client read-back (both modules set the same flag):

```lua
-- 1 if XP is disabled, nil if enabled
if IsXPUserDisabled() then
    -- XP is off
end
```

PartyXP only sends a command when the desired state differs from `IsXPUserDisabled()`, so `/reload` does not spam `.xp`.

When `db.modules.PartyXP.paused` is true, PartyXP always sends `.xp disable` if XP is on, ignoring roster. `/eca partyxp pause` sets the flag and syncs immediately; `/eca partyxp unpause` clears it and debounced sync restores roster logic.

When `PartyXP.forceXP` is true (session-only, not saved), PartyXP sends `.xp enable` if XP is off, ignoring roster. `/eca partyxp force` sets it; `/eca partyxp unforce` clears it. Cleared on `/reload`. Mutually exclusive with pause.

## Addon slash commands (client)

```lua
SLASH_EDSCUSTOMADDON1 = "/eca"
SlashCmdList["EDSCUSTOMADDON"] = function(msg)
    -- msg is the text after /eca
end
```

This addon: `/eca ui`, `/eca partyxp on|off|pause|unpause|force|unforce|status`, `/eca debug`.
