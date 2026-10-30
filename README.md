# Modules.luau - Hệ thống đa ngôn ngữ cho WindUI

Ừm, nói ngắn gọn thì đây là một cái module nhỏ gắn thêm vào WindUI để UI của bạn đổi được ngôn ngữ. Bạn tự viết bản dịch cho vài ngôn ngữ mình muốn (ví dụ `en` và `vi`), còn mấy ngôn ngữ còn lại thì để nó tự dịch bằng Google Translate. Bản dịch được lưu cache vào file, nên lần sau mở lại không phải dịch từ đầu.

Có sẵn **30 ngôn ngữ** trong dropdown. Có thể hơi dài dòng một chút, nhưng mình viết kỹ để lần sau bạn (hoặc ai đó) mở ra đọc là làm được liền.

---

## Mục lục

1. [Nó làm được gì](#nó-làm-được-gì)
2. [Cần gì để chạy](#cần-gì-để-chạy)
3. [Cài đặt nhanh (copy là chạy)](#cài-đặt-nhanh)
4. [Cách viết chữ trong UI](#cách-viết-chữ-trong-ui)
5. [Tất cả option của Localization](#tất-cả-option-của-localization)
6. [Các hàm bạn có thể gọi](#các-hàm-bạn-có-thể-gọi)
7. [Icon cho thông báo dịch](#icon-cho-thông-báo-dịch)
8. [Tùy chỉnh nội dung thông báo](#tùy-chỉnh-nội-dung-thông-báo)
9. [Chặn một chữ không cho dịch](#chặn-một-chữ-không-cho-dịch)
10. [Cache lưu ở đâu](#cache-lưu-ở-đâu)
11. [Code mẫu đầy đủ](#code-mẫu-đầy-đủ)
12. [Lỗi hay gặp](#lỗi-hay-gặp)

---

## Nó làm được gì

- Đổi ngôn ngữ cả UI ngay lúc đang chạy, không cần chạy lại script.
- Bản dịch thủ công (chuẩn nhất) cho ngôn ngữ nào bạn muốn.
- Tự dịch những chữ còn thiếu bằng Google Translate (bật bằng `AutoTranslate = true`).
- Tự kiểm tra bản dịch tự động, nếu thấy dịch lỗi (ví dụ còn sót chữ gốc, lẫn chữ nước khác) thì nó dịch lại.
- Lưu cache và ngôn ngữ đã chọn, lần sau mở script là có sẵn.
- Có thông báo "Đang dịch... / Dịch xong / Dịch lỗi", kèm icon.
- Có sẵn dropdown chọn ngôn ngữ, một dòng là xong.

## Cần gì để chạy

- Executor chạy được `loadstring` và `game:HttpGet`.
- WindUI bản bạn đang dùng (ở đây là bản `WindUI-Mod`), vì module hook vào `CreateWindow`, `Localization`, `SetLanguage`.
- Muốn **tự dịch** thì executor phải gọi được Google Translate (bằng `request`/`http_request` hoặc `HttpGet`). Nếu không gọi được thì chỉ có những ngôn ngữ bạn tự viết bảng dịch là hoạt động, mấy cái còn lại giữ nguyên tiếng gốc.
- Muốn có cache thì executor cần có `readfile` / `writefile` (không có cũng chạy, chỉ là không lưu).

## Cài đặt nhanh

Chỗ này quan trọng nhất, nên mình nói kỹ: **phải `Install` ngay sau khi load WindUI, và trước `Localization` với `CreateWindow`.** Nếu để sau thì nó không hook kịp.

```lua
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

-- 1) Load + cài module (đặt TRƯỚC Localization và CreateWindow)
local Modules = loadstring(game:HttpGet("https://raw.githubusercontent.com/72msreal-pixel/WindUI/refs/heads/main/Modules.luau"))()
local LangController = Modules:Install(WindUI)

-- 2) Khai báo ngôn ngữ
WindUI:Localization({
    Enabled = true,
    DefaultLanguage = "en",
    AutoTranslate = true,
    Translations = {
        en = { Hello = "Hello" },
        vi = { Hello = "Xin chào" },
    },
})

-- hoặc
-- WindUI:Localization({
--    Enabled = true,
--    DefaultLanguage = "en",
--    AutoTranslate = true,
--    Translations = {
--        en = {},
--    },
--})

-- 3) Tạo window như bình thường (Folder ở đây module sẽ tự lấy)
local Window = WindUI:CreateWindow({
    Title = "loc:Hello",
    Folder = "My Hub",
})

-- hoặc
-- local Window = WindUI:CreateWindow({
--    Title = "Hello",
--    Folder = "My Hub",
-- })

```

Về `Folder`: bạn **không cần** truyền `Folder` vào `Install`. Module tự lấy `Folder` từ `CreateWindow`. (Truyền cũng được, nhưng thừa.)

Rồi thêm dropdown chọn ngôn ngữ vào tab nào đó, thường là tab Settings:

```lua
LangController:AddDropdown(TabHandles.Settings, {
    Title = "loc:Language",
    Desc  = "loc:LanguageDesc",
})

-- hoặc

-- LangController:AddDropdown(TabHandles.Settings, {
--     Title = "Seclect Language",
--     Desc  = "You Desc :3",
-- })
```

Xong. Dropdown này có đủ 30 ngôn ngữ, chọn cái nào là UI đổi cái đó.

## Cách viết chữ trong UI

Có hai cách, và bạn có thể dùng lẫn nhau.

### Cách 1: dùng key `loc:`

Bạn viết `"loc:TênKey"` vào chỗ chữ, rồi khai báo key đó trong bảng `Translations`.

```lua
Translations = {
    en = { Main = "Main", MainDesc = "Main features" },
    vi = { Main = "Chính", MainDesc = "Phần chính" },
}

Tabs.Features:Tab({ Title = "loc:Main", Desc = "loc:MainDesc" })
```

Cái này chuẩn nhất vì bạn kiểm soát được từng chữ.

**Lưu ý hay quên:** key nào bạn dùng cũng **phải có trong bảng của ngôn ngữ gốc** (mặc định là `en`). Nếu thiếu, UI sẽ hiện `[TênKey]` (có ngoặc vuông) cho dễ phát hiện.

### Cách 2: viết thẳng tiếng Anh

Không cần khai báo gì hết, cứ viết chữ tiếng Anh bình thường:

```lua
Tab:Toggle({ Title = "Auto Farm", Callback = function(v) end })
```

Khi chọn ngôn ngữ khác, module sẽ tự dịch "Auto Farm" (cần `AutoTranslate = true`).

Chỗ này mình hơi muốn nhấn mạnh: chữ viết thẳng **phải là ngôn ngữ gốc** (tiếng Anh nếu bạn để `SourceLanguage = "en"`). Nếu bạn viết tiếng Việt thẳng vào UI thì nó vẫn tưởng đó là tiếng Anh rồi dịch, ra kết quả rất kỳ.

Còn nếu bạn muốn tiếng Việt là ngôn ngữ gốc thì đặt `SourceLanguage = "vi"` và `DefaultLanguage = "vi"`, rồi viết bảng `vi` làm bảng chính. Cũng được, chỉ cần nhất quán.

## Tất cả option của Localization

Các option dưới đây truyền vào `WindUI:Localization({ ... })`. Cái nào không ghi thì dùng mặc định.

| Option | Mặc định | Giải thích |
|---|---|---|
| `Enabled` | `true` | Bật/tắt cả hệ thống. |
| `Prefix` | `"loc:"` | Tiền tố để nhận biết key. Đổi được nhưng không được để trống. |
| `DefaultLanguage` | `"en"` | Ngôn ngữ mở lên lần đầu. |
| `SourceLanguage` | = `DefaultLanguage` | Ngôn ngữ gốc của chữ bạn viết trong code. |
| `Language` | không có | Ép dùng một ngôn ngữ cụ thể lúc khởi động (bỏ qua ngôn ngữ đã lưu). |
| `Translations` | `{}` | Bảng dịch thủ công, dạng `{ en = {...}, vi = {...} }`. |
| `AutoTranslate` | `false` | `true` thì chữ thiếu sẽ được tự dịch bằng Google. |
| `NoTranslations` | `{}` | Danh sách chữ không bao giờ dịch (xem [phần dưới](#chặn-một-chữ-không-cho-dịch)). |
| `TranslateUnkeyed` | `true` | Đặt `false` thì chỉ dịch chữ có `loc:`, chữ viết thẳng sẽ không đụng tới. |
| `Languages` | 14 mã phổ biến | Danh sách mã ngôn ngữ cho phép tự dịch. Dropdown của `AddDropdown` luôn dùng đủ 30. |
| `Notifications` | `true` | Hiện thông báo khi dịch. |
| `Messages` | mặc định | Tự đặt nội dung thông báo ([xem](#tùy-chỉnh-nội-dung-thông-báo)). |
| `Icons` | mặc định | Icon cho thông báo ([xem](#icon-cho-thông-báo-dịch)). |
| `Cache` | `true` | Có lưu cache dịch ra file không. |
| `SaveSelection` | `true` | Có nhớ ngôn ngữ người dùng đã chọn không. |
| `AutoPruneCache` | `false` | `true` thì tự xóa bản dịch của chữ không còn dùng nữa. |
| `Verify` | `true` | Tự kiểm tra và sửa bản dịch tự động. |
| `OnRepair` | không có | Hàm gọi mỗi khi một bản dịch bị sửa lại. |
| `OnError` | không có | Hàm nhận chuỗi lỗi khi module gặp lỗi. |
| `Request` | không có | Tự cung cấp hàm HTTP nếu executor của bạn lạ. Nhận `{Url, Method, Timeout}`. |
| `SyncSwap` | `true` | Khi chọn ngôn ngữ mới, giữ ngôn ngữ cũ đến khi dịch xong rồi đổi một lượt (đỡ bị nhảy chữ lộn xộn). |
| `SwapTimeout` | `10` | Chờ tối đa bao nhiêu giây trước khi đổi dù chưa dịch xong. |
| `Concurrency` | `2` | Số yêu cầu dịch chạy song song (tối đa 8). |
| `BatchSize` | `40` | Số chữ gộp trong mỗi yêu cầu. |
| `RequestInterval` | `0.3` | Giãn cách giữa các yêu cầu (giây), để khỏi bị Google chặn. |
| `MaxRetries` | `2` | Số lần thử lại khi lỗi mạng (tối đa 3). |
| `RetryCooldown` | `60` | Chữ nào dịch lỗi thì chờ bao lâu (giây) mới thử lại. |

Mấy cái cuối (`Concurrency`, `BatchSize`, `RequestInterval`...) thật ra bạn không cần đụng đâu. Mặc định ổn rồi, mình liệt kê cho đủ thôi.

## Các hàm bạn có thể gọi

`LangController` là cái bạn nhận được từ `Modules:Install(...)`.

```lua
LangController:SetLanguage("vi")      -- đổi ngôn ngữ, trả về true/false, lỗi
LangController:GetLanguage()          -- lấy mã ngôn ngữ hiện tại, ví dụ "vi"
LangController:Refresh()              -- áp dụng lại toàn bộ chữ
LangController:Refresh(true)          -- như trên, nhưng thử lại cả những chữ từng dịch lỗi
LangController:GetStatus()            -- bảng thông tin: Language, Busy, TrackedObjects, CachePath, LastError...
LangController:GetCachePath()         -- đường dẫn file cache
LangController:Destroy()              -- tắt hẳn hệ thống (trả WindUI về như cũ)
```

Nghe khi ngôn ngữ đổi:

```lua
local conn = LangController:OnChanged(function(newLang, oldLang)
    -- làm gì đó khi đổi ngôn ngữ
end)
conn:Disconnect() -- ngừng nghe
```

Dropdown chọn ngôn ngữ (có `Callback` là tùy chọn):

```lua
LangController:AddDropdown(Tab, {
    Title = "loc:Language",
    Desc  = "loc:LanguageDesc",
    Callback = function(code, ok, err)
        -- code: mã ngôn ngữ vừa chọn, ok: thành công hay không
    end,
})
```

Ngoài ra, sau khi `Install`, bạn cũng gọi được thẳng `WindUI:SetLanguage("vi")` và `WindUI:GetLanguage()`.

Nếu fork WindUI của bạn không tự lộ GUI ra cho module thấy (module sẽ báo "No exposed GUI root found"), thì gắn tay bằng:

```lua
LangController:AttachRoot(ScreenGuiCuaBan)
```

### Mấy hàm nâng cao (hơi ít dùng)

Nằm trong `LangController.Manager`:

```lua
local M = LangController.Manager
M:SetTranslations("vi", { Hello = "Chào nha" })   -- thêm/sửa bản dịch lúc đang chạy (false = xóa 1 dòng)
M:ClearCache("vi")                                 -- xóa cache của 1 ngôn ngữ (bỏ tham số = xóa hết)
M:GetOriginalText(textLabel)                       -- lấy chữ gốc của một TextLabel
M:SetOriginalText(textLabel, "New text")           -- đổi chữ gốc của một TextLabel
M:SetTextParts(textLabel, { "Line 1", "Line 2" }, "\n") -- chữ ghép từ nhiều đoạn, dịch từng đoạn
```

## Icon cho thông báo dịch

Mỗi khi dịch, module hiện thông báo của WindUI. Có 3 loại và mỗi loại có icon mặc định:

| Loại | Lúc nào | Icon mặc định |
|---|---|---|
| `Start` | Bắt đầu dịch | `languages` |
| `Done` | Dịch xong | `badge-check` |
| `Fail` | Dịch lỗi | `triangle-alert` |

Icon là **tên icon lucide** (WindUI dùng bộ lucide), hoặc `"rbxassetid://..."` nếu bạn muốn icon riêng. Đổi bằng option `Icons`:

```lua
WindUI:Localization({
    ...
    Icons = {
        Start = "loader",
        Done  = "check",
        Fail  = "wifi-off",
        -- Fail = "rbxassetid://123456789",  -- icon riêng cũng được
        -- Start = false,                     -- false = không hiện icon
    },
})
```

Nếu bạn gõ sai tên icon (hoặc icon không có trong bộ), thông báo vẫn hiện bình thường, chỉ là không có icon, chứ không bị lỗi. Nên nếu thấy thiếu icon thì kiểm tra lại tên nha.

## Tùy chỉnh nội dung thông báo

Module có sẵn nội dung thông báo cho `en, vi, zh, ja, ko, th, id, fr, de, es, pt, ru`. Ngôn ngữ nào không có trong danh sách đó thì hiện tiếng Anh. Muốn tự viết thì dùng `Messages`:

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

`%s` sẽ được thay bằng mã ngôn ngữ viết hoa (ví dụ `JA`). Mỗi mục là tùy chọn, mục nào thiếu thì dùng mặc định.

Muốn tắt hẳn thông báo: `Notifications = false`.

## Chặn một chữ không cho dịch

Có mấy chữ chắc chắn bạn không muốn dịch: tên hub, tên theme, tên người... Có 3 cách:

**Cách 1:** đưa vào `NoTranslations`:

```lua
NoTranslations = { "My Hub", "Dark", "Blue" }
```

Chữ này (khi nó nằm trọn trong một dòng, hoặc xuất hiện trong dòng khác) sẽ được giữ nguyên.

**Cách 2:** đặt vào trong bảng ngôn ngữ, với một key đặc biệt tên `NoTranslations`:

```lua
en = {
    NoTranslations = { "My Hub", "Dark" },
    Hello = "Hello",
}
```

**Cách 3:** với một object cụ thể (TextLabel, TextButton), gắn thuộc tính:

```lua
textLabel:SetAttribute("ModulesNoTranslate", true)
```

## Cache lưu ở đâu

File nằm ở:

```
<Folder của bạn>/language/LanguageCache.json
```

Ví dụ `Folder = "My Hub"` thì file là `My Hub/language/LanguageCache.json`. Trong đó có bản dịch tự động đã lưu và ngôn ngữ người dùng chọn lần trước. Lấy đường dẫn bằng `LangController:GetCachePath()`.

Muốn dịch lại từ đầu thì xóa file này, hoặc gọi `LangController.Manager:ClearCache()`.

Nếu bạn sửa chữ gốc trong code (đổi bảng `en`), module nhận ra và tự bỏ cache cũ, nên không lo bị dính bản dịch cũ.

## Code mẫu đầy đủ

Bản này ngắn gọn hơn script thật, nhưng đủ để thấy mọi thứ nối với nhau thế nào:

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

-- Chữ có key: dịch tay (en / vi), ngôn ngữ khác tự dịch
MainTab:Toggle({
    Title = "loc:AutoFarm",
    Callback = function(value) end,
})

-- Chữ viết thẳng tiếng Anh: tự dịch hết
MainTab:Button({
    Title = "Teleport to Spawn",
    Callback = function() end,
})

-- Dropdown chọn ngôn ngữ
LangController:AddDropdown(SettingsTab, {
    Title = "loc:Language",
    Desc = "loc:LanguageDesc",
})
```

## Lỗi hay gặp

**UI hiện `[Main]`, `[Settings]` (có ngoặc vuông).**
Bạn dùng `loc:Main` nhưng chưa khai báo key `Main` trong bảng của ngôn ngữ gốc (`en`). Thêm vào là hết.

**Chọn ngôn ngữ khác nhưng chữ không đổi.**
Có vài nguyên nhân hay gặp:
- Chưa bật `AutoTranslate = true` và bạn cũng chưa viết bảng dịch cho ngôn ngữ đó.
- Executor không gọi được Google Translate. Thử `LangController:GetStatus().LastError` để xem lỗi.
- Bạn `Install` sau `CreateWindow`. Phải `Install` trước.

**Thông báo "Dịch lỗi".**
Thường là mạng hoặc executor chặn request. Module sẽ tự thử lại vài lần. Nếu cứ lỗi mãi, bạn có thể tự đưa hàm HTTP vào qua option `Request`.

**Bản dịch tự động nhìn hơi kỳ.**
Bình thường thôi, Google dịch mà. Chữ nào quan trọng thì tự viết vào bảng `Translations`, bản thủ công luôn được ưu tiên hơn bản tự dịch.

**Chữ tiếng Việt viết thẳng bị dịch sai.**
Xem lại phần [viết thẳng tiếng Anh](#cách-2-viết-thẳng-tiếng-anh). Chữ viết thẳng phải đúng là ngôn ngữ gốc.

**Báo "No exposed GUI root found".**
Fork WindUI của bạn không lộ GUI ra. Gọi `LangController:AttachRoot(ScreenGui)` với ScreenGui của hub.

**Thấy `warn` từ `[Modules.Language]` trong console.**
Đó là module tự báo lỗi của nó (mạng, text quá dài, v.v.). Không ảnh hưởng gì nếu UI vẫn chạy bình thường. Nếu muốn nhận lỗi để xử lý riêng thì dùng option `OnError`.

---

Nếu có chỗ nào chưa rõ hoặc bạn thấy thiếu mục nào thì cứ nói, mình bổ sung thêm.
