-- Polestar_TabStyles (load on demand): the guide window's tab styles past
-- the underline strip (guideWindow.tabStyle; UI/GuideFrameTabStyles.lua
-- loads this the first time one is drawn). "switcher" turns the navigator's
-- title into a menu of the open guides; "edge" stands small icon tabs on the
-- window's top edge; "strip" runs an icon column down the window's left
-- edge. Every style keeps a tab's clicks, tooltip and menu (GF.TabClick,
-- GF.TabTip, GF.TabMenu) and the limit of six tabs. A part of the window
-- (GF.Part): it joins the live window and every copy.

local ns = Polestar
ns.UI.GuideFrame.Part(function(GF)
	local UI, Theme, W, Anim, L, floor, max, min = ns.UI, ns.Theme, ns.Widgets, ns.Anim, ns.L, math.floor, math.max, math.min
	local Engine, T = GF.Engine, GF.Text
	local MAX_TABS = 6

	-- Sizes: an edge tab, its lit height and the row it stands in; a side
	-- strip's column, its buttons and their gap.
	local EDGE_W, EDGE_H, EDGE_ON_H, EDGE_ROW, EDGE_GAP, EDGE_IN = 30, 22, 25, 25, 3, 8
	local SIDE_W, SIDE_BTN_W, SIDE_BTN_H, SIDE_GAP, SIDE_PAD = 33, 29, 30, 2, 4

	local F, nav
	-- The window's style frames (UI/GuideFrameTabStyles.lua keeps them).
	local own
	GF.Bind(function(p)
		F, nav = p.F, p.nav
		own = GF.TabStyleFrames()
	end)

	local function full(n) return n >= MAX_TABS end
	local function addTip(n) return full(n) and L["Six tabs is the limit"] or L["Open a guide in a new tab"] end
	local function openPicker() UI.ShowPicker({ newTab = true }) end
	local hideWindow = GF.HideWindow

	-- A 1px edge on the sides of `f` that `sides` names ("TOP", "LEFT",
	-- "RIGHT", "BOTTOM"), in the border wash.
	local function edges(f, sides)
		local out = {}
		for _, side in ipairs(sides) do
			local t = f:CreateTexture(nil, "BORDER")
			t:SetTexture(Theme.Media("white"))
			if side == "TOP" or side == "BOTTOM" then
				t:SetPoint(side .. "LEFT", f, side .. "LEFT", 0, 0)
				t:SetPoint(side .. "RIGHT", f, side .. "RIGHT", 0, 0)
				W.Painter(t, function(x) x:SetHeight(Theme.Pixel(f)) end)
			else
				t:SetPoint("TOP" .. side, f, "TOP" .. side, 0, 0)
				t:SetPoint("BOTTOM" .. side, f, "BOTTOM" .. side, 0, 0)
				W.Painter(t, function(x) x:SetWidth(Theme.Pixel(f)) end)
			end
			W.Color(t, "border")
			out[#out + 1] = t
		end
		return out
	end

	-- An icon tab (edge, strip): its ground, the lit ground of the active
	-- one, the accent mark, the glyph. kind: "tab", "add" or "close".
	local function iconTab(parent, kind, style)
		local b = CreateFrame("Button", nil, parent)
		b.psStyle = style
		b.Ground = W.Fill(b, "sidebar", "BACKGROUND", -6)
		b.Selected = W.Fill(b, "bg", "BACKGROUND", -5)
		b.Selected:Hide()
		b.Hover = W.Hover(b, 0.7)
		b.Bar = b:CreateTexture(nil, "OVERLAY")
		b.Bar:SetTexture(Theme.Media("white"))
		W.Color(b.Bar, "accent")
		b.Bar:Hide()
		b.Icon = b:CreateTexture(nil, "ARTWORK")
		b.Icon:SetSize(13, 13)
		b.Icon:SetPoint("CENTER", b, "CENTER", 0, 0)
		W.Color(b.Icon, "textMuted")
		if style == "edge" then
			b.Edges = edges(b, { "TOP", "LEFT", "RIGHT" })
			b.Bar:SetHeight(2)
		else
			b.Bar:SetWidth(2)
		end
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
		if kind == "tab" then
			b:SetScript("OnClick", GF.TabClick)
			b:SetScript("OnEnter", function(self)
				if not self.psActive then W.Color(self.Icon, "textDim") end
				GF.TabTip(self, style == "edge" and "ANCHOR_TOP" or "ANCHOR_LEFT")
			end)
			b:SetScript("OnLeave", function(self)
				if not self.psActive then W.Color(self.Icon, "textMuted") end
				W.HideTooltip(self)
			end)
			-- Its parts for a skin's hooks.guideTab, with the style they are drawn in.
			b.psParts = { selected = b.Selected, bar = b.Bar, icon = b.Icon, style = style }
		else
			b.Icon:SetTexture(Theme.Media(kind == "add" and "plus" or "close"))
			if kind == "close" then b.Icon:SetSize(10, 10) end
			b:SetScript("OnClick", function(self, button)
				if button ~= "LeftButton" or not self:IsEnabled() then return end
				if kind == "add" then openPicker() else hideWindow() end
			end)
			b:SetScript("OnEnter", function(self)
				if self:IsEnabled() then W.Color(self.Icon, kind == "close" and "danger" or "text") end
				W.Tooltip(self, style == "edge" and "ANCHOR_TOP" or "ANCHOR_LEFT", self.psTip or "")
				GF.HoverIn()
			end)
			b:SetScript("OnLeave", function(self)
				W.Color(self.Icon, "textMuted", self:IsEnabled() and 1 or 0.35)
				W.HideTooltip(self)
			end)
			if kind == "close" then b.psTip = L["Hide window"] end
		end
		return b
	end

	-- The switcher: the navigator's title as a button with the tab count and
	-- a chevron; its menu lists the open guides.
	local function switcherMenu(self)
		local E = Engine()
		local tabs, active = GF.TabsOf(E)
		if not tabs then return end
		local n = #tabs
		local items = { { heading = true, text = L["Open guides"], right = string.format(L["%d of %d"], n, MAX_TABS) } }
		local probe = {}
		for i, t in ipairs(tabs) do
			GF.TabFacts(probe, t)
			local num, total = t.stepNumber or t.stepIndex, t.stepTotal or t.stepCount
			items[#items + 1] = {
				text = probe.psTitle, icon = probe.psIcon, sub = probe.psRange, marked = i == active,
				right = (num and total) and (num .. "/" .. total) or nil,
				onClick = function() if i ~= active and E.SelectTab then E.SelectTab(i) end end,
				onRemove = function()
					if E.CloseTab then E.CloseTab(i) end
					-- What is left, in the menu again.
					if own and own.switch and own.switch:IsShown() and #(GF.TabsOf(Engine()) or {}) > 0 then switcherMenu(own.switch) end
				end,
				removeTip = L["Close tab"],
			}
		end
		items[#items + 1] = { separator = true }
		items[#items + 1] = { text = L["Open a guide in a new tab"], icon = "plus", disabled = full(n),
			tip = full(n) and L["Six tabs is the limit"] or nil, onClick = openPicker }
		local reopen = GF.ReopenItem()
		if reopen then
			if reopen.tip and #reopen.tip <= 28 then reopen.sub, reopen.tip = reopen.tip, nil end
			items[#items + 1] = reopen
		end
		W.ShowMenu(self, items, { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 0, y = -3, minWidth = 260 })
	end

	local function makeSwitch()
		local b = CreateFrame("Button", nil, nav)
		b:SetHeight(30)
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
		b.Hover = W.Hover(b, 0.7)
		b.Icon = b:CreateTexture(nil, "ARTWORK")
		b.Icon:SetSize(14, 14)
		W.Color(b.Icon, "accent")
		b.Label = GF.SizeAs(T(b, "small", "textDim"), "bar")
		b.Badge = CreateFrame("Frame", nil, b)
		b.Badge:SetHeight(15)
		b.Badge.Fill = W.Fill(b.Badge, "accent", "BACKGROUND", -4)
		b.Badge.Text = T(b.Badge, "small", "onAccent")
		b.Badge.Text:SetPoint("CENTER", b.Badge, "CENTER", 0, 0)
		b.Chevron = W.Tex(b, "ARTWORK", "chevron-down", "textMuted")
		b.Chevron:SetSize(10, 10)
		b:SetScript("OnClick", function(self, button)
			local E = Engine()
			if not E then return end
			if button == "RightButton" then return GF.TabMenu(self) end
			if button == "MiddleButton" then
				if E.CloseTab then E.CloseTab(self.psIndex) end
				return
			end
			if W.MenuShown(self) then return W.HideMenu() end
			W.HideTooltip(self)
			switcherMenu(self)
		end)
		b:SetScript("OnEnter", function(self)
			W.Color(self.Label, "text")
			if not W.MenuShown(self) then GF.TabTip(self, "ANCHOR_BOTTOM") end
		end)
		b:SetScript("OnLeave", function(self)
			W.Color(self.Label, "textDim")
			W.HideTooltip(self)
		end)
		b.psMenuAt = { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 0, y = -3 }
		b:Hide()
		return b
	end

	local function switchOf() return own.switch or GF.AdoptTabFrame("switch", makeSwitch()) end

	-- The edge row: above the top edge, or under the bottom one when the bars sit there.
	local function edgeOf()
		if own.edge then return own.edge end
		local e = CreateFrame("Frame", nil, F)
		e:SetHeight(EDGE_ROW)
		e.tabs = {}
		e.Add = iconTab(e, "add", "edge")
		e.Add.Ground:Hide()
		for _, t in ipairs(e.Add.Edges) do W.Color(t, "border", 0.6) end
		e.Close = iconTab(e, "close", "edge")
		e:Hide()
		return GF.AdoptTabFrame("edge", e)
	end

	-- The side strip: a column outside the window's left edge.
	local function sideOf()
		if own.side then return own.side end
		local s = CreateFrame("Frame", nil, F)
		s:SetWidth(SIDE_W)
		s.Ground = W.Fill(s, "sidebar", "BACKGROUND", -7)
		s.Edges = edges(s, { "TOP", "LEFT", "BOTTOM" })
		s.tabs = {}
		s.Add = iconTab(s, "add", "strip")
		s.Add.Ground:Hide()
		s:Hide()
		return GF.AdoptTabFrame("side", s)
	end

	-- The window's own ground on a tab (or the side strip): its opacity
	-- (guideWindow.bgOpacity, ui.bgOpacity), none and no edges in the
	-- transparent style. The accent mark and the glyph stay.
	local function ground(b)
		local a = F.psBare and 0 or (F.psBgAlpha or Theme.GroundAlpha())
		if rawget(b, "Ground") then b.Ground:SetAlpha(a) end
		if rawget(b, "Selected") then b.Selected:SetAlpha(a) end
		for _, t in ipairs(rawget(b, "Edges") or {}) do t:SetShown(not F.psBare) end
	end

	local function paintIconTab(b, active)
		b.psActive = active
		b.Selected:SetShown(active)
		b.Ground:SetShown(not active)
		b.Bar:SetShown(active)
		W.Color(b.Icon, active and "accent" or "textMuted")
		Theme.SkinHook("guideTab", b, b.psParts, active)
	end

	local function fillTab(b, i, t, active)
		b.psIndex = i
		GF.TabFacts(b, t)
		b.Icon:SetTexture(Theme.Media(b.psIcon))
		paintIconTab(b, i == active)
	end

	local function renderEdge(tabs, active)
		local e = edgeOf()
		local bottom = GF.BarsBottom()
		e:ClearAllPoints()
		if bottom then
			e:SetPoint("TOPLEFT", F, "BOTTOMLEFT", EDGE_IN, 0)
			e:SetPoint("TOPRIGHT", F, "BOTTOMRIGHT", -EDGE_IN, 0)
		else
			e:SetPoint("BOTTOMLEFT", F, "TOPLEFT", EDGE_IN, 0)
			e:SetPoint("BOTTOMRIGHT", F, "TOPRIGHT", -EDGE_IN, 0)
		end
		-- The side the tabs stand on: their foot meets the window's edge.
		local foot = bottom and "TOP" or "BOTTOM"
		local cap = bottom and "BOTTOM" or "TOP"
		local x = 0
		local n = #tabs
		for i = 1, n do
			local b = e.tabs[i]
			if not b then
				b = iconTab(e, "tab", "edge")
				e.tabs[i] = b
			end
			b.psMenuAt = bottom and { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 0, y = -2 }
				or { point = "BOTTOMLEFT", relPoint = "TOPLEFT", x = 0, y = 2 }
			fillTab(b, i, tabs[i], active)
			b:SetSize(EDGE_W, b.psActive and EDGE_ON_H or EDGE_H)
			b:ClearAllPoints()
			-- The active tab covers the window's edge under it, one pixel in.
			b:SetPoint(foot .. "LEFT", e, foot .. "LEFT", x, b.psActive and (bottom and 1 or -1) or 0)
			b.Bar:ClearAllPoints()
			b.Bar:SetPoint(cap .. "LEFT", b, cap .. "LEFT", 0, 0)
			b.Bar:SetPoint(cap .. "RIGHT", b, cap .. "RIGHT", 0, 0)
			b:SetFrameLevel(e:GetFrameLevel() + (b.psActive and 3 or 1))
			b:Show()
			x = x + EDGE_W + EDGE_GAP
		end
		for i = n + 1, #e.tabs do e.tabs[i]:Hide() end
		e.Add:SetSize(EDGE_W, EDGE_H)
		e.Add:ClearAllPoints()
		e.Add:SetPoint(foot .. "LEFT", e, foot .. "LEFT", x, 0)
		e.Add.psTip = addTip(n)
		if full(n) then e.Add:Disable() else e.Add:Enable() end
		W.Color(e.Add.Icon, "textMuted", full(n) and 0.35 or 1)
		e.Close:SetSize(EDGE_W, EDGE_H)
		e.Close:ClearAllPoints()
		e.Close:SetPoint(foot .. "RIGHT", e, foot .. "RIGHT", 0, 0)
		e.Close:SetShown(not nav.psClear)
		for _, b in ipairs(e.tabs) do ground(b) end
		ground(e.Add)
		ground(e.Close)
		e:Show()
	end

	local function renderSide(tabs, active)
		local s = sideOf()
		local bottom = GF.BarsBottom()
		local n = #tabs
		s:ClearAllPoints()
		if bottom then
			s:SetPoint("BOTTOMRIGHT", F, "BOTTOMLEFT", 0, 0)
		else
			s:SetPoint("TOPRIGHT", F, "TOPLEFT", 0, 0)
		end
		local y = SIDE_PAD
		for i = 1, n do
			local b = s.tabs[i]
			if not b then
				b = iconTab(s, "tab", "strip")
				b.Bar:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -5)
				b.Bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 5)
				s.tabs[i] = b
			end
			b.psMenuAt = { point = "TOPRIGHT", relPoint = "TOPLEFT", x = -2, y = 0 }
			fillTab(b, i, tabs[i], active)
			b.Ground:Hide()
			b:SetSize(b.psActive and SIDE_BTN_W + 1 or SIDE_BTN_W, SIDE_BTN_H)
			b:ClearAllPoints()
			-- The active one reaches over the window's left edge, one pixel in.
			b:SetPoint("TOPLEFT", s, "TOPLEFT", SIDE_PAD - 1, -y)
			b:Show()
			y = y + SIDE_BTN_H + SIDE_GAP
		end
		for i = n + 1, #s.tabs do s.tabs[i]:Hide() end
		s.Add:SetSize(SIDE_BTN_W, SIDE_BTN_H)
		s.Add:ClearAllPoints()
		s.Add:SetPoint("TOPLEFT", s, "TOPLEFT", SIDE_PAD - 1, -y)
		s.Add.psTip = addTip(n)
		if full(n) then s.Add:Disable() else s.Add:Enable() end
		W.Color(s.Add.Icon, "textMuted", full(n) and 0.35 or 1)
		s:SetHeight(y + SIDE_BTN_H + SIDE_PAD)
		for _, b in ipairs(s.tabs) do ground(b) end
		ground(s.Add)
		ground(s)
		s:Show()
	end

	-- Where the switcher starts: at the title's left anchor. A layout's glyph
	-- before the title (Atlas's emblem) is the switcher's own icon.
	local function renderSwitch(tabs, active)
		local b = switchOf()
		local t = tabs[active] or tabs[1]
		if not t then return b:Hide() end
		b.psIndex = active or 1
		b.psActive = true
		GF.TabFacts(b, t)
		local _, rel, relPoint, ox = nav.Title:GetPoint(1)
		ox = tonumber(ox) or 8
		local glyph = rel and rel ~= nav and rel ~= nav.Steps and rel.GetObjectType and rel:GetObjectType() == "Texture" and rel or nil
		b:ClearAllPoints()
		-- textX: the label's inset; back: how far left of the title the switcher starts.
		local textX, back
		if glyph then
			b:SetPoint("LEFT", glyph, "LEFT", -5, 0)
			b.Icon:Hide()
			textX = 5 + floor((glyph:GetWidth() or 16) + 0.5) + ox
			back = textX
		else
			b:SetPoint("LEFT", rel or nav, relPoint or "LEFT", ox - 7, 0)
			b.Icon:SetTexture(Theme.Media(b.psIcon))
			b.Icon:ClearAllPoints()
			b.Icon:SetPoint("LEFT", b, "LEFT", 7, 0)
			b.Icon:Show()
			textX, back = 7 + 14 + 8, 7
		end
		-- The title's own face (a layout may set it).
		local path, size, flags = nav.Title:GetFont()
		if path then b.Label:SetFont(path, size, flags) end
		b.Label:SetText(b.psTitle or "")
		b.Label:SetWidth(0)
		local natural = floor(b.Label:GetStringWidth() + 1)
		local n = #tabs
		local count = b.Badge.Text
		count:SetText(tostring(n))
		local badgeW = n > 1 and max(15, floor(count:GetStringWidth() + 1) + 10) or 0
		b.Badge:SetWidth(max(1, badgeW))
		b.Badge:SetShown(n > 1)
		if n > (b.psCount or n) and n > 1 then Anim.To(b.Badge, "alpha", 0.25, 1, Anim.BASE, "out") end
		b.psCount = n
		local tail = (badgeW > 0 and badgeW + 6 or 0) + 10 + 8
		-- The room the title had: its width at its anchors, at least 40; on
		-- screen, up to the first control right of it.
		local room = max(40, floor((nav.Title:GetWidth() or 0) + 0.5)) + back
		b:SetWidth(1)
		local left = b:GetLeft()
		if type(left) == "number" and left > 0 then
			local edge
			for _, c in ipairs({ nav.Steps, nav.Skip, nav.Nearby, nav.Report, nav.Lookup, nav.Menu }) do
				local l = c:IsShown() and c:GetLeft()
				if type(l) == "number" and l > left + 10 and (not edge or l < edge) then edge = l end
			end
			if edge then room = max(room, floor(edge - left - 6)) end
		end
		local labelW = max(10, min(natural, room - textX - tail))
		b.Label:SetWidth(labelW)
		b.Label:ClearAllPoints()
		b.Label:SetPoint("LEFT", b, "LEFT", textX, 0)
		b.Badge:ClearAllPoints()
		b.Badge:SetPoint("LEFT", b.Label, "RIGHT", 6, 0)
		b.Chevron:ClearAllPoints()
		b.Chevron:SetPoint("LEFT", badgeW > 0 and b.Badge or b.Label, "RIGHT", badgeW > 0 and 6 or 8, 0)
		b:SetWidth(textX + labelW + tail)
		nav.Title:Hide()
		b:Show()
	end

	local function hide(f) if f then f:Hide() end end

	-- The style's frames, made the first time it is drawn (GF.PlaceClose,
	-- before the layout's hooks).
	function GF.TabStyleBuild(style)
		if not own then return end
		if style == "switcher" then switchOf() elseif style == "edge" then edgeOf() elseif style == "strip" then sideOf() end
	end

	-- Draw `style`'s tabs and hide the others' (GF.RenderTabStyle).
	function GF.TabStyleDraw(style)
		if not own then return end
		local tabs, active
		if style and style ~= "underline" then tabs, active = GF.TabsOf(Engine()) end
		if style and style ~= "underline" and not tabs then style = nil end
		if style == "switcher" then renderSwitch(tabs, active) else hide(own.switch) end
		if style == "edge" then renderEdge(tabs, active) else hide(own.edge) end
		if style == "strip" then renderSide(tabs, active) else hide(own.side) end
	end

	-- How far `style` reaches past the window's left and top edges (GF.TabsOutside). -> left, top
	function GF.TabStyleReach(style)
		if style == "strip" then return SIDE_W, 0 end
		if style == "edge" then return 0, EDGE_ON_H end
		return 0, 0
	end
end)
