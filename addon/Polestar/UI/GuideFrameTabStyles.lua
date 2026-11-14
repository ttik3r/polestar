-- The guide window's tab styles (guideWindow.tabStyle) and its close button
-- (UI/GuideFrame.lua). "underline" is the strip above the navigator
-- (UI/GuideFrameTabs.lua); "switcher" (the navigator's title as a menu of
-- the open guides), "edge" (small icon tabs on the window's top edge) and
-- "strip" (an icon column down its left edge) live in Polestar_TabStyles
-- (load on demand), loaded the first time one of them is drawn. Without it
-- the window keeps the underline style and says so once in the chat.

local ADDON, ns = ...
local L = ns.L
local STYLES = { underline = true, switcher = true, edge = true, strip = true }
local TAB_STYLES = "Polestar_TabStyles"

-- Polestar_TabStyles, loaded once when a window first needs it. -> loaded
local tried, loaded = false, false
local function loadStyles()
	if loaded or tried then return loaded end
	tried = true
	local A = C_AddOns
	local load = A and A.LoadAddOn or LoadAddOn
	local ok, done = false, false
	if load then ok, done = pcall(load, TAB_STYLES) end
	loaded = ok and done and true or false
	if not loaded then ns.Print(L["The other tab styles are missing or turned off (Polestar_TabStyles): the tabs show above the step bar."]) end
	return loaded
end

ns.UI.GuideFrame.Part(function(GF)
	local W = ns.Widgets
	local Theme = ns.Theme
	local F, strip, nav
	-- This window's style frames: a table once its parts exist, each made the
	-- first time it is drawn (a window on underline with tabs off makes none).
	local own

	local function hideWindow()
		local click = nav and nav.Close and nav.Close:GetScript("OnClick")
		if click then click(nav.Close) end
	end
	GF.HideWindow = hideWindow

	-- A style's frame joins the window: among its parts for a skin's hooks
	-- (Skin API 2; Theme.GuideParts hands it out from now on, nil before),
	-- the chrome that fades with the bars, in the skin's colours.
	local PART_KEY = { switch = "tabSwitch", edge = "tabEdge", side = "tabSide", x = "windowClose" }
	local function register()
		if not GF.parts then return end
		local skinParts = GF.SkinParts and GF.SkinParts()
		for k, key in pairs(PART_KEY) do
			local f = own[k]
			if f and GF.parts[key] ~= f then
				GF.parts[key] = f
				if skinParts then skinParts[key] = f end
			end
		end
	end
	-- The frames of this window's styles (Polestar_TabStyles reads and adds to them). -> own, or nil
	function GF.TabStyleFrames() return own end
	function GF.AdoptTabFrame(k, f)
		own[k] = f
		local chrome = GF.chrome
		chrome[#chrome + 1] = f
		f:SetAlpha(nav.Menu:GetAlpha())
		Theme.Repaint(f)
		register()
		return f
	end

	-- The window's close: a glyph right of the menu, past a hairline.
	local function closeOf()
		if own.x then return own.x end
		local x = W.IconButton(nav, "close", 22, L["Hide window"], hideWindow, 10)
		x.psOnEnter = function(self) W.Color(self.Icon, "danger") end
		x:Hide()
		own.rule = W.Divider(nav, true)
		own.rule:SetHeight(18)
		own.rule:Hide()
		return GF.AdoptTabFrame("x", x)
	end

	local function hide(f) if f then f:Hide() end end

	GF.Bind(function(p)
		F, strip, nav = p.F, p.strip, p.nav
		if nav and F and not own and GF.chrome then
			own = {}
			-- A skin's close square fades with the bars too.
			local chrome = GF.chrome
			chrome[#chrome + 1] = nav.Close
		end
		if own then register() end
	end)

	-- The style the window draws its tabs in: guideWindow.tabStyle while the
	-- tabs show (guideWindow.tabs, not compact, the Engine has tabs); nil
	-- otherwise. A style of Polestar_TabStyles loads it; without it, underline.
	function GF.TabStyle()
		if not (strip and strip.psHasTabs) or GF.Compact() or not GF.On("tabs") then return nil end
		local s = ns.Get("guideWindow.tabStyle")
		if not STYLES[s] then return "underline" end
		if s ~= "underline" and not GF.TabStyleBuild and not loadStyles() then return "underline" end
		return s
	end

	-- The window's close and the menu. A skin's close square (the guideTitle
	-- hook) keeps the skin's place, the menu its inset (menuRight); the edge
	-- style's × is a tab of its own, the switcher has none ("…" has Hide
	-- window). Otherwise the underline and strip styles' own × sits right of
	-- "…" past a hairline.
	function GF.PlaceClose()
		if not (own and nav) then return end
		local style = GF.TabStyle()
		local skinClose = nav.psSkinClose and style ~= "edge"
		local x = style and style ~= "edge" and style ~= "switcher" and not nav.psClear and not skinClose
		nav.Close:SetShown(skinClose and true or false)
		-- The style's frames, made here on its first use: before the layout's
		-- hooks run, so a skin's guideLayout dresses them from the first time.
		if style and style ~= "underline" and GF.TabStyleBuild then GF.TabStyleBuild(style) end
		GF.PlaceReach(style)
		if x then closeOf():Show() else hide(own.x) end
		nav.Menu:ClearAllPoints()
		if x then
			own.x:ClearAllPoints()
			own.x:SetPoint("RIGHT", nav, "RIGHT", -6, 0)
			own.rule:ClearAllPoints()
			own.rule:SetPoint("RIGHT", own.x, "LEFT", -4, 0)
			own.rule:Show()
			nav.Menu:SetPoint("RIGHT", own.rule, "LEFT", -3, 0)
		else
			hide(own.rule)
			-- The edge style takes a skin's close square away, and the room it kept.
			local inset = (nav.psSkinClose and not skinClose) and 8 or tonumber(nav.psMenuRight) or 8
			nav.Menu:SetPoint("RIGHT", nav, "RIGHT", -inset, 0)
		end
	end

	-- How far the window's own parts stand past its top and bottom edges (the
	-- edge style's tabs: on the top edge, or the bottom one with the bars
	-- there), kept on the window frame (F.psTopReach, F.psBottomReach) for
	-- what sits on those edges: the heads-up card (UI/ClassToast.lua), a
	-- layout's cards above the window (Theme.GuideReach). Set with the style,
	-- before the layout's hooks run. -> top, bottom
	function GF.TopReach()
		return F and F.psTopReach or 0, F and F.psBottomReach or 0
	end
	function GF.PlaceReach(style)
		if not F then return end
		local _, out = 0, 0
		if style and GF.TabStyleReach then _, out = GF.TabStyleReach(style) end
		local bottom = GF.BarsBottom()
		local top, under = bottom and 0 or out, bottom and out or 0
		if F.psTopReach == top and F.psBottomReach == under then return end
		F.psTopReach, F.psBottomReach = top, under
		-- The heads-up card on the live window steps clear of the tabs.
		local CT = GF.live and ns.UI.ClassToast
		if CT and CT.Place then CT.Place(false) end
	end

	-- What the navigator gives up right of the menu for the close (GF.Layout's title room).
	function GF.CloseRoom()
		if nav and nav.Close:IsShown() then return 18 end
		if not (own and own.x and own.x:IsShown()) then return 0 end
		return own.x:GetWidth() + 6 + 4 + 1 + 3 - 8
	end

	-- Draw the tabs in the style in use (GF.Layout, after the layout's hooks
	-- placed the navigator; TABS_CHANGED). No style: none of them show.
	function GF.RenderTabStyle()
		if GF.StripShown() then GF.RenderTabs() end
		if own and GF.TabStyleDraw then GF.TabStyleDraw(GF.TabStyle()) end
	end

	-- How far the styles drawn outside the window reach past its left and top
	-- (bottom, with the bars there) edges: a host showing a copy (the settings
	-- preview) leaves that room. -> left, top
	function GF.TabsOutside()
		local style = GF.TabStyle()
		if GF.TabStyleReach then return GF.TabStyleReach(style) end
		return 0, 0
	end
end)
