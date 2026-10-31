local Modules = { Version = "0.1.1" }
local Installed = setmetatable({}, { __mode = "k" })
local httpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

Modules.Languages = {
    {Code="en", Name="English"}, {Code="vi", Name="Tiếng Việt"},
    {Code="zh-cn", Name="简体中文"}, {Code="zh-tw", Name="繁體中文"},
    {Code="ja", Name="日本語"}, {Code="ko", Name="한국어"},
    {Code="th", Name="ไทย"}, {Code="id", Name="Bahasa Indonesia"},
    {Code="ms", Name="Bahasa Melayu"}, {Code="fil", Name="Filipino"},
    {Code="fr", Name="Français"}, {Code="de", Name="Deutsch"},
    {Code="es", Name="Español"}, {Code="pt", Name="Português"},
    {Code="it", Name="Italiano"}, {Code="nl", Name="Nederlands"},
    {Code="pl", Name="Polski"}, {Code="ru", Name="Русский"},
    {Code="uk", Name="Українська"}, {Code="tr", Name="Türkçe"},
    {Code="ar", Name="العربية"}, {Code="hi", Name="हिन्दी"},
    {Code="bn", Name="বাংলা"}, {Code="ur", Name="اردو"},
    {Code="fa", Name="فارسی"}, {Code="he", Name="עברית"},
    {Code="el", Name="Ελληνικά"}, {Code="ro", Name="Română"},
    {Code="sv", Name="Svenska"}, {Code="da", Name="Dansk"},
}

local function copy(t)
    local result = {}
    for key, value in pairs(t or {}) do result[key] = value end
    return result
end

