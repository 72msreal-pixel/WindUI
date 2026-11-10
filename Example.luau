-- đầy đủ tất cả cách sử dụng
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local PathfindingService = game:GetService("PathfindingService")
local LocalizationService = game:GetService("LocalizationService")
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local localPlayer = Players.LocalPlayer
local PlayerGui = localPlayer:WaitForChild("PlayerGui", 10)
local playerCharacter = localPlayer.Character or localPlayer.CharacterAdded:Wait()
localPlayer.CharacterAdded:Connect(function(character) playerCharacter = character end)
local Camera = Workspace.CurrentCamera

local LIB_FILE = "Main.luau"
local LIB_URL = "https://raw.githubusercontent.com/72msreal-pixel/WindUI/refs/heads/main/Main.luau"

local IMAGE_ID = "rbxassetid://7229442422" -- decal mẫu trong tài liệu Roblox
local VIDEO_ID = "rbxassetid://5608384572" -- video mẫu trong tài liệu Roblox

local WindUI, Window
local ready = false


function Notify(title, content, icon, duration)
	if not ready then return end
	return WindUI:Notify({
		Title = title,
		Content = content,
		Icon = icon or "bell",
		Duration = duration or 3,
	})
end

function Guard(fn)
	return function(...)
		if ready then return fn(...) end
	end
end

function Report(label)
	return function(...)
		local out = {}
		for i, v in ipairs({ ... }) do
			out[i] = typeof(v) == "table" and table.concat(v, ", ") or tostring(v)
		end
		Notify(label, table.concat(out, " | "), "check")
	end
end

function MakeButtons(...)
	local list = {}
	for i, b in ipairs({ ... }) do
		list[i] = { Title = b[1], Icon = b[2], Variant = b[3], Callback = b[4] or Report(b[1]) }
	end
	return list
end

