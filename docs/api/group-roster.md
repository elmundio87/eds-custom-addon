# Group roster (WotLK 3.3.5a)

## Counts

| Function | Returns |
|----------|---------|
| `GetNumPartyMembers()` | Other party members, 0–4. **Does not include the player.** In BGs this is the BG party. |
| `GetRealNumPartyMembers()` | Non-BG party count while in a battleground. |
| `GetNumRaidMembers()` | Raid size, 0–40. **Includes the player.** |
| `GetRealNumRaidMembers()` | Non-BG raid count while in a battleground. |
| `GetPartyMember(index)` | `1` if `partyN` exists, else `nil`. |
| `GetPartyLeaderIndex()` | Leader index 1–4, or `nil` if you are leader. |
| `IsPartyLeader()` / `IsRaidLeader()` / `IsRaidOfficer()` | Self checks. |
| `UnitInParty(unit)` / `UnitInRaid(unit)` | Membership. |

Do not use `IsInGroup()`, `IsInRaid()`, or `GetNumGroupMembers()` — they were added in MoP 5.0.4.

## Unit tokens

| Token | Meaning |
|-------|---------|
| `"player"` | You |
| `"party1"` … `"party4"` | Other party members (never you) |
| `"raid1"` … `"raid40"` | Raid members (**may be you**) |

`UnitName(unit)`, `UnitClass(unit)`, `UnitLevel(unit)`, `UnitIsConnected(unit)` accept these tokens.

`UnitIsConnected(unit)` returns `1` if online, `nil` if offline/disconnected.

`GetRaidRosterInfo(index)` returns `name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML`. Prefer `UnitIsConnected("raid"..i)` over the `online` field right after login.

## Detect group kind

```lua
local function GetGroupState()
    local raidCount = GetNumRaidMembers()
    if raidCount > 0 then
        return "raid", raidCount
    end
    local partyCount = GetNumPartyMembers()
    if partyCount > 0 then
        return "party", partyCount
    end
    return "solo", 0
end
```

## Iterate other members (skip self)

Raid tokens include the player. Party tokens do not. Always skip `"player"` so solo-in-a-raid-shell does not count as an online partner:

```lua
local function HasOnlinePartner()
    local count, prefix = GetNumRaidMembers(), "raid"
    if count == 0 then
        count, prefix = GetNumPartyMembers(), "party"
    end
    if count == 0 then
        return false
    end
    for i = 1, count do
        local unit = prefix .. i
        if not UnitIsUnit(unit, "player") and UnitIsConnected(unit) then
            return true
        end
    end
    return false
end
```

## Battlegrounds

`GetNumPartyMembers()` inside a BG can return the BG party, not your real group. Use `GetRealNumPartyMembers()` / `GetRealNumRaidMembers()` if a module must ignore BG groups. PartyXP v1 does not special-case BGs.
