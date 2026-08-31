# Lua standards reference

## File template

```lua
local addon = EdsCustomAddon

local Foo = {
    name = "Foo",
}

function Foo:Init(owner)
    self.addon = owner
    owner:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function Foo:Enable()
    self.enabled = true
end

function Foo:Disable()
    self.enabled = false
end

function Foo:OnEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        addon:Debounce("Foo.Sync", 0.2, function()
            Foo:Sync()
        end)
    end
end

addon:RegisterModule(Foo)
```

## Debounce

`addon:Debounce(key, delay, fn)` replaces any pending callback with the same `key`. `delay` is seconds (`GetTime()` based). Default 0.2.

The debounce frame lives in `Core/Util.lua`. Do not create extra `OnUpdate` frames in modules.

## Sending `.xp` (and other GM commands)

```lua
addon:SendServerCommand(addon.db.xp.enable)
addon:SendServerCommand(addon.db.xp.disable)
```

Whispers `UnitName("player")` so the command works while dead/ghost. SAY is only a last-resort fallback when the name is missing and the player is alive.

This realm's module is `mod-individual-xp`: `.xp enable` / `.xp disable`. `.xp on` / `.xp off` print usage and do nothing. Override `db.xp.enable` / `db.xp.disable` for ChromieCraft-style commands.

Read-back: `IsXPUserDisabled()` → `1` if XP is off.

Only send when the flag disagrees with the desired state. PartyXP also resyncs on `PLAYER_ALIVE` / `PLAYER_UNGHOST`.

## Group scan

```lua
local count, prefix = GetNumRaidMembers(), "raid"
if count == 0 then
    count, prefix = GetNumPartyMembers(), "party"
end
for i = 1, count do
    local unit = prefix .. i
    if not UnitIsUnit(unit, "player") and UnitIsConnected(unit) then
        -- online partner
    end
end
```

## Anti-patterns

| Avoid | Use instead |
|-------|-------------|
| `IsInGroup()` | `GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0` |
| `GROUP_ROSTER_UPDATE` | `PARTY_MEMBERS_CHANGED` + `RAID_ROSTER_UPDATE` |
| `C_Timer.After(0.2, fn)` | `addon:Debounce` |
| `SendChatMessage("/xp off")` | `addon:SendServerCommand(addon.db.xp.disable)` |
| `SendChatMessage(".xp off", "SAY")` | `addon:SendServerCommand(addon.db.xp.disable)` |
| `.xp on` / `.xp off` on this server | `.xp enable` / `.xp disable` |
| Polling roster in OnUpdate | Events + debounce |
| `raid1` without skipping player | `UnitIsUnit(unit, "player")` |
| Global `function SyncXP()` | `function PartyXP:SyncXP()` |

## String / slash parsing

```lua
msg = addon:Trim(msg or "")
local cmd, rest = msg:match("^(%S+)%s*(.*)$")
cmd = cmd and string.lower(cmd) or ""
```

No `string.split` in 5.1 unless you write it. Keep parsers linear.

## Frames

Name the core frame `EdsCustomAddonFrame` (already created). Module UI frames, when added, should use an `ECA` prefix (`ECA_PartyXPFrame`) to avoid collisions with sibling addons.