function ConfigList()
	local names = {}
	for _, n in ipairs(Window.ConfigManager:AllConfigs()) do names[#names + 1] = n end
	table.sort(names)
	return names
end

function HexTheme(theme)
	local out = {}
	for key, value in pairs(theme) do
		out[key] = key == "Name" and value or Color3.fromHex(value)
	end
	return out
end

function MakePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	for key, value in pairs(props) do part[key] = value end
	return part
end

function MakeCamera(position, target)
	local cam = Instance.new("Camera")
	cam.CFrame = CFrame.new(position, target)
	return cam
end

-- Camera phải nằm trong ViewportFrame thì viewport mới render ổn định
function AddViewport(tab, object, cam, interactive, height)
	local viewport = tab:Viewport({
		Object = object,
		Camera = cam,
		Interactive = interactive,
		Height = height,
	})
	cam.Parent = viewport.Main.CanvasGroup.Viewport
	return viewport
end

function AddTab(section, title, icon, desc, extra)
	local config = {
		Title = title,
		Icon = icon,
		Desc = desc,
		ShowTabTitle = true,
		TabTitleAlign = "Left",
	}
	for k, v in pairs(extra or {}) do config[k] = v end
	return section:Tab(config)
end

local src = (isfile and isfile(LIB_FILE)) and readfile(LIB_FILE) or game:HttpGet(LIB_URL)
WindUI = loadstring(src)()

for _, theme in ipairs({
	{
		Name = "Neon",
		Accent = "#0b0f1a", Dialog = "#0f1424", Outline = "#00e5ff", Text = "#e6faff",
		Placeholder = "#5f7a85", Background = "#070a14", Button = "#1c2b45", Icon = "#00e5ff",
		Toggle = "#00e5ff", Slider = "#7c4dff", Checkbox = "#7c4dff", Primary = "#7c4dff",
	},
	{
		Name = "Sunset",
		Accent = "#2a1410", Dialog = "#33180f", Outline = "#ffb74d", Text = "#fff3e0",
		Placeholder = "#a1887f", Background = "#1b0d08", Button = "#e65100", Icon = "#ffb74d",
		Toggle = "#ff7043", Slider = "#ff7043", Checkbox = "#ff7043", Primary = "#ff7043",
	},
}) do
	WindUI:AddTheme(HexTheme(theme))
end

WindUI:Localization({
	Enabled = true,
	Prefix = "loc:",
	DefaultLanguage = "en",
	Translations = {
		en = { TITLE = "WindUI Plus Example", WELCOME = "Welcome to WindUI Plus!" },
		vi = { TITLE = "Ví dụ WindUI Plus", WELCOME = "Chào mừng đến với WindUI Plus!" },
	},
})

WindUI:SetNotificationLower(false)

WindUI:OnThemeChange(function(themeName)
	print("[Example] Theme ->", themeName)
end)

Window = WindUI:CreateWindow({
	Title = "loc:TITLE",
	Author = "by YourName",
	Icon = "zap",
	IconSize = 22,
	IconThemed = true,
	IconRadius = 0,
	Folder = "WindUIPlusExample",
	Theme = "Dark",

	Size = UDim2.fromOffset(620, 480),
	MinSize = Vector2.new(560, 350),
	MaxSize = Vector2.new(850, 560),
	Resizable = true,
	AutoScale = true,
	Radius = 16,
	SideBarWidth = 200,
	HideSearchBar = false,
	ScrollBarEnabled = true,

	Transparent = true,
	Acrylic = false,
	ShadowTransparency = 0.7,
	BackgroundImageTransparency = 0.4,
	HidePanelBackground = false,

	ModernLayout = false,
	ModernLayoutMergeElements = true,

	ToggleKey = Enum.KeyCode.RightShift,
	BottomDragBarEnabled = true,
	IgnoreAlerts = false,

	User = {
		Enabled = true,
		Anonymous = false,
		Callback = function() Notify("User", "Bạn vừa bấm vào khung user", "user") end,
	},

	Topbar = { Height = 52, ButtonsType = "Default" },

	OpenButton = {
		Title = "Open UI",
		Icon = "monitor",
		CornerRadius = UDim.new(1, 0),
		StrokeThickness = 2,
		Enabled = true,
		Draggable = true,
		OnlyMobile = false,
		Scale = 1,
		Color = ColorSequence.new(Color3.fromHex("#40c9ff"), Color3.fromHex("#e81cff")),
	},

	Watermark = {
		Enabled = true,
		Text = "WindUI Plus",
		Opacity = 0.35,
		Position = "bottom-right",
		Size = 14,
		Padding = 12,
		Offset = Vector2.new(0, 0),
	},
})

Window:OnOpen(function() print("[Example] Window opened") end)
Window:OnClose(function() print("[Example] Window closed") end)
Window:OnDestroy(function() print("[Example] Window destroyed") end)

Window:Tag({ Title = "v0.0.6", Icon = "github", Color = Color3.fromHex("#315dff"), Radius = 999 })
Window:Tag({ Title = "Beta", Color = Color3.fromHex("#e53935"), Border = true })
Window:Tag({
	Title = "Gradient",
	Icon = "sparkles",
	Color = WindUI:Gradient({
		["0"] = { Color = "#ff0080", Transparency = 0 },
		["100"] = { Color = "#7928ca", Transparency = 0 },
	}, { Rotation = 45 }),
})

Window:CreateTopbarButton("Fullscreen", "maximize", function() Window:ToggleFullscreen() end, 990)
Window:CreateTopbarButton("Theme", "palette", function()
	WindUI:SetTheme(WindUI:GetCurrentTheme() == "Dark" and "Light" or "Dark")
end, 991)
Window:CreateTopbarButton("Notify", "bell", function()
	Notify("Topbar", "Bạn vừa bấm nút trên topbar", "bell")
end, 992, nil, Color3.fromHex("#ffb300"))

local shortcutId = Window:BindShortcut(Enum.KeyCode.K, function()
	Notify("Shortcut", "Ctrl + K được nhấn", "keyboard")
end, { Ctrl = true, EnabledWhenClosed = true, Description = "Demo shortcut" })

Window:BindShortcut(Enum.KeyCode.L, function()
	Notify("Shortcut", "Ctrl + Shift + L được nhấn", "keyboard")
end, { Ctrl = true, Shift = true, Description = "Demo shortcut 2" })

Window:SideBarLabel({ Title = "WindUI Plus" })
Window:SideBarButton({
	Title = "Copy Discord",
	Icon = "message-circle",
	Variant = "Secondary",
	Callback = function()
		if setclipboard then setclipboard("https://discord.gg/example") end
		Notify("Copied", "Đã copy link Discord", "copy")
	end,
})
Window:SideBarSpace()
Window:SideBarDivider()

local ElementsSection = Window:Section({ Title = "Elements", Icon = "layout-grid", Opened = true })
local SystemSection = Window:Section({ Title = "System", Icon = "settings", Opened = true })
local LinksSection = Window:Section({ Title = "Links", Icon = "link", Opened = false })

local ButtonTab = AddTab(ElementsSection, "Buttons", "mouse-pointer-click", "Button, Keybind, Paragraph, Label")
local ToggleTab = AddTab(ElementsSection, "Toggles", "toggle-right", "Toggle, Checkbox, ToggleKeybind")
local InputTab = AddTab(ElementsSection, "Inputs", "sliders-horizontal", "Slider, Stepper, Input, Keybind, Color")
local DropdownTab = AddTab(ElementsSection, "Dropdowns", "chevrons-up-down", "Dropdown, Segmented")
local DisplayTab = AddTab(ElementsSection, "Display", "gauge", "Progress, Stats, Notice, Tags, Code")
local MediaTab = AddTab(ElementsSection, "Media", "image", "Image, Video, Viewport")
local LayoutTab = AddTab(ElementsSection, "Layout", "columns-2", "Group, HStack, VStack, Section")
local DialogTab = AddTab(SystemSection, "Dialogs", "message-square", "Notify, Popup, Dialog, Watermark")
local ConfigTab = AddTab(SystemSection, "Config", "save", "Lưu / tải cấu hình")
local SettingsTab = AddTab(SystemSection, "Settings", "settings-2", "Theme, Window, Language")
local LockedTab = AddTab(SystemSection, "Locked Tab", "lock", nil, { Locked = true })
local EmptyTab = AddTab(SystemSection, "Empty", "inbox", nil, {
	ShowTabTitle = false,
	CustomEmptyPage = { Icon = "inbox", IconSize = 48, Title = "Chưa có nội dung", Desc = "Tab trống tuỳ chỉnh" },
})

LinksSection:Label({ Title = "Liên kết", Icon = "link" })
for _, def in ipairs({
	{ "Primary", "star", "Primary" },
	{ "Secondary", "heart", "Secondary" },
	{ "White", "sun", "White" },
	{ "FullRounded", "circle", "Primary", true },
}) do
	LinksSection:Button({
		Title = def[1],
		Icon = def[2],
		Variant = def[3],
		FullRounded = def[4],
		Callback = Report(def[1]),
	})
end
LinksSection:Space()
LinksSection:Divider()

ButtonTab:Paragraph({
	Title = "loc:WELCOME",
	Desc = "Paragraph hỗ trợ Buttons ở dưới, Image, Thumbnail và Tags.",
	Image = "info",
	ImageSize = 30,
	Color = "Blue",
	Buttons = {
		{ Title = "Docs", Icon = "book-open", Variant = "Primary", Callback = Report("Docs") },
		{ Title = "Close", Icon = "x", Variant = "White", Callback = Report("Close") },
		{ Title = "More", Icon = "ellipsis", Variant = "Secondary", Callback = Report("More") },
	},
})

ButtonTab:Paragraph({
	Title = "Paragraph có Tags",
	Desc = "Chỉ có chữ, không nút.",
	Tags = {
		{ Title = "Info", Icon = "info", Color = Color3.fromHex("#039be5") },
		{ Title = "Border", Border = true },
	},
})

ButtonTab:Paragraph({
	Title = "Paragraph có Thumbnail",
	Desc = "Thumbnail nằm phía trên nội dung.",
	Thumbnail = IMAGE_ID,
	ThumbnailSize = 100,
	Locked = false,
})

ButtonTab:Label({ Title = "Label mặc định", Icon = "tag" })
ButtonTab:Label({ Title = "Label Placeholder", Icon = "tag", Placeholder = true })
ButtonTab:Label({ Title = "Label cao + bo góc lớn", Icon = "tag", Height = 54, Radius = 20, Padding = 4 })

ButtonTab:Divider()

local ColorSection = ButtonTab:Section({ Title = "Color", Desc = "Red / Orange / Green / Blue / White / Grey / Color3", Icon = "palette", Opened = true, Box = true, BoxBorder = true })

local mainButton = ColorSection:Button({
	Title = "Default Button",
	Desc = "Icon mặc định = mouse-pointer-click",
	Callback = Report("Default"),
})
for _, def in ipairs({
	{ "Red", "Red", "flame" },
	{ "Orange", "Orange", "sun" },
	{ "Green", "Green", "check" },
	{ "Blue", "Blue", "droplet" },
	{ "White", "White", "circle" },
	{ "Grey", "Grey", "moon" },
	{ "Color3 tuỳ chọn", Color3.fromHex("#8e24aa"), "sparkles", "Purple" },
}) do
	ColorSection:Button({ Title = def[1], Color = def[2], Icon = def[3], Callback = Report(def[4] or def[1]) })
end

local LayoutSection = ButtonTab:Section({ Title = "Justify / IconAlign / Size", Icon = "align-center", Opened = false, Box = true })

LayoutSection:Button({ Title = "Justify Between, icon phải (mặc định)", Callback = Report("Between") })
LayoutSection:Button({ Title = "Justify Center", Justify = "Center", Callback = Report("Center") })
LayoutSection:Button({ Title = "Icon bên trái", Justify = "Center", IconAlign = "Left", Icon = "arrow-left", Callback = Report("Left") })
LayoutSection:Button({ Title = "IconColor riêng", Icon = "heart", IconColor = Color3.fromHex("#ff5252"), Callback = Report("Heart") })
LayoutSection:Button({ Title = "IconThemed", Icon = "star", IconThemed = true, Callback = Report("Themed") })
LayoutSection:Button({ Title = "Size Small", Size = "Small", Callback = Report("Small") })
LayoutSection:Button({ Title = "Size Default", Size = "Default", Callback = Report("Default size") })
LayoutSection:Button({ Title = "Size Large", Desc = "Large + Thumbnail", Size = "Large", Thumbnail = IMAGE_ID, ThumbnailSize = 80, Callback = Report("Large") })
LayoutSection:Button({ Title = "Có Image", Desc = "Image + ImageSize", Image = IMAGE_ID, ImageSize = 36, Callback = Report("Image") })

local StateSection = ButtonTab:Section({ Title = "Tags / Locked / Method", Icon = "tags", Opened = false, Box = true })

StateSection:Button({
	Title = "Button có Tags",
	Desc = "Tags = {{Title, Icon, Color, Border, Radius}}",
	Tags = {
		{ Title = "NEW", Color = Color3.fromHex("#43a047") },
		{ Title = "HOT", Icon = "flame", Color = Color3.fromHex("#e53935"), Border = true },
		{ Title = "Square", Radius = 6 },
	},
	Callback = Report("Tags"),
})

local lockedButton = StateSection:Button({ Title = "Locked Button", Locked = true, LockedTitle = "Cần VIP", Callback = Report("never") })

StateSection:Button({
	Title = "Lock / Unlock nút bên trên",
	Icon = "unlock",
	Callback = function()
		if lockedButton.Locked then lockedButton:Unlock() else lockedButton:Lock() end
	end,
})
StateSection:Button({ Title = "Highlight Default Button", Icon = "sun", Callback = function() mainButton:Highlight() end })
StateSection:Button({
	Title = "Đổi Title và Desc",
	Icon = "pencil",
	Callback = function()
		mainButton:SetTitle("Title mới " .. os.date("%X"))
		mainButton:SetDesc("Desc mới")
	end,
})

ButtonTab:Space({ Columns = 2 })

for _, config in ipairs({
	{ Title = "ButtonKeybind", Desc = "Bấm nút hoặc phím F", Icon = "zap", Value = Enum.KeyCode.F, CanChange = true, Callback = Report("ButtonKeybind") },
	{ Title = "ButtonKeybind Center, màu Green", Icon = "play", Color = "Green", Value = Enum.KeyCode.H, Justify = "Center", IconAlign = "Left", Callback = Report("Keybind Green") },
	{ Title = "ButtonKeybind không đổi được phím", Value = Enum.KeyCode.J, CanChange = false, Callback = Report("Keybind cố định") },
	{ Title = "ButtonKeybind bị khoá", Value = Enum.KeyCode.U, Locked = true, LockedTitle = "Đã khoá", Callback = Report("never") },
}) do
	ButtonTab:ButtonKeybind(config)
end

local toggleMain = ToggleTab:Toggle({
	Title = "Toggle",
	Desc = "Value mặc định = true",
	Value = true,
	Flag = "demo_toggle",
	Callback = Report("Toggle"),
})
ToggleTab:Toggle({ Title = "Toggle không Desc", Value = false, Flag = "demo_toggle_plain", Callback = Report("Plain") })
ToggleTab:Toggle({ Title = "Toggle + Icon check", Icon = "check", IconSize = 23, Value = false, Flag = "demo_toggle_icon", Callback = Report("Icon") })
ToggleTab:Toggle({ Title = "Toggle + Icon lớn", Icon = "zap", IconSize = 30, Value = true, Callback = Report("Icon lớn") })
ToggleTab:Toggle({
	Title = "Toggle có Tags",
	Desc = "Tags hiện dưới tiêu đề",
	Tags = { { Title = "NEW", Color = Color3.fromHex("#43a047") } },
	Callback = Report("Tags"),
})
ToggleTab:Toggle({ Title = "Toggle Type = Checkbox", Type = "Checkbox", Value = true, Flag = "demo_checkbox_type", Callback = Report("Checkbox Type") })

ToggleTab:Divider()

ToggleTab:Checkbox({ Title = "Checkbox", Desc = "Element riêng", Value = false, Flag = "demo_checkbox", Callback = Report("Checkbox") })
ToggleTab:Checkbox({ Title = "Checkbox + Icon", Value = true, Icon = "check", IconSize = 18, Callback = Report("Checkbox Icon") })
ToggleTab:Checkbox({ Title = "Checkbox bị khoá", Value = true, Locked = true, LockedTitle = "Không đổi được", Callback = Report("never") })

ToggleTab:Divider()

ToggleTab:ToggleKeybind({
	Title = "ToggleKeybind",
	Desc = "Bật/tắt bằng phím G",
	Value = false,
	Keybind = Enum.KeyCode.G,
	CanChange = true,
	Flag = "demo_togglekeybind",
	Callback = Report("ToggleKeybind"),
})
ToggleTab:ToggleKeybind({
	Title = "ToggleKeybind kiểu Checkbox",
	Value = true,
	Keybind = Enum.KeyCode.V,
	Type = "Checkbox",
	Callback = Report("ToggleKeybind Checkbox"),
})
ToggleTab:ToggleKeybind({
	Title = "ToggleKeybind cố định phím B",
	Keybind = Enum.KeyCode.B,
	CanChange = false,
	Callback = Report("ToggleKeybind cố định"),
})

ToggleTab:Divider()

local lockableToggle = ToggleTab:Toggle({ Title = "Toggle bị khoá", Locked = true, LockedTitle = "Đang khoá", Value = false, Callback = Report("Lockable") })
ToggleTab:Toggle({
	Title = "Mở khoá toggle bên trên",
	Value = false,
	Callback = function(state)
		if state then lockableToggle:Unlock() else lockableToggle:Lock() end
	end,
})
ToggleTab:Button({ Title = "Set toggle đầu = false (không gọi callback)", Icon = "toggle-left", Callback = function() toggleMain:Set(false, false) end })
ToggleTab:Button({ Title = "Set toggle đầu = true (có callback)", Icon = "toggle-right", Callback = function() toggleMain:Set(true) end })
ToggleTab:Button({ Title = "Lock tất cả trong tab", Icon = "lock", Callback = function() ToggleTab:LockAll() end })
ToggleTab:Button({ Title = "Unlock tất cả trong tab", Icon = "unlock", Callback = function() ToggleTab:UnlockAll() end })

InputTab:Slider({
	Title = "Slider",
	Desc = "Value = {Min, Max, Default}, Step = 1",
	Value = { Min = 0, Max = 100, Default = 50 },
	Step = 1,
	IsTooltip = true,
	IsTextbox = true,
	Width = 130,
	Flag = "demo_slider",
	Callback = Report("Slider"),
})
InputTab:Slider({ Title = "Slider không Textbox", Value = { Min = 0, Max = 100, Default = 20 }, IsTextbox = false, Callback = Report("No textbox") })
InputTab:Slider({ Title = "Slider rộng 220", Value = { Min = 0, Max = 500, Default = 250 }, Step = 10, Width = 220, Callback = Report("Wide") })
InputTab:Slider({ Title = "Slider số âm", Value = { Min = -50, Max = 50, Default = 0 }, Step = 5, Callback = Report("Negative") })
InputTab:Slider({ Title = "Slider thập phân", Value = { Min = 0, Max = 1, Default = 0.5 }, Step = 0.05, Flag = "demo_slider_float", Callback = Report("Float") })
InputTab:Slider({
	Title = "Slider có Icons",
	Icons = { From = "sfsymbols:sunMinFill", To = "sfsymbols:sunMaxFill" },
	Value = { Min = 0, Max = 10, Default = 5 },
	IsTextbox = false,
	Callback = Report("Icons"),
})
InputTab:Slider({ Title = "Slider không Title", Value = { Min = 0, Max = 10, Default = 5 }, Callback = Report("No title") })
InputTab:Slider({ Title = "Slider bị khoá", Value = { Min = 0, Max = 100, Default = 70 }, Locked = true, LockedTitle = "Khoá", Callback = Report("never") })

InputTab:Divider()

local mainStepper = InputTab:Stepper({
	Title = "Stepper",
	Desc = "Giữ nút để tăng/giảm nhanh",
	Value = { Min = 0, Max = 50, Default = 10 },
	Step = 5,
	Prefix = "x",
	Suffix = " lvl",
	Callback = Report("Stepper"),
})
InputTab:Stepper({
	Title = "Stepper thập phân",
	Value = { Min = 0, Max = 5, Default = 1 },
	Step = 0.25,
	Precision = 2,
	Callback = Report("Stepper decimal"),
})
InputTab:Stepper({
	Title = "Stepper có Format",
	Value = { Min = 1, Max = 99, Default = 1 },
	Format = function(value) return "Lv." .. value end,
	HoldDelay = 0.4,
	HoldRate = 0.05,
	Callback = Report("Stepper format"),
})
InputTab:Stepper({
	Title = "Stepper rộng + nút to",
	Value = { Min = 0, Max = 1000, Default = 100 },
	Step = 50,
	Prefix = "$",
	Width = 240,
	ButtonSize = 40,
	Callback = Report("Stepper wide"),
})
InputTab:Stepper({ Title = "Stepper bị khoá", Value = 7, Locked = true, Callback = Report("never") })
InputTab:Button({ Title = "Stepper:Set(25)", Callback = function() mainStepper:Set(25) end })
InputTab:Button({ Title = "Stepper:Add(5)", Callback = function() mainStepper:Add(5) end })
InputTab:Button({ Title = "Stepper:Decrement(5)", Callback = function() mainStepper:Decrement(5) end })
InputTab:Button({ Title = "Stepper:SetRange(0, 100)", Callback = function() mainStepper:SetRange(0, 100) end })

InputTab:Divider()

local mainInput = InputTab:Input({
	Title = "Input",
	Desc = "Gõ xong nhấn Enter hoặc click ra ngoài",
	Placeholder = "Nhập chữ...",
	Flag = "demo_input",
	Callback = Report("Input"),
})
InputTab:Input({ Title = "Input có icon", Placeholder = "Tìm kiếm...", InputIcon = "search", Callback = Report("Input icon") })
InputTab:Input({ Title = "Input có giá trị sẵn", Value = "Xin chào", Callback = Report("Input value") })
InputTab:Input({ Title = "Input xoá khi focus", Placeholder = "Click vào để xoá", ClearTextOnFocus = true, Callback = Report("Input clear") })
InputTab:Input({ Title = "Input bị khoá", Value = "Không sửa được", Locked = true, LockedTitle = "Khoá", Callback = Report("never") })
InputTab:Input({ Title = "Textarea", Type = "Textarea", Placeholder = "Nhiều dòng...", Flag = "demo_textarea", Callback = Report("Textarea") })
InputTab:Button({ Title = "Input:Set('Đã đổi')", Callback = function() mainInput:Set("Đã đổi") end })
InputTab:Button({ Title = "Input:SetPlaceholder", Callback = function() mainInput:SetPlaceholder("Placeholder mới") end })

InputTab:Divider()

InputTab:Keybind({
	Title = "Keybind",
	Desc = "Click để đổi phím",
	Value = Enum.KeyCode.X,
	CanChange = true,
	Flag = "demo_keybind",
	Callback = Report("Keybind pressed"),
})
InputTab:Keybind({ Title = "Keybind có Blacklist", Value = Enum.KeyCode.Z, Blacklist = { Enum.KeyCode.Escape, Enum.KeyCode.Backspace }, Callback = Report("Blacklist") })
InputTab:Keybind({ Title = "Keybind chuột trái", Value = "MouseLeft", Callback = Report("MouseLeft") })
InputTab:Keybind({ Title = "Keybind cố định", Value = Enum.KeyCode.Q, CanChange = false, Callback = Report("Fixed") })
InputTab:Keybind({ Title = "Keybind bị khoá", Value = Enum.KeyCode.E, Locked = true, LockedTitle = "Khoá", Callback = Report("never") })

InputTab:Divider()

local mainColor = InputTab:Colorpicker({
	Title = "Colorpicker",
	Desc = "Có Transparency",
	Default = Color3.fromRGB(0, 145, 255),
	Transparency = 0,
	Flag = "demo_color",
	Callback = function(color, transparency)
		Notify("Colorpicker", ("%s | alpha %.2f"):format(tostring(color), transparency or 0), "palette")
	end,
})
InputTab:Colorpicker({ Title = "Colorpicker không Transparency", Default = Color3.fromRGB(255, 170, 0), Callback = Report("Color 2") })
InputTab:Colorpicker({ Title = "Colorpicker bị khoá", Default = Color3.fromRGB(0, 200, 83), Locked = true, Callback = Report("never") })
InputTab:Button({ Title = "Đặt màu đỏ", Callback = function() mainColor:Set(Color3.fromRGB(255, 0, 0), 0) end })

local mainDropdown = DropdownTab:Dropdown({
	Title = "Dropdown",
	Desc = "Chọn 1",
	Values = { "Apple", "Banana", "Cherry", "Durian" },
	Value = "Banana",
	AllowNone = false,
	Flag = "demo_dropdown",
	Callback = Report("Dropdown"),
})
DropdownTab:Dropdown({ Title = "Dropdown có Search", Values = { "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta" }, Value = "Alpha", SearchBarEnabled = true, Callback = Report("Search") })
DropdownTab:Dropdown({ Title = "Dropdown AllowNone", Values = { "On", "Off" }, AllowNone = true, Callback = Report("AllowNone") })
DropdownTab:Dropdown({ Title = "Dropdown MenuWidth 300", Values = { "Một", "Hai", "Ba" }, Value = "Một", MenuWidth = 300, Callback = Report("MenuWidth") })
DropdownTab:Dropdown({
	Title = "Dropdown Multi",
	Desc = "Chọn nhiều",
	Values = { "Red", "Green", "Blue", "Yellow", "Purple", "Orange" },
	Value = { "Red", "Blue" },
	Multi = true,
	AllowNone = true,
	SearchBarEnabled = true,
	MenuWidth = 220,
	Flag = "demo_dropdown_multi",
	Callback = Report("Multi"),
})
DropdownTab:Dropdown({ Title = "Dropdown bị khoá", Values = { "A", "B" }, Value = "A", Locked = true, LockedTitle = "Khoá", Callback = Report("never") })

DropdownTab:Divider()

DropdownTab:Dropdown({
	Title = "Item có Desc + Icon + Locked",
	Values = {
		{ Title = "Sword", Desc = "Sát thương cao", Icon = "sword" },
		{ Title = "Shield", Desc = "Phòng thủ", Icon = "shield" },
		{ Title = "Legendary", Desc = "Đã khoá", Icon = "crown", Locked = true },
	},
	Value = "Sword",
	Callback = function(item)
		Notify("Item", type(item) == "table" and item.Title or tostring(item), "package")
	end,
})
DropdownTab:Dropdown({
	Title = "Item có Image",
	Values = {
		{ Title = "Avatar 1", Image = IMAGE_ID, ImageSize = 24 },
		{ Title = "Avatar 2", Image = IMAGE_ID, ImageSize = 24 },
	},
	Callback = function(item)
		Notify("Image item", type(item) == "table" and item.Title or tostring(item), "user")
	end,
})
DropdownTab:Dropdown({
	Title = "SpecialType = Player",
	Desc = "Tự cập nhật theo người chơi",
	SpecialType = "Player",
	ExcludeLocalPlayer = true,
	SearchBarEnabled = true,
	Callback = Report("Player"),
})
DropdownTab:Dropdown({ Title = "Player gồm cả bản thân", SpecialType = "Player", Callback = Report("Player all") })
DropdownTab:Dropdown({ Title = "SpecialType = Team", SpecialType = "Team", Callback = Report("Team") })
DropdownTab:Dropdown({
	Title = "Menu Dropdown",
	Desc = "Không Callback = menu hành động",
	Values = {
		{ Title = "Rejoin", Icon = "refresh-cw", Callback = function() Notify("Menu", "Rejoin", "refresh-cw") end },
		{ Title = "Copy JobId", Icon = "copy", Callback = function() Notify("Menu", game.JobId ~= "" and game.JobId or "Studio", "copy") end },
		{ Title = "Đã khoá", Icon = "lock", Locked = true },
	},
})

DropdownTab:Button({
	Title = "Dropdown:Refresh (đổi danh sách)",
	Icon = "refresh-cw",
	Callback = function()
		mainDropdown:Refresh({ "One", "Two", "Three" })
		mainDropdown:Select("Two")
	end,
})
DropdownTab:Button({ Title = "Dropdown:GetSelected", Callback = function() Report("GetSelected")(mainDropdown:GetSelected()) end })

DropdownTab:Divider()

local mainSegmented = DropdownTab:Segmented({
	Title = "Segmented",
	Desc = "Chọn 1",
	Options = {
		{ Title = "Easy", Value = 1, Icon = "smile" },
		{ Title = "Normal", Value = 2 },
		{ Title = "Hard", Value = 3, Icon = "skull" },
		{ Title = "Locked", Value = 4, Disabled = true },
	},
	Value = 2,
	AllowNone = false,
	Flag = "demo_segmented",
	Callback = Report("Segmented"),
})
DropdownTab:Segmented({ Title = "Segmented AllowNone", Options = { "Left", "Center", "Right" }, AllowNone = true, Callback = Report("Segmented none") })
DropdownTab:Segmented({
	Title = "Segmented Multi",
	Desc = "Min 1, Max 2",
	Options = { "A", "B", "C", "D" },
	Multi = true,
	Value = { "A" },
	MinSelections = 1,
	MaxSelections = 2,
	Callback = Report("Segmented Multi"),
})
DropdownTab:Segmented({ Title = "Segmented bị khoá", Options = { "A", "B" }, Value = "A", Locked = true, Callback = Report("never") })
DropdownTab:Button({ Title = "Segmented:Select(3)", Callback = function() mainSegmented:Select(3) end })

local mainProgress = DisplayTab:Progress({
	Title = "Progress",
	Desc = "Value = {Min, Max, Default}",
	Value = { Min = 0, Max = 100, Default = 40 },
	Suffix = "%",
	Color = "Green",
})
DisplayTab:Progress({ Title = "Progress đỏ", Value = { Min = 0, Max = 100, Default = 85 }, Suffix = "%", Color = "Red" })
DisplayTab:Progress({ Title = "Progress hex", Value = { Min = 0, Max = 100, Default = 60 }, Color = "#ab47bc" })
DisplayTab:Progress({ Title = "Progress Prefix/Suffix", Value = { Min = 0, Max = 200, Default = 120 }, Prefix = "HP ", Suffix = " / 200", ValueWidth = 140 })
DisplayTab:Progress({ Title = "Progress thập phân", Value = { Min = 0, Max = 1, Default = 0.37 }, Precision = 2 })
DisplayTab:Progress({
	Title = "Progress Format",
	Value = { Min = 0, Max = 100, Default = 75 },
	Format = function(value, min, max) return ("%d/%d"):format(value, max) end,
})
DisplayTab:Progress({ Title = "Progress ẩn số", Value = { Min = 0, Max = 100, Default = 50 }, ShowValue = false })

local mainProgressBar = DisplayTab:ProgressBar({
	Title = "ProgressBar",
	Value = { Min = 0, Max = 100, Default = 65 },
	DisplayMode = "Percent",
	Width = 160,
})
DisplayTab:ProgressBar({ Title = "ProgressBar hiện Value", Value = { Min = 0, Max = 50, Default = 20 }, DisplayMode = "Value" })
DisplayTab:ProgressBar({
	Title = "ProgressBar Format",
	Value = { Min = 0, Max = 100, Default = 30 },
	Format = function(value, percent) return ("%d (%d%%)"):format(value, percent) end,
})
DisplayTab:ProgressBar({ Title = "ProgressBar không Animate", Value = { Min = 0, Max = 100, Default = 90 }, Animate = false })
DisplayTab:ProgressBar({ Title = "ProgressBar vô hạn", Indeterminate = true, IndeterminateText = "Loading...", Speed = 1 })
DisplayTab:ProgressBar({ Title = "ProgressBar vô hạn nhanh", Indeterminate = true, Speed = 3, Width = 220 })

DisplayTab:Button({
	Title = "Tăng 10% cho Progress và ProgressBar",
	Icon = "plus",
	Callback = function()
		mainProgress:Add(10)
		mainProgressBar:Set(math.min(mainProgressBar:Get() + 10, 100))
	end,
})

DisplayTab:Divider()

local mainStats = DisplayTab:Stats({
	Title = "Stats",
	Items = {
		{ Key = "FPS", Value = "60" },
		{ Key = "Ping", Value = "32ms", Color = "Green" },
		{ Key = "Players", Value = tostring(#Players:GetPlayers()) },
	},
})
DisplayTab:Stats({
	Title = "Stats dạng key = value",
	Items = { Money = "$1,200", Level = "15", Rank = "Gold" },
	RowHeight = 26,
	ValueWidth = 160,
})
DisplayTab:Button({
	Title = "Cập nhật Stats",
	Callback = function()
		mainStats:Update("FPS", tostring(math.floor(1 / RunService.RenderStepped:Wait())))
		mainStats:Update("Players", tostring(#Players:GetPlayers()))
	end,
})

DisplayTab:Divider()

DisplayTab:Notice({
	Title = "Notice mặc định",
	Content = "Khối thông báo có nút hành động.",
	Icon = "info",
	Buttons = MakeButtons({ "OK", "check", "Primary" }, { "Bỏ qua", "x", "Secondary" }),
})
for _, def in ipairs({
	{ "Notice đỏ", "Lỗi nghiêm trọng.", "octagon-alert", "Red" },
	{ "Notice cam", "Cảnh báo.", "triangle-alert", "Orange", { AccentWidth = 10 } },
	{ "Notice xanh lá", "Thành công.", "circle-check", "Green", { Radius = 20, Padding = 20 } },
	{ "Notice màu hex", "Màu tuỳ chỉnh.", "palette", "#ab47bc" },
}) do
	local config = { Title = def[1], Content = def[2], Icon = def[3], Color = def[4] }
	for k, v in pairs(def[5] or {}) do config[k] = v end
	DisplayTab:Notice(config)
end

DisplayTab:Divider()

DisplayTab:Tags({ Items = { "Lua", "Roblox", "UI" } })
DisplayTab:Tags({
	Items = {
		{ Title = "Hot", Icon = "flame", Color = Color3.fromHex("#e53935") },
		{ Title = "New", Icon = "sparkles", Color = Color3.fromHex("#43a047") },
		{ Title = "Border", Border = true },
		{
			Title = "Gradient",
			Color = WindUI:Gradient({
				["0"] = { Color = "#00c6ff", Transparency = 0 },
				["100"] = { Color = "#0072ff", Transparency = 0 },
			}),
		},
	},
	Gap = 10,
	Height = 30,
})
DisplayTab:Tags({ Items = { "Vuông 1", "Vuông 2" }, Radius = 4, Border = true })

DisplayTab:Divider()

local mainCode = DisplayTab:Code({
	Title = "Code",
	Code = 'print("Hello WindUI Plus")\nfor i = 1, 3 do\n\twarn(i)\nend',
	OnCopy = function() Notify("Code", "Đã copy!", "copy") end,
})
DisplayTab:Code({
	Title = "Code cỡ chữ lớn, cao 120",
	Code = 'local speed = 16\nlocal jump = 50\nprint(speed + jump)',
	CodeSize = 18,
	Height = 120,
})
DisplayTab:Code({
	Title = "Code theme tuỳ chỉnh",
	Code = 'local name = "WindUI"\n-- comment\nprint(name, 123, true)',
	CodeTheme = {
		str = "#ffd54f",
		numbers = "#ff8a65",
		boolean = "#ff8a65",
		comment = "#78909c",
		lua = "#ba68c8",
		call = "#4fc3f7",
	},
})
DisplayTab:Code({ Title = "Code không copy được", Code = 'print("read only")', CanCopied = false })
DisplayTab:Button({ Title = "Code:SetCode", Callback = function() mainCode:SetCode('print("Đã đổi code")') end })

-- Media: Image/Video dùng id mẫu trong IMAGE_ID và VIDEO_ID
for _, config in ipairs({
	{ AspectRatio = "16:9", Radius = 12 },
	{ AspectRatio = "1:1", Radius = 24 },
	{ AspectRatio = "4:3", Radius = 0 },
}) do
	config.Image = IMAGE_ID
	MediaTab:Image(config)
end

MediaTab:Divider()

MediaTab:Video({ Title = "Video", Desc = "Loop, tắt tiếng", Video = VIDEO_ID, Height = 200, Looped = true, Playing = false, Volume = 0 })
MediaTab:Video({ Title = "Video có tiếng, cao 140", Video = VIDEO_ID, Height = 140, Playing = false, Volume = 0.5, Radius = 20, Padding = 10 })

MediaTab:Divider()

local ballPart = MakePart({
	Shape = Enum.PartType.Ball,
	Size = Vector3.new(4, 4, 4),
	Color = Color3.fromRGB(0, 145, 255),
	Material = Enum.Material.Neon,
	CFrame = CFrame.new(0, 0, 0),
})
local boxPart = MakePart({
	Size = Vector3.new(3, 3, 3),
	Color = Color3.fromRGB(255, 112, 67),
	Material = Enum.Material.SmoothPlastic,
})

local ballViewport = AddViewport(MediaTab, ballPart, MakeCamera(Vector3.new(0, 2, 9), Vector3.zero), true, 220)
local boxViewport = AddViewport(MediaTab, boxPart, MakeCamera(Vector3.new(6, 4, 6), Vector3.zero), false, 160)

local characterViewport
if playerCharacter:FindFirstChild("HumanoidRootPart") then
	playerCharacter.Archivable = true
	local characterClone = playerCharacter:Clone()
	local center = characterClone:GetPivot().Position
	characterViewport = AddViewport(MediaTab, characterClone, MakeCamera(center + Vector3.new(0, 1, 7), center), true, 260)
end

for _, def in ipairs({
	{ "Viewport:SetHeight(300)", function() ballViewport:SetHeight(300) end },
	{ "Viewport:SetInteractive(false)", function() ballViewport:SetInteractive(false) end },
	{ "Viewport:SetInteractive(true)", function() ballViewport:SetInteractive(true) end },
	{ "Viewport:Focus()", function() ballViewport:Focus() end },
	{ "Viewport:SetObject (đổi sang hình cầu)", function() boxViewport:SetObject(ballPart:Clone()) end },
}) do
	MediaTab:Button({ Title = def[1], Callback = def[2] })
end

local groupRow = LayoutTab:Group({})
groupRow:Button({ Title = "Left", Callback = Report("Left") })
groupRow:Divider()
groupRow:Button({ Title = "Right", Callback = Report("Right") })

local groupTriple = LayoutTab:Group({})
groupTriple:Toggle({ Title = "Toggle", Callback = Report("Group Toggle") })
groupTriple:Space()
groupTriple:Button({ Title = "Button", Callback = Report("Group Button") })

local hStack = LayoutTab:HStack({ AutoSpace = true })
for _, name in ipairs({ "H1", "H2", "H3" }) do
	hStack:Button({ Title = name, Justify = "Center", Callback = Report(name) })
end

local vStack = LayoutTab:VStack({})
vStack:Button({ Title = "V1", Callback = Report("V1") })
vStack:Toggle({ Title = "V2 toggle", Callback = Report("V2") })
vStack:Slider({ Title = "V3 slider", Value = { Min = 0, Max = 10, Default = 5 }, Callback = Report("V3") })

local closedSection = LayoutTab:Section({
	Title = "Section đóng sẵn",
	Desc = "Click để mở",
	Icon = "folder",
	IconThemed = true,
	Opened = false,
	Box = true,
	BoxBorder = true,
})
closedSection:Toggle({ Title = "Toggle trong Section", Callback = Report("Section Toggle") })
closedSection:Slider({ Title = "Slider trong Section", Value = { Min = 0, Max = 10, Default = 3 }, Callback = Report("Section Slider") })

local openedSection = LayoutTab:Section({ Title = "Section mở sẵn, không Box", Opened = true })
openedSection:Button({ Title = "Button trong Section", Callback = Report("Section Button") })

local styledSection = LayoutTab:Section({
	Title = "Section tuỳ chỉnh chữ",
	Desc = "Căn giữa, chữ lớn",
	Icon = "type",
	Opened = true,
	Box = true,
	TextXAlignment = "Center",
	TextSize = 22,
	DescTextSize = 14,
	FontWeight = Enum.FontWeight.Bold,
	DescFontWeight = Enum.FontWeight.Regular,
	TextTransparency = 0,
	DescTextTransparency = 0.6,
	HeaderSize = 56,
	IconSize = 24,
	Hover = false,
})
styledSection:Label({ Title = "Label trong Section", Icon = "tag" })

for _, def in ipairs({
	{ "Section:Open()", "Open" },
	{ "Section:Close()", "Close" },
	{ "Section:SetTitle", "SetTitle", "Tiêu đề mới" },
	{ "Section:SetDesc", "SetDesc", "Mô tả mới" },
}) do
	LayoutTab:Button({ Title = def[1], Callback = function() closedSection[def[2]](closedSection, def[3]) end })
end

local multiSection = LayoutTab:MultiSection({ Title = "MultiSection", Desc = "Tab con", Icon = "layers", Opened = true, Box = true })
local subTabOne = multiSection:Tab({ Title = "Sub 1", Icon = "house", Selected = true })
local subTabTwo = multiSection:Tab({ Title = "Sub 2", Icon = "star", Desc = "Có Desc" })
local subTabThree = multiSection:Tab({ Title = "Sub 3" })
subTabOne:Toggle({ Title = "Toggle ở Sub 1", Callback = Report("Sub1") })
subTabTwo:Button({ Title = "Button ở Sub 2", Callback = Report("Sub2") })
subTabThree:Input({ Title = "Input ở Sub 3", Callback = Report("Sub3") })
LayoutTab:Button({ Title = "MultiSection:SelectTab(Sub 2)", Callback = function() multiSection:SelectTab(subTabTwo) end })

LayoutTab:Space({ Columns = 1 })
LayoutTab:Space({ Columns = 3 })
LayoutTab:Divider()
LayoutTab:Divider({ Thickness = 3, Padding = 10, Transparency = 0.5, Color = "Grey" })
LayoutTab:Divider({ Thickness = 2, Color = "Red", Transparency = 0.2 })
LayoutTab:Divider({ Thickness = 1, Color = Color3.fromHex("#00e5ff") })

DialogTab:Button({
	Title = "Notify cơ bản",
	Icon = "bell",
	Callback = function()
		WindUI:Notify({ Title = "Xin chào", Content = "Thông báo mặc định", Icon = "bell", Duration = 4 })
	end,
})
DialogTab:Button({
	Title = "Notify không icon, không nội dung",
	Callback = function()
		WindUI:Notify({ Title = "Chỉ có tiêu đề", Duration = 3 })
	end,
})
DialogTab:Button({
	Title = "Notify có nút",
	Icon = "bell-ring",
	Callback = function()
		WindUI:Notify({
			Title = "Có nút",
			Content = "Notify với Buttons",
			Icon = "mouse-pointer",
			Duration = 8,
			CanClose = true,
			Buttons = MakeButtons({ "Đồng ý", "check", "Primary" }, { "Huỷ", "x", "Secondary" }),
		})
	end,
})
DialogTab:Button({
	Title = "Notify nền ảnh, tự đóng bằng :Close()",
	Icon = "image",
	Callback = function()
		local imageNotify = WindUI:Notify({
			Title = "Nền ảnh",
			Content = "Đóng sau 2 giây",
			Icon = "image",
			Background = IMAGE_ID,
			BackgroundImageTransparency = 0.7,
			Duration = 10,
			CanClose = false,
		})
		task.delay(2, function()
			if imageNotify and imageNotify.Close then imageNotify:Close() end
		end)
	end,
})
DialogTab:Button({
	Title = "Notify IconThemed, 10 giây",
	Callback = function()
		WindUI:Notify({ Title = "IconThemed", Content = "Icon theo theme", Icon = "sparkles", IconThemed = true, Duration = 10 })
	end,
})

DialogTab:Divider()

DialogTab:Button({
	Title = "Dialog hai nút",
	Icon = "message-square",
	Callback = function()
		Window:Dialog({
			Title = "Xác nhận",
			Content = "Bạn có chắc không?",
			Icon = "circle-help",
			IconThemed = true,
			Width = 320,
			Buttons = MakeButtons({ "Huỷ", nil, "Secondary" }, { "Đồng ý", "check", "Primary" }),
		})
	end,
})
DialogTab:Button({
	Title = "Dialog ba nút, rộng 400",
	Callback = function()
		Window:Dialog({
			Title = "Lưu thay đổi?",
			Content = "Có thay đổi chưa lưu trong cấu hình.",
			Width = 400,
			Buttons = MakeButtons({ "Không lưu", "trash-2", "Secondary" }, { "Huỷ", "x", "White" }, { "Lưu", "save", "Primary" }),
		})
	end,
})
DialogTab:Button({
	Title = "Dialog chỉ có tiêu đề",
	Callback = function()
		Window:Dialog({ Title = "Chỉ tiêu đề", Buttons = MakeButtons({ "OK", nil, "Primary" }) })
	end,
})

DialogTab:Divider()

DialogTab:Button({
	Title = "Popup",
	Icon = "app-window",
	Callback = function()
		WindUI:Popup({
			Title = "Popup",
			Content = "Popup toàn màn hình",
			Icon = "sparkles",
			IconThemed = true,
			Buttons = MakeButtons({ "Đóng", "x", "Secondary" }, { "Tiếp tục", "arrow-right", "Primary" }),
		})
	end,
})
DialogTab:Button({
	Title = "Popup có Thumbnail",
	Callback = function()
		WindUI:Popup({
			Title = "Popup ảnh",
			Content = "Có Thumbnail bên cạnh",
			Icon = "image",
			Thumbnail = { Image = IMAGE_ID, Title = "Thumbnail" },
			Buttons = MakeButtons({ "Đóng", "x", "Secondary" }),
		})
	end,
})

DialogTab:Divider()

local watermark = Window.WatermarkObject
DialogTab:Input({
	Title = "Watermark text",
	Placeholder = "Nhập chữ watermark",
	Callback = Guard(function(text)
		if watermark and text ~= "" then watermark:SetText(text) end
	end),
})
DialogTab:Slider({
	Title = "Watermark opacity",
	Value = { Min = 0, Max = 1, Default = 0.35 },
	Step = 0.05,
	Callback = Guard(function(value)
		if watermark then watermark:SetOpacity(value) end
	end),
})
DialogTab:Toggle({
	Title = "Watermark hiện",
	Value = true,
	Callback = Guard(function(value)
		if watermark then watermark:SetEnabled(value) end
	end),
})

local configManager = Window.ConfigManager

if not configManager then
	ConfigTab:Notice({ Title = "Config không khả dụng", Content = "Cần executor có writefile và Window.Folder.", Color = "Red", Icon = "triangle-alert" })
else
	local configName = "default"
	local currentConfig = configManager:CreateConfig(configName)

	ConfigTab:Input({
		Title = "Tên config",
		Placeholder = "default",
		Callback = Guard(function(text)
			if text ~= "" then configName = text end
		end),
	})

	local configDropdown = ConfigTab:Dropdown({
		Title = "Danh sách config",
		Values = ConfigList(),
		Callback = function(name)
			if name then configName = name end
		end,
	})

	-- Gộp logic Save/Load: cùng tạo config theo tên rồi gọi method
	function ConfigAction(method, message, icon)
		return function()
			currentConfig = configManager:CreateConfig(configName)
			local ok, result = currentConfig[method](currentConfig)
			Notify("Config", ok ~= false and (message .. configName) or tostring(result), icon)
			configDropdown:Refresh(ConfigList())
		end
	end

	ConfigTab:Button({ Title = "Save", Icon = "save", Callback = ConfigAction("Save", "Đã lưu: ", "save") })
	ConfigTab:Button({ Title = "Load", Icon = "folder-open", Callback = ConfigAction("Load", "Đã tải: ", "folder-open") })
	ConfigTab:Button({
		Title = "Delete",
		Icon = "trash-2",
		Color = "Red",
		Callback = function()
			local ok, message = configManager:DeleteConfig(configName)
			Notify("Config", message, ok and "trash-2" or "x")
			configDropdown:Refresh(ConfigList())
		end,
	})
	ConfigTab:Button({
		Title = "Refresh list",
		Icon = "refresh-cw",
		Callback = function() configDropdown:Refresh(ConfigList()) end,
	})

	ConfigTab:Toggle({
		Title = "Tự load config này khi mở script",
		Value = false,
		Callback = Guard(function(value)
			currentConfig = configManager:CreateConfig(configName)
			currentConfig:SetAutoLoad(value)
			currentConfig:Save()
		end),
	})

	ConfigTab:Button({
		Title = "Config:Set / Get dữ liệu custom",
		Callback = function()
			currentConfig:Set("lastOpened", os.time())
			Notify("Custom", tostring(currentConfig:Get("lastOpened")), "database")
		end,
	})
	ConfigTab:Button({
		Title = "Liệt kê tất cả Flag",
		Callback = function()
			Notify("Flags", table.concat(Window:ListFlags(), ", "), "flag", 6)
		end,
	})
	ConfigTab:Button({
		Title = "GetFlag demo_slider",
		Callback = function()
			Notify("GetFlag", tostring(Window:GetFlag("demo_slider")), "flag")
		end,
	})
	ConfigTab:Button({ Title = "SetFlag demo_slider = 80", Callback = function() Window:SetFlag("demo_slider", 80) end })
	ConfigTab:Button({
		Title = "SetFlags nhiều giá trị",
		Callback = function()
			Window:SetFlags({ demo_toggle = false, demo_dropdown = "Cherry", demo_input = "xin chào" })
		end,
	})
end

local themeNames = {}
for name in pairs(WindUI:GetThemes()) do themeNames[#themeNames + 1] = name end
table.sort(themeNames)

SettingsTab:Dropdown({
	Title = "Theme",
	Desc = "Gồm cả theme Neon và Sunset tự tạo",
	Values = themeNames,
	Value = WindUI:GetCurrentTheme(),
	SearchBarEnabled = true,
	Callback = function(name) WindUI:SetTheme(name) end,
})

SettingsTab:Toggle({ Title = "Transparent", Value = Window.Transparent, Callback = function(value) Window:ToggleTransparency(value) end })
SettingsTab:Toggle({ Title = "Acrylic", Value = false, Callback = function(value) WindUI:ToggleAcrylic(value) end })
SettingsTab:Toggle({ Title = "Panel background", Value = true, Callback = function(value) Window:SetPanelBackground(value) end })
SettingsTab:Toggle({ Title = "Thanh kéo dưới", Value = true, Callback = function(value) Window:SetBottomDragBarEnabled(value) end })
SettingsTab:Toggle({ Title = "Cho phép resize", Value = true, Callback = function(value) Window:IsResizable(value) end })

SettingsTab:Slider({
	Title = "UI Scale",
	Value = { Min = 0.5, Max = 1.5, Default = 1 },
	Step = 0.05,
	Callback = Guard(function(value) Window:SetUIScale(value) end),
})
SettingsTab:Slider({
	Title = "Window Width",
	Value = { Min = 560, Max = 850, Default = 620 },
	Step = 10,
	Callback = Guard(function(value) Window:SetSize(UDim2.fromOffset(value, Window.Size.Y.Offset)) end),
})

SettingsTab:Input({
	Title = "Phím ẩn/hiện UI",
	Desc = "Gõ tên KeyCode, ví dụ: RightShift, F4, Insert",
	Placeholder = "RightShift",
	Callback = Guard(function(text)
		local key = Enum.KeyCode[text]
		if key then
			Window:SetToggleKey(key)
			Notify("ToggleKey", text, "keyboard")
		else
			Notify("ToggleKey", "KeyCode không hợp lệ", "x")
		end
	end),
})
SettingsTab:Input({
	Title = "Window Title",
	Placeholder = "Tiêu đề mới...",
	Callback = Guard(function(text)
		if text ~= "" then Window:SetTitle(text) end
	end),
})
SettingsTab:Input({
	Title = "Window Author",
	Placeholder = "Tác giả mới...",
	Callback = Guard(function(text)
		if text ~= "" then Window:SetAuthor(text) end
	end),
})

SettingsTab:Dropdown({
	Title = "Language",
	Values = { "en", "vi" },
	Value = "en",
	Callback = Guard(function(language) WindUI:SetLanguage(language) end),
})

SettingsTab:Dropdown({
	Title = "User panel",
	Values = { "Hiện tên thật", "Ẩn danh", "Tắt" },
	Value = "Hiện tên thật",
	Callback = Guard(function(choice)
		if choice == "Tắt" then
			Window.User:Disable()
		else
			Window.User:Enable()
			Window.User:SetAnonymous(choice == "Ẩn danh")
		end
	end),
})

SettingsTab:Divider()

SettingsTab:Button({
	Title = "Sửa nút OpenButton",
	Icon = "square-pen",
	Callback = function()
		Window:EditOpenButton({
			Title = "Mở menu",
			Icon = "layout-dashboard",
			OnlyIcon = false,
			Draggable = true,
			CornerRadius = UDim.new(0, 14),
			StrokeThickness = 3,
			Scale = 1.1,
			Color = ColorSequence.new(Color3.fromHex("#ff9800"), Color3.fromHex("#f44336")),
		})
	end,
})
for _, def in ipairs({
	{ "Đưa window về giữa", "crosshair", "SetToTheCenter" },
	{ "Fullscreen", "maximize", "ToggleFullscreen" },
	{ "Khoá tất cả element", "lock", "LockAll" },
	{ "Mở khoá tất cả", "unlock", "UnlockAll" },
}) do
	SettingsTab:Button({ Title = def[1], Icon = def[2], Callback = function() Window[def[3]](Window) end })
end
SettingsTab:Button({ Title = "Chọn tab Buttons", Icon = "mouse-pointer-click", Callback = function() ButtonTab:Select() end })
SettingsTab:Button({
	Title = "Bỏ phím tắt Ctrl+K",
	Icon = "keyboard-off",
	Callback = function()
		Window:UnbindShortcut(shortcutId)
		Notify("Shortcut", "Đã bỏ Ctrl+K", "keyboard-off")
	end,
})
SettingsTab:Button({
	Title = "Liệt kê phím tắt",
	Icon = "list",
	Callback = function()
		local names = {}
		for _, shortcut in ipairs(Window:GetShortcuts()) do
			names[#names + 1] = shortcut.KeyCode.Name .. " (" .. tostring(shortcut.Description) .. ")"
		end
		Notify("Shortcuts", table.concat(names, ", "), "keyboard", 5)
	end,
})
SettingsTab:Button({
	Title = "Huỷ UI (Destroy)",
	Icon = "power",
	Color = "Red",
	Justify = "Center",
	Callback = function() Window:Destroy() end,
})

ButtonTab:Select()
ready = true
Notify("WindUI Plus", "Đã tải example thành công!", "circle-check", 4)