local function newManager(WindUI)
    local Library = {}
    function Library:Notify(options)
        if type(WindUI.Notify) == "function" then return WindUI:Notify(options) end
    end
    local LM = {
        Records = {}, Cache = {}, Failed = {}, Listeners = {}, Dropdowns = {},
        Active = false, Dead = false, Scheduled = false, Busy = false,
        SaveScheduled = false, Epoch = 0, LastRequest = -math.huge,
        CurrentLanguage = "en", LastError = nil,
        Marks = {}, Bad = {}, Reverse = {},
        DisplayLanguage = "en", Held = false, HoldToken = 0,
        Committing = false, CommitAgain = false, CommitQueued = false,
        SaveDirtyAt = 0, Saving = false,
    }
    Library._LanguageManager = LM

    local function newSlicer(budget)
        local started = os.clock()
        return function(minUsed)
            if os.clock() - started >= (minUsed or budget) then
                task.wait()
                started = os.clock()
                return true
            end
            return false
        end
    end

    local function isShown(node, memo)
        if node == nil then return false end
        local known = memo[node]
        if known ~= nil then return known end
        local shown = true
        if node:IsA("GuiObject") then shown = node.Visible
        elseif node:IsA("LayerCollector") then shown = node.Enabled end
        if shown then
            local parent = node.Parent
            if parent == nil then shown = false
            elseif parent ~= game then shown = isShown(parent, memo) end
        end
        memo[node] = shown
        return shown
    end

    function LM:Code(code)
        if type(code) ~= "string" then return nil end
        code = code:lower():gsub("_", "-")
        if #code < 2 or #code > 24 or not code:match("^[a-z]+[a-z%-]*$") then return nil end
        return code
    end

    function LM:Error(message)
        self.LastError = tostring(message)
        warn("[Modules.Language] " .. self.LastError)
        if self.Config and type(self.Config.OnError) == "function" then
            local callback, detail = self.Config.OnError, self.LastError
            task.defer(function() pcall(callback, detail) end)
        end
    end

    function LM:Format(record, value)
        return value
    end

    function LM:Ignored(record)
        return not self.Config.Enabled or record.NoTranslate or record.Object:GetAttribute("ModulesNoTranslate") == true
            or (record.Property == "Text" and record.Object:IsA("TextBox"))
    end

    function LM:Fallback(source)
        local defaults = self.Config.Translations[self.Config.SourceLanguage]
        return type(defaults) == "table" and type(defaults[source]) == "string" and defaults[source] or source
    end

    local NO_TRANSLATE_KEYS = { notranslations = true, notranslation = true, notranslate = true, donottranslate = true }

    function LM:SplitDictionary(dict, set)
        local clean = {}
        for key, value in pairs(dict) do
            if type(key) == "string" and NO_TRANSLATE_KEYS[(key:lower():gsub("[%s_%-]", ""))] then
                if type(value) == "string" then
                    set[value] = true
                elseif type(value) == "table" then
                    for _, item in pairs(value) do
                        if type(item) == "string" then set[item] = true end
                    end
                end
            else
                clean[key] = value
            end
        end
        return clean
    end

    function LM:BuildTerms()
        local list = {}
        for term in pairs(self.Config.NoTranslate) do
            if term ~= "" then table.insert(list, term) end
        end
        table.sort(list, function(a, b)
            if #a ~= #b then return #a > #b end
            return a < b
        end)
        self.Config.NoTranslateList = list
    end

    function LM:NoTranslateKey()
        return table.concat(self.Config.NoTranslateList, "\n") .. "\n" .. (self.SourceSignature or "")
    end

    function LM:HasProtected(text)
        for _, term in ipairs(self.Config.NoTranslateList) do
            if text:find(term, 1, true) then return true end
        end
        return false
    end

    function LM:MaskProtected(text, make)
        for _, term in ipairs(self.Config.NoTranslateList) do
            local out, cursor = {}, 1
            while true do
                local first, last = text:find(term, cursor, true)
                if not first then break end
                table.insert(out, text:sub(cursor, first - 1))
                table.insert(out, make(term))
                cursor = last + 1
            end
            if cursor > 1 then
                table.insert(out, text:sub(cursor))
                text = table.concat(out)
            end
        end
        return text
    end

    function LM:Templatize(source)
        if type(source) ~= "string" or not source:find("%d") then return source, nil end
        if source:find("{n%d+}") then return source, nil end
        if not source:match("[%a\128-\255]") then return source, nil end
        local numbers = {}
        local template = source:gsub("%d[%d%.,]*", function(match)
            local core = match:match("^(.-)[%.,]*$")
            local tail = match:sub(#core + 1)
            numbers[#numbers + 1] = core
            return "{n" .. #numbers .. "}" .. tail
        end)
        return template, numbers
    end

    function LM:FillNumbers(text, numbers)
        return (text:gsub("{n(%d+)}", function(index) return numbers[tonumber(index)] end))
    end

    function LM:Lookup(source, language)
        if self.Config.NoTranslate[source] then return source, true end
        local dict = self.Config.Translations[language]
        if type(dict) == "table" and type(dict[source]) == "string" then return dict[source], true end
        if language == self.Config.SourceLanguage then return source, true end
        if not source:match("[%a\128-\255]") then return source, true end
        if self.Config.AutoTranslations then
            local cache = self.Cache[language]
            local key, numbers = self:Templatize(source)
            local cached = cache and cache[key]
            if type(cached) == "string" then
                return numbers and self:FillNumbers(cached, numbers) or cached, true
            end
        end
        return self:Fallback(source), false
    end

    function LM:NeedsTranslation(source, language)
        if not self.Active or not self.Config.AutoTranslations or source == "" then return false end
        if self.MissingSources[source] then return false end
        if not source:match("[%a\128-\255]") then return false end
        local _, found = self:Lookup(source, language)
        if found then return false end
        local failed = self.Failed[language]
        return not (failed and failed[source] and failed[source] > os.clock())
    end

    function LM:Resolve(record, language)
        local value, found, anyFound = record.Source, true, false
        local translating = self.Active and not self:Ignored(record)
        if translating then
            if record.Parts then
                local values = {}
                for index, source in ipairs(record.Parts) do
                    local translated, resolved = self:Lookup(source, language)
                    values[index] = translated
                    found = found and resolved
                    anyFound = anyFound or resolved
                end
                value = table.concat(values, record.Separator)
            else
                local keyed = record.Key and self.KeyTranslations[language]
                if keyed and type(keyed[record.Key]) == "string" then
                    value, found = keyed[record.Key], true
                else
                    value, found = self:Lookup(record.Source, language)
                end
                anyFound = found
            end
        end
        value = self:Format(record, value)
        local tag = "source"
        if translating then
            tag = found and language or (anyFound and "mixed" or self.Config.SourceLanguage)
        end
        return value, found, tag, translating
    end

    function LM:Write(record, value, found, tag, translating)
        record.Expected = value
        record.Resolved = found
        record.Language = tag
        if translating and value ~= record.Source then
            record.Produced = record.Produced or {}
            record.Produced[value] = true
            if not record.Parts then self:Remember(value, record.Source) end
        end
        if record.Object.Parent ~= nil and record.Object[record.Property] ~= value then record.Object[record.Property] = value end
    end

    function LM:Apply(record)
        if self.Dead then return end
        record.Pending = nil
        local value, found, tag, translating = self:Resolve(record, self.DisplayLanguage)
        self:Write(record, value, found, tag, translating)
    end

    function LM:Flush(record)
        if not record.Pending then return end
        record.Pending = nil
        local records = self.Records[record.Object]
        if records and records[record.Property] == record then
            self:Write(record, record.PV, record.PF, record.PT, record.PR)
        end
    end

    function LM:Remember(value, source)
        local old = self.Reverse[value]
        if old == nil then self.Reverse[value] = source
        elseif old ~= source then self.Reverse[value] = false end
    end

    function LM:CommitPass()
        local language = self.DisplayLanguage
        local config = self.Config
        local slice = newSlicer(config and config.FrameBudget or 0.003)
        local function stale() return self.Dead or self.DisplayLanguage ~= language end

        local list = {}
        for _, properties in pairs(self.Records) do
            for _, record in pairs(properties) do list[#list + 1] = record end
        end

        local memo, shown, hidden = {}, {}, {}
        for index = 1, #list do
            local record = list[index]
            if isShown(record.Object, memo) then shown[#shown + 1] = record else hidden[#hidden + 1] = record end
            if slice() and stale() then return end
        end

        for index = 1, #shown do
            local record = shown[index]
            record.PV, record.PF, record.PT, record.PR = self:Resolve(record, language)
            record.Pending = true
            if slice() and stale() then return end
        end

        if slice(0.0015) and stale() then return end
        local sync = newSlicer(config and config.SyncBudget or 0.006)
        for index = 1, #shown do
            self:Flush(shown[index])
            if sync() and stale() then return end
        end

        for index = 1, #hidden do
            local record = hidden[index]
            local records = self.Records[record.Object]
            if records and records[record.Property] == record then self:Apply(record) end
            if slice() and stale() then return end
        end
    end

    function LM:Commit()
        if self.Dead then return end
        if self.Committing then self.CommitAgain = true; return end
        self.Committing = true
        task.spawn(function()
            local ok, err = pcall(function()
                repeat
                    self.CommitAgain = false
                    self:CommitPass()
                until not self.CommitAgain or self.Dead
            end)
            self.Committing = false
            if not ok then self:Error(err) end
        end)
    end

    function LM:CommitSoon()
        if self.CommitQueued or self.Dead then return end
        self.CommitQueued = true
        task.delay(0.1, function()
            self.CommitQueued = false
            self:Commit()
        end)
    end

    function LM:ApplyAll() self:Commit() end

    function LM:ReleaseHold()
        if not self.Held then return end
        self.Held = false
        self.HoldToken = self.HoldToken + 1
        self.DisplayLanguage = self.CurrentLanguage
        self:Commit()
    end

    function LM:Hold()
        self.Held = true
        self.HoldToken = self.HoldToken + 1
        local token = self.HoldToken
        task.delay(self.Config.SwapTimeout, function()
            if self.HoldToken == token and self.Held then self:ReleaseHold() end
        end)
        self:Schedule(0)
    end

    function LM:Untrack(object)
        local properties = self.Records[object]
        if not properties then return end
        self.Records[object] = nil
        for _, record in pairs(properties) do
            for _, connection in ipairs(record.Connections) do connection:Disconnect() end
        end
        if self.Active and self.Config.AutoPruneCache then self:ScheduleSave() end
    end

    function LM:Track(object, properties)
        if self.Dead or self.Records[object] then return end
        if not (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then return end
        properties = properties or {}
        local records = {}
        self.Records[object] = records
        local names = object:IsA("TextBox") and {"PlaceholderText"} or {"Text"}
        for _, property in ipairs(names) do
            local raw = type(properties[property]) == "string" and properties[property] or object[property]
            local source, key = self:Source(raw)
            local record = { Object = object, Property = property, Source = source,
                Key = key, Raw = raw, NoTranslate = properties.NoTranslate == true, Connections = {} }
            records[property] = record
            self:Apply(record)
            table.insert(record.Connections, object:GetPropertyChangedSignal(property):Connect(function()
                local current = object[property]
                if current == record.Expected then return end
                if record.Produced and record.Produced[current] and current ~= record.Source then
                    self:Apply(record)
                    return
                end
                record.Raw = current
                record.Source, record.Key = self:Source(current)
                record.Parts = nil
                self:Apply(record)
                self:Schedule()
                self:ScheduleSave()
            end))
            table.insert(record.Connections, object:GetAttributeChangedSignal("ModulesNoTranslate"):Connect(function()
                self:Apply(record)
                self:Schedule()
            end))
        end
        local main = records.Text or records.PlaceholderText
        table.insert(main.Connections, object.Destroying:Connect(function() self:Untrack(object) end))
        self:Schedule()
    end

    function LM:Collect(slice)
        local records = {}
        for _, properties in pairs(self.Records) do
            for _, record in pairs(properties) do records[#records + 1] = record end
        end
        local result, seen = {}, {}
        local function add(source)
            source = self:Templatize(source)
            if not seen[source] then
                seen[source] = true
                result[#result + 1] = source
            end
        end
        for _, record in ipairs(records) do
            if not self:Ignored(record) then
                if record.Parts then
                    for _, source in ipairs(record.Parts) do add(source) end
                else
                    add(record.Source)
                end
            end
            if slice then slice() end
        end
        table.sort(result)
        return result, seen
    end

    function LM:PruneCache()
        local _, live = self:Collect()
        local removed = 0
        for _, dict in pairs(self.Cache) do
            for source in pairs(dict) do
                if not live[source] then dict[source] = nil; removed = removed + 1 end
            end
        end
        for _, group in ipairs({self.Marks, self.Bad}) do
            for _, dict in pairs(group) do
                for source in pairs(dict) do if not live[source] then dict[source] = nil end end
            end
        end
        return removed
    end

    function LM:ReadDisk()
        if not self.Config.Cache or type(readfile) ~= "function" then return nil end
        local ok, content = pcall(readfile, self.Config.CacheFile)
        if not ok then return nil end
        local decoded, data = pcall(function() return httpService:JSONDecode(content) end)
        if not decoded or type(data) ~= "table" or (data.Version ~= 1 and data.Version ~= 2)
            or data.SourceLanguage ~= self.Config.SourceLanguage
            or data.SourceSignature ~= self.SourceSignature then return nil end
        local staleTerms = data.NoTranslateKey ~= self:NoTranslateKey()
        if type(data.Translations) == "table" then
            for code, dict in pairs(data.Translations) do
                local normalized = self:Code(code)
                if normalized and normalized ~= self.Config.SourceLanguage and type(dict) == "table" then
                    self.Cache[normalized] = self.Cache[normalized] or {}
                    self.Marks[normalized] = self.Marks[normalized] or {}
                    for source, entry in pairs(dict) do
                        if type(source) == "string" and not (staleTerms and self:HasProtected(source)) then
                            if type(entry) == "string" then
                                self.Cache[normalized][source] = entry
                            elseif type(entry) == "table" and type(entry.t) == "string" then
                                if entry.m == "bad" then
                                    self.Bad[normalized] = self.Bad[normalized] or {}
                                    self.Bad[normalized][source] = entry.t
                                else
                                    self.Cache[normalized][source] = entry.t
                                    if entry.m == "ok" or entry.m == "fixed" then self.Marks[normalized][source] = entry.m end
                                end
                            end
                        end
                    end
                end
            end
        end
        return self:Code(data.SelectedLanguage)
    end

    function LM:SaveCache(sliced)
        if not self.Active or not self.Config.Cache or type(writefile) ~= "function" then return false end
        if self.Saving then return false end
        local step = sliced and newSlicer(self.Config.FrameBudget) or function() return false end
        if self.Config.AutoPruneCache then self:PruneCache() end
        self.Saving = true
        local ok, err = pcall(function()
            local folder = self.Config.CacheFile:match("^(.*)/[^/]+$")
            if folder and type(makefolder) == "function" then
                local path = ""
                for piece in folder:gmatch("[^/]+") do
                    path = path == "" and piece or path .. "/" .. piece
                    if type(isfolder) ~= "function" or not isfolder(path) then
                        local made, reason = pcall(makefolder, path)
                        if not made and (type(isfolder) ~= "function" or not isfolder(path)) then error(reason) end
                    end
                end
            end
            local _, live = self:Collect(sliced and step or nil)
            local names, codes = {}, {}
            for code in pairs(self.Cache) do codes[code] = true end
            for code in pairs(self.Bad) do codes[code] = true end
            codes[self.Config.SourceLanguage] = nil
            for code in pairs(codes) do table.insert(names, code) end
            table.sort(names)
            local parts = {}
            for _, code in ipairs(names) do
                local block = {}
                local dict = self.Cache[code]
                if dict then
                    local marks = self.Marks[code]
                    for source, value in pairs(dict) do
                        block[source] = {t = value, m = (marks and marks[source]) or "new"}
                    end
                end
                local bad = self.Bad[code]
                if bad then
                    for source, value in pairs(bad) do
                        if not block[source] then block[source] = {t = value, m = "bad"} end
                    end
                end
                parts[#parts + 1] = '"' .. code .. '":' .. httpService:JSONEncode(block)
                step()
            end
            local base = {}
            for source in pairs(live) do base[source] = {t = source, m = "source"} end
            parts[#parts + 1] = '"' .. self.Config.SourceLanguage .. '":' .. httpService:JSONEncode(base)
            local head = httpService:JSONEncode({
                Version = 2, SourceLanguage = self.Config.SourceLanguage, SourceSignature = self.SourceSignature,
                NoTranslateKey = self:NoTranslateKey(),
                SelectedLanguage = self.Config.SaveSelection and self.CurrentLanguage or nil,
            })
            writefile(self.Config.CacheFile, head:sub(1, -2) .. ',"Translations":{' .. table.concat(parts, ",") .. "}}")
        end)
        self.Saving = false
        if not ok then self:Error("Cannot save cache: " .. tostring(err)) end
        return ok
    end

    function LM:ScheduleSave()
        if not self.Active or self.Dead then return end
        self.SaveDirtyAt = os.clock()
        if self.SaveScheduled then return end
        self.SaveScheduled = true
        local function attempt()
            if self.Dead then self.SaveScheduled = false; return end
            local quiet = os.clock() - self.SaveDirtyAt >= self.Config.SaveDelay
            if self.Held or self.Committing or not quiet then
                task.delay(0.5, attempt)
                return
            end
            self.SaveScheduled = false
            self:SaveCache(true)
        end
        task.delay(self.Config.SaveDelay, attempt)
    end

    function LM:HTTP(url)
        if type(self.Config.Request) == "function" then
            return self.Config.Request({Url = url, Method = "GET", Timeout = 15})
        end
        local hosts = {
            "https://translate.googleapis.com/translate_a/single",
            "https://clients5.google.com/translate_a/single",
            "https://translate.google.com/translate_a/single",
        }
        if self.GoodHost and self.GoodHost > 1 then
            local first = table.remove(hosts, self.GoodHost)
            table.insert(hosts, 1, first)
        end
        local hostIndex = {
            ["translate.googleapis.com"] = 1, ["clients5.google.com"] = 2, ["translate.google.com"] = 3,
        }
        local query = url:match("%?(.*)$") or ""
        local sender = request or http_request or (syn and syn.request) or (http and http.request)
        local problems = {}
        for _, host in ipairs(hosts) do
            local target = host .. "?" .. query
            if host:find("clients5", 1, true) then target = target:gsub("client=gtx", "client=dict-chrome-ex") end
            local name = host:match("//([^/]+)") or host
            local function viaRequest()
                local okReq, res = pcall(sender, {Url = target, Method = "GET", Timeout = 15})
                local status = okReq and type(res) == "table" and tonumber(res.StatusCode or res.Status) or 0
                if okReq and type(res) == "table" and status >= 200 and status < 300 and type(res.Body) == "string" and res.Body:sub(1, 1) == "[" then
                    return res.Body
                end
                return nil, name .. " request: " .. (okReq and ("HTTP " .. status) or tostring(res):sub(1, 60))
            end
            local function viaHttpGet()
                local okGet, body = pcall(function() return game:HttpGet(target) end)
                if okGet and type(body) == "string" and body:sub(1, 1) == "[" then return body end
                return nil, name .. " HttpGet: " .. (okGet and "bad body" or tostring(body):sub(1, 60))
            end
            local attempts = type(sender) == "function" and {viaRequest, viaHttpGet} or {viaHttpGet}
            for _, attempt in ipairs(attempts) do
                local body, problem = attempt()
                if body then
                    self.GoodHost = hostIndex[name] or self.GoodHost
                    return body
                end
                table.insert(problems, problem)
            end
        end
        if not sender and RunService:IsClient() and #problems == 0 then
            error("Auto translation needs Request = function(options) ... end or a supported HTTP function.")
        end
        error("All endpoints failed -> " .. table.concat(problems, " | "))
    end

    function LM:Protect(source)
        if source:find("ZXQ", 1, true) then return nil end
        local tags = {}
        local text = source:gsub("<[^>]+>", function(tag)
            table.insert(tags, tag)
            return string.format("ZXQT%04dQXZ", #tags)
        end)
        for _, pattern in ipairs({"%%[%d%.%+%-]*[cdiouxXeEfgGqs]", "{[%w_%.]+}", "rbxassetid://%d+", "https?://[^%s<>]+"}) do
            text = text:gsub(pattern, function(term)
                table.insert(tags, term)
                return string.format("ZXQT%04dQXZ", #tags)
            end)
        end
        text = self:MaskProtected(text, function(term)
            table.insert(tags, term)
            return string.format("ZXQT%04dQXZ", #tags)
        end)
        return text, tags
    end

    function LM:Restore(value, tags)
        local seen, invalid = {}, false
        value = value:gsub("ZXQT(%d+)QXZ", function(index)
            index = tonumber(index)
            if not tags[index] or seen[index] then invalid = true; return "" end
            seen[index] = true
            return tags[index]
        end)
        for index in ipairs(tags) do if not seen[index] then return nil end end
        if invalid or value:find("ZXQ", 1, true) then return nil end
        return value
    end

    function LM:Payload(items)
        local pieces = {}
        for index, item in ipairs(items) do
            table.insert(pieces, string.format("ZXQB%06dQXZ\n%s\n", index, item.Text))
        end
        table.insert(pieces, "ZXQENDQXZ")
        return table.concat(pieces)
    end

    function LM:URL(items, language)
        return "https://translate.googleapis.com/translate_a/single?client=gtx&dt=t&ie=UTF-8&oe=UTF-8&sl="
            .. httpService:UrlEncode(self.Config.SourceLanguage)
            .. "&tl=" .. httpService:UrlEncode(language)
            .. "&q=" .. httpService:UrlEncode(self:Payload(items))
    end

    function LM:Decode(body, items)
        local data = httpService:JSONDecode(body)
        if type(data) ~= "table" or type(data[1]) ~= "table" then error("Unexpected Google JSON response") end
        local pieces = {}
        for _, segment in ipairs(data[1]) do
            if type(segment) == "table" and type(segment[1]) == "string" then table.insert(pieces, segment[1]) end
        end
        local output, starts, ends = table.concat(pieces), {}, {}
        local cursor = 1
        for index in ipairs(items) do
            local marker = string.format("ZXQB%06dQXZ", index)
            local first, last = output:find(marker, cursor, true)
            if not first or output:find(marker, last + 1, true) then error("Batch marker missing or duplicated; source text retained") end
            if index == 1 and output:sub(1, first - 1):match("%S") then error("Unexpected batch prefix") end
            starts[index], ends[index], cursor = first, last, last + 1
        end
        local finish, finishEnd = output:find("ZXQENDQXZ", cursor, true)
        if not finish or output:sub(finishEnd + 1):match("%S") then error("Batch end marker missing or invalid") end
        local translated = {}
        for index, item in ipairs(items) do
            local value = output:sub(ends[index] + 1, (starts[index + 1] or finish) - 1)
            value = value:match("^%s*(.-)%s*$")
            value = self:Restore(value, item.Tags)
            if not value or (value == "" and item.Source:match("%S")) then error("Invalid protected text; source text retained") end
            translated[index] = (item.Source:match("^%s*") or "") .. value .. (item.Source:match("%s*$") or "")
        end
        return translated
    end

    function LM:IsFormatError(reason)
        reason = tostring(reason)
        return reason:find("Batch ", 1, true) ~= nil or reason:find("Invalid protected", 1, true) ~= nil
            or reason:find("Unexpected", 1, true) ~= nil or reason:find("Empty translation", 1, true) ~= nil
    end

    function LM:Pace()
        local now = os.clock()
        local slot = math.max(now, self.NextSlot or 0)
        self.NextSlot = slot + self.Config.RequestInterval
        if slot > now then task.wait(slot - now) end
    end

    function LM:Send(items, language, epoch)
        local url = self:URL(items, language)
        local reason = "Translation failed"
        for attempt = 0, self.Config.MaxRetries do
            if self.Dead or self.Epoch ~= epoch or self.CurrentLanguage ~= language then return nil, "cancelled" end
            self:Pace()
            if self.Dead or self.Epoch ~= epoch or self.CurrentLanguage ~= language then return nil, "cancelled" end
            local status, retryAfter = 0, nil
            local ok, result = pcall(function()
                local response = self:HTTP(url)
                if type(response) == "string" then return self:Decode(response, items) end
                if type(response) ~= "table" then error("Invalid HTTP response") end
                status = tonumber(response.StatusCode or response.Status) or 0
                local headers = response.Headers or {}
                retryAfter = tonumber(headers["Retry-After"] or headers["retry-after"])
                if status < 200 or status >= 300 or response.Success == false then error("HTTP " .. tostring(status)) end
                return self:Decode(response.Body or "", items)
            end)
            if ok then return result end
            reason = tostring(result)
            if self:IsFormatError(reason) then return nil, reason end
            if attempt < self.Config.MaxRetries then
                task.wait(math.min(30, retryAfter or (2 ^ (attempt + 1))))
            end
        end
        return nil, reason
    end

    function LM:Plain(text, from, to, epoch, language)
        if self.Dead or self.Epoch ~= epoch or self.CurrentLanguage ~= language then return nil, "cancelled" end
        self:Pace()
        if self.Dead or self.Epoch ~= epoch or self.CurrentLanguage ~= language then return nil, "cancelled" end
        local url = "https://translate.googleapis.com/translate_a/single?client=gtx&dt=t&ie=UTF-8&oe=UTF-8&sl="
            .. httpService:UrlEncode(from) .. "&tl=" .. httpService:UrlEncode(to)
            .. "&q=" .. httpService:UrlEncode(text)
        local ok, result = pcall(function()
            local response = self:HTTP(url)
            local body = type(response) == "string" and response or (type(response) == "table" and response.Body) or ""
            local data = httpService:JSONDecode(body)
            if type(data) ~= "table" or type(data[1]) ~= "table" then error("Unexpected Google JSON response") end
            local pieces = {}
            for _, segment in ipairs(data[1]) do
                if type(segment) == "table" and type(segment[1]) == "string" then table.insert(pieces, segment[1]) end
            end
            local value = table.concat(pieces):match("^%s*(.-)%s*$")
            if value == "" or value:find("ZXQ", 1, true) then error("Empty translation") end
            return value
        end)
        if ok then return result end
        return nil, tostring(result)
    end

    function LM:SendSegments(item, language, epoch)
        for _, tag in ipairs(item.Tags) do
            if tag:sub(1, 1) == "<" then return nil, "Protected tags; source retained" end
        end
        local text, pieces, position, translatedAny = item.Text, {}, 1, false
        while true do
            local first, last = text:find("ZXQT%d+QXZ", position)
            local chunk = text:sub(position, (first or (#text + 1)) - 1)
            local core = chunk:match("^%s*(.-)%s*$")
            if core ~= "" and core:match("[%a\128-\255]") then
                local value, why = self:Plain(core, self.Config.SourceLanguage, language, epoch, language)
                if not value then return nil, why end
                chunk = (chunk:match("^%s*") or "") .. value .. (chunk:match("%s*$") or "")
                translatedAny = true
            end
            pieces[#pieces + 1] = chunk
            if not first then break end
            pieces[#pieces + 1] = text:sub(first, last)
            position = last + 1
        end
        local restored = translatedAny and self:Restore(table.concat(pieces), item.Tags) or nil
        if not restored then return nil, "Protected tags; source retained" end
        return (item.Source:match("^%s*") or "") .. restored .. (item.Source:match("%s*$") or "")
    end

    function LM:SendPlain(item, language, epoch)
        if #item.Tags > 0 then return self:SendSegments(item, language, epoch) end
        local value, why = self:Plain(item.Text, self.Config.SourceLanguage, language, epoch, language)
        if not value then return nil, why end
        return (item.Source:match("^%s*") or "") .. value .. (item.Source:match("%s*$") or "")
    end

    local VIET_SINGLE = {[0x110] = true, [0x111] = true, [0x1A0] = true, [0x1A1] = true, [0x1AF] = true, [0x1B0] = true}
    local OWN = {
        zh = {"cjk"}, ja = {"kana", "cjk"}, ko = {"hangul", "cjk"}, th = {"thai"},
        ru = {"cyr"}, uk = {"cyr"}, bg = {"cyr"}, ar = {"arab"}, fa = {"arab"}, ur = {"arab"},
        he = {"hebrew"}, iw = {"hebrew"}, el = {"greek"}, hi = {"deva"}, bn = {"beng"},
    }

    local function scriptCounts(text)
        local c = {latin = 0, viet = 0, cjk = 0, kana = 0, hangul = 0, cyr = 0, thai = 0, arab = 0, hebrew = 0, greek = 0, deva = 0, beng = 0}
        pcall(function()
            for _, cp in utf8.codes(text) do
                local key
                if (cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122) then key = "latin"
                elseif VIET_SINGLE[cp] or (cp >= 0x1EA0 and cp <= 0x1EF9) then key = "viet"
                elseif (cp >= 0x4E00 and cp <= 0x9FFF) or (cp >= 0x3400 and cp <= 0x4DBF) then key = "cjk"
                elseif cp >= 0x3040 and cp <= 0x30FF then key = "kana"
                elseif (cp >= 0xAC00 and cp <= 0xD7AF) or (cp >= 0x1100 and cp <= 0x11FF) then key = "hangul"
                elseif cp >= 0x0400 and cp <= 0x04FF then key = "cyr"
                elseif cp >= 0x0E00 and cp <= 0x0E7F then key = "thai"
                elseif cp >= 0x0600 and cp <= 0x06FF then key = "arab"
                elseif cp >= 0x0590 and cp <= 0x05FF then key = "hebrew"
                elseif cp >= 0x0370 and cp <= 0x03FF then key = "greek"
                elseif cp >= 0x0900 and cp <= 0x097F then key = "deva"
                elseif cp >= 0x0980 and cp <= 0x09FF then key = "beng" end
                if key then c[key] = c[key] + 1 end
            end
        end)
        return c
    end

    function LM:Others(source, language)
        local out = {}
        for code, dict in pairs(self.Config.Translations) do
            if code ~= language and code ~= self.Config.SourceLanguage and type(dict) == "table" and type(dict[source]) == "string" then
                out[code] = dict[source]
            end
        end
        for code, dict in pairs(self.Cache) do
            local marks = self.Marks[code]
            if code ~= language and code ~= self.Config.SourceLanguage and out[code] == nil
                and type(dict[source]) == "string" and marks and marks[source] then
                out[code] = dict[source]
            end
        end
        return out
    end

    function LM:Check(language, source, value)
        if type(value) ~= "string" or value:match("^%s*$") then return "empty" end
        source = self:MaskProtected(source, function() return " " end)
        value = self:MaskProtected(value, function() return " " end)
        local prefix = language:match("^[a-z]+") or language
        local own = OWN[prefix]
        local allowed = {latin = true}
        if own then for _, key in ipairs(own) do allowed[key] = true end end
        if prefix == "vi" then allowed.viet = true end
        local sc, vc = scriptCounts(source), scriptCounts(value)
        for key, count in pairs(vc) do
            if count > 0 and not allowed[key] and sc[key] == 0 then return "foreign-script:" .. key end
        end
        local others = self:Others(source, language)
        local sourceWords = {}
        for word in source:gmatch("%a+") do if #word >= 4 then sourceWords[word:lower()] = true end end
        local has3 = source:find("%a%a%a") ~= nil
        local has4 = next(sourceWords) ~= nil
        local function keptElsewhere(lowerWord)
            local n = 0
            for _, other in pairs(others) do
                if other:lower():find(lowerWord, 1, true) then n = n + 1 end
            end
            return n >= 2
        end
        local function mixed()
            for word in value:gmatch("%a+") do
                local lowerWord = word:lower()
                if #word >= 4 and sourceWords[lowerWord] and not keptElsewhere(lowerWord) then return "mixed:" .. word end
            end
            return nil
        end
        if own then
            local ownCount = 0
            for _, key in ipairs(own) do ownCount = ownCount + vc[key] end
            if ownCount == 0 then
                if has3 and not source:match("^[%u%d%s%p]+$") then return "untranslated" end
                return nil
            end
            return mixed()
        end
        if prefix == "vi" and vc.viet > 0 then
            local reason = mixed()
            if reason then return reason end
        end
        if has4 and value:lower() == source:lower() then
            local differ, total = 0, 0
            for _, other in pairs(others) do
                total = total + 1
                if other:lower() ~= source:lower() then differ = differ + 1 end
            end
            if differ >= 2 and differ * 2 > total then return "untranslated(cross)" end
        end
        return nil
    end

    function LM:Repair(language, source, value, reason, epoch)
        if source:find("<", 1, true) or source:find("{n%d+}") or self:HasProtected(source) then return value, "ok" end
        local lead, tail = source:match("^%s*") or "", source:match("%s*$") or ""
        local fresh, why = self:Plain(source, self.Config.SourceLanguage, language, epoch, language)
        if why == "cancelled" then return nil, "cancelled" end
        if fresh then
            fresh = lead .. fresh .. tail
            if fresh == value then return value, "ok" end
            if not self:Check(language, source, fresh) then return fresh, "fixed" end
        elseif not self:IsFormatError(why) then
            return nil, "net"
        end
        local codes = {}
        for code in pairs(self:Others(source, language)) do table.insert(codes, code) end
        table.sort(codes)
        local others = self:Others(source, language)
        for index = 1, math.min(2, #codes) do
            local translated, why2 = self:Plain(others[codes[index]], codes[index], language, epoch, language)
            if why2 == "cancelled" then return nil, "cancelled" end
            if translated then
                translated = lead .. translated .. tail
                if not self:Check(language, source, translated) then return translated, "fixed" end
            end
        end
        return nil, "bad"
    end

    function LM:Audit(language, epoch)
        if not self.Config.Verify or language == self.Config.SourceLanguage then return end
        local dict = self.Cache[language]
        if not dict then return end
        self.Marks[language] = self.Marks[language] or {}
        local marks, manual = self.Marks[language], self.Config.Translations[language]
        local budget, changed, skipped = 8, false, false
        local slice = newSlicer(self.Config.FrameBudget)
        for _, source in ipairs(self:Collect(slice)) do
            if slice() and (self.Dead or epoch ~= self.Epoch or self.CurrentLanguage ~= language) then
                if changed then self:Commit(); self:ScheduleSave() end
                return
            end
            local value = dict[source]
            if type(value) == "string" and not marks[source] and not self.Config.NoTranslate[source]
                and not (type(manual) == "table" and manual[source]) then
                local reason = self:Check(language, source, value)
                if not reason then
                    marks[source] = "ok"
                    changed = true
                elseif budget <= 0 then
                    skipped = true
                else
                    budget = budget - 1
                    local fixed, verdict = self:Repair(language, source, value, reason, epoch)
                    if self.Dead or epoch ~= self.Epoch or self.CurrentLanguage ~= language or verdict == "cancelled" then
                        if changed then self:Commit(); self:ScheduleSave() end
                        return
                    end
                    if verdict == "net" then
                        if changed then self:Commit(); self:ScheduleSave() end
                        self:Retry()
                        return
                    elseif verdict == "bad" then
                        self.Bad[language] = self.Bad[language] or {}
                        self.Bad[language][source] = value
                        dict[source] = nil
                        self.Failed[language] = self.Failed[language] or {}
                        self.Failed[language][source] = os.clock() + self.Config.RetryCooldown * 20
                    else
                        dict[source] = fixed
                        marks[source] = verdict
                    end
                    changed = true
                    if type(self.Config.OnRepair) == "function" then
                        pcall(self.Config.OnRepair, language, source, value, fixed, verdict, reason)
                    end
                end
            end
        end
        if changed then self:Commit(); self:ScheduleSave() end
        if skipped then self.Pending = true end
    end

    function LM:SendBatch(items, language, epoch)
        local result, reason = self:Send(items, language, epoch)
        if result then return result end
        if reason == "cancelled" or not self:IsFormatError(reason) then return nil, reason end
        if #items == 1 then
            local value, why = self:SendPlain(items[1], language, epoch)
            if value then return {value} end
            return nil, why
        end
        local mid = math.floor(#items / 2)
        local left, right = {}, {}
        for index, item in ipairs(items) do table.insert(index <= mid and left or right, item) end
        local a, ra = self:SendBatch(left, language, epoch)
        if ra == "cancelled" then return nil, ra end
        local b, rb = self:SendBatch(right, language, epoch)
        if rb == "cancelled" then return nil, rb end
        if not a and not b then return nil, ra or rb end
        local merged = {}
        for index = 1, #left do merged[index] = a and a[index] or nil end
        for index = 1, #right do merged[mid + index] = b and b[index] or nil end
        return merged, ra or rb
    end

    local MESSAGES = {
        en = {Title = "Language", Start = "Translating to %s...", Done = "Translation complete (%s)", Fail = "Translation failed (%s), will retry shortly"},
        vi = {Title = "Ngôn ngữ", Start = "Đang dịch sang %s...", Done = "Dịch thành công (%s)", Fail = "Dịch thất bại (%s), sẽ thử lại sau"},
        zh = {Title = "语言", Start = "正在翻译为 %s...", Done = "翻译成功 (%s)", Fail = "翻译失败 (%s)，稍后重试"},
        ja = {Title = "言語", Start = "%s に翻訳中...", Done = "翻訳が完了しました (%s)", Fail = "翻訳に失敗しました (%s)。まもなく再試行します"},
        ko = {Title = "언어", Start = "%s(으)로 번역 중...", Done = "번역 완료 (%s)", Fail = "번역 실패 (%s), 곧 다시 시도합니다"},
        th = {Title = "ภาษา", Start = "กำลังแปลเป็น %s...", Done = "แปลสำเร็จ (%s)", Fail = "แปลไม่สำเร็จ (%s) กำลังลองใหม่"},
        id = {Title = "Bahasa", Start = "Menerjemahkan ke %s...", Done = "Terjemahan selesai (%s)", Fail = "Terjemahan gagal (%s), akan dicoba lagi"},
        fr = {Title = "Langue", Start = "Traduction en %s...", Done = "Traduction terminée (%s)", Fail = "Échec de la traduction (%s), nouvel essai bientôt"},
        de = {Title = "Sprache", Start = "Übersetze nach %s...", Done = "Übersetzung abgeschlossen (%s)", Fail = "Übersetzung fehlgeschlagen (%s), neuer Versuch folgt"},
        es = {Title = "Idioma", Start = "Traduciendo a %s...", Done = "Traducción completada (%s)", Fail = "Error de traducción (%s), se reintentará"},
        pt = {Title = "Idioma", Start = "Traduzindo para %s...", Done = "Tradução concluída (%s)", Fail = "Falha na tradução (%s), tentando novamente"},
        ru = {Title = "Язык", Start = "Перевод на %s...", Done = "Перевод завершён (%s)", Fail = "Ошибка перевода (%s), повтор позже"},
    }

    local DEFAULT_ICONS = {Start = "languages", Done = "badge-check", Fail = "triangle-alert"}

    function LM:Toast(kind, language)
        if self.Dead or not self.Config.Notifications then return end
        local code = language:match("^[a-z]+") or language
        local custom = self.Config.Messages
        local function pick(field)
            local entry = type(custom) == "table" and (custom[language] or custom[code]) or nil
            if type(entry) == "table" and type(entry[field]) == "string" then return entry[field] end
            local default = MESSAGES[code] or MESSAGES.en
            return default[field] or MESSAGES.en[field]
        end
        local function pickIcon()
            local icons = type(self.Config.Icons) == "table" and self.Config.Icons or nil
            local name = icons and icons[kind]
            if name == nil then name = DEFAULT_ICONS[kind] end
            if name == false or type(name) ~= "string" or name == "" then return nil end
            if name:sub(1, 13) == "rbxassetid://" then return name end
            local pack = WindUI.Icons
            if type(pack) == "table" and type(pack.Icon) == "function" then
                local okIcon, found = pcall(pack.Icon, name)
                if not okIcon or not found then return nil end
            end
            return name
        end
        local ok, notification = pcall(function()
            return Library:Notify({
                Title = pick("Title"),
                Content = string.format(pick(kind), language:upper()),
                Duration = kind == "Fail" and 6 or 4,
                Icon = pickIcon(),
            })
        end)
        if ok and type(notification) == "table" then
            for _, key in ipairs({"Title", "ContentLabel", "SubContentLabel"}) do
                local object = notification[key]
                if typeof(object) == "Instance" then pcall(object.SetAttribute, object, "ModulesNoTranslate", true) end
            end
        end
    end

    function LM:Retry()
        if self.Dead or self.RetryScheduled then return end
        self.FailCount = (self.FailCount or 0) + 1
        if self.FailCount > 6 then return end
        self.RetryScheduled = true
        task.delay(self.Config.RetryCooldown + 1, function()
            self.RetryScheduled = false
            if not self.Dead then self:Schedule() end
        end)
    end

    function LM:BuildBatches(sources, language, epoch)
        local slice = newSlicer(self.Config.FrameBudget)
        local batches, batch = {}, {}
        local base = #self:URL({}, language)
        local markerLen = #httpService:UrlEncode(string.format("ZXQB%06dQXZ\n", 1)) + #httpService:UrlEncode("\n")
        local used = base
        local limit, maxItems = self.Config.MaxURLLength, self.Config.BatchSize
        for _, source in ipairs(sources) do
            if slice() and (self.Dead or epoch ~= self.Epoch or self.CurrentLanguage ~= language) then
                return {}, true
            end
            if self:NeedsTranslation(source, language) then
                local text, tags = self:Protect(source)
                if text then
                    local size = markerLen + #httpService:UrlEncode(text)
                    if base + size > limit then
                        self.Failed[language] = self.Failed[language] or {}
                        self.Failed[language][source] = os.clock() + self.Config.RetryCooldown
                        self:Error("Text exceeds batch URL limit; supply a manual translation or shorten this source")
                    else
                        if #batch > 0 and (used + size > limit or #batch >= maxItems) then
                            table.insert(batches, batch)
                            batch, used = {}, base
                        end
                        table.insert(batch, {Source = source, Text = text, Tags = tags})
                        used = used + size
                    end
                else
                    self.Failed[language] = self.Failed[language] or {}
                    self.Failed[language][source] = os.clock() + self.Config.RetryCooldown
                    self:Error("Source contains reserved ZXQ markers; supply a manual translation")
                end
            end
        end
        if #batch > 0 then table.insert(batches, batch) end
        return batches, false
    end

    function LM:HandleResult(batch, result, reason, language, epoch, sources)
        if self.Dead or epoch ~= self.Epoch then return end
        self.Failed[language] = self.Failed[language] or {}
        if result then
            self.Cache[language] = self.Cache[language] or {}
            local missing = false
            for index, item in ipairs(batch) do
                if type(result[index]) == "string" then
                    self.Cache[language][item.Source] = result[index]
                    if self.Marks[language] then self.Marks[language][item.Source] = nil end
                else
                    missing = true
                    self.Failed[language][item.Source] = os.clock() + self.Config.RetryCooldown
                end
            end
            if not self.Held then self:CommitSoon() end
            self:ScheduleSave()
            if missing then self:Retry() else self.FailCount = 0 end
        elseif reason ~= "cancelled" and self.CurrentLanguage == language then
            if self:IsFormatError(reason) then
                for _, item in ipairs(batch) do
                    self.Failed[language][item.Source] = os.clock() + self.Config.RetryCooldown
                end
                self:Error(reason)
                self:Retry()
            else
                for _, source in ipairs(sources) do
                    self.Failed[language][source] = os.clock() + self.Config.RetryCooldown
                end
                self:Error(reason)
                self:Retry()
                if self.ToastFail ~= language then
                    self.ToastFail = language
                    self:Toast("Fail", language)
                end
                return "net"
            end
        end
    end

    function LM:RunBatches(batches, language, epoch, sources)
        local nextIndex, running, stop = 1, 0, false
        local workers = math.max(1, math.min(self.Config.Concurrency, #batches))
        for _ = 1, workers do
            running = running + 1
            task.spawn(function()
                while not stop and not self.Dead and epoch == self.Epoch do
                    local index = nextIndex
                    if index > #batches then break end
                    nextIndex = index + 1
                    local batch = batches[index]
                    local ok, result, reason = pcall(function() return self:SendBatch(batch, language, epoch) end)
                    if not ok then result, reason = nil, tostring(result) end
                    local handled, flag = pcall(self.HandleResult, self, batch, result, reason, language, epoch, sources)
                    if not handled then self:Error(flag) end
                    if flag == "net" then stop = true end
                end
                running = running - 1
            end)
        end
        while running > 0 do task.wait() end
        return stop
    end

    function LM:Work()
        while self.Active and not self.Dead and self.Config.AutoTranslations do
            local epoch, language = self.Epoch, self.CurrentLanguage
            local sources = self:Collect(newSlicer(self.Config.FrameBudget))
            local batches, stale = {}, true
            if not self.Dead and epoch == self.Epoch and language == self.CurrentLanguage then
                batches, stale = self:BuildBatches(sources, language, epoch)
            end
            if not stale then
                if #batches == 0 then
                    self:ReleaseHold()
                    if self.ToastDone ~= language and not self.Pending and not self.Dead then
                        self.ToastStart, self.ToastDone, self.ToastFail = language, language, nil
                        self:Toast("Done", language)
                    end
                    self:Audit(language, epoch)
                    break
                end
                if language ~= self.Config.SourceLanguage and self.ToastStart ~= language then
                    self.ToastStart, self.ToastDone, self.ToastFail = language, nil, nil
                    self:Toast("Start", language)
                end
                local netFail = self:RunBatches(batches, language, epoch, sources)
                if self.Dead or netFail then
                    self:ReleaseHold()
                    break
                end
            end
        end
    end

    function LM:Schedule(delay)
        if self.Dead or not self.Active or not self.Config.AutoTranslations or self.Scheduled then return end
        self.Scheduled = true
        task.delay(delay or self.Config.Debounce, function()
            self.Scheduled = false
            if self.Dead then return end
            if self.Busy then self.Pending = true; return end
            self.Busy = true
            local ok, err = pcall(function() self:Work() end)
            self.Busy = false
            if not ok then self:Error(err) end
            if self.Pending then self.Pending = false; self:Schedule() else self:ReleaseHold() end
        end)
    end

    function LM:GetLanguages()
        local result, seen = {}, {}
        local function add(code)
            code = self:Code(code)
            if code and not seen[code] then seen[code] = true; table.insert(result, code) end
        end
        add(self.Config.DefaultLanguage)
        for code, dict in pairs(self.Config.Translations) do if type(dict) == "table" then add(code) end end
        if self.Config.AutoTranslations then
            for _, code in ipairs(self.Config.Languages) do add(code) end
            add(self.CurrentLanguage)
        end
        table.sort(result)
        return result
    end

    function LM:IsAvailable(code)
        if self.Config.AutoTranslations then return true end
        return code == self.Config.DefaultLanguage or type(self.Config.Translations[code]) == "table"
    end

    function LM:Notify(previous)
        for listener in pairs(self.Listeners) do
            local ok, err = pcall(listener, self.CurrentLanguage, previous)
            if not ok then self:Error(err) end
        end
        self:SyncDropdowns()
    end

    function LM:OnChanged(callback)
        assert(type(callback) == "function", "OnChanged expects a function")
        self.Listeners[callback] = true
        local handle = {}
        function handle:Disconnect() LM.Listeners[callback] = nil end
        return handle
    end

    function LM:SetLanguage(code)
        if self.Dead then return false, "Language manager was destroyed" end
        if not self.Active then return false, "Call WindUI:Localization first" end
        code = self:Code(code)
        if not code then return false, "Invalid language code" end
        if not self.Config.Enabled and code ~= self.Config.DefaultLanguage then return false, "Language switching is disabled" end
        if not self:IsAvailable(code) then return false, "No dictionary for this language" end
        local previous = self.CurrentLanguage
        self.Epoch = self.Epoch + 1
        self.CurrentLanguage = code
        self.FailCount = 0
        self.ToastStart, self.ToastDone, self.ToastFail = nil, nil, nil
        if self.Config.AutoTranslations and self.Config.SyncSwap
            and code ~= self.Config.SourceLanguage and code ~= self.DisplayLanguage then
            self:Hold()
        else
            self.Held = false
            self.HoldToken = self.HoldToken + 1
            self.DisplayLanguage = code
            self:Commit()
            self:Schedule()
        end
        self:ScheduleSave()
        if previous ~= code then self:Notify(previous) end
        return true
    end

    function LM:GetLanguage() return self.CurrentLanguage end

    function LM:Refresh(retryFailed)
        if self.Dead then return false end
        if retryFailed then self.Failed = {}; self.FailCount = 0 end
        self:ApplyAll()
        self:SyncDropdowns()
        self:Schedule()
        self:ScheduleSave()
        return true
    end

    function LM:SetTranslations(language, dictionary, replace)
        language = self:Code(language)
        assert(language and type(dictionary) == "table", "Expected language code and dictionary")
        local target = replace and {} or (self.Config.Translations[language] or {})
        dictionary = self:SplitDictionary(dictionary, self.Config.NoTranslate)
        for source, value in pairs(dictionary) do
            assert(type(source) == "string" and (type(value) == "string" or value == false), "Translations must map source strings to strings (false removes an entry)")
            target[source] = value ~= false and value or nil
        end
        self.Config.Translations[language] = target
        self:BuildTerms()
        return self:Refresh()
    end

    function LM:ClearCache(language)
        if language then
            language = self:Code(language)
            assert(language, "Invalid language code")
            self.Cache[language], self.Failed[language] = nil, nil
            self.Marks[language], self.Bad[language] = nil, nil
        else self.Cache, self.Failed, self.Marks, self.Bad = {}, {}, {}, {} end
        self.Epoch = self.Epoch + 1
        self:Refresh()
    end

    function LM:GetOriginalText(object, property)
        property = property or "Text"
        local records = self.Records[object]
        return records and records[property] and records[property].Source or object[property]
    end

    function LM:SetOriginalText(object, source, property)
        property = property or "Text"
        assert(type(source) == "string", "Original text must be a string")
        local records = self.Records[object]
        local record = records and records[property]
        if not record then object[property] = source; return end
        record.Raw = source
        record.Source, record.Key = self:Source(source)
        record.Parts = nil
        self:Apply(record)
        self:Schedule()
        self:ScheduleSave()
    end

    function LM:SetTextParts(object, sources, separator)
        local records = self.Records[object]
        local record = records and records.Text
        if not record then object.Text = table.concat(sources, separator or ", "); return end
        record.Parts = {}
        for index, source in ipairs(sources) do record.Parts[index] = tostring(source) end
        record.Separator = separator or ", "
        record.Source = table.concat(record.Parts, record.Separator)
        self:Apply(record)
        self:Schedule()
    end

    function LM:Configure(options)
        assert(not self.Dead, "Language manager was destroyed")
        options = options or {}
        local default = assert(self:Code(options.DefaultLanguage or "en"), "Invalid DefaultLanguage")
        local source = assert(self:Code(options.SourceLanguage or default), "Invalid SourceLanguage")
        local translations, noTranslate = {}, {}
        for code, dict in pairs(options.Translations or {}) do
            local normalized = self:Code(code)
            assert(normalized and type(dict) == "table", "Translations must contain language tables")
            translations[normalized] = self:SplitDictionary(dict, noTranslate)
        end
        for _, item in ipairs(type(options.NoTranslations) == "table" and options.NoTranslations or {}) do
            if type(item) == "string" then noTranslate[item] = true end
        end
        local firstConfigure = self.Config == nil
        local oldSource = self.Config and self.Config.SourceLanguage
        local oldFile = self.Config and self.Config.CacheFile
        self.Config = {
            Enabled = options.Enabled ~= false, AutoTranslations = options.AutoTranslations == true,
            DefaultLanguage = default, SourceLanguage = source, Translations = translations, NoTranslate = noTranslate,
            Languages = options.Languages or {"en", "vi", "zh-CN", "zh-TW", "ja", "ko", "fr", "de", "es", "th", "id", "pt", "ru", "ar"},
            Cache = options.Cache ~= false, CacheFile = assert(options.CacheFile, "CacheFile must be set by the WindUI adapter"),
            SaveSelection = options.SaveSelection ~= false, AutoPruneCache = options.AutoPruneCache == true,
            Debounce = math.max(0.05, tonumber(options.Debounce) or 0.2),
            BatchSize = math.max(1, math.floor(tonumber(options.BatchSize) or 200)),
            MaxURLLength = math.max(512, math.min(16000, tonumber(options.MaxURLLength) or 8000)),
            Concurrency = math.max(1, math.min(8, math.floor(tonumber(options.Concurrency) or 4))),
            RequestInterval = math.max(0.05, tonumber(options.RequestInterval) or 0.15),
            MaxRetries = math.max(0, math.min(3, math.floor(tonumber(options.MaxRetries) or 2))),
            RetryCooldown = math.max(5, tonumber(options.RetryCooldown) or 60),
            Request = options.Request, OnError = options.OnError,
            Verify = options.Verify ~= false, OnRepair = options.OnRepair,
            Notifications = options.Notifications ~= false, Messages = options.Messages, Icons = options.Icons,
            SyncSwap = options.SyncSwap ~= false,
            SwapTimeout = math.max(2, tonumber(options.SwapTimeout) or 10),
            FrameBudget = math.max(0.0005, math.min(0.012, tonumber(options.FrameBudget) or 0.003)),
            SyncBudget = math.max(0.001, math.min(0.016, tonumber(options.SyncBudget) or 0.006)),
            SaveDelay = math.max(0.5, tonumber(options.SaveDelay) or 2),
        }
        if firstConfigure then self.DisplayLanguage = source end
        self:BuildTerms()
        if oldSource ~= source or oldFile ~= self.Config.CacheFile then self.Cache, self.Marks, self.Bad = {}, {}, {} end
        self.Epoch = self.Epoch + 1
        self.Failed = {}
        self.Active = true
        local previous = self.CurrentLanguage
        local saved = self:ReadDisk()
        local selected = self:Code(options.Language) or (self.Config.SaveSelection and saved) or default
        if not self.Config.Enabled or not self:IsAvailable(selected) then selected = default end
        self.CurrentLanguage = selected
        if self.Config.AutoTranslations and self.Config.SyncSwap
            and selected ~= source and selected ~= self.DisplayLanguage then
            self:Hold()
        else
            self.Held = false
            self.HoldToken = self.HoldToken + 1
            self.DisplayLanguage = selected
            self:Commit()
            self:Schedule()
        end
        self:Notify(previous)
        self:ScheduleSave()
        return self
    end

    function LM:Destroy()
        if self.Dead then return end
        self:SaveCache()
        self.Dead = true
        self.Epoch = self.Epoch + 1
        local objects = {}
        for object in pairs(self.Records) do table.insert(objects, object) end
        for _, object in ipairs(objects) do self:Untrack(object) end
        self.Listeners, self.Dropdowns = {}, {}
    end

    function LM:Source(raw)
        if type(raw) ~= "string" then return tostring(raw or ""), nil end
        local prefix = self.Prefix or "loc:"
        if raw:sub(1, #prefix) == prefix then
            local key = raw:sub(#prefix + 1)
            local defaults = self.KeyTranslations[self.SourceLanguage] or {}
            if type(defaults[key]) ~= "string" then
                local fallback = "[" .. key .. "]"
                self.MissingSources[fallback] = true
                return fallback, key
            end
            return defaults[key], key
        end
        return raw, nil
    end

    function LM:SyncDropdowns()
        for dropdown, entry in pairs(self.Dropdowns) do
            entry.Syncing = true
            local value = entry.Labels[self.CurrentLanguage] or self.CurrentLanguage
            local setter = dropdown.Select or dropdown.SetValue
            if type(setter) == "function" then
                local ok, err = pcall(setter, dropdown, value)
                if not ok then self:Error("Dropdown synchronization: " .. tostring(err)) end
            end
            entry.Syncing = false
        end
    end

    return LM
end

local Controller = {}
Controller.__index = Controller

function Controller:_error(message)
    if self.Manager then self.Manager:Error(message) else warn("[Modules] " .. tostring(message)) end
end

function Controller:_configure()
    if not self.Options or not self.Folder or self.Dead then return end
    local options = copy(self.Options)
    local manager = self.Manager
    local source = assert(manager:Code(options.SourceLanguage or options.DefaultLanguage or "en"), "Invalid source language")
    local keyed, flat, missing, signature = {}, {}, {}, {}
    for code, dict in pairs(options.Translations or {}) do
        local normalized = assert(manager:Code(code), "Invalid dictionary language")
        assert(type(dict) == "table", "Each language dictionary must be a table")
        keyed[normalized] = dict
    end
    local defaults = keyed[source] or {}
    for key, value in pairs(defaults) do
        if type(key) == "string" and type(value) == "string" then
            signature[#signature + 1] = key .. "=" .. value
        end
    end
    table.sort(signature)
    local nextSignature = table.concat(signature, "\n")
    if manager.SourceSignature and manager.SourceSignature ~= nextSignature then
        manager.Cache, manager.Marks, manager.Bad = {}, {}, {}
    end
    manager.SourceSignature = nextSignature
    local sourceKeys = {}
    for key, value in pairs(defaults) do
        if type(value) == "string" then
            sourceKeys[value] = sourceKeys[value] or {}
            table.insert(sourceKeys[value], key)
        end
    end
    for code, dict in pairs(keyed) do
        flat[code] = {}
        for sourceText, keys in pairs(sourceKeys) do
            local value, complete = nil, true
            for _, key in ipairs(keys) do
                if type(dict[key]) ~= "string" or (value ~= nil and value ~= dict[key]) then
                    complete = false
                    break
                end
                value = dict[key]
            end
            if complete then flat[code][sourceText] = value end
        end
        for key, value in pairs(dict) do
            if type(key) == "string" then
                local reserved = key:lower():gsub("[%s_%-]", "")
                if reserved == "notranslations" or reserved == "notranslation"
                    or reserved == "notranslate" or reserved == "donottranslate" then
                    flat[code][key] = value
                elseif defaults[key] == nil and type(value) == "string" then
                    missing["[" .. key .. "]"] = true
                end
            end
        end
    end
    manager.KeyTranslations, manager.MissingSources = keyed, missing
    manager.SourceLanguage, manager.Prefix = source, options.Prefix or "loc:"
    assert(type(manager.Prefix) == "string" and manager.Prefix ~= "", "Prefix must not be empty")
    options.Translations = flat
    options.AutoTranslations = options.AutoTranslate == true or options.AutoTranslations == true
    options.CacheFile = self.StorageRoot .. "/language/LanguageCache.json"
    options.Concurrency = options.Concurrency or 2
    options.BatchSize = options.BatchSize or 40
    options.RequestInterval = options.RequestInterval or 0.3
    local terms = {}
    for _, term in ipairs(options.NoTranslations or {}) do terms[#terms + 1] = term end
    local codes = {}
    for _, language in ipairs(Modules.Languages) do
        codes[#codes + 1] = language.Code
        terms[#terms + 1] = language.Name .. " [" .. language.Code .. "]"
    end
    options.NoTranslations = terms
    options.Languages = options.Languages or codes
    if manager.Config and options.Language == nil and self.ConfiguredFolder == self.Folder then
        options.Language = manager.CurrentLanguage
    end
    self.ConfiguredFolder = self.Folder
    manager:Configure(options)
    for _, records in pairs(manager.Records) do
        for _, record in pairs(records) do
            if record.Key then record.Source = manager:Source(record.Raw) end
        end
    end
    manager:Refresh()
end

function Controller:AttachRoot(root)
    assert(typeof(root) == "Instance", "AttachRoot expects a GUI Instance")
    if self.Dead or self.Roots[root] then return self end
    self.Roots[root] = true
    local function track(object)
        if self.Dead or not self.Manager.Config then return end
        if self.Options and self.Options.TranslateUnkeyed == false then
            local isBox = object:IsA("TextBox")
            if not (isBox or object:IsA("TextLabel") or object:IsA("TextButton")) then return end
            local value = isBox and object.PlaceholderText or object.Text
            if value:sub(1, #self.Manager.Prefix) ~= self.Manager.Prefix then return end
        end
        local ok, err = pcall(self.Manager.Track, self.Manager, object)
        if not ok then self:_error(err) end
    end
    self.Connections[#self.Connections + 1] = root.DescendantAdded:Connect(function(object)
        task.defer(function()
            if object.Parent ~= nil then track(object) end
        end)
    end)
    track(root)
    local started = os.clock()
    for _, object in ipairs(root:GetDescendants()) do
        track(object)
        if os.clock() - started > 0.003 then task.wait(); started = os.clock() end
    end
    self.Connections[#self.Connections + 1] = root.Destroying:Connect(function()
        self.Roots[root] = nil
        if self.PrimaryRoot == root then self:Destroy() end
    end)
    return self
end

function Controller:_roots(window)
    local wind = self.WindUI
    for _, key in ipairs({"ScreenGui", "NotificationGui", "DropdownGui", "TooltipGui", "GUI"}) do
        local root = wind[key]
        if typeof(root) == "Instance" then
            if key == "ScreenGui" or key == "GUI" then self.PrimaryRoot = root end
            self:AttachRoot(root)
        end
    end
    local elements = window and window.UIElements
    if type(elements) == "table" and typeof(elements.Main) == "Instance" then
        local node = elements.Main
        while node.Parent and not node:IsA("ScreenGui") do node = node.Parent end
        if node:IsA("ScreenGui") then
            self.PrimaryRoot = self.PrimaryRoot or node
            self:AttachRoot(node)
        else
            self:AttachRoot(elements.Main)
        end
    end
    if next(self.Roots) == nil then
        self:_error("No exposed GUI root found. Call controller:AttachRoot(yourScreenGui) for this WindUI fork.")
    end
end

local function safeFolder(folder)
    assert(type(folder) == "string" and folder ~= "", "Window.Folder is required for language storage")
    folder = folder:gsub("\\", "/"):gsub("/+", "/"):gsub("/$", "")
    assert(folder ~= "" and folder:sub(1, 1) ~= "/" and not folder:find(":", 1, true), "Folder must be a relative path")
    for piece in folder:gmatch("[^/]+") do assert(piece ~= "." and piece ~= "..", "Unsafe folder path") end
    return folder
end

function Controller:_hookSections(window)
    if type(window) ~= "table" then return end
    self.SectionHooked = self.SectionHooked or setmetatable({}, {__mode = "k"})
    local hooked = self.SectionHooked
    local controller = self

    local function watchSection(section)
        local frame = section.ElementFrame
        if typeof(frame) ~= "Instance" then return end
        local outline = frame:FindFirstChild("Outline")
        local content = outline and outline:FindFirstChild("Content")
        if not content then return end
        local connection
        connection = content:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            if controller.Dead then connection:Disconnect() return end
            if type(section.Open) ~= "function" then return end
            if section.Expandable == false or not section.Opened then return end
            pcall(function() section:Open(true) end)
        end)
        content.Destroying:Once(function() connection:Disconnect() end)
    end

    local function hookContainer(container)
        if type(container) ~= "table" or hooked[container] then return end
        hooked[container] = true
        for _, name in ipairs({"Section", "Tab"}) do
            local ok, original = pcall(function() return container[name] end)
            if ok and type(original) == "function" then
                container[name] = function(...)
                    local result = table.pack(original(...))
                    local object = result[1]
                    if type(object) == "table" then
                        pcall(hookContainer, object)
                        if name == "Section" then pcall(watchSection, object) end
                    end
                    return table.unpack(result, 1, result.n)
                end
            end
        end
    end

    pcall(hookContainer, window)
end

function Controller:BindWindow(window, folder)
    assert(not self.Dead, "Modules controller was destroyed")
    assert(type(window) == "table", "BindWindow expects a WindUI window table")
    self.Window = window
    self:_hookSections(window)
    self.Folder = safeFolder(folder or window.Folder or self.InstallOptions.Folder)
    local configManager = window.ConfigManager or self.WindUI.ConfigManager
    local path = type(configManager) == "table" and configManager.Path
    local base = type(path) == "string" and path:gsub("\\", "/"):match("^(.-)/config/?$")
    self.StorageRoot = safeFolder(base or self.Folder)
    self:_configure()
    if self.Manager.Config then self:_roots(window) end
    return self
end

function Controller:SetLanguage(code)
    return self.Manager:SetLanguage(code)
end
function Controller:GetLanguage() return self.Manager:GetLanguage() end
function Controller:GetCachePath()
    return self.StorageRoot and (self.StorageRoot .. "/language/LanguageCache.json") or nil
end
function Controller:Refresh(retryFailed) return self.Manager:Refresh(retryFailed) end
function Controller:OnChanged(callback) return self.Manager:OnChanged(callback) end

function Controller:AddDropdown(tab, options)
    assert(self.Manager.Config, "CreateWindow must run before AddDropdown")
    assert(type(tab) == "table" and type(tab.Dropdown) == "function", "This WindUI tab does not expose Dropdown")
    options = copy(options)
    local entry = { Syncing = true, Labels = {} }
    local values, reverse = {}, {}
    for _, language in ipairs(Modules.Languages) do
        local label = language.Name .. " [" .. language.Code .. "]"
        values[#values + 1] = label
        reverse[label], entry.Labels[language.Code] = language.Code, label
    end
    local callback = options.Callback
    options.Title = options.Title or "Language / Ngôn ngữ"
    options.Desc = options.Desc or "30 languages • Manual dictionaries + automatic translation"
    options.Values, options.Multi, options.AllowNone = values, false, false
    options.Value = entry.Labels[self:GetLanguage()] or values[1]
    options.Callback = function(value)
        if entry.Syncing then return end
        if type(value) == "table" then value = value[1] end
        local code = reverse[value]
        if not code then return end
        local ok, err = self:SetLanguage(code)
        if not ok then self:_error(err); self.Manager:SyncDropdowns() end
        if callback then callback(code, ok, err) end
    end
    local dropdown = tab:Dropdown(options)
    self.Manager.Dropdowns[dropdown] = entry
    entry.Syncing = false
    return dropdown
end

function Controller:GetStatus()
    local tracked = 0
    for _ in pairs(self.Manager.Records) do tracked = tracked + 1 end
    return { Version = Modules.Version, Language = self:GetLanguage(),
        DisplayLanguage = self.Manager.DisplayLanguage, Busy = self.Manager.Busy,
        TrackedObjects = tracked, CachePath = self:GetCachePath(),
        LastError = self.Manager.LastError, Dead = self.Dead == true }
end

function Controller:Destroy()
    if self.Dead then return end
    self.Dead = true
    self.Manager:Destroy()
    for _, connection in ipairs(self.Connections) do connection:Disconnect() end
    for key, wrapper in pairs(self.Wrappers) do
        if self.WindUI[key] == wrapper then self.WindUI[key] = self.Original[key] end
    end
    Installed[self.WindUI] = nil
    self.Roots, self.Connections = {}, {}
end

function Modules:Install(WindUI, options)
    assert(type(WindUI) == "table" and type(WindUI.CreateWindow) == "function", "Expected a loaded WindUI table")
    if Installed[WindUI] then return Installed[WindUI] end
    local controller = setmetatable({ WindUI = WindUI, InstallOptions = options or {},
        Roots = {}, Connections = {}, Original = {}, Wrappers = {},
        Manager = newManager(WindUI) }, Controller)
    Installed[WindUI] = controller
    local function hook(name, wrapper)
        controller.Original[name] = WindUI[name]
        controller.Wrappers[name] = wrapper
        WindUI[name] = wrapper
    end
    hook("Localization", function(_, config)
        assert(not controller.Dead, "Modules controller was destroyed")
        assert(type(config) == "table", "Localization expects a configuration table")
        controller.Options = copy(config)
        local original = controller.Original.Localization
        if type(original) == "function" then
            local native = copy(config)
            native.Enabled = false
            original(WindUI, native)
        end
        if controller.Window then controller:BindWindow(controller.Window, controller.Folder)
        elseif controller.InstallOptions.Folder then
            controller.Folder = safeFolder(controller.InstallOptions.Folder)
            controller.StorageRoot = controller.Folder
            controller:_configure()
        end
        return config
    end)
    hook("SetLanguage", function(_, code)
        if controller.Manager.Config then return controller:SetLanguage(code) end
        local original = controller.Original.SetLanguage
        if type(original) == "function" then return original(WindUI, code) end
        return false, "Call Localization and CreateWindow first"
    end)
    hook("GetLanguage", function() return controller:GetLanguage() end)
    hook("CreateWindow", function(_, config)
        local window = controller.Original.CreateWindow(WindUI, config)
        if window then controller:BindWindow(window, config.Folder) end
        return window
    end)
    if WindUI.Window then controller:BindWindow(WindUI.Window) end
    return controller
end

return Modules
