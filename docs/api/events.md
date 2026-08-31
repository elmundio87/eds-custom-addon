# Events (WotLK 3.3.5a)

Register on a frame with `frame:RegisterEvent("EVENT_NAME")`. Handler: `OnEvent(self, event, ...)`.

## Login / load

| Event | Notes |
|-------|--------|
| `ADDON_LOADED` | `arg1` = addon name (folder name). SavedVariables are available. Fire once per addon. |
| `PLAYER_LOGIN` | Player is in-world enough for most APIs. After all `ADDON_LOADED`. |
| `PLAYER_ENTERING_WORLD` | Login, `/reload`, and zoning. Good for an initial roster scan. |
| `PLAYER_ALIVE` | Resurrected (including in-place). Use to retry commands that `/say` could not send as a ghost. |
| `PLAYER_UNGHOST` | Left ghost form. Same retry as `PLAYER_ALIVE`. |

## Party / raid

| Event | When |
|-------|------|
| `PARTY_MEMBERS_CHANGED` | Join/leave, invite result, roster change. **Primary party event.** Can fire several times per change. |
| `RAID_ROSTER_UPDATE` | Raid formed/disbanded, join/leave, loot method. |
| `PARTY_MEMBER_DISABLE` | Member offline or dead. `arg1` = player **name**, not a unit id. Re-scan the roster. |
| `PARTY_MEMBER_ENABLE` | Member back online. `arg1` = player name. Re-scan the roster. |
| `PARTY_INVITE_REQUEST` | Incoming invite. `arg1` = inviter name. |
| `PARTY_LEADER_CHANGED` | Leadership changed. |
| `PARTY_LOOT_METHOD_CHANGED` | Loot method changed. |

There is no `GROUP_ROSTER_UPDATE` in 3.3.5.

## XP

| Event | When |
|-------|------|
| `PLAYER_XP_UPDATE` | XP bar changed. |
| `PLAYER_LEVEL_UP` | Level up. |
| `UPDATE_EXHAUSTION` | Rested state changed. |

`IsXPUserDisabled()` is a function, not an event. Poll it after sending `.xp enable|disable`; the flag may update on the next tick.

## Patterns used in this addon

- Debounce roster handlers (~0.2s). `PARTY_MEMBERS_CHANGED` bursts.
- Re-scan the full roster on `PARTY_MEMBER_DISABLE` / `PARTY_MEMBER_ENABLE` instead of trusting `arg1`.
- First XP sync on `PLAYER_ENTERING_WORLD`, not only on `ADDON_LOADED` (roster can still be empty at load).
- Retry XP sync on `PLAYER_ALIVE` / `PLAYER_UNGHOST` (in-place rez may not fire `PLAYER_ENTERING_WORLD`).
