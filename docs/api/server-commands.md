# Server commands (AzerothCore / ChromieCraft)

Server GM/player commands are **dot-commands**. The client has no `SlashCmdList` entry for them. The server intercepts outgoing chat that starts with `.`.

## Sending a command

```lua
SendChatMessage(".xp off", "SAY")
SendChatMessage(".xp on", "SAY")
```

`SendChatMessage(msg [, chatType [, language [, channel]]])`. Default chat type is `"SAY"`. Max 255 characters.

Do **not** send `SendChatMessage("/xp off")`. A leading slash is a client command, not a server command.

Sibling addons (Chatter) use the same pattern: `SendChatMessage(".llmc " .. command, "SAY")`.

## ChromieCraft XP toggle

| Command | Effect |
|---------|--------|
| `.xp on` | Re-enable XP gain |
| `.xp off` | Disable XP gain |

This sets `PLAYER_FLAGS_NO_XP_GAIN` on the character.

Client read-back:

```lua
-- 1 if XP is disabled, nil if enabled
if IsXPUserDisabled() then
    -- XP is off
end
```

PartyXP only sends a command when the desired state differs from `IsXPUserDisabled()`, so `/reload` does not spam `.xp`.

## Other AC modules (not this server)

`mod-individual-xp` uses `.xp enable` / `.xp disable` / `.xp set <n>`. ChromieCraft uses `.xp on|off`. Match the server.

## Addon slash commands (client)

Register a client slash handler with:

```lua
SLASH_EDSCUSTOMADDON1 = "/eca"
SlashCmdList["EDSCUSTOMADDON"] = function(msg)
    -- msg is the text after /eca
end
```

This addon: `/eca partyxp on|off|status` and `/eca debug`.
