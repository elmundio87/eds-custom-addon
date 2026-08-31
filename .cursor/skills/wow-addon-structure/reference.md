# Addon structure reference

## Load sequence

1. TOC lists Lua files. They execute top to bottom.
2. `Util.lua` creates `EdsCustomAddon` and helpers.
3. `Config.lua` attaches defaults and `LoadConfig`.
4. `Core.lua` creates `EdsCustomAddonFrame`, registers `ADDON_LOADED`, binds `/eca`.
5. `UI.lua` defines `CreateUI` / `ToggleUI` (panel is built after modules init).
6. Each module file calls `RegisterModule`.
7. `ADDON_LOADED` with `arg1 == "Eds Custom Addon"` → `LoadConfig` → `InitModules` → `CreateUI`.
8. For each module: `Init(addon)`, then `Enable()` if `db.modules[name].enabled ~= false`.

The addon **name** is the folder name (`Eds Custom Addon`). That string is what `ADDON_LOADED` delivers. The global table is `EdsCustomAddon`.

## Registry

| Field / method | Role |
|----------------|------|
| `addon.modules[name]` | Lookup by exact name |
| `addon.moduleOrder` | Init/dispatch order (TOC order) |
| `addon:RegisterModule(mod)` | No-op if name already registered |
| `addon:GetModule(name)` | Case-insensitive |
| `addon:EnableModule` / `DisableModule` | Persist to `db.modules[name].enabled` and call Enable/Disable |
| `addon:RegisterEvent(event)` | `frame:RegisterEvent` |

Core `OnEvent` swallows `ADDON_LOADED` for this addon. Every other event is forwarded to modules with `enabled` and `OnEvent`.

## SavedVariables

`EdsCustomAddonDB` is per-character. `LoadConfig` fills missing keys from `addon.defaults` without overwriting existing values.

```lua
addon.defaults = {
    debug = false,
    ui = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
    xp = { enable = ".xp enable", disable = ".xp disable" },
    modules = {
        PartyXP = { enabled = true },
    },
}
```

New module defaults go under `modules.<Name>`. Read via `addon.db` only after `Init` (never at file load).

## Slash routing

```
/eca                  → help
/eca help             → help
/eca ui               → toggle ECA_Panel
/eca debug            → toggle addon.db.debug
/eca partyxp on|off|status
/eca <module> <rest>  → module:Slash(rest)
```

Module slash handlers should `addon:Print` user-facing status. Use `addon:Debug` for noisy traces. `Enable`/`Disable` stay silent so the `/eca ui` checkboxes are not chat-spam.

Optional `module.title` and `module.tooltip` are used by the panel. New modules appear on `/eca ui` automatically once `RegisterModule` runs.

## New module checklist

1. `Modules/Foo/Foo.lua` with `name = "Foo"` (optional `title`, `tooltip`).
2. TOC line `Modules\Foo\Foo.lua` (after `Core\UI.lua`).
3. `defaults.modules.Foo = { enabled = true }` if togglable.
4. `Init`: `owner:RegisterEvent(...)` for events you handle.
5. `Enable`/`Disable` idempotent; do not send server commands from `Disable` unless the feature requires it.
6. Debounce bursty events with `addon:Debounce("Foo.Key", 0.2, fn)`.
7. Document any new server dot-command in `docs/api/server-commands.md`.

## Out of scope for v1

Ace3, XML frames, localization tables, git, minimap button, BG `GetRealNum*` handling. Add them as separate modules when needed, not as Core rewrites.
