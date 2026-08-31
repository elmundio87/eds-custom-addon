---
name: wow-addon-structure
description: >-
  Guides the layout of Eds Custom Addon (WotLK 3.3.5a / AzerothCore).
  Use when adding a module, editing the TOC, changing Core/Config, or scaffolding
  a new UI/automation feature for this repo.
disable-model-invocation: true
---

# WoW addon structure (this repo)

## Layout

```
Eds Custom Addon.toc     # filename MUST match the folder name
Core/Util.lua            # Trim, Print, Debug, Debounce
Core/Config.lua          # defaults + SavedVariablesPerCharacter merge
Core/Core.lua            # frame, module registry, /eca slash dispatch
Core/UI.lua              # /eca ui toggle panel (not a feature module)
Modules/<Name>/<Name>.lua
docs/api/                # 3.3.5 API cache
```

No Ace3 or LibStub. Plain `CreateFrame` + events. Interface: **30300**.

## Adding a module

1. Create `Modules/<Name>/<Name>.lua`.
2. Append `Modules\<Name>\<Name>.lua` to the TOC (backslashes, after Core files).
3. Add `defaults.modules.<Name> = { enabled = true }` in `Core/Config.lua` if the module is togglable.
4. Implement the registry contract and call `EdsCustomAddon:RegisterModule(module)` at file end.

## Module contract

```lua
local addon = EdsCustomAddon
local MyMod = {
    name = "MyMod",           -- keys db.modules and /eca <name>
    title = "My Mod",         -- optional; /eca ui checkbox label
    tooltip = "What it does", -- optional; hover text on the checkbox
}

function MyMod:Init(owner)   -- register events on owner
function MyMod:Enable()      -- start work; set self.enabled = true
function MyMod:Disable()     -- stop work; set self.enabled = false
function MyMod:OnEvent(event, ...)  -- only while enabled
function MyMod:Slash(rest)   -- /eca mymod <rest>

addon:RegisterModule(MyMod)
```

- `Init` runs once after SavedVariables load. `Enable`/`Disable` may run later via `/eca` or `/eca ui`.
- Register events with `owner:RegisterEvent("EVENT")`. Core dispatches to enabled modules.
- Keep feature code in the module. Core stays a thin registry + slash router.
- Registered modules appear automatically on the `/eca ui` panel. Do not put the panel itself in `Modules/`.

## TOC rules

- `## Interface: 30300`
- `## SavedVariablesPerCharacter: EdsCustomAddonDB` (already declared; do not add a second SV unless needed)
- Load order: Util → Config → Core → UI → modules
- Paths use `\` (Windows client, same as sibling addons)

## Slash

`/eca` is owned by Core. First token is the module name (case-insensitive) or `ui` / `debug` / `help`. Do not register extra `SLASH_*` keys unless Core cannot route the command. `/eca ui` toggles `ECA_Panel`.

## Details

See [reference.md](reference.md) for Enable/Disable lifecycle, SavedVariables merge, and a full new-module checklist.
