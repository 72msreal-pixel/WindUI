# Modules.luau - Multi-Language System for WindUI

So basically, this is a small module you plug into WindUI so your UI can switch languages. You write the translations yourself for a few languages you care about (like `en` and `vi`), and it'll auto-translate the rest with Google Translate. Translations get cached to a file, so next time you open it, it doesn't have to start from scratch.

There are **30 languages** built into the dropdown. This might run a bit long, but I wanted to write it up properly so that next time you (or anyone else) opens it, you can just get going.

---

## Table of Contents

1. [What it does](#what-it-does)
2. [What you need](#what-you-need)
3. [Quick setup (copy, paste, done)](#quick-setup)
4. [Writing text in the UI](#writing-text-in-the-ui)
5. [All Localization options](#all-localization-options)
6. [Functions you can call](#functions-you-can-call)
7. [Icons for translation notifications](#icons-for-translation-notifications)
8. [Customizing notification text](#customizing-notification-text)
9. [Blocking a word from being translated](#blocking-a-word-from-being-translated)
10. [Where the cache lives](#where-the-cache-lives)
11. [Full example](#full-example)
12. [Common errors](#common-errors)

---

## What it does

- Switches the whole UI's language on the fly. No need to rerun the script.
- Manual translations (the most accurate) for whichever languages you want.
- Auto-translates any missing text with Google Translate (turn it on with `AutoTranslate = true`).
- Checks its own auto-translations, and if one looks off (like leftover source text or mixed-in words from another language), it redoes it.
- Caches translations and remembers the language you picked, so it's ready next time you run the script.
- Shows "Translating... / Done / Failed" notifications, with icons.
- Comes with a language dropdown. One line and you're done.

## What you need

- An executor that supports `loadstring` and `game:HttpGet`.
- The WindUI version you're using (here it's the `WindUI-Mod` build), since the module hooks into `CreateWindow`, `Localization`, and `SetLanguage`.
- For **auto-translate**, your executor has to be able to reach Google Translate (through `request`/`http_request` or `HttpGet`). If it can't, only the languages you wrote translation tables for will work, and everything else stays in the source language.
- For caching, your executor needs `readfile` / `writefile`. It still works without them, it just won't save anything.

## Quick setup

This is the most important part, so listen up: **you have to call `Install` right after loading WindUI, and before `Localization` and `CreateWindow`.** If you do it later, the hook won't catch in time.

```lua
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

-- 1) Load + install the module (put this BEFORE Localization and CreateWindow)
local Modules = loadstring(game:HttpGet("https://raw.githubusercontent.com/72msreal-pixel/WindUI/refs/heads/main/Modules.luau"))()
local LangController = Modules:Install(WindUI)

-- 2) Set up your languages
WindUI:Localization({
    Enabled = true,
    DefaultLanguage = "en",
    AutoTranslate = true,
    Translations = {
        en = { Hello = "Hello" },
        vi = { Hello = "Xin chào" },
    },
})

-- or
-- WindUI:Localization({
--    Enabled = true,
--    DefaultLanguage = "en",
--    AutoTranslate = true,
--    Translations = {
--        en = {},
--    },
--})

-- 3) Create the window like normal (the module grabs Folder from here on its own)
local Window = WindUI:CreateWindow({
    Title = "loc:Hello",
    Folder = "My Hub",
})

-- or
-- local Window = WindUI:CreateWindow({
--    Title = "Hello",
--    Folder = "My Hub",
-- })

```

About `Folder`: you **don't need** to pass `Folder` into `Install`. The module pulls it from `CreateWindow`. (You can pass it if you want, it's just redundant.)

Then add the language dropdown to a tab, usually your Settings tab:

```lua
LangController:AddDropdown(TabHandles.Settings, {
    Title = "loc:Language",
    Desc  = "loc:LanguageDesc",
})

-- or

-- LangController:AddDropdown(TabHandles.Settings, {
--     Title = "Select Language",
--     Desc  = "Your Desc :3",
-- })
```

That's it. The dropdown has all 30 languages, and whichever one you pick, the UI switches to it.

## Writing text in the UI

There are two ways, and you can mix them.

### Option 1: use `loc:` keys

Write `"loc:KeyName"` wherever you'd put text, then define that key in the `Translations` table.

```lua
Translations = {
    en = { Main = "Main", MainDesc = "Main features" },
    vi = { Main = "Chính", MainDesc = "Phần chính" },
}

Tabs.Features:Tab({ Title = "loc:Main", Desc = "loc:MainDesc" })
```

This one's the most accurate since you control every single string.

**Easy to forget:** every key you use **has to exist in the source language's table** (`en` by default). If it's missing, the UI will show `[KeyName]` (with square brackets) so it's easy to spot.

### Option 2: just write plain English

You don't need to declare anything. Just write regular English text:

```lua
Tab:Toggle({ Title = "Auto Farm", Callback = function(v) end })
```

When you pick another language, the module will translate "Auto Farm" automatically (needs `AutoTranslate = true`).

I really want to stress this one: plain text **has to be in the source language** (English if you set `SourceLanguage = "en"`). If you write Vietnamese straight into the UI, it'll still assume it's English and try to translate it, and you'll get some really weird results.

And if you want Vietnamese to be the source language, set `SourceLanguage = "vi"` and `DefaultLanguage = "vi"`, then write the `vi` table as your main one. That works too, just stay consistent.

## All Localization options

You pass these into `WindUI:Localization({ ... })`. Anything you leave out uses the default.

| Option | Default | What it does |
|---|---|---|
| `Enabled` | `true` | Turns the whole system on/off. |
| `Prefix` | `"loc:"` | The prefix used to recognize keys. You can change it, but it can't be empty. |
| `DefaultLanguage` | `"en"` | The language it opens in the first time. |
| `SourceLanguage` | = `DefaultLanguage` | The language of the text you write in your code. |
| `Language` | none | Forces a specific language at startup (ignores the saved one). |
| `Translations` | `{}` | Your manual translation tables, like `{ en = {...}, vi = {...} }`. |
| `AutoTranslate` | `false` | When `true`, missing text gets auto-translated with Google. |
| `NoTranslations` | `{}` | A list of words that never get translated (see [below](#blocking-a-word-from-being-translated)). |
| `TranslateUnkeyed` | `true` | Set to `false` to only translate text with `loc:` and leave plain text alone. |
| `Languages` | 14 common codes | The list of language codes allowed for auto-translate. The `AddDropdown` dropdown always uses all 30. |
| `Notifications` | `true` | Shows notifications while translating. |
| `Messages` | defaults | Set your own notification text ([see here](#customizing-notification-text)). |
| `Icons` | defaults | Icons for the notifications ([see here](#icons-for-translation-notifications)). |
| `Cache` | `true` | Whether to save translations to a cache file. |
| `SaveSelection` | `true` | Whether to remember the language the user picked. |
| `AutoPruneCache` | `false` | When `true`, automatically deletes translations for text that's no longer used. |
| `Verify` | `true` | Automatically checks and fixes auto-translations. |
| `OnRepair` | none | A function that gets called whenever a translation is repaired. |
| `OnError` | none | A function that receives an error string whenever the module hits an error. |
| `Request` | none | Provide your own HTTP function if your executor is unusual. Receives `{Url, Method, Timeout}`. |
| `SyncSwap` | `true` | When you pick a new language, it keeps the old one until translation finishes, then swaps everything at once (so text doesn't jump around). |
| `SwapTimeout` | `10` | The max number of seconds to wait before swapping even if translation isn't done. |
| `Concurrency` | `2` | How many translation requests run in parallel (max 8). |
| `BatchSize` | `40` | How many strings get bundled into each request. |
| `RequestInterval` | `0.3` | The gap between requests (in seconds), so Google doesn't block you. |
| `MaxRetries` | `2` | How many times it retries on network errors (max 3). |
| `RetryCooldown` | `60` | How long (in seconds) to wait before retrying a string that failed to translate. |

You really don't need to touch the last few (`Concurrency`, `BatchSize`, `RequestInterval`...). The defaults are fine, I just listed them to be complete.

## Functions you can call

`LangController` is what you get back from `Modules:Install(...)`.

```lua
LangController:SetLanguage("vi")      -- switch languages, returns true/false, error
LangController:GetLanguage()          -- get the current language code, e.g. "vi"
LangController:Refresh()              -- reapply all text
LangController:Refresh(true)          -- same as above, but also retries strings that failed before
LangController:GetStatus()            -- info table: Language, Busy, TrackedObjects, CachePath, LastError...
LangController:GetCachePath()         -- path to the cache file
LangController:Destroy()              -- shuts the whole system down (puts WindUI back like it was)
```

Listen for language changes:

```lua
local conn = LangController:OnChanged(function(newLang, oldLang)
    -- do something when the language changes
end)
conn:Disconnect() -- stop listening
```

The language dropdown (`Callback` is optional):

```lua
LangController:AddDropdown(Tab, {
    Title = "loc:Language",
    Desc  = "loc:LanguageDesc",
    Callback = function(code, ok, err)
        -- code: the language code that was just picked, ok: whether it worked
    end,
})
```

Also, after `Install`, you can call `WindUI:SetLanguage("vi")` and `WindUI:GetLanguage()` directly.

If your WindUI fork doesn't expose its GUI to the module (the module will say "No exposed GUI root found"), attach it manually with:

```lua
LangController:AttachRoot(YourScreenGui)
```

### Advanced functions (rarely used)

These live in `LangController.Manager`:

```lua
local M = LangController.Manager
M:SetTranslations("vi", { Hello = "Chào nha" })   -- add/edit translations at runtime (false = delete a line)
M:ClearCache("vi")                                 -- clear the cache for one language (leave it out to clear everything)
M:GetOriginalText(textLabel)                       -- get the original text of a TextLabel
M:SetOriginalText(textLabel, "New text")           -- change the original text of a TextLabel
M:SetTextParts(textLabel, { "Line 1", "Line 2" }, "\n") -- text built from multiple parts, each part translated separately
```

## Icons for translation notifications

Whenever it translates, the module shows a WindUI notification. There are 3 types, and each one has a default icon:

| Type | When | Default icon |
|---|---|---|
| `Start` | Translation starts | `languages` |
| `Done` | Translation finishes | `badge-check` |
| `Fail` | Translation fails | `triangle-alert` |

Icons are **Lucide icon names** (WindUI uses the Lucide set), or `"rbxassetid://..."` if you want your own. Change them with the `Icons` option:

```lua
WindUI:Localization({
    ...
    Icons = {
        Start = "loader",
        Done  = "check",
        Fail  = "wifi-off",
        -- Fail = "rbxassetid://123456789",  -- a custom icon works too
        -- Start = false,                     -- false = no icon
    },
})
```

If you mistype an icon name (or the icon isn't in the set), the notification still shows up fine, it just won't have an icon, and nothing errors out. So if an icon's missing, double-check the name.

## Customizing notification text

The module comes with built-in notification text for `en, vi, zh, ja, ko, th, id, fr, de, es, pt, ru`. Any language that isn't on that list falls back to English. If you want to write your own, use `Messages`:

```lua
Messages = {
    vi = {
        Title = "Ngôn ngữ",
        Start = "Đang dịch sang %s...",
        Done  = "Dịch xong rồi (%s)",
        Fail  = "Dịch lỗi (%s), lát thử lại",
    },
}
```

`%s` gets replaced with the uppercase language code (like `JA`). Every entry is optional, and anything you skip uses the default.

To turn notifications off completely: `Notifications = false`.

## Blocking a word from being translated

There are some words you definitely don't want translated: hub names, theme names, people's names, stuff like that. You've got 3 ways to do it:

**Option 1:** put them in `NoTranslations`:

```lua
NoTranslations = { "My Hub", "Dark", "Blue" }
```

These words stay as-is (whether they're the whole line or show up inside another line).

**Option 2:** put them inside a language table, under a special key called `NoTranslations`:

```lua
en = {
    NoTranslations = { "My Hub", "Dark" },
    Hello = "Hello",
}
```

**Option 3:** for one specific object (a TextLabel or TextButton), set an attribute:

```lua
textLabel:SetAttribute("ModulesNoTranslate", true)
```

## Where the cache lives

The file is at:

```
<your Folder>/language/LanguageCache.json
```

For example, if `Folder = "My Hub"`, the file is `My Hub/language/LanguageCache.json`. It holds the saved auto-translations and the language the user picked last time. You can get the path with `LangController:GetCachePath()`.

To start translating from scratch, delete this file or call `LangController.Manager:ClearCache()`.

If you change the source text in your code (like editing the `en` table), the module notices and throws out the old cache on its own, so you won't get stuck with stale translations.

## Full example

This one's shorter than the real script, but it's enough to show how everything fits together:

```lua
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local Modules = loadstring(game:HttpGet("https://raw.githubusercontent.com/72msreal-pixel/WindUI/refs/heads/main/Modules.luau"))()
local LangController = Modules:Install(WindUI)

WindUI:Localization({
    Enabled = true,
    Prefix = "loc:",
    DefaultLanguage = "en",
    SourceLanguage = "en",
    AutoTranslate = true,
    Notifications = true,

    Icons = {
        Start = "languages",
        Done  = "circle-check",
        Fail  = "triangle-alert",
    },

    NoTranslations = { "My Hub", "Dark", "Blue" },

    Translations = {
        en = {
            HubTitle = "My Hub",
            Main = "Main",
            Settings = "Settings",
            AutoFarm = "Auto Farm",
            Language = "Language",
            LanguageDesc = "30 languages - manual + automatic translation",
        },
        vi = {
            HubTitle = "My Hub",
            Main = "Chính",
            Settings = "Cài đặt",
            AutoFarm = "Tự động cày",
            Language = "Ngôn ngữ",
            LanguageDesc = "30 ngôn ngữ - dịch thủ công + tự động",
        },
    },
})

local Window = WindUI:CreateWindow({
    Title = "loc:HubTitle",
    Folder = "My Hub",
    Theme = "Blue",
})

local Section = Window:Section({ Title = "loc:Main", Opened = true })
local MainTab = Section:Tab({ Title = "loc:Main", Icon = "house" })
local SettingsTab = Section:Tab({ Title = "loc:Settings", Icon = "settings" })

-- Keyed text: translated by hand (en / vi), auto-translated for everything else
MainTab:Toggle({
    Title = "loc:AutoFarm",
    Callback = function(value) end,
})

-- Plain English text: fully auto-translated
MainTab:Button({
    Title = "Teleport to Spawn",
    Callback = function() end,
})

-- Language dropdown
LangController:AddDropdown(SettingsTab, {
    Title = "loc:Language",
    Desc = "loc:LanguageDesc",
})
```

## Common errors

**The UI shows `[Main]`, `[Settings]` (with square brackets).**
You used `loc:Main`, but you never defined the `Main` key in the source language's table (`en`). Add it and you're good.

**You pick another language but the text doesn't change.**
A few common causes:
- `AutoTranslate = true` isn't on, and you also haven't written a translation table for that language.
- Your executor can't reach Google Translate. Check `LangController:GetStatus().LastError` to see the error.
- You called `Install` after `CreateWindow`. It has to come first.

**"Translation failed" notification.**
Usually it's the network, or your executor is blocking the request. The module retries a few times on its own. If it keeps failing, you can pass in your own HTTP function with the `Request` option.

**Auto-translations look a little off.**
That's normal, it's Google Translate. For the important stuff, write it into the `Translations` table yourself. Manual translations always win over auto-translations.

**Plain Vietnamese text is getting translated wrong.**
Check out the [plain English section](#option-2-just-write-plain-english). Plain text has to actually be in the source language.

**It says "No exposed GUI root found".**
Your WindUI fork doesn't expose its GUI. Call `LangController:AttachRoot(ScreenGui)` with your hub's ScreenGui.

**You see a `warn` from `[Modules.Language]` in the console.**
That's the module reporting its own errors (network, text too long, etc.). It's harmless as long as the UI is still working. If you want to catch the errors and handle them yourself, use the `OnError` option.

---

If anything's unclear, or you think a section is missing, just say so and I'll add it.
