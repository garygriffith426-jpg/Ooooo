-- Mini Admin | The Silent Hour v3 (rebuilt from scratch)
-- Mobile + PC. Tabs: Player, Movement, World, Settings

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local lp = Players.LocalPlayer
local CONFIG_FILE = "MiniAdmin_SilentHour.json"

-- settings -------------------------------------------------------------
local S = {
	Speed = false, SpeedVal = 32,
	Jump = false, JumpVal = 90,
	InfJump = false,
	Fly = false, FlySpeed = 60,
	Noclip = false,
	Fullbright = false,
	CollectESP = false,
}

-- connection helper ----------------------------------------------------
local conns = {}
local function bind(signal, fn)
	local c = signal:Connect(fn)
	conns[#conns + 1] = c
	return c
end

local offs = {} -- feature shutdown functions, used by cleanup

-- character helpers ----------------------------------------------------
local function getHum()
	local ch = lp.Character
	return ch and ch:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
	local ch = lp.Character
	return ch and ch:FindFirstChild("HumanoidRootPart")
end

-- config ---------------------------------------------------------------
local function saveConfig()
	pcall(function()
		writefile(CONFIG_FILE, HttpService:JSONEncode(S))
	end)
end

local function loadConfig()
	pcall(function()
		if isfile and isfile(CONFIG_FILE) then
			local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
			for k, v in pairs(data) do
				if S[k] ~= nil and type(S[k]) == type(v) then
					S[k] = v
				end
			end
		end
	end)
end

loadConfig()

-- features (state kept in a table to stay under the local limit) ------
local F = { orig = {}, bv = nil, lightOrig = nil }

-- Speed / Jump
local function applySpeedJump()
	local hum = getHum()
	if not hum then return end
	if S.Speed then
		if not F.orig.speed then F.orig.speed = hum.WalkSpeed end
		hum.WalkSpeed = S.SpeedVal
	elseif F.orig.speed then
		hum.WalkSpeed = F.orig.speed
		F.orig.speed = nil
	end
	if S.Jump then
		if not F.orig.jump then
			F.orig.jump = { hum.UseJumpPower, hum.JumpPower }
		end
		hum.UseJumpPower = true
		hum.JumpPower = S.JumpVal
	elseif F.orig.jump then
		hum.UseJumpPower = F.orig.jump[1]
		hum.JumpPower = F.orig.jump[2]
		F.orig.jump = nil
	end
end
offs[#offs + 1] = function()
	S.Speed = false
	S.Jump = false
	applySpeedJump()
end

-- Infinite jump
bind(UserInputService.JumpRequest, function()
	if S.InfJump then
		local hum = getHum()
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)
offs[#offs + 1] = function() S.InfJump = false end

-- Fly
local function stopFly()
	if F.bv then
		F.bv:Destroy()
		F.bv = nil
	end
	local hum = getHum()
	if hum then hum.PlatformStand = false end
end

bind(RunService.Heartbeat, function()
	local root, hum = getRoot(), getHum()
	if not (root and hum) then return end
	if S.Fly then
		if not F.bv or F.bv.Parent ~= root then
			if F.bv then F.bv:Destroy() end
			F.bv = Instance.new("BodyVelocity")
			F.bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
			F.bv.Velocity = Vector3.zero
			F.bv.Parent = root
		end
		hum.PlatformStand = true
		local cam = workspace.CurrentCamera
		local dir = hum.MoveDirection
		local vel = Vector3.zero
		if dir.Magnitude > 0 and cam then
			local look = cam.CFrame.LookVector
			local fwd = Vector3.new(look.X, 0, look.Z)
			if fwd.Magnitude > 0 then
				local forwardAmt = dir:Dot(fwd.Unit)
				vel = dir * S.FlySpeed + Vector3.new(0, look.Y * forwardAmt * S.FlySpeed, 0)
			end
		end
		F.bv.Velocity = vel
	elseif F.bv then
		stopFly()
	end
end)
offs[#offs + 1] = function()
	S.Fly = false
	stopFly()
end

-- Noclip
bind(RunService.Stepped, function()
	if S.Noclip and lp.Character then
		for _, p in ipairs(lp.Character:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
	end
end)
offs[#offs + 1] = function() S.Noclip = false end

-- Fullbright
local function applyFullbright()
	if S.Fullbright then
		if not F.lightOrig then
			F.lightOrig = {
				Brightness = Lighting.Brightness,
				ClockTime = Lighting.ClockTime,
				GlobalShadows = Lighting.GlobalShadows,
				Ambient = Lighting.Ambient,
			}
		end
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(178, 178, 178)
	elseif F.lightOrig then
		for k, v in pairs(F.lightOrig) do Lighting[k] = v end
		F.lightOrig = nil
	end
end
offs[#offs + 1] = function()
	S.Fullbright = false
	applyFullbright()
end

-- respawn handling
bind(lp.CharacterAdded, function()
	F.orig = {}
	F.bv = nil
	task.wait(0.5)
	applySpeedJump()
end)

-- keep speed/jump enforced if the game resets them
bind(RunService.Heartbeat, function()
	local hum = getHum()
	if not hum then return end
	if S.Speed and hum.WalkSpeed ~= S.SpeedVal then hum.WalkSpeed = S.SpeedVal end
	if S.Jump and hum.JumpPower ~= S.JumpVal then hum.JumpPower = S.JumpVal end
end)

-- UI -------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "MiniAdminSilentHour"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local okParent = pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not okParent or not gui.Parent then gui.Parent = lp:WaitForChild("PlayerGui") end

local COL = {
	bg = Color3.fromRGB(16, 14, 22),
	panel = Color3.fromRGB(21, 19, 29),
	row = Color3.fromRGB(27, 25, 36),
	line = Color3.fromRGB(40, 37, 52),
	accent = Color3.fromRGB(150, 100, 250),
	accentDim = Color3.fromRGB(45, 32, 82),
	text = Color3.fromRGB(242, 240, 250),
	muted = Color3.fromRGB(128, 124, 142),
	off = Color3.fromRGB(58, 55, 74),
}

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local function corner(o, r) return mk("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o) end
local function stroke(o, c)
	return mk("UIStroke", { Color = c or COL.line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function vlist(p, pad)
	return mk("UIListLayout", { Padding = UDim.new(0, pad or 0), SortOrder = Enum.SortOrder.LayoutOrder }, p)
end
local function txt(parent, text, size, color, font, align, props)
	local t = mk("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size or 12,
		TextColor3 = color or COL.text, Font = font or Enum.Font.Gotham,
		TextXAlignment = align or Enum.TextXAlignment.Left, RichText = true,
	}, parent)
	if props then for k, v in pairs(props) do t[k] = v end end
	return t
end
local function hex(c)
	return string.format("#%02x%02x%02x", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local AX = Enum.AutomaticSize.Y
local CENTER = Enum.TextXAlignment.Center

-- window
local main = mk("Frame", {
	Size = UDim2.fromOffset(640, 400), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundColor3 = COL.bg,
	BorderSizePixel = 0, Active = true, ClipsDescendants = true,
}, gui)
corner(main, 14)
stroke(main)
local uiScale = mk("UIScale", {}, main)
local function fit()
	local v = gui.AbsoluteSize
	uiScale.Scale = math.clamp(math.min(v.X / 680, v.Y / 440), 0.45, 1)
end
fit()
bind(gui:GetPropertyChangedSignal("AbsoluteSize"), fit)

-- top bar
local top = mk("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Active = true }, main)
mk("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = COL.line, BorderSizePixel = 0 }, top)
local logo = mk("Frame", { Size = UDim2.fromOffset(24, 24), Position = UDim2.new(0, 16, 0.5, -12), BackgroundColor3 = COL.accent, BorderSizePixel = 0 }, top)
corner(logo, 7)
txt(logo, "S", 13, COL.text, Enum.Font.GothamBold, CENTER, { Size = UDim2.fromScale(1, 1) })
txt(top, "SIERRA", 15, COL.text, Enum.Font.GothamBold, nil, { Position = UDim2.fromOffset(50, 0), Size = UDim2.new(0.5, 0, 1, 0) })

local function topBtn(text, xOff)
	local b = mk("TextButton", {
		Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, xOff, 0.5, -15),
		BackgroundColor3 = COL.bg, Text = text, TextColor3 = COL.text,
		Font = Enum.Font.GothamBold, TextSize = 13, AutoButtonColor = true,
	}, top)
	corner(b, 8)
	stroke(b)
	return b
end
local searchBtn = topBtn("?", -112)
local minBtn = topBtn("-", -76)
local closeBtn = topBtn("X", -40)

-- floating open button (mobile friendly)
local openBtn = mk("TextButton", {
	Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 10, 0.5, -22),
	BackgroundColor3 = COL.accent, Text = "SH", TextColor3 = COL.text,
	Font = Enum.Font.GothamBold, TextSize = 14, Visible = false,
}, gui)
corner(openBtn, 22)

local function setMenu(v)
	main.Visible = v
	openBtn.Visible = not v
end
bind(minBtn.MouseButton1Click, function() setMenu(false) end)
bind(openBtn.MouseButton1Click, function() setMenu(true) end)
bind(UserInputService.InputBegan, function(i, gp)
	if not gp and i.KeyCode == Enum.KeyCode.RightShift then setMenu(not main.Visible) end
end)

-- dragging (top bar)
do
	local dragging, dragStart, startPos
	bind(top.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, i.Position, main.Position
		end
	end)
	bind(UserInputService.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = (i.Position - dragStart) / uiScale.Scale
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	bind(UserInputService.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

-- sidebar
local side = mk("Frame", { Size = UDim2.new(0, 130, 1, -44), Position = UDim2.fromOffset(0, 44), BackgroundTransparency = 1 }, main)
mk("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = COL.line, BorderSizePixel = 0 }, side)
local sideList = mk("ScrollingFrame", {
	Size = UDim2.new(1, -1, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = AX,
}, side)
mk("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, sideList)
vlist(sideList, 6)

-- content area
local content = mk("Frame", { Size = UDim2.new(1, -130, 1, -44), Position = UDim2.fromOffset(130, 44), BackgroundTransparency = 1 }, main)
local crumb = txt(content, "", 12, COL.muted, nil, nil, { Position = UDim2.fromOffset(16, 8), Size = UDim2.new(0.7, 0, 0, 20) })
txt(content, "1.0.0", 12, COL.muted, nil, Enum.TextXAlignment.Right, { Position = UDim2.new(1, -86, 0, 8), Size = UDim2.fromOffset(70, 20) })

local pages, navs, crumbs = {}, {}, {}

local function showPage(name)
	for n, pg in pairs(pages) do pg.Visible = (n == name) end
	for n, nv in pairs(navs) do
		local on = (n == name)
		nv.box.BackgroundColor3 = on and COL.accentDim or COL.row
		nv.st.Color = on and COL.accent or COL.line
		nv.gl.TextColor3 = on and COL.accent or COL.muted
		nv.lb.TextColor3 = on and COL.accent or COL.muted
	end
	local c = crumbs[name]
	if c then
		crumb.Text = string.format('<font color="%s">%s</font>  →  <font color="%s">%s</font>', hex(COL.muted), c[1], hex(COL.accent), c[2])
	end
end

local function addGroup(name, glyph, collapsed)
	local g = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AX, BackgroundTransparency = 1 }, sideList)
	vlist(g, 4)
	local head = mk("TextButton", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, g)
	local box = mk("Frame", { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(0, 0, 0.5, -13), BackgroundColor3 = COL.row }, head)
	corner(box, 8)
	stroke(box)
	txt(box, glyph, 12, COL.muted, Enum.Font.GothamBold, CENTER, { Size = UDim2.fromScale(1, 1) })
	txt(head, name, 13, COL.muted, Enum.Font.GothamMedium, nil, { Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -56, 1, 0) })
	local chev = txt(head, "^", 11, COL.muted, Enum.Font.GothamBold, Enum.TextXAlignment.Right, { Position = UDim2.new(1, -16, 0, 0), Size = UDim2.fromOffset(16, 34) })
	local items = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AX, BackgroundTransparency = 1 }, g)
	vlist(items, 4)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 22) }, items)
	local open = not collapsed
	items.Visible = open
	chev.Text = open and "^" or "v"
	bind(head.MouseButton1Click, function()
		open = not open
		items.Visible = open
		chev.Text = open and "^" or "v"
	end)
	return items
end

local function addPage(group, name)
	local pg = mk("ScrollingFrame", {
		Size = UDim2.new(1, -28, 1, -42), Position = UDim2.fromOffset(14, 34),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = AX, Visible = false,
	}, content)
	vlist(pg, 10)
	pages[name] = pg
	crumbs[name] = { group, name }
	return pg
end

local function addNav(items, name, glyph)
	local b = mk("TextButton", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, items)
	local box = mk("Frame", { Size = UDim2.fromOffset(24, 24), Position = UDim2.new(0, 0, 0.5, -12), BackgroundColor3 = COL.row }, b)
	corner(box, 7)
	local st = stroke(box)
	local gl = txt(box, glyph, 11, COL.muted, Enum.Font.GothamBold, CENTER, { Size = UDim2.fromScale(1, 1) })
	local lb = txt(b, name, 12, COL.muted, Enum.Font.GothamMedium, nil, { Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -32, 1, 0) })
	navs[name] = { box = box, st = st, gl = gl, lb = lb }
	bind(b.MouseButton1Click, function() showPage(name) end)
end

-- cleanup --------------------------------------------------------------
local function cleanup()
	for _, off in ipairs(offs) do pcall(off) end
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	conns = {}
	if gui then gui:Destroy() end
end

-- control rows (same helper names as before) ---------------------------
local function newRow(page, h)
	local r = mk("Frame", { Size = UDim2.new(1, 0, 0, h or 40), BackgroundColor3 = COL.panel, BorderSizePixel = 0 }, page)
	corner(r, 10)
	stroke(r)
	return r
end

local function addToggle(page, text, key, onChange)
	local row = newRow(page)
	txt(row, text, 13, COL.text, nil, nil, { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.7, 0, 1, 0) })
	local track = mk("TextButton", {
		Size = UDim2.fromOffset(36, 20), Position = UDim2.new(1, -50, 0.5, -10),
		Text = "", AutoButtonColor = false,
	}, row)
	corner(track, 10)
	local knob = mk("Frame", { Size = UDim2.fromOffset(14, 14), BackgroundColor3 = COL.text, BorderSizePixel = 0 }, track)
	corner(knob, 7)
	local function refresh()
		track.BackgroundColor3 = S[key] and COL.accent or COL.off
		knob.Position = S[key] and UDim2.fromOffset(19, 3) or UDim2.fromOffset(3, 3)
	end
	refresh()
	bind(track.MouseButton1Click, function()
		S[key] = not S[key]
		refresh()
		if onChange then onChange(S[key]) end
		saveConfig()
	end)
	if onChange and S[key] then task.defer(onChange, S[key]) end
	return refresh
end

local function addSlider(page, text, key, min, max, onChange)
	local row = newRow(page, 54)
	txt(row, text, 13, COL.text, nil, nil, { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(0.6, 0, 0, 20) })
	local val = txt(row, tostring(S[key]), 13, COL.accent, Enum.Font.GothamBold, Enum.TextXAlignment.Right, { Position = UDim2.new(1, -74, 0, 6), Size = UDim2.fromOffset(60, 20) })
	local bar = mk("Frame", { Size = UDim2.new(1, -28, 0, 6), Position = UDim2.new(0, 14, 0, 36), BackgroundColor3 = COL.off, BorderSizePixel = 0 }, row)
	corner(bar, 3)
	local fill = mk("Frame", { BackgroundColor3 = COL.accent, BorderSizePixel = 0, Size = UDim2.new((S[key] - min) / (max - min), 0, 1, 0) }, bar)
	corner(fill, 3)
	local function setVal(v)
		v = math.clamp(math.floor(v + 0.5), min, max)
		S[key] = v
		fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
		val.Text = tostring(v)
		if onChange then onChange(v) end
	end
	local sliding = false
	local function fromInput(i)
		local a = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		setVal(min + (max - min) * a)
	end
	bind(row.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			sliding = true
			fromInput(i)
		end
	end)
	bind(UserInputService.InputChanged, function(i)
		if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			fromInput(i)
		end
	end)
	bind(UserInputService.InputEnded, function(i)
		if sliding and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			sliding = false
			saveConfig()
		end
	end)
end

local function addButton(page, text, callback)
	local b = mk("TextButton", {
		Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = COL.accentDim, Text = text,
		TextColor3 = COL.accent, Font = Enum.Font.GothamMedium, TextSize = 13,
	}, page)
	corner(b, 10)
	stroke(b, COL.accent)
	bind(b.MouseButton1Click, callback)
	return b
end

-- player table ---------------------------------------------------------
local thumbs = {}
local tables = {}

local function buildTable(parent, maxRows)
	local card = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AX, BackgroundColor3 = COL.panel, BorderSizePixel = 0 }, parent)
	corner(card, 12)
	stroke(card)
	vlist(card, 0)

	local head = mk("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1 }, card)
	local chipHolder = mk("Frame", { Size = UDim2.new(0.6, 0, 0, 24), Position = UDim2.fromOffset(12, 11), BackgroundTransparency = 1 }, head)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, chipHolder)
	local filter, query = "all", ""

	local function chip(text)
		local c = mk("TextButton", {
			Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = COL.row, Text = text, TextColor3 = COL.muted,
			Font = Enum.Font.Gotham, TextSize = 11, AutoButtonColor = false,
		}, chipHolder)
		mk("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, c)
		corner(c, 7)
		stroke(c)
		return c
	end
	local chipAll = chip("All Players")
	local chipStaff = chip("Staff Members")
	local chipNon = chip("Non Staff")

	local search = mk("TextBox", {
		Size = UDim2.fromOffset(130, 24), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 11),
		BackgroundColor3 = COL.row, Text = "", PlaceholderText = "Search for a player...",
		PlaceholderColor3 = COL.muted, TextColor3 = COL.text, Font = Enum.Font.Gotham,
		TextSize = 11, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
	}, head)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 8) }, search)
	corner(search, 7)
	stroke(search)

	local colHead = mk("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 }, card)
	mk("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = COL.line, BorderSizePixel = 0 }, colHead)
	local cols = { { "Username", 0, 14 }, { "User ID", 0.42, 0 }, { "Account Age", 0.60, 0 }, { "Rank", 0.77, 0 }, { "Actions", 1, -78 } }
	for _, c in ipairs(cols) do
		txt(colHead, c[1], 11, COL.muted, nil, nil, { Position = UDim2.new(c[2], c[3], 0, 0), Size = UDim2.new(0.2, 0, 1, 0) })
	end

	local rows = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AX, BackgroundTransparency = 1 }, card)
	vlist(rows, 0)

	local function addRow(p)
		local r = mk("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 }, rows)
		mk("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = COL.line, BorderSizePixel = 0 }, r)
		local av = mk("ImageLabel", {
			Size = UDim2.fromOffset(28, 28), Position = UDim2.new(0, 14, 0.5, -14),
			BackgroundColor3 = COL.row, Image = thumbs[p.UserId] or "",
		}, r)
		corner(av, 8)
		if not thumbs[p.UserId] then
			task.spawn(function()
				local ok, img = pcall(function()
					return Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
				end)
				if ok and img then
					thumbs[p.UserId] = img
					if av.Parent then av.Image = img end
				end
			end)
		end
		txt(r, p.DisplayName, 12, COL.text, Enum.Font.GothamBold, nil, { Position = UDim2.fromOffset(50, 6), Size = UDim2.new(0.38, -50, 0, 16) })
		txt(r, "@" .. p.Name, 10, COL.muted, nil, nil, { Position = UDim2.fromOffset(50, 22), Size = UDim2.new(0.38, -50, 0, 14) })
		txt(r, tostring(p.UserId), 11, COL.muted, nil, nil, { Position = UDim2.fromScale(0.42, 0), Size = UDim2.new(0.18, 0, 1, 0) })
		txt(r, p.AccountAge .. " days", 11, COL.muted, nil, nil, { Position = UDim2.fromScale(0.60, 0), Size = UDim2.new(0.17, 0, 1, 0) })
		txt(r, p.Team and p.Team.Name or "Guest", 11, COL.muted, nil, nil, { Position = UDim2.fromScale(0.77, 0), Size = UDim2.new(0.12, 0, 1, 0) })
		if p ~= lp then
			local b = mk("TextButton", {
				Size = UDim2.fromOffset(66, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
				BackgroundColor3 = COL.accentDim, Text = "Manage", TextColor3 = COL.accent,
				Font = Enum.Font.Gotham, TextSize = 11,
			}, r)
			corner(b, 6)
			bind(b.MouseButton1Click, function()
				local a = getRoot()
				local tc = p.Character
				local tr = tc and tc:FindFirstChild("HumanoidRootPart")
				if a and tr then a.CFrame = tr.CFrame * CFrame.new(0, 0, 3) end
			end)
		end
	end

	local function refresh()
		for _, c in ipairs(rows:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
		local list = Players:GetPlayers()
		local staffCount = 0
		for _, p in ipairs(list) do
			if lp.Team and p.Team == lp.Team then staffCount += 1 end
		end
		chipAll.Text = "All Players (" .. #list .. ")"
		chipStaff.Text = "Staff Members (" .. staffCount .. ")"
		chipNon.Text = "Non Staff (" .. (#list - staffCount) .. ")"
		for chipObj, key in pairs({ [chipAll] = "all", [chipStaff] = "staff", [chipNon] = "non" }) do
			chipObj.TextColor3 = (filter == key) and COL.accent or COL.muted
			chipObj.BackgroundColor3 = (filter == key) and COL.accentDim or COL.row
		end
		local q = query:lower()
		local shown = 0
		for _, p in ipairs(list) do
			local isStaff = lp.Team ~= nil and p.Team == lp.Team
			local pass = (filter == "all") or (filter == "staff" and isStaff) or (filter == "non" and not isStaff)
			if pass and (q == "" or p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true)) then
				if not maxRows or shown < maxRows then
					shown += 1
					addRow(p)
				end
			end
		end
	end

	bind(chipAll.MouseButton1Click, function() filter = "all"; refresh() end)
	bind(chipStaff.MouseButton1Click, function() filter = "staff"; refresh() end)
	bind(chipNon.MouseButton1Click, function() filter = "non"; refresh() end)
	bind(search:GetPropertyChangedSignal("Text"), function() query = search.Text; refresh() end)
	tables[#tables + 1] = refresh
	refresh()
end

bind(Players.PlayerAdded, function() task.wait(0.2) for _, r in ipairs(tables) do r() end end)
bind(Players.PlayerRemoving, function() task.wait(0.2) for _, r in ipairs(tables) do r() end end)

-- Collectible ESP -------------------------------------------------------
local CE = {
	running = false, count = 0, scanId = 0, acc = 0, tags = {}, conns = {},
	keys = {
		"pumpkin", "candy", "coin", "orb", "gem", "egg", "collect", "pickup", "token",
		"crystal", "halloween", "treasure", "loot", "present", "gift", "fruit", "berry", "mushroom", "shard",
	},
	verbs = { "collect", "pick", "grab", "take", "loot" },
}

local function ceMatch(str, list)
	str = str:lower()
	for _, k in ipairs(list) do
		if str:find(k, 1, true) then return true end
	end
	return false
end

local function ceIsCharacter(inst)
	local m = inst
	while m and m ~= workspace do
		if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then return true end
		m = m.Parent
	end
	return false
end

local function ceTarget(inst)
	if inst:IsA("ProximityPrompt") then
		local par = inst.Parent
		if par and (par:IsA("BasePart") or par:IsA("Model"))
			and (ceMatch(inst.ActionText, CE.verbs) or ceMatch(inst.ObjectText, CE.keys)) then
			return par
		end
		return nil
	end
	if inst:IsA("BasePart") or inst:IsA("Model") then
		if ceMatch(inst.Name, CE.keys) then return inst end
		-- items named by number/id inside a folder like "Halloween2026Pumpkins"
		local par = inst.Parent
		if par and par:IsA("Folder") and ceMatch(par.Name, CE.keys) then return inst end
	end
	return nil
end

local function ceRemove(inst)
	local e = CE.tags[inst]
	if e then
		e.gui:Destroy()
		CE.tags[inst] = nil
		CE.count -= 1
	end
end

local function ceAdd(inst)
	if CE.tags[inst] or CE.count >= 300 or ceIsCharacter(inst) then return end
	local a = inst.Parent
	while a and a ~= workspace do
		if CE.tags[a] then return end
		a = a.Parent
	end
	local adornee = inst:IsA("BasePart") and inst or (inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true))
	if not adornee then return end
	for t in pairs(CE.tags) do
		if t:IsDescendantOf(inst) then ceRemove(t) end
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "CollectESP"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(120, 36)
	bb.StudsOffset = Vector3.new(0, 2, 0)
	bb.Adornee = adornee
	bb.Parent = gui
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Text = inst.Name
	lbl.TextColor3 = Color3.fromRGB(255, 170, 60)
	lbl.TextStrokeTransparency = 0.3
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.Parent = bb
	CE.tags[inst] = { gui = bb, adornee = adornee, label = lbl }
	CE.count += 1
end

local function ceStop()
	CE.running = false
	CE.scanId += 1
	for _, c in ipairs(CE.conns) do pcall(function() c:Disconnect() end) end
	CE.conns = {}
	for t in pairs(CE.tags) do ceRemove(t) end
end

local function ceStart()
	if CE.running then return end
	CE.running = true
	CE.scanId += 1
	local id = CE.scanId
	task.spawn(function()
		local n = 0
		for _, d in ipairs(workspace:GetDescendants()) do
			if not CE.running or CE.scanId ~= id then return end
			local t = ceTarget(d)
			if t then ceAdd(t) end
			n += 1
			if n % 400 == 0 then task.wait() end
		end
	end)
	CE.conns[1] = workspace.DescendantAdded:Connect(function(d)
		task.defer(function()
			if not CE.running then return end
			local t = ceTarget(d)
			if t and t.Parent then ceAdd(t) end
		end)
	end)
	CE.conns[2] = workspace.DescendantRemoving:Connect(function(d)
		if CE.tags[d] then ceRemove(d) end
	end)
end

bind(RunService.Heartbeat, function(dt)
	if not CE.running then return end
	CE.acc += dt
	if CE.acc < 0.15 then return end
	CE.acc = 0
	local root = getRoot()
	for inst, e in pairs(CE.tags) do
		if not (inst.Parent and e.adornee.Parent) then
			ceRemove(inst)
		elseif root then
			local d = math.floor((e.adornee.Position - root.Position).Magnitude)
			e.label.Text = inst.Name .. "\n" .. d .. " studs"
		end
	end
end)

offs[#offs + 1] = function()
	S.CollectESP = false
	ceStop()
end

-- navigation & pages ---------------------------------------------------
local gGeneral = addGroup("General", "=")
local gAdmin = addGroup("Admin", "+", true)
local gSettings = addGroup("Settings", "*", true)

local pgDash = addPage("General", "Dashboard")
local pgCmds = addPage("General", "Commands")
local pgPlayers = addPage("General", "Players")
local pgServer = addPage("General", "Server")
local pgTune = addPage("Admin", "Tuning")
local pgConfig = addPage("Settings", "Config")

addNav(gGeneral, "Dashboard", "#")
addNav(gGeneral, "Commands", ">_")
addNav(gGeneral, "Players", "@")
addNav(gGeneral, "Server", "~")
addNav(gAdmin, "Tuning", "+")
addNav(gSettings, "Config", "=")

bind(searchBtn.MouseButton1Click, function() showPage("Players") end)
bind(closeBtn.MouseButton1Click, cleanup)

-- Dashboard
local hr = os.date("*t").hour
local greet = hr < 12 and "Good morning" or (hr < 18 and "Good afternoon" or "Good evening")

local topRow = mk("Frame", { Size = UDim2.new(1, 0, 0, 104), BackgroundTransparency = 1 }, pgDash)
local banner = mk("Frame", { Size = UDim2.new(0.62, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0 }, topRow)
corner(banner, 12)
mk("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(135, 85, 235), Color3.fromRGB(100, 76, 188)),
	Rotation = 20,
}, banner)
txt(banner, greet .. ", <b>" .. lp.DisplayName .. "</b>.", 19, COL.text, Enum.Font.Gotham, nil, {
	Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, -30), TextYAlignment = Enum.TextYAlignment.Bottom,
})
txt(banner, "Administrator", 12, COL.text, nil, nil, { Position = UDim2.new(0, 16, 1, -28), Size = UDim2.new(1, -32, 0, 18), TextTransparency = 0.15 })

local actCard = mk("Frame", { Size = UDim2.new(0.36, 0, 1, 0), Position = UDim2.fromScale(0.64, 0), BackgroundColor3 = COL.panel, BorderSizePixel = 0 }, topRow)
corner(actCard, 12)
stroke(actCard)
txt(actCard, "Action Required", 12, COL.muted, nil, nil, { Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 16) })
local actNum = txt(actCard, "0 on", 22, COL.text, Enum.Font.GothamMedium, nil, { Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 28) })
txt(actCard, "currently enabled", 12, COL.muted, nil, nil, { Position = UDim2.fromOffset(14, 56), Size = UDim2.new(1, -28, 0, 16) })
local art = mk("Frame", { Size = UDim2.fromOffset(46, 36), Position = UDim2.new(1, -40, 0, 22), BackgroundTransparency = 1 }, actCard)
corner(art, 6)
mk("UIStroke", { Color = COL.accentDim, Thickness = 3 }, art)
local artDot = mk("Frame", { Size = UDim2.fromOffset(12, 12), Position = UDim2.new(1, -52, 0, 16), BackgroundColor3 = COL.accentDim }, actCard)
corner(artDot, 6)
local notifDot = mk("Frame", { Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(78, 31), BackgroundColor3 = Color3.fromRGB(255, 70, 80), Visible = false }, actCard)
corner(notifDot, 3)
local reviewBtn = txt(actCard, "Review →", 12, COL.accent, Enum.Font.GothamMedium, nil, { Position = UDim2.fromOffset(14, 78), Size = UDim2.fromOffset(80, 18) })
local reviewHit = mk("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, reviewBtn)
bind(reviewHit.MouseButton1Click, function() showPage("Commands") end)

local statRow = mk("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1 }, pgDash)
local function statCard(idx, glyph, label)
	local c = mk("Frame", { Size = UDim2.new(0.328, 0, 1, 0), Position = UDim2.fromScale((idx - 1) * 0.336, 0), BackgroundColor3 = COL.panel, BorderSizePixel = 0 }, statRow)
	corner(c, 12)
	stroke(c)
	local ib = mk("Frame", { Size = UDim2.fromOffset(36, 36), Position = UDim2.new(0, 12, 0.5, -18), BackgroundColor3 = COL.accentDim }, c)
	corner(ib, 10)
	txt(ib, glyph, 14, COL.accent, Enum.Font.GothamBold, CENTER, { Size = UDim2.fromScale(1, 1) })
	txt(c, label, 11, COL.muted, nil, nil, { Position = UDim2.fromOffset(56, 9), Size = UDim2.new(1, -60, 0, 14) })
	return txt(c, "", 17, COL.text, Enum.Font.GothamBold, nil, { Position = UDim2.fromOffset(56, 24), Size = UDim2.new(1, -60, 0, 24) })
end
local stPlayers = statCard(1, "P", "Players Ingame")
local stFeatures = statCard(2, "F", "Staff Ingame")
local stUptime = statCard(3, "T", "Server Uptime")

buildTable(pgDash, 4)

local startT = os.clock()
local function updateStats()
	stPlayers.Text = string.format('%d <font size="11" color="%s">/ %d</font>', #Players:GetPlayers(), hex(COL.muted), Players.MaxPlayers)
	local n = 0
	for _, k in ipairs({ "Speed", "Jump", "InfJump", "Fly", "Noclip", "Fullbright", "CollectESP" }) do
		if S[k] then n += 1 end
	end
	local staff = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if lp.Team and p.Team == lp.Team then staff += 1 end
	end
	stFeatures.Text = tostring(staff)
	actNum.Text = n .. " on"
	notifDot.Visible = n > 0
	local sec = workspace.DistributedGameTime
	stUptime.Text = string.format("%dh, %dm", math.floor(sec / 3600), math.floor(sec % 3600 / 60))
end
updateStats()
do
	local acc = 0
	bind(RunService.Heartbeat, function(dt)
		acc += dt
		if acc >= 1 then
			acc = 0
			updateStats()
		end
	end)
end

-- Players page
buildTable(pgPlayers)

-- Commands
addToggle(pgCmds, "Walk Speed", "Speed", function() applySpeedJump() end)
addToggle(pgCmds, "Jump Power", "Jump", function() applySpeedJump() end)
addToggle(pgCmds, "Fly", "Fly")
addToggle(pgCmds, "Noclip", "Noclip")
addToggle(pgCmds, "Infinite Jump", "InfJump")
addToggle(pgCmds, "Fullbright", "Fullbright", function() applyFullbright() end)
addToggle(pgCmds, "Collectible ESP", "CollectESP", function(on) if on then ceStart() else ceStop() end end)
addButton(pgCmds, "Reset Character", function()
	local hum = getHum()
	if hum then hum.Health = 0 end
end)

-- Server
local function infoRow(page, label, value)
	local r = newRow(page, 38)
	txt(r, label, 12, COL.muted, nil, nil, { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.4, 0, 1, 0) })
	txt(r, value, 12, COL.text, Enum.Font.GothamMedium, Enum.TextXAlignment.Right, { Position = UDim2.fromScale(0.4, 0), Size = UDim2.new(0.6, -14, 1, 0) })
end
infoRow(pgServer, "Place ID", tostring(game.PlaceId))
infoRow(pgServer, "Job ID", game.JobId ~= "" and game.JobId or "Studio")
infoRow(pgServer, "Max Players", tostring(Players.MaxPlayers))

-- Tuning
addSlider(pgTune, "Speed Value", "SpeedVal", 16, 150, function() if S.Speed then applySpeedJump() end end)
addSlider(pgTune, "Jump Value", "JumpVal", 50, 250, function() if S.Jump then applySpeedJump() end end)
addSlider(pgTune, "Fly Speed", "FlySpeed", 20, 200)

-- Config
addButton(pgConfig, "Save Config", function() saveConfig() end)
addButton(pgConfig, "Unload Script", cleanup)

-- font (Inter, like the reference)
do
	local weights = {
		[Enum.Font.GothamBold] = Enum.FontWeight.Bold,
		[Enum.Font.GothamMedium] = Enum.FontWeight.Medium,
	}
	local function applyFont(o)
		if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
			pcall(function()
				o.FontFace = Font.new("rbxasset://fonts/families/Inter.json", weights[o.Font] or Enum.FontWeight.Regular)
			end)
		end
	end
	for _, o in ipairs(gui:GetDescendants()) do applyFont(o) end
	bind(gui.DescendantAdded, applyFont)
end

showPage("Dashboard")
applySpeedJump()
