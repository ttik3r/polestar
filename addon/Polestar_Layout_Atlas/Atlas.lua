-- Atlas: a layout for Polestar's guide window (Skin API 2, Theme.RegisterLayout).
-- The step is a node on a timeline: its title and area, its goals with their
-- action icons and quests, the tip under them; Up next is a rail that fades
-- ahead. Nothing else sits in the window: banner notices, While you're here,
-- Along the way, Optional, Training due and the party line are cards stacked
-- above it, the class quest is a heads-up above them, and the Journey is a
-- card joined below. Compact mode is dense: no Up next, no XP row, no Journey,
-- the tip as a strip at the foot.
--
-- A layout is structure only: it has no tokens and no colours. Every colour
-- here is a token of the skin in use (Theme.Color, Theme.Accent), so any skin
-- colours it; Polestar_Skin_Atlas is the look's own.
--
-- Hooks use only the parts they are handed (the settings' preview calls them
-- on a copy of the window). Every hook is offered only where this Polestar
-- has it (capability "surfaces.<hook>"), so on an older one the part it would
-- change stays Polestar's own.

local ADDON = ...
local Theme = Polestar and Polestar.Theme
if not (Theme and Theme.RegisterLayout and (Theme.API_VERSION or 0) >= 2) then return end

local function check(what, ok, message)
	if not ok then
		print(("|cffff8040%s|r: %s refused: %s"):format(ADDON, what, tostring(message)))
	elseif message then
		print(("%s: %s: %s"):format(ADDON, what, message))
	end
end

-- Whether this Polestar hands hook `name` to a layout.
local function has(name)
	return Theme.HasCapability ~= nil and Theme.HasCapability("surfaces." .. name) == true
end

---------------------------------------------------------------------------
-- Core reads. Everything Atlas needs from Polestar that the Skin API does not
-- hand over yet, each behind one function here and nowhere else. Each answers
-- nil (or does nothing) when the internal it reads is missing, and the part
-- it feeds then stays Polestar's own. Each is a read the Skin API should
-- offer; the names say which.
---------------------------------------------------------------------------

local P = Polestar
local Core = {}
local function ui() return P.UI end
local function frame() local u = P.UI; return u and u.GuideFrame end

-- Settings: a value by path (Polestar.Get).
function Core.setting(path) return P.Get and P.Get(path) end
function Core.compact() return Core.setting("ui.compact") and true or false end
-- Polestar's own strings (its locale table), English when it has none.
function Core.tr(s) local L = P.L; return (L and L[s]) or s end

-- Goal and quest words (UI.GoalText and its kin).
function Core.goalText(goal)
	local u = ui()
	return (u and u.GoalText and u.GoalText(goal)) or goal.text or ""
end
function Core.plainGoalText(goal)
	local u = ui()
	return (u and u.PlainGoalText and u.PlainGoalText(goal)) or goal.text or ""
end
function Core.goalProgress(goal)
	local u = ui()
	if u and u.GoalProgress then return u.GoalProgress(goal) end
	local p = goal.progress
	return p and p.max and (p.cur or 0) .. "/" .. p.max or nil
end
function Core.questTitle(quest) local u = ui(); return u and u.QuestTitle and u.QuestTitle(quest) or nil end
function Core.mapName(map) local u = ui(); return u and u.MapName and u.MapName(map) or nil end
function Core.stepSummary(view) local u = ui(); return u and u.StepSummary and u.StepSummary(view) or nil end
-- A quest's own level (docs/skins/API-GAPS.md 25: not on the goal yet).
function Core.questLevel(quest)
	local Lv, E = P.Levels, P.Engine
	local lvl = quest and Lv and Lv.QuestLevel and Lv.QuestLevel(quest, E and E.GetGuide and E.GetGuide() or nil)
	if type(lvl) == "number" and lvl > 0 then return lvl end
end
-- An area objective's spots line (UI.AreaLine: "Rockjaw Troggs all over
-- this area: 12 spots"), the line Polestar puts under such a goal.
function Core.areaLine(goal) local u = ui(); return u and u.AreaLine and u.AreaLine(goal) or nil end
function Core.distanceText(yards) return P.FormatDistance and P.FormatDistance(yards, { round = 5 }) or nil end

-- The arrow: what it points at, how far, and pointing it at a goal.
function Core.target() local N = P.Nav; return N and N.GetTarget and N.GetTarget() or nil end
function Core.distance() local N = P.Nav; return N and N.GetDistance and N.GetDistance() or nil end
function Core.yardsTo(goal)
	local C = P.Compat
	if not (C and C.MapToWorld and C.GetPlayerWorldPosition and goal.map and goal.x and goal.y) then return nil end
	local gc, gx, gy = C.MapToWorld(goal.map, goal.x, goal.y, goal.f)
	local pc, px, py = C.GetPlayerWorldPosition()
	if gc and gc == pc and px and py then return math.sqrt((gx - px) ^ 2 + (gy - py) ^ 2) end
end
-- -> the arrow's target once it points at the goal, or nil.
function Core.aim(goal)
	local G = frame()
	if not G then return nil end
	if G.AimGoal and G.AimGoal(goal) then return nil end
	if G.PointAt and goal.map and goal.x and goal.y then
		G.PointAt(goal, goal.text)
		return Core.target()
	end
end
function Core.canSkip() local E = P.Engine; return E ~= nil and E.SkipGoal ~= nil end
function Core.skipGoal(step, index) local E = P.Engine; if E and E.SkipGoal and step then E.SkipGoal(step, index) end end
-- The window laid out again (a card of Atlas's own changed its content).
function Core.relayout() local G = frame(); if G and G.Layout then G.Layout() end end

-- Banner and class notice read: the notice the window's banner carries
-- (-> kind, its record), taking it up and putting it off; the heads-up card
-- above the window that carries the class quest.
function Core.notice() local G = frame(); if G and G.BannerNotice then return G.BannerNotice() end end
function Core.takeNotice() local G = frame(); if G and G.TakeBanner then G.TakeBanner() end end
function Core.laterNotice() local G = frame(); if G and G.LaterBanner then G.LaterBanner() end end
function Core.showHeadsUp(card)
	local u = ui()
	local CT = u and u.ClassToast
	return CT and CT.ShowCard and CT.ShowCard(card) or false
end
function Core.hideHeadsUp() local u = ui(); local CT = u and u.ClassToast; if CT and CT.Hide then CT.Hide() end end
-- The class quest card's chain on screen (its key), for its ×.
function Core.classCardKey()
	local u = ui()
	local CC = u and u.ClassCard
	return CC and CC.shown and CC.shown.key or nil
end

-- Training-due read: where to train (Engine.TrainingAdvice):
-- -> { trainer = { npcName, map }, title, guide } or an empty table.
function Core.training()
	local E = P.Engine
	return E and E.TrainingAdvice and E.TrainingAdvice() or {}
end

-- Along the way read: the open goals the window lists under the step
-- (Engine.GetAlong), each by its row's step and goal (-> goal view or nil).
function Core.alongGoals()
	local E, out = P.Engine, {}
	for _, s in ipairs(E and E.GetAlong and E.GetAlong() or {}) do
		for _, g in ipairs(s.goals or {}) do
			if g.step and g.index then out[g.step .. ":" .. g.index] = g end
		end
	end
	return out
end

-- XP-to-next read: Polestar's own line on the XP row ("about 9 min to 5").
function Core.xpLine(xp) return xp and xp.psLine or nil end

-- Tip pager read: the step's tips, one per page (a list of strings), and
-- whether the tip is opened; nil while this Polestar keeps one tip.
function Core.tipPages(tip)
	local list = tip and tip.psTips
	return type(list) == "table" and #list > 1 and list or nil
end
function Core.tipOpen(tip)
	local G = frame()
	if G and G.TipOpen then return G.TipOpen() and true or false end
	return tip and tip.psOpen and true or false
end

---------------------------------------------------------------------------
-- Atlas's own pieces on a frame: one table per frame, hidden all at once
-- when the layout leaves (onLeave). A key starting with "_" holds what is
-- not Atlas's own (Polestar's frames, a part's look before Atlas changed it)
-- and is never hidden.
---------------------------------------------------------------------------

local stores = setmetatable({}, { __mode = "k" })
local function store(f)
	local s = stores[f]
	if not s then
		s = {}
		stores[f] = s
	end
	return s
end

local function hideAll(t, seen)
	seen = seen or {}
	if seen[t] then return end
	seen[t] = true
	for k, v in pairs(t) do
		if type(v) == "table" and not (type(k) == "string" and k:sub(1, 1) == "_") then
			if type(v.Hide) == "function" then v:Hide() else hideAll(v, seen) end
		end
	end
end

-- The guide window `f` sits in (a frame marked psGuideWindow), or nil.
local function windowOf(f)
	local p = f
	for _ = 1, 16 do
		if not p then return nil end
		if type(p) == "table" and rawget(p, "psGuideWindow") then return p end
		p = p.GetParent and p:GetParent() or nil
	end
	return nil
end

-- Whether the layout leaving the window of `parts` takes back what it did
-- to `f`: `f` sits in that window, or in none and the window is the live one.
function Core.leaves(f, parts, live)
	local w = windowOf(f)
	if w then return parts ~= nil and w == parts.window end
	return live == true
end

-- Whether `f` sits in `window` (a part of the window a hook handed over).
local function isUnder(f, window)
	local p = f
	for _ = 1, 12 do
		if not p then return false end
		if p == window then return true end
		p = p.GetParent and p:GetParent() or nil
	end
	return false
end

---------------------------------------------------------------------------
-- Hooks: each part of the look adds its handlers; registration joins them
-- (guidePlace and the other questions take the first answer, guideShows
-- passes the answer along, guideLayout adds up the room asked).
---------------------------------------------------------------------------

local chains, order = {}, {}
local function on(name, fn)
	local c = chains[name]
	if not c then
		c = {}
		chains[name] = c
		order[#order + 1] = name
	end
	c[#c + 1] = fn
end

local leaving = {}
local function onLeave(fn) leaving[#leaving + 1] = fn end

local tr, compact = Core.tr, Core.compact

-- A role's face, size and flags, read off a probe of Atlas's own.
local probeFs
local function probe(role)
	if not probeFs then
		probeFs = UIParent:CreateFontString(nil, "OVERLAY")
		probeFs:Hide()
	end
	Theme.Font(probeFs, role)
	local path, size, flags = probeFs:GetFont()
	return path, size or 12, flags
end

-- The semibold face: the "number" role's.
local function semibold() return (probe("number")) end

-- Atlas's small caps labels, over its cards.
local function capsLabel(fs)
	Theme.Font(fs, "small")
	local path, size, flags = fs:GetFont()
	if path and size then fs:SetFont(path, size - 1, flags) end
	fs:SetTextColor(Theme.Color("textMuted"))
end

local function pixel(f) return Theme.Pixel and Theme.Pixel(f) or 1 end

---------------------------------------------------------------------------
-- The header: no backdrop and no rule; the guide's emblem and title on the
-- left, then the step count with its arrows, Skip as its glyph alone, and
-- the menu on the right. The player's own switches (guideWindow.skipButton,
-- .reportButton, .rules, nav.nearbyButton) say what shows; Atlas only sets
-- it out. Lookup is in the menu.
---------------------------------------------------------------------------

on("guideTitle", function(nav, parts)
	if parts.band then parts.band:Hide() end
	if parts.bar then parts.bar:Hide() end
end)

local function navBack(nav)
	local own = nav and stores[nav]
	if not (own and own.atlas) then return end
	own.atlas = nil
	if own.emblem then own.emblem:Hide() end
	Theme.Font(nav.Steps.Count, "number")
	nav.Steps:ClearAllPoints()
	nav.Steps:SetPoint("LEFT", nav, "LEFT", 8, 0)
	-- Polestar's own order right of the count: Skip, Nearby, Report, Lookup.
	nav.Report:ClearAllPoints()
	nav.Report:SetPoint("RIGHT", nav.Lookup, "LEFT", 0, 0)
	nav.Nearby:ClearAllPoints()
	nav.Nearby:SetPoint("RIGHT", nav.Report, "LEFT", 0, 0)
	nav.Skip:ClearAllPoints()
	nav.Skip:SetPoint("RIGHT", (nav.Nearby:IsShown() and nav.Nearby) or (nav.Report:IsShown() and nav.Report) or nav.Menu, "LEFT", -2, 0)
	if nav.Skip.Label then
		nav.Skip.Label:Show()
		nav.Skip:SetWidth(math.floor(7 + 11 + 5 + nav.Skip.Label:GetStringWidth() + 8 + 0.5))
	end
	nav.Lookup:Show()
	Theme.Font(nav.Title, "small")
end
onLeave(function(parts) navBack(parts.nav) end)

-- Right to left from the menu: Report and Nearby where the player shows
-- them, Skip (its glyph alone), then the step count.
local SKIP_W = 7 + 11 + 7
local function navRow(nav)
	local prev = nav.Menu
	for _, b in ipairs({ nav.Report, nav.Nearby, nav.Skip }) do
		if b == nav.Skip then
			if b.Label then b.Label:Hide() end
			b:SetWidth(SKIP_W)
		end
		b:ClearAllPoints()
		b:SetPoint("RIGHT", prev, "LEFT", b == nav.Skip and -2 or 0, 0)
		if b:IsShown() then prev = b end
	end
	nav.Steps:ClearAllPoints()
	nav.Steps:SetPoint("RIGHT", prev, "LEFT", -2, 0)
end

local function header(parts)
	local nav = parts.nav
	if not (nav and nav.Steps and nav.Steps.Count and nav.Menu and nav.Title) then return end
	local own = store(nav)
	own.atlas = true
	if not own.emblem then
		own.emblem = nav:CreateTexture(nil, "ARTWORK")
		own.emblem:SetTexture(Theme.Media("emblem"))
		own.emblem:SetSize(16, 16)
	end
	own.emblem:ClearAllPoints()
	own.emblem:SetPoint("LEFT", nav, "LEFT", 10, 0)
	own.emblem:Show()
	nav.Lookup:Hide()
	local path, size, flags = probe("note")
	nav.Steps.Count:SetFont(path, size + 2, flags)
	local cw = math.max(40, math.ceil(nav.Steps.Count:GetUnboundedStringWidth()) + 1)
	nav.Steps.Count:SetWidth(cw)
	nav.Steps:SetWidth(24 + cw + 24)
	navRow(nav)
	Theme.Font(nav.Title, "goal")
	nav.Title:SetTextColor(Theme.Color("textDim"))
	nav.Title:ClearAllPoints()
	nav.Title:SetPoint("LEFT", own.emblem, "RIGHT", 8, 0)
	nav.Title:SetPoint("RIGHT", nav.Steps, "LEFT", -8, 0)
	nav.Title:SetJustifyH("LEFT")
	nav.Title:SetWordWrap(false)
	local text = nav.Title:GetText()
	nav.Title:SetShown(text ~= nil and text ~= "")
end
on("guideLayout", function(parts) header(parts) end)
-- The render shows or hides Skip, Report and Nearby again and puts Skip
-- back by them: set the row out again.
on("guideRender", function(view, parts)
	local nav = parts.nav
	local own = nav and stores[nav]
	if own and own.atlas and nav.Skip and nav.Steps and nav.Menu then navRow(nav) end
end)

-- With the foot bar off, room under the window's last part.
on("guideLayout", function() return Core.setting("guideWindow.progress") == false and 8 or 0 end)

---------------------------------------------------------------------------
-- The cards above the window, top down, by how far each is from the step
-- on screen: a banner notice (it asks for an answer: the way back, a tab to
-- reopen), the class quest card, While you're here (later steps' work, to
-- get ahead), Along the way (earlier steps' work still owed while the route
-- moves on), Optional (this step's extras), Training due, the party line
-- (the group on this very step, its wait). 5 apart, each on the window's own
-- ground (a frame painted as the guide window, so the skin in use colours
-- it), each with a close ×. The class quest heads-up sits on top of them
-- (guideAnchor). The Journey is a card joined to the window's foot.
---------------------------------------------------------------------------

local GAP = 5
local OPT_ROW, OPT_PAD = 23, 14

-- The step on screen (guideRender), per window: a card closed with its ×
-- stays closed on that step.
local stepOf = setmetatable({}, { __mode = "k" })
local closedOn = {} -- card -> the step it was closed on

-- The parts the window handed over at this layout (guidePlace), taken up by
-- the cards at guideLayout.
local slots = {}

-- The window's own ground on a card of Atlas's, transparent with it.
local function dress(card, window)
	if card.psBare ~= window.psBare or card.psBgAlpha ~= window.psBgAlpha or card.psBgColor ~= window.psBgColor then
		card.psBare, card.psBgAlpha, card.psBgColor = window.psBare, window.psBgAlpha, window.psBgColor
		Theme.Repaint(card)
	end
end

local function stackFrame(window)
	local own = store(window)
	if not own.stack then
		own.stack = CreateFrame("Frame", nil, window)
		own.stack:SetPoint("BOTTOMLEFT", window, "TOPLEFT", 0, GAP)
		own.stack:SetPoint("BOTTOMRIGHT", window, "TOPRIGHT", 0, GAP)
		own.stack:SetHeight(1)
		own.stack.cards = {}
	end
	return own.stack
end

local function closeButton(parent)
	local x = CreateFrame("Button", nil, parent)
	x:SetSize(18, 18)
	x.Icon = x:CreateTexture(nil, "ARTWORK")
	x.Icon:SetTexture(Theme.Media("close"))
	x.Icon:SetSize(10, 10)
	x.Icon:SetPoint("CENTER")
	x:SetScript("OnEnter", function(self) self.Icon:SetVertexColor(Theme.Color("text")) end)
	x:SetScript("OnLeave", function(self) self.Icon:SetVertexColor(Theme.Color("textMuted")) end)
	return x
end

-- Card i's backing, with its ×.
local function backing(stack, i)
	local b = stack.cards[i]
	if not b then
		b = CreateFrame("Frame", nil, stack)
		b.psGuide = true
		Theme.Skin(b, "guide")
		b:SetFrameLevel(stack:GetFrameLevel())
		b.Close = closeButton(b)
		b.Close:SetPoint("TOPRIGHT", b, "TOPRIGHT", -4, -4)
		b.Close:SetScript("OnClick", function(self) if self.psClose then self.psClose() end end)
		stack.cards[i] = b
	end
	return b
end

-- A small circled "i" after a card's label, its tooltip saying what the card holds.
local function infoIcon(owner, label, tip)
	local own = store(owner)
	local b = own.info
	if not b then
		b = CreateFrame("Button", nil, owner)
		b:SetSize(12, 12)
		b.Icon = b:CreateTexture(nil, "ARTWORK")
		b.Icon:SetTexture(Theme.Media(Theme.Icon and Theme.Icon("info") or "info"))
		b.Icon:SetSize(8, 8)
		b.Icon:SetPoint("CENTER")
		b:SetScript("OnEnter", function(self)
			self.Icon:SetVertexColor(Theme.Color("textDim"))
			if GameTooltip then
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:SetText(self.psTip or "", 1, 1, 1, 1, true)
				GameTooltip:Show()
			end
		end)
		b:SetScript("OnLeave", function(self)
			self.Icon:SetVertexColor(Theme.Color("textMuted"))
			if GameTooltip then GameTooltip:Hide() end
		end)
		own.info = b
	end
	b.psTip = tip
	b.Icon:SetVertexColor(Theme.Color("textMuted"))
	b:ClearAllPoints()
	b:SetPoint("LEFT", label, "RIGHT", 1, 0)
	b:SetShown(label:IsShown())
	return b
end

-- While you're here: on its card, its label in caps as the other cards'.
-- Its panel and edge are Polestar's own textures (no hook hands them over),
-- out of sight while Atlas holds the part.
local function hereLook(here, on)
	local own = store(here)
	for _, t in ipairs({ here.Panel, here.Edge }) do
		if t and t.SetAlpha then t:SetAlpha(on and 0 or 1) end
	end
	if not here.Label then return end
	if on then
		own._label = own._label or here.Label:GetText()
		capsLabel(here.Label)
		here.Label:SetText(string.upper(own._label or ""))
		infoIcon(here, here.Label, tr("Get ahead, if possible"))
	elseif own._label then
		Theme.Font(here.Label, "small")
		here.Label:SetText(own._label)
		here.Label:SetTextColor(Theme.Accent())
		own._label = nil
		if own.info then own.info:Hide() end
	end
end

-- Its rows as the target's line: no step line under it and no × of its own
-- (the card's × stays), the count beside the distance ("2/12 · 80 yd").
-- An off-route timer's row keeps its line and its × (they are its point).
-- -> the height its rows gave up
local HERE_COUNT = "|c%x%x%x%x%x%x%x%x(%d+/%d+)|r"
local function hereRows(here)
	local shift = 0
	for _, r in ipairs(rawget(here, "Rows") or {}) do
		local own = store(r)
		if own.count then own.count:Hide() end
		if r:IsShown() and r.Text and r.Sub and r.Close and r.Dist and not r.psOff then
			if shift ~= 0 then
				local p, rel, rp, x, y = r:GetPoint(1)
				r:ClearAllPoints()
				r:SetPoint(p, rel, rp, x, (y or 0) + shift)
			end
			if r.Sub:IsShown() then
				local d = 2 + math.floor(r.Sub:GetStringHeight() + 0.5)
				r.Sub:Hide()
				own._sub = true
				r:SetHeight(math.max(1, (r:GetHeight() or 0) - d))
				shift = shift + d
			end
			if r.Close:IsShown() then
				r.Close:Hide()
				own._close = true
			end
			-- From Polestar's own line (UI.SetCounted keeps it), so a second
			-- layout finds the count it took out at the first.
			local text = type(r.Text.psCounted) == "string" and r.Text.psCounted or r.Text:GetText() or ""
			local count = text:match(HERE_COUNT) or text:match("%s(%d+/%d+)%s*$")
			if count then
				local left = text:gsub("%s*" .. HERE_COUNT, "", 1)
				if left == text then left = text:gsub("%s+%d+/%d+%s*$", "", 1) end
				r.Text:SetText(left)
				own._text = true
				if not own.count then
					own.count = r:CreateFontString(nil, "OVERLAY")
					own.count:SetJustifyH("RIGHT")
					own.count:SetWordWrap(false)
				end
				local c = own.count
				c:SetFont(r.Dist:GetFont())
				c:SetTextColor(Theme.Color("textMuted"))
				local dist = r.Dist:GetText()
				c:SetText(count .. ((dist and dist ~= "") and "  \194\183  " or ""))
				c:ClearAllPoints()
				c:SetPoint("RIGHT", r.Dist, "LEFT", 0, 0)
				c:Show()
				local w = r.Text:GetWidth() or 0
				if w > 0 then r.Text:SetWidth(math.max(40, w - math.ceil(c:GetStringWidth()) - 4)) end
			end
		end
	end
	return shift
end

-- Its rows back as Polestar laid them out.
local function hereRowsBack(here)
	for _, r in ipairs(rawget(here, "Rows") or {}) do
		local own = stores[r]
		if own then
			if own._sub then r.Sub:Show() end
			if own._close then r.Close:Show() end
			if own._text and type(r.Text.psCounted) == "string" then r.Text:SetText(r.Text.psCounted) end
			own._sub, own._close, own._text = nil, nil, nil
			if own.count then own.count:Hide() end
		end
	end
end

onLeave(function(parts)
	if parts.here then
		hereLook(parts.here, false)
		hereRowsBack(parts.here)
	end
end)

-- Along the way: the open goals of along steps the route has passed (and
-- pinned quests'), Polestar's own part on a card of its own, its heading in
-- caps as the other cards' ("ALONG THE WAY", "ALONG THE WAY, UNTIL STEP 30",
-- "STILL TO DO"), no rule over it. Its rows as While you're here's: the
-- count beside the distance ("6/10  ·  80 yd"), the "optional" tag kept in
-- the line; a click points the arrow (Polestar's own row does it).
local ALONG_EVERY = 0.25
local alongViews -- step:goal -> goal view, read once a render (guideRender)

local function alongLook(along, on)
	local own = store(along)
	if along.Rule and along.Rule.SetAlpha then along.Rule:SetAlpha(on and 0 or 1) end
	local label = along.Label
	if not label then return end
	if on then
		-- Polestar sets the heading at each render; a layout again finds it upper.
		local text = label:GetText() or ""
		if text ~= own._upper then own._label = text end
		capsLabel(label)
		own._upper = string.upper(own._label or "")
		label:SetText(own._upper)
		infoIcon(along, label, tr("Still open from steps you have passed"))
	elseif own._label then
		Theme.Font(label, "small")
		label:SetText(own._label)
		label:SetTextColor(Theme.Color("textMuted"))
		own._label, own._upper = nil, nil
		if own.info then own.info:Hide() end
	end
end

local function alongRowList(along)
	local list = {}
	for _, r in ipairs({ along:GetChildren() }) do
		if rawget(r, "Text") and rawget(r, "Icon") and r:IsShown() then list[#list + 1] = r end
	end
	table.sort(list, function(a, b)
		local _, _, _, _, ya = a:GetPoint(1)
		local _, _, _, _, yb = b:GetPoint(1)
		return (ya or 0) > (yb or 0)
	end)
	return list
end

-- A row's right side: its count and the distance to its goal, kept fresh.
local function alongMeta(r)
	local own = store(r)
	local m = own.meta
	if not m then
		m = CreateFrame("Frame", nil, r)
		m:SetAllPoints(r)
		m.Text = m:CreateFontString(nil, "OVERLAY")
		m.Text:SetJustifyH("RIGHT")
		m.Text:SetWordWrap(false)
		m:SetScript("OnUpdate", function(self, elapsed)
			self.psElapsed = (self.psElapsed or 0) + elapsed
			if self.psElapsed < ALONG_EVERY then return end
			self.psElapsed = 0
			if self.psPaint then self.psPaint() end
		end)
		own.meta = m
	end
	return m
end

-- -> the height the rows took on (a line the meta's room wrapped)
local function alongRows(along)
	local shift = 0
	for _, r in ipairs(alongRowList(along)) do
		local own = store(r)
		local m = alongMeta(r)
		if shift ~= 0 then
			local _, rel, _, x, y = r:GetPoint(1)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", rel, "TOPLEFT", x or 0, (y or 0) - shift)
			r:SetPoint("TOPRIGHT", rel, "TOPRIGHT", 0, (y or 0) - shift)
		end
		-- From Polestar's own line (UI.SetCounted keeps it), so a second
		-- layout finds the count it took out at the first.
		local text = type(r.Text.psCounted) == "string" and r.Text.psCounted or r.Text:GetText() or ""
		local count = text:match(HERE_COUNT)
		if count then
			r.Text:SetText((text:gsub("%s*" .. HERE_COUNT, "", 1)))
			own._text = true
		end
		r.Text:SetTextColor(Theme.Color("text"))
		own._color = true
		local view = alongViews and r.psStep and r.psGoal and alongViews[r.psStep .. ":" .. r.psGoal] or nil
		local function paint()
			local yards = view and Core.yardsTo(view)
			local dist = yards and Core.distanceText(yards)
			local meta = count and dist and (count .. "  \194\183  " .. dist) or count or dist
			m.Text:SetText(meta or "")
			return meta
		end
		m.Text:SetFont(r.Text:GetFont())
		m.Text:SetTextColor(Theme.Color("textMuted"))
		m.Text:ClearAllPoints()
		m.Text:SetPoint("TOPRIGHT", r, "TOPRIGHT", -OPT_PAD, -math.floor(((r:GetHeight() or 24) - (r.Text:GetLineHeight() or 12)) / 2 + 0.5))
		m.psPaint = view and paint or nil
		local meta = paint()
		m:SetShown(meta ~= nil)
		local w = r.Text:GetWidth() or 0
		if meta and w > 0 then
			-- Room for the widest the meta grows to as the distance changes.
			r.Text:SetWidth(math.max(40, w - math.ceil(m.Text:GetStringWidth()) - 18))
		end
		local need = math.ceil(r.Text:GetStringHeight() or 0) + 8
		local h = r:GetHeight() or 0
		if need > h then
			r:SetHeight(need)
			shift = shift + (need - h)
		end
	end
	return shift
end

local function alongRowsBack(along)
	for _, r in ipairs({ along:GetChildren() }) do
		local own = stores[r]
		if own then
			if own._text and type(r.Text.psCounted) == "string" then r.Text:SetText(r.Text.psCounted) end
			if own._color then r.Text:SetTextColor(Theme.Color("textDim")) end
			own._text, own._color = nil, nil
			if own.meta then
				own.meta.psPaint = nil
				own.meta:Hide()
			end
		end
	end
end

on("guideRender", function() alongViews = nil end)

onLeave(function(parts)
	if parts.along then
		alongLook(parts.along, false)
		alongRowsBack(parts.along)
	end
end)

-- A banner notice (Looking ahead, the tab just closed and its Reopen, a quest
-- left, a step skipped, the bags, a newer Polestar...) as a heads-up card on
-- top of the stack: Polestar's own banner, its text, its action link, Later
-- and its × as they are; the card's ground in place of its tint and rule.
local function bannerLook(banner, on)
	for _, t in ipairs({ banner.Fill, banner.Rule }) do
		if t and t.SetAlpha then t:SetAlpha(on and 0 or 1) end
	end
end

onLeave(function(parts) if parts.banner then bannerLook(parts.banner, false) end end)

-- The party's place on this guide (and "Go on without them") on a card:
-- Polestar's own line under a "PARTY" label, no rule over it.
local seenParty = setmetatable({}, { __mode = "k" })
local function partyLook(party, on)
	if on then seenParty[party] = true end
	if party.Rule and party.Rule.SetAlpha then party.Rule:SetAlpha(on and 0 or 1) end
end

-- The card that holds the party line: its label, the line under it.
local function partyCard(stack, party)
	local c = stack.party
	if not c then
		c = CreateFrame("Frame", nil, stack)
		c.Label = c:CreateFontString(nil, "OVERLAY")
		stack.party = c
	end
	capsLabel(c.Label)
	c.Label:SetText(string.upper(tr("Party")))
	c.Label:ClearAllPoints()
	c.Label:SetPoint("TOPLEFT", c, "TOPLEFT", OPT_PAD, -8)
	local top = 8 + math.ceil(c.Label:GetStringHeight())
	party:SetParent(c)
	party:ClearAllPoints()
	party:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -top)
	party:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -top)
	party:Show()
	c:SetHeight(top + (party:GetHeight() or 28) + 2)
	return c
end

-- The party line is not among the parts handed over: the layout leaving a
-- window gives the ones it saw in that window their rule back.
onLeave(function(parts, live)
	for party in pairs(seenParty) do
		if Core.leaves(party, parts, live) then partyLook(party, false) end
	end
end)

-- The training reminder as a card: "TRAINING DUE", the trainer line and the
-- place on its right; × puts it off (Later), a click takes it up.
local function trainCard(stack)
	if stack.train then return stack.train end
	local f = CreateFrame("Button", nil, stack)
	f.Label = f:CreateFontString(nil, "OVERLAY")
	f.Icon = f:CreateTexture(nil, "ARTWORK")
	f.Icon:SetSize(15, 15)
	f.Text = f:CreateFontString(nil, "OVERLAY")
	f.Text:SetWordWrap(false)
	f.Text:SetJustifyH("LEFT")
	f.Place = f:CreateFontString(nil, "OVERLAY")
	f.Place:SetJustifyH("RIGHT")
	f.Place:SetWordWrap(false)
	f:SetScript("OnClick", function(self) if self.psTrainer then Core.takeNotice() end end)
	stack.train = f
	return f
end

local function fillTrain(f, width)
	local advice = Core.training()
	local trainer = not advice.guide and advice.trainer or nil
	local place = (advice.title and advice.title ~= "" and advice.title)
		or (trainer and (trainer.npcName or (trainer.map and Core.mapName(trainer.map)))) or nil
	f.psTrainer = trainer
	capsLabel(f.Label)
	f.Label:SetText(string.upper(tr("Training due")))
	f.Label:ClearAllPoints()
	f.Label:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -8)
	Theme.Font(f.Text, "small")
	f.Text:SetTextColor(Theme.Color("text"))
	f.Text:SetText(tr("New spells at your class trainer"))
	Theme.Font(f.Place, "small")
	f.Place:SetTextColor(Theme.Color("textMuted"))
	f.Place:SetText(place or "")
	f.Place:SetShown(place ~= nil)
	f.Icon:SetTexture(Theme.VerbIcon("talk"))
	f.Icon:SetVertexColor(Theme.Color("npc"))
	local rowY = -8 - f.Label:GetStringHeight() - 4
	f.Icon:ClearAllPoints()
	f.Icon:SetPoint("CENTER", f, "TOPLEFT", 14 + 7.5, rowY - 10)
	f.Place:ClearAllPoints()
	f.Place:SetPoint("RIGHT", f, "TOPRIGHT", -30, rowY - 10)
	f.Place:SetWidth(math.min(f.Place:GetStringWidth() + 1, 120))
	f.Text:ClearAllPoints()
	f.Text:SetPoint("LEFT", f, "TOPLEFT", 39, rowY - 10)
	f.Text:SetPoint("RIGHT", f.Place, "LEFT", -8, 0)
	f:SetSize(width, math.floor(8 + f.Label:GetStringHeight() + 4 + 20 + 6 + 0.5))
	return f
end

-- Optional: the step's optional goals and its notes, taken out of the goal
-- list (guideTakes) onto a card of their own. A row aims the arrow, Skip
-- puts the goal by, and the count and the distance sit on its right.
local opt = setmetatable({}, { __mode = "k" }) -- window -> { step, goals, notes, sig }

local function takesOut(goal)
	return (goal.optional or goal.t == "note") and true or false
end
on("guideTakes", function(goal) return takesOut(goal) or nil end)

local function optCard(stack)
	if stack.opt then return stack.opt end
	local c = CreateFrame("Frame", nil, stack)
	c.Label = c:CreateFontString(nil, "OVERLAY")
	c.Rows, c.Notes = {}, {}
	stack.opt = c
	return c
end

local function optMeta(r)
	local goal = r._goal
	local target = Core.target()
	local active = not goal.previewOnly and not goal.dismissed and goal.status ~= "done" and goal.status ~= "skipped"
	local aimed = active and target and ((target.stepIndex == r.psStep and target.goalIndex == goal.index) or r._point == target)
	r.Mark:SetShown(aimed and true or false)
	local yards
	if active then
		if aimed then yards = Core.distance() end
		yards = yards or Core.yardsTo(goal)
	end
	local count = Core.goalProgress(goal)
	local dist = yards and Core.distanceText(yards)
	local meta = count and dist and (count .. "  \194\183  " .. dist) or count or dist
	r.Meta:SetText(meta or "")
	r.Meta:SetShown(meta ~= nil)
	local right = r.psMetaRight + (meta and math.ceil(r.Meta:GetUnboundedStringWidth()) + 6 or 0)
	r.Text:SetWidth(math.max(40, r.psWidth - (OPT_PAD + 12 + 6) - right - 2))
end

local function optRow(c, i)
	local r = c.Rows[i]
	if r then return r end
	r = CreateFrame("Button", nil, c)
	r.Mark = r:CreateTexture(nil, "ARTWORK")
	r.Mark:SetTexture(Theme.Media("white"))
	r.Mark:SetWidth(2)
	r.Mark:SetPoint("TOPLEFT", r, "TOPLEFT", OPT_PAD - 5, -2)
	r.Mark:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", OPT_PAD - 5, 2)
	r.Mark:Hide()
	r:SetScript("OnClick", function(self)
		local goal = self._goal
		if not goal or goal.previewOnly or goal.dismissed or goal.status == "done" or goal.status == "skipped" then return end
		self._point = Core.aim(goal)
		optMeta(self)
	end)
	r:SetScript("OnUpdate", function(self, elapsed)
		self.psElapsed = (self.psElapsed or 0) + elapsed
		if self.psElapsed < 0.25 or not self._goal then return end
		self.psElapsed = 0
		optMeta(self)
	end)
	r.Icon = r:CreateTexture(nil, "ARTWORK")
	r.Icon:SetSize(12, 12)
	r.Icon:SetPoint("LEFT", r, "LEFT", OPT_PAD, 0)
	r.Text = r:CreateFontString(nil, "OVERLAY")
	Theme.Font(r.Text, "small")
	r.Text:SetJustifyH("LEFT")
	r.Text:SetWordWrap(false)
	r.Meta = r:CreateFontString(nil, "OVERLAY")
	Theme.Font(r.Meta, "small")
	r.Meta:SetJustifyH("RIGHT")
	r.Skip = CreateFrame("Button", nil, r)
	r.Skip.Label = r.Skip:CreateFontString(nil, "OVERLAY")
	Theme.Font(r.Skip.Label, "small")
	r.Skip.Label:SetPoint("CENTER")
	r.Skip:SetScript("OnClick", function() if r._goal then Core.skipGoal(r.psStep, r._goal.index) end end)
	r.Skip:SetScript("OnEnter", function(b) b.Label:SetTextColor(Theme.Color("text")) end)
	r.Skip:SetScript("OnLeave", function(b) b.Label:SetTextColor(Theme.Color("textDim")) end)
	c.Rows[i] = r
	return r
end

-- Filled from the step on screen (guideRender), laid out with the stack.
local function fillOptional(view, parts)
	local window = parts and parts.window
	if not window then return end
	local o = opt[window] or {}
	opt[window] = o
	o.goals, o.notes, o.step = {}, {}, view and view.index or nil
	local sig = {}
	for _, goal in ipairs(view and view.goals or {}) do
		if goal.status ~= "na" and not goal.folded and takesOut(goal) then
			local list = goal.t == "note" and o.notes or o.goals
			list[#list + 1] = goal
			sig[#sig + 1] = goal.index .. (goal.status or "") .. (goal.dismissed and "d" or "")
		end
	end
	-- The render comes after the layout: lay out again when the card's content changed.
	local now = (o.step or 0) .. ":" .. table.concat(sig, ",")
	if now ~= o.sig then
		o.sig = now
		local live = Theme.GuideParts and Theme.GuideParts()
		if live and live.window == window then Core.relayout() end
	end
end

local function layoutOptional(stack, window, step)
	local c = optCard(stack)
	local o = opt[window]
	local n, m = o and #o.goals or 0, o and #o.notes or 0
	if n + m == 0 or closedOn.opt == step then
		c:Hide()
		return nil
	end
	local width = window:GetWidth() or 0
	local lh = 9
	for i = 1, m do
		local fs = c.Notes[i]
		if not fs then
			fs = c:CreateFontString(nil, "OVERLAY")
			Theme.Font(fs, "label")
			fs:SetJustifyH("LEFT")
			fs:SetJustifyV("TOP")
			fs:SetWordWrap(true)
			c.Notes[i] = fs
		end
		fs:SetTextColor(Theme.Color("quest"))
		fs:SetText(Core.goalText(o.notes[i]))
		fs:SetWidth(math.max(40, width - OPT_PAD * 2 - 18))
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", c, "TOPLEFT", OPT_PAD, -lh)
		fs:Show()
		lh = lh + math.floor(fs:GetStringHeight() + 0.5) + 3
	end
	for i = m + 1, #c.Notes do c.Notes[i]:Hide() end
	c.Label:ClearAllPoints()
	c.Label:SetPoint("TOPLEFT", c, "TOPLEFT", OPT_PAD, -lh)
	capsLabel(c.Label)
	c.Label:SetText(string.upper(tr("Optional")))
	c.Label:SetShown(n > 0)
	infoIcon(c, c.Label, tr("Optional objectives during this step"))
	if n > 0 then lh = lh + math.ceil(c.Label:GetStringHeight()) + 3 end
	for i = 1, n do
		local goal = o.goals[i]
		local r = optRow(c, i)
		local done, dismissed = goal.status == "done", goal.dismissed
		if not r._goal or r._goal.index ~= goal.index or r.psStep ~= o.step then r._point = nil end
		r._goal, r.psStep = goal, o.step
		r.Mark:SetVertexColor(Theme.Accent())
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -lh)
		r:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -lh)
		r:SetHeight(OPT_ROW)
		r.Icon:SetTexture(done and Theme.Media("check") or (dismissed and Theme.Media("skip")) or Theme.VerbIcon(goal.t))
		r.Icon:SetVertexColor(Theme.Color(done and "success" or "textDim"))
		r.Text:SetText((done or dismissed) and Core.plainGoalText(goal) or Core.goalText(goal))
		r.Text:SetTextColor(Theme.Color((done or dismissed) and "textMuted" or "text"))
		r.Meta:SetTextColor(Theme.Color("textMuted"))
		local right = OPT_PAD
		r.Skip.Label:SetText(dismissed and tr("Undo") or tr("Skip"))
		r.Skip.Label:SetTextColor(Theme.Color("textDim"))
		local canSkip = not done and not goal.previewOnly and Core.canSkip()
		r.Skip:SetShown(canSkip and true or false)
		if canSkip then
			r.Skip:SetSize(math.floor(r.Skip.Label:GetStringWidth() + 8 + 0.5), 14)
			r.Skip:ClearAllPoints()
			r.Skip:SetPoint("RIGHT", r, "RIGHT", -right, 0)
			right = right + r.Skip:GetWidth() + 6
		end
		r.Meta:ClearAllPoints()
		r.Meta:SetPoint("RIGHT", r, "RIGHT", -right, 0)
		r.Text:ClearAllPoints()
		r.Text:SetPoint("LEFT", r.Icon, "RIGHT", 6, 0)
		r.psMetaRight, r.psWidth = right, width
		optMeta(r)
		r:Show()
		lh = lh + OPT_ROW
	end
	for i = n + 1, #c.Rows do
		c.Rows[i]:Hide()
		c.Rows[i]._goal = nil
	end
	c:SetHeight(lh + 6)
	return c
end

if has("guideTakes") then
	on("guideRender", function(view, parts) fillOptional(view, parts) end)
end
on("guideRender", function(view, parts) if parts.window then stepOf[parts.window] = view and view.index or nil end end)

-- The class guide on offer: the heads-up card above the window (×, Later),
-- not a banner in it. Shown once per notice; its buttons are the banner's
-- own (open the guide in a tab, Later).
local headsUpFor
local function classHeadsUp(n)
	if headsUpFor == n then return true end
	local shown = Core.showHeadsUp({
		head = string.upper(tr("Class quest")),
		title = n.title or "",
		giver = n.heads, route = n.why,
		icon = Theme.Media("icon-train"), iconColor = "accent",
		act = { label = tr("Open in a tab"), run = function() Core.takeNotice(); Core.hideHeadsUp() end },
		later = { label = tr("Later"), run = function() Core.laterNotice() end },
	})
	if shown then headsUpFor = n end
	return shown
end

-- The class quest card (in the window under Polestar's own layout) as a
-- card above it, its × putting the chain away for the session.
local classShut = {}

on("guidePlace", function(name, part, width, height)
	if name == "here" then
		hereLook(part, true)
		local h = math.max(1, height - hereRows(part))
		part:SetHeight(h)
		local body = rawget(part, "Body")
		if type(body) == "table" and body.SetHeight then body:SetHeight(h) end
		slots.here = part
		return true
	end
	if name == "banner" and part.psKind == "classQuest" then
		local _, n = Core.notice()
		if n and classHeadsUp(n) then
			part:Hide()
			return true
		end
	elseif name == "banner" and part.psKind == "train" then
		slots.train = part
		part:Hide()
		return true
	end
	if name == "classCard" then
		local key = Core.classCardKey()
		if key and classShut[key] then
			part:Hide()
			return true
		end
		part:SetHeight(height)
		slots.class, slots.classKey = part, key
		return true
	end
	if name == "journey" and not compact() then
		part:SetHeight(height)
		slots.journey = part
		return true
	end
	-- Every other banner notice: a heads-up card on top of the stack.
	if name == "banner" then
		bannerLook(part, true)
		part:SetHeight(height)
		slots.banner = part
		return true
	end
	if name == "along" then
		alongViews = alongViews or Core.alongGoals()
		alongLook(part, true)
		part:SetHeight(height + alongRows(part))
		slots.along = part
		return true
	end
	if name == "party" then
		partyLook(part, true)
		part:SetHeight(height)
		slots.party = part
		return true
	end
end)

local function layoutStack(parts)
	local window = parts.window
	local stack = stackFrame(window)
	local step = stepOf[window]
	if closedOn.here and closedOn.here ~= step then closedOn.here = nil end
	if closedOn.opt and closedOn.opt ~= step then closedOn.opt = nil end
	if closedOn.along and closedOn.along ~= step then closedOn.along = nil end
	if closedOn.party and closedOn.party ~= step then closedOn.party = nil end
	local list = {}
	local function add(f, close) list[#list + 1] = { f = f, close = close } end
	local function relay() Core.relayout() end
	local s = slots
	-- A banner notice keeps its own × (and Later): none of the card's.
	if s.banner and isUnder(s.banner, window) then add(s.banner, nil) end
	if s.class and isUnder(s.class, window) then
		local key = s.classKey
		add(s.class, function() if key then classShut[key] = true end relay() end)
	end
	if s.here and isUnder(s.here, window) then
		if closedOn.here == step then s.here:Hide() else add(s.here, function() closedOn.here = step relay() end) end
	end
	if s.along and isUnder(s.along, window) then
		if closedOn.along == step then s.along:Hide() else add(s.along, function() closedOn.along = step relay() end) end
	end
	local optional = layoutOptional(stack, window, step)
	if optional then add(optional, function() closedOn.opt = step relay() end) end
	if s.train and isUnder(s.train, window) then
		add(fillTrain(trainCard(stack), window:GetWidth() or 300), Core.laterNotice)
	elseif stack.train then
		stack.train:Hide()
	end
	if s.party and isUnder(s.party, window) and closedOn.party ~= step then
		add(partyCard(stack, s.party), function() closedOn.party = step relay() end)
	elseif s.party then
		s.party:Hide()
	end
	if not (s.party and stack.party and s.party:GetParent() == stack.party) and stack.party then stack.party:Hide() end
	slots = {}
	local width = window:GetWidth() or 300
	local y = 0
	for i = #list, 1, -1 do
		local f = list[i].f
		local h = f:GetHeight() or 0
		local b = backing(stack, i)
		b:ClearAllPoints()
		b:SetPoint("BOTTOMLEFT", stack, "BOTTOMLEFT", 0, y)
		b:SetSize(width, h)
		dress(b, window)
		b:Show()
		b.Close.psClose = list[i].close
		b.Close.Icon:SetVertexColor(Theme.Color("textMuted"))
		b.Close:SetFrameLevel(b:GetFrameLevel() + 5)
		b.Close:SetShown(list[i].close ~= nil)
		f:SetParent(b)
		f:SetFrameLevel(b:GetFrameLevel() + 1)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
		f:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
		f:Show()
		-- A badge on the class card steps left of the ×.
		local badge = rawget(f, "Badge")
		if type(badge) == "table" and badge:IsShown() then
			badge:ClearAllPoints()
			badge:SetPoint("TOPRIGHT", f, "TOPRIGHT", -26, -10)
		end
		y = y + h + GAP
	end
	for i = #list + 1, #stack.cards do stack.cards[i]:Hide() end
	if #list > 0 then
		stack:SetHeight(y - GAP)
		stack:Show()
	else
		stack:Hide()
	end
end

-- The Journey: collapsed on a card joined to the window's foot.
local function layoutBottom(parts, journey)
	local window = parts.window
	local own = store(window)
	if not journey and not own.bottom then return end
	if not own.bottom then
		local b = CreateFrame("Frame", nil, window)
		b:SetPoint("TOPLEFT", window, "BOTTOMLEFT", 0, 0)
		b:SetPoint("TOPRIGHT", window, "BOTTOMRIGHT", 0, 0)
		b:SetHeight(1)
		b.psGuide = true
		Theme.Skin(b, "guide")
		own.bottom = b
	end
	local b = own.bottom
	if journey and isUnder(journey, window) then
		journey:SetParent(b)
		journey:ClearAllPoints()
		journey:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
		journey:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
		dress(b, window)
		b:SetHeight((journey:GetHeight() or 0) + 2)
		b:Show()
	else
		b:Hide()
	end
end

on("guideLayout", function(parts)
	if not parts.window then return end
	local journey = slots.journey
	layoutStack(parts)
	layoutBottom(parts, journey)
end)

-- The heads-up card stands on the stack, over the cards.
on("guideAnchor", function()
	local parts = Theme.GuideParts and Theme.GuideParts()
	local own = parts and parts.window and stores[parts.window]
	if own and own.stack and own.stack:IsShown() then return own.stack end
end)

-- The class quest card's own "Later" row: the × does it.
on("guideShows", function(what, shown)
	if what == "classCardLater" then return false end
	return shown
end)

---------------------------------------------------------------------------
-- The step as a node on the timeline: its title in semibold with its area on
-- the right, one line per goal with its action icon, the live goal in
-- semibold with its count in the accent, each quest's level after it, an
-- objective's quest on the line under it, the counts in a column on the
-- right. The window's top bar fills as the guide goes.
---------------------------------------------------------------------------

local TITLE_PAD = 10
local TITLE_UP = 1 -- the step title over the goal lines, in px

local function plainText(s) return ((s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- The step's title (guidePerson): the heading's state before Atlas changed
-- it is kept under _header, and given back when the layout leaves.
local function headerBack(person)
	local own = person and stores[person]
	local was = own and own._header
	if not was then return end
	own._header = nil
	person.Name:SetFont(was.font[1], was.font[2], was.font[3])
	person.Name:SetWordWrap(was.wrap)
	person.Name:ClearAllPoints()
	person.Name:SetPoint(unpack(was.name))
	person.Where:ClearAllPoints()
	person.Where:SetPoint(unpack(was.where))
	person.Where:SetJustifyH(was.justify)
	-- Polestar's own role for it (UI/GuideFrame.lua), so a later repaint
	-- keeps it: Theme.Font above gave the string the goal role.
	Theme.Font(person.Where, "small")
	person.Where:SetTextColor(Theme.Color("textDim"))
	if person.Icon then person.Icon:SetAlpha(1) end
end
onLeave(function(parts) headerBack(parts.person) end)

local function stepHeader(person, width)
	if not (person.Name and person.Where and person.Why and person.Level) then return nil end
	local own = store(person)
	if not own._header then
		own._header = {
			font = { person.Name:GetFont() },
			wrap = person.Name:CanWordWrap(),
			name = { person.Name:GetPoint(1) },
			where = { person.Where:GetPoint(1) },
			justify = person.Where:GetJustifyH(),
		}
	end
	local _, goalSize, flags = probe("goal")
	local path = semibold() or own._header.font[1]
	person.Name:SetFont(path, goalSize + TITLE_UP, flags)
	Theme.Font(person.Where, "goal")
	person.Where:SetTextColor(Theme.Color("textMuted"))
	person.Name:SetWordWrap(false)
	if person.Icon then person.Icon:SetAlpha(0) end
	person.Level:Hide()
	local pad = (not compact() and has("guideInset")) and 11 or 14
	local whereW = 0
	if person.Where:IsShown() then
		whereW = math.min(person.Where:GetUnboundedStringWidth() + 1, math.floor(width * 0.45))
		person.Where:SetWidth(whereW)
		person.Where:SetJustifyH("RIGHT")
	end
	person.Name:ClearAllPoints()
	person.Name:SetPoint("TOPLEFT", person, "TOPLEFT", pad, -TITLE_PAD)
	person.Name:SetWidth(width - (whereW > 0 and whereW + 10 or 0))
	-- The area sits on the title's row, at the right edge.
	if whereW > 0 then
		person.Where:ClearAllPoints()
		person.Where:SetPoint("TOP", person.Name, "TOP", 0, 0)
		person.Where:SetPoint("RIGHT", person, "RIGHT", -pad, 0)
		person.Where:SetPoint("BOTTOM", person.Name, "BOTTOM", 0, 0)
	end
	local h = TITLE_PAD + person.Name:GetStringHeight()
	if person.Why:IsShown() then
		person.Why:SetWidth(width)
		person.Why:ClearAllPoints()
		person.Why:SetPoint("TOPLEFT", person.Name, "BOTTOMLEFT", 0, -3)
		h = h + 3 + person.Why:GetStringHeight()
	end
	return h + 8
end
on("guidePerson", function(person, width) return stepHeader(person, width) end)

-- A line under the step's title.
local function underline(person)
	if not person then return end
	local own = store(person)
	if not own.under then
		own.under = person:CreateTexture(nil, "ARTWORK")
		own.under:SetTexture(Theme.Media("white"))
	end
	local r, g, b = Theme.Color("textMuted")
	own.under:ClearAllPoints()
	own.under:SetPoint("BOTTOMLEFT", person, "BOTTOMLEFT", 12, 0)
	own.under:SetPoint("BOTTOMRIGHT", person, "BOTTOMRIGHT", -12, 0)
	own.under:SetHeight(pixel(person))
	own.under:SetVertexColor(r, g, b, 0.35)
	own.under:Show()
end
on("guideRender", function(view, parts) underline(parts.person) end)

-- A goal row (guideRow; Polestar paints the row again at every fill, so a
-- row keeps Atlas's look only while Atlas is the layout). The row's font
-- before Atlas is kept under _font.
local function rowBack(row)
	local own = stores[row]
	if not own then return end
	if own._font then
		row.Text:SetFont(own._font[1], own._font[2], own._font[3])
		own._font = nil
	end
	if own.level then own.level:Hide() end
	if own.count then own.count:Hide() end
	row.psLevelWidth = nil
	if own._single then
		row.Text:SetWordWrap(true)
		row.Text:SetMaxLines(2)
		own._single = nil
	end
	if row.Check then
		row.Check:SetAlpha(1)
		row.Check:Enable()
	end
end
onLeave(function(parts)
	for _, row in ipairs(parts.rows or {}) do
		rowBack(row)
		local own = stores[row]
		if own and own._alt then
			own._alt = nil
			if row.Alt then row.Alt:Show() end
		end
	end
end)

-- Sub-text `sub` without its line `line` (both as shown, colours aside):
-- nil when nothing is left.
local function dropLine(sub, line)
	local want, out = plainText(line), {}
	for l in (sub .. "\n"):gmatch("(.-)\n") do
		if plainText(l) ~= want then out[#out + 1] = l end
	end
	return #out > 0 and table.concat(out, "\n") or nil
end

-- The goal's spots line goes (the arrow leads through the spots); on the
-- rail the next-spot button goes too (a click on the arrow moves on).
local function spotsOff(row, goal, own)
	local area = Core.areaLine(goal)
	local sub = area and row.Sub and row.Sub:IsShown() and row.Sub:GetText() or nil
	if sub then
		local left = dropLine(sub, area)
		row.Sub:SetText(left or "")
		row.Sub:SetShown(left ~= nil)
	end
	own._alt = nil
	if row.Alt and row.Alt:IsShown() and not compact() and has("guideInset") then
		row.Alt:Hide()
		own._alt = true
	end
end

local function goalRow(row, goal, info)
	local own = store(row)
	rowBack(row)
	spotsOff(row, goal, own)
	local text = row.Text:GetText() or ""
	local live = info.current and not info.done and not info.skipped
	own._single = true
	row.Text:SetWordWrap(false)
	row.Text:SetMaxLines(1)
	local path, size, flags = row.Text:GetFont()
	if path and size then
		own._font = { path, size, flags }
		row.Text:SetFont((live and semibold()) or path, math.max(8, size - 2), flags)
	end
	if live and goal.progress then
		text = text:gsub("|c%x%x%x%x%x%x%x%x(%d+/%d+)|r", "|c" .. Theme.Hex("accent") .. "%1|r")
	end
	local muted = Theme.Hex("textMuted")
	if info.skipped or not goal.quest then
		row.Text:SetText(text)
		return
	end
	local lvl = Core.questLevel(goal.quest)
	if goal.t == "accept" or goal.t == "turnin" then
		-- The line names the quest already: its level after it.
		if lvl then
			if not own.level then own.level = row:CreateFontString(nil, "OVERLAY") end
			local label = own.level
			Theme.Font(label, "small")
			label:SetTextColor(Theme.Color("textMuted"))
			label:SetText("[" .. lvl .. "]")
			label:ClearAllPoints()
			label:SetPoint("LEFT", row.Text, "RIGHT", 5, 0)
			label:Show()
			row.psLevelWidth = math.ceil(label:GetUnboundedStringWidth()) + 6
		end
		row.Text:SetText(text)
		return
	end
	row.Text:SetText(text)
	-- An objective: its quest and level on the line under it.
	local title = Core.questTitle(goal.quest)
	if not (title and row.Sub) then return end
	local sub = row.Sub:IsShown() and row.Sub:GetText() or nil
	if sub and plainText(sub):find(title, 1, true) then return end
	local line = title .. (lvl and ("  |c" .. muted .. "[" .. lvl .. "]|r") or "")
	row.Sub:SetText((sub and sub ~= "") and (line .. "\n" .. sub) or line)
	row.Sub:Show()
end

-- The count in a column on the right. The tick stays laid out (its room
-- keeps the column clear) but unseen and off.
local COUNT = "|c%x%x%x%x%x%x%x%x(%d+/%d+)|r"
local function countColumn(row, info)
	local own = store(row)
	if row.Check and row.Check:IsShown() then
		row.Check:SetAlpha(0)
		row.Check:Disable()
	end
	local text = row.Text:GetText() or ""
	local count = text:match(COUNT) or text:match("%s(%d+/%d+)%s*$")
	if not count then return end
	text = text:gsub("%s*" .. COUNT, "", 1)
	if text == row.Text:GetText() then text = text:gsub("%s+%d+/%d+%s*$", "", 1) end
	row.Text:SetText(text)
	if not own.count then
		own.count = row:CreateFontString(nil, "OVERLAY")
		own.count:SetJustifyH("RIGHT")
	end
	local path, size, flags = row.Text:GetFont()
	own.count:SetFont(path, size, flags)
	own.count:SetText(count)
	if info.current and not info.done and not info.skipped then
		own.count:SetTextColor(Theme.Accent())
	else
		own.count:SetTextColor(Theme.Color(info.done and "textMuted" or "textDim"))
	end
	own.count:ClearAllPoints()
	own.count:SetPoint("TOPRIGHT", row, "TOPRIGHT", -14, -4)
	own.count:Show()
end

on("guideRow", function(row, goal, info)
	if not (row.Text and goal and info) then return end
	goalRow(row, goal, info)
	countColumn(row, info)
end)

-- After the rows are laid out: "Other" (the next spot) in the count's
-- column, on the line under the count.
on("guideLayout", function(parts)
	for _, row in ipairs(parts.rows or {}) do
		local own = stores[row]
		local count = own and own.count
		local alt = row.Alt
		if row:IsShown() and alt and alt:IsShown() and alt.Icon then
			local inset = (alt:GetWidth() - alt.Icon:GetWidth()) / 2
			alt:ClearAllPoints()
			if count and count:IsShown() then
				alt:SetPoint("TOPRIGHT", count, "BOTTOMRIGHT", inset, -1)
			else
				alt:SetPoint("TOPRIGHT", row, "TOPRIGHT", -14 + inset, -2)
			end
		end
	end
end)

-- The top bar fills as the guide goes: a soft wash in the accent, a 2px
-- accent edge along its foot. The transparent window has no bar to fill.
on("guideProgress", function(foot, frac)
	local parts = Theme.GuideParts and Theme.GuideParts()
	local nav = parts and parts.nav
	if not (nav and parts.window and isUnder(foot, parts.window)) then return end
	local own = store(nav)
	if parts.window.psBare then
		if own.fill then own.fill:Hide(); own.edge:Hide() end
		return
	end
	if not own.fill then
		own.fill = nav:CreateTexture(nil, "BACKGROUND", nil, 2)
		own.fill:SetTexture(Theme.Media("white"))
		own.edge = nav:CreateTexture(nil, "ARTWORK")
		own.edge:SetTexture(Theme.Media("white"))
	end
	local w = math.max(0.01, (nav:GetWidth() or 0) * math.min(1, math.max(0, tonumber(frac) or 0)))
	local r, g, b = Theme.Accent()
	own.fill:ClearAllPoints()
	own.fill:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, 0)
	own.fill:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 0, 0)
	own.fill:SetWidth(w)
	own.fill:SetVertexColor(r, g, b, 0.10)
	own.edge:ClearAllPoints()
	own.edge:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 0, 0)
	own.edge:SetSize(w, 2 * pixel(nav))
	own.edge:SetVertexColor(r, g, b, 1)
	own.fill:Show()
	own.edge:Show()
end)

---------------------------------------------------------------------------
-- The rail: a line down the window's left from the steps before's nodes
-- (each a disc in the success colour once done, hollow when skipped; the
-- player's guideWindow.lastSteps, 1 by Atlas's default) through the current step's
-- (a disc in the accent) to the steps in Up next (hollow nodes, fainter
-- ahead).
-- The card and Up next are set in from it (guideInset); each Up next row is
-- its first goal on one line with its zone on the right (guideUpRow). The
-- "after" line is not shown: the rail shows the next step already. Out of
-- compact mode only, and only where Polestar sets parts in (guideInset).
---------------------------------------------------------------------------

local CARD_X, UP_X, RAIL = 22, 13, 15 -- the card's and Up next's insets, the rail's x
local FADE = { 0.9, 0.65, 0.4 } -- the steps ahead, fainter further on

local function onRail() return not compact() and has("guideInset") end

on("guideInset", function(name)
	if not onRail() then return nil end
	if name == "card" then return CARD_X end
	if name == "upnext" then return UP_X end
end)

-- Done goals stay in place; the goals do not scroll on their own; on the
-- rail Up next has no heading to open it by.
on("guideShows", function(what, shown)
	if what == "done" then return true end
	if what == "goalScroll" then return false end
	if what == "upnextHead" then return not onRail() end
	return shown
end)

-- Up next's rows, in order.
local function upRows(frame)
	local rows = {}
	if not (frame and frame:IsShown()) then return rows end
	for _, r in ipairs({ frame:GetChildren() }) do
		if type(rawget(r, "Num")) == "table" and rawget(r, "psIndex") and r:IsShown() then rows[#rows + 1] = r end
	end
	table.sort(rows, function(a, b) return a.psIndex < b.psIndex end)
	return rows
end

-- A step's line on the rail: its first goal that is not a walk, in the
-- goal's words, and the zone it is in.
local function stepLine(v)
	local first, place
	for _, g in ipairs(v.goals or {}) do
		if g.status ~= "na" then
			if not place and g.map then place = Core.mapName(g.map) end
			if not first and g.t ~= "goto" then first = g end
		end
	end
	first = first or (v.goals and v.goals[1])
	return first and Core.goalText(first) or Core.stepSummary(v) or "", place
end

-- An Up next row (guideUpRow; Polestar sets the row again at every fill).
on("guideUpRow", function(row, v)
	if type(rawget(row, "Text")) ~= "table" then return end
	local own = store(row)
	if not onRail() then
		if own.zone then own.zone:Hide() end
		return
	end
	local text, place = stepLine(v or {})
	row.Text:SetText(text)
	row.Text:SetTextColor(Theme.Color("textDim"))
	row.Text:SetMaxLines(1)
	if not own.zone then
		own.zone = row:CreateFontString(nil, "OVERLAY")
		Theme.Font(own.zone, "label")
		own.zone:SetJustifyH("RIGHT")
		own.zone:SetWordWrap(false)
	end
	own.zone:SetText(place or "")
	own.zone:SetTextColor(Theme.Color("textMuted"))
	own.zone:ClearAllPoints()
	own.zone:SetPoint("RIGHT", row, "TOPRIGHT", -14, -12)
	own.zone:SetShown(place ~= nil)
	row:Show()
end)

-- Up next's rows fade ahead; each text stops short of its zone. A row not
-- yet laid out (no width) takes Up next's width (`width`, from guidePlace);
-- with neither, its text keeps Polestar's width.
local function upFit(frame, width)
	local rows = upRows(frame)
	for i, r in ipairs(rows) do
		r:SetAlpha(onRail() and (FADE[i] or FADE[#FADE]) or 1)
		if onRail() then
			local zone = stores[r] and stores[r].zone
			local zw = (zone and zone:IsShown()) and math.min(zone:GetStringWidth() + 1, 110) or 0
			if zone then zone:SetWidth(zw) end
			local left = 59 -- Polestar's text column in the row
			local rw = r:GetWidth()
			if not (type(rw) == "number" and rw > 0) then rw = tonumber(width) end
			if rw and rw > 0 then r.Text:SetWidth(math.max(40, rw - left - 14 - (zw > 0 and zw + 8 or 0))) end
		end
	end
end
onLeave(function(parts) for _, r in ipairs(upRows(parts.upnext)) do r:SetAlpha(1) end end)

on("guidePlace", function(name, part, width)
	if name == "after" and onRail() then
		part:Hide()
		return true
	end
	if name == "upnext" then upFit(part, width) end
end)

-- A node: a disc, with a ring of the window's ground round it (the current
-- step) or a hollow middle (the steps ahead).
local function node(holder, key, parent)
	local n = holder[key]
	if n then return n end
	n = {}
	for i, part in ipairs({ "ring", "disc", "hole" }) do
		local t = parent:CreateTexture(nil, "OVERLAY", nil, i)
		t:SetTexture(Theme.Media("circle"))
		n[part] = t
	end
	holder[key] = n
	return n
end

local function paintNode(n, current, alpha)
	local br, bg, bb = Theme.Color("bg")
	local size = current and 10 or 8
	n.ring:SetSize(size + 6, size + 6)
	n.ring:SetVertexColor(br, bg, bb, current and 1 or 0)
	n.disc:SetSize(size, size)
	n.hole:SetSize(size - 2, size - 2)
	if current then
		local r, g, b = Theme.Accent()
		n.disc:SetVertexColor(r, g, b, 1)
		n.hole:SetVertexColor(0, 0, 0, 0)
	else
		local r, g, b = Theme.Color("textDim")
		n.disc:SetVertexColor(r, g, b, 0.42 * alpha)
		n.hole:SetVertexColor(br, bg, bb, 1)
	end
end

local function placeNode(n, rel, point, x, y)
	for _, part in ipairs({ "ring", "disc", "hole" }) do
		local t = n[part]
		t:ClearAllPoints()
		t:SetPoint("CENTER", rel, point, x, y)
		t:Show()
	end
end

local function hideNode(n)
	if n then n.ring:Hide(); n.disc:Hide(); n.hole:Hide() end
end

-- A step before's node: a filled disc in the success colour once done; a
-- skipped step's hollow, as a step not done.
local function paintPast(n, status)
	local br, bg, bb = Theme.Color("bg")
	n.ring:SetSize(14, 14)
	n.ring:SetVertexColor(br, bg, bb, 0)
	n.disc:SetSize(8, 8)
	n.hole:SetSize(6, 6)
	if status == "done" then
		local r, g, b = Theme.Color("success")
		n.disc:SetVertexColor(r, g, b, 0.85)
		n.hole:SetVertexColor(0, 0, 0, 0)
	else
		local r, g, b = Theme.Color("textMuted")
		n.disc:SetVertexColor(r, g, b, 0.6)
		n.hole:SetVertexColor(br, bg, bb, 1)
	end
end

-- The steps before (parts.last, guideWindow.lastSteps: Polestar fills its
-- Rows, oldest first, from the window's own step, and leaves them out in
-- compact mode and where no step comes before): on the rail, each row's
-- number, icon and text in Up next's columns, its first goal in the goal's
-- words, "skipped" after a skipped step. Polestar places them again at
-- every layout. -> the rows shown
local function lastLines(last, person)
	local rows = {}
	local n = tonumber(rawget(last, "psCount")) or 0
	local pool = rawget(last, "Rows")
	if type(pool) ~= "table" then return rows end
	for i = 1, n do
		local r = pool[i]
		if r and rawget(r, "psView") and rawget(r, "Text") and rawget(r, "Num") then rows[#rows + 1] = r end
	end
	if #rows == 0 then return rows end
	-- Up next's columns: the rows stand out of the card by the card's inset
	-- over Up next's.
	last:ClearAllPoints()
	last:SetPoint("BOTTOMLEFT", person, "TOPLEFT", -(CARD_X - UP_X), 0)
	last:SetPoint("BOTTOMRIGHT", person, "TOPRIGHT", 0, 0)
	local w = last:GetWidth()
	for _, r in ipairs(rows) do
		local text = stepLine(r.psView)
		if rawget(r, "psStatus") == "skipped" then
			text = text .. "  |c" .. Theme.Hex("textMuted") .. tr("skipped") .. "|r"
		end
		r.Text:SetText(text)
		r.Text:SetTextColor(Theme.Color("textDim"))
		if type(w) == "number" and w > 0 then r.Text:SetWidth(math.max(40, w - 59 - 14)) end
	end
	return rows
end

-- The rail and its nodes, on a layer of Atlas's own over the window.
-- The target bar on the step's title: on the rail, centred in the gap
-- between the current node's ring (its right edge at RAIL - CARD_X + 8)
-- and the title (11 in), at any bar width; off it, Polestar's place.
local function placeMark(person, on)
	local mark = person and rawget(person, "Mark")
	if not mark then return end
	local x = on and (RAIL - CARD_X + 8 + 11) / 2 or nil
	mark:ClearAllPoints()
	if x then
		mark:SetPoint("TOP", person, "TOPLEFT", x, -6)
		mark:SetPoint("BOTTOM", person, "BOTTOMLEFT", x, 4)
	else
		mark:SetPoint("TOPLEFT", person, "TOPLEFT", 0, -6)
		mark:SetPoint("BOTTOMLEFT", person, "BOTTOMLEFT", 0, 4)
	end
end
onLeave(function(parts) placeMark(parts.person, false) end)

local function rail(parts)
	local window, person = parts.window, parts.person
	local own = store(window)
	if not own.rail then
		own.rail = CreateFrame("Frame", nil, window)
		own.rail:SetAllPoints(window)
		own.rail.dots = {}
	end
	local layer = own.rail
	layer:SetFrameLevel(window:GetFrameLevel() + 8)
	local parent = person and person:GetParent()
	if not (onRail() and person and person:IsShown() and parent and parent:IsShown() and person.Name) then
		layer:Hide()
		placeMark(person, false)
		return
	end
	layer:Show()
	placeMark(person, true)
	local last = parts.last
	local past = (last and last:IsShown()) and lastLines(last, person) or {}
	if not layer.pasts then layer.pasts = {} end
	local top
	for i = 1, math.max(#past, #layer.pasts) do
		local pn = node(layer.pasts, i, layer)
		local r = past[i]
		if r then
			paintPast(pn, rawget(r, "psStatus"))
			placeNode(pn, r, "LEFT", RAIL - UP_X, 0)
			top = top or pn.disc
		else
			hideNode(pn)
		end
	end
	local cn = node(layer, "cur", layer)
	paintNode(cn, true, 1)
	placeNode(cn, person, "TOPLEFT", RAIL - CARD_X, -(10 + person.Name:GetStringHeight() / 2))
	local bottom = cn.disc
	local rows = upRows(parts.upnext)
	for i = 1, math.max(#rows, #layer.dots) do
		local d = node(layer.dots, i, layer)
		local r = rows[i]
		if r then
			paintNode(d, false, FADE[i] or FADE[#FADE])
			placeNode(d, r, "TOPLEFT", RAIL - UP_X, -12)
			bottom = d.disc
		else
			hideNode(d)
		end
	end
	if not layer.line then
		layer.line = layer:CreateTexture(nil, "ARTWORK")
		layer.line:SetTexture(Theme.Media("white"))
	end
	layer.line:SetWidth(pixel(layer))
	layer.line:ClearAllPoints()
	top = top or cn.disc
	layer.line:SetPoint("TOP", top, "CENTER", 0, 0)
	layer.line:SetPoint("BOTTOM", bottom, "CENTER", 0, 0)
	local r, g, b = Theme.Color("textMuted")
	layer.line:SetVertexColor(r, g, b, 0.35)
	layer.line:SetShown(bottom ~= top)
end
on("guideLayout", function(parts) if parts.window then rail(parts) end end)

---------------------------------------------------------------------------
-- The tip: a faint line over it and an "i" for its toggle, its text on one
-- line until opened. A step with more than one tip gets a pager on the
-- right ("1/2 ›"), where Polestar hands the tips over (Core.tipPages).
---------------------------------------------------------------------------

local tipPage = setmetatable({}, { __mode = "k" }) -- tip -> { list, at }

local function pager(tip)
	local own = store(tip)
	local pages = Core.tipPages(tip)
	-- Polestar's own pager, where it has one, stays.
	if not pages or rawget(tip, "Pager") then
		if own.pager then own.pager:Hide() end
		tipPage[tip] = nil
		return
	end
	local state = tipPage[tip]
	if not state or state.list ~= pages then
		state = { list = pages, at = 1 }
		tipPage[tip] = state
	end
	if not own.pager then
		local b = CreateFrame("Button", nil, tip)
		b:SetSize(36, 16)
		b.Label = b:CreateFontString(nil, "OVERLAY")
		b.Label:SetPoint("RIGHT", b, "RIGHT", 0, 0)
		b.Label:SetJustifyH("RIGHT")
		b:SetScript("OnClick", function()
			local s = tipPage[tip]
			if not s then return end
			s.at = s.at % #s.list + 1
			tip.Text:SetText(s.list[s.at])
			Core.relayout()
		end)
		b:SetScript("OnEnter", function(self) self.Label:SetTextColor(Theme.Color("text")) end)
		b:SetScript("OnLeave", function(self) self.Label:SetTextColor(Theme.Color("textMuted")) end)
		own.pager = b
	end
	local b = own.pager
	Theme.Font(b.Label, "small")
	b.Label:SetTextColor(Theme.Color("textMuted"))
	b.Label:SetText(state.at .. "/" .. #pages .. " \226\128\186")
	b:ClearAllPoints()
	b:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -12, -4)
	b:Show()
end

local function tipLook(tip, on)
	local own = store(tip)
	if not own.rule then
		own.rule = tip:CreateTexture(nil, "ARTWORK")
		own.rule:SetTexture(Theme.Media("white"))
	end
	own.rule:SetShown(on)
	local icon = tip.Toggle and tip.Toggle.Icon
	if not on then
		if own.pager then own.pager:Hide() end
		if icon then icon:SetTexture(Theme.Media(Core.tipOpen(tip) and "chevron-up" or "chevron-down")) end
		return
	end
	if icon then icon:SetTexture(Theme.Media(Theme.Icon and Theme.Icon("info") or "info")) end
	own.rule:ClearAllPoints()
	own.rule:SetPoint("TOPLEFT", tip, "TOPLEFT", 11, 0)
	own.rule:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -12, 0)
	own.rule:SetHeight(pixel(tip))
	local r, g, b = Theme.Color("textMuted")
	own.rule:SetVertexColor(r, g, b, 0.35)
	pager(tip)
end
onLeave(function(parts) if parts.tip then tipLook(parts.tip, false) end end)

on("guidePlace", function(name, part)
	if name == "tip" then tipLook(part, true) end
end)

---------------------------------------------------------------------------
-- The XP row: "Level 4 · 62% · " before Polestar's own line (its pace and
-- the time to the next level), a star in the accent for its icon.
---------------------------------------------------------------------------

local function xpBack(xp)
	local own = xp and stores[xp]
	if not (own and own.atlas) then return end
	own.atlas = nil
	local line = Core.xpLine(xp)
	if line then xp.Text:SetText(line) end
	xp.Icon:SetTexture(Theme.Media("icon-level"))
	xp.Icon:SetVertexColor(Theme.Color("textMuted"))
end

local function xpLook(xp)
	if not (xp.Text and xp.Icon) then return end
	store(xp).atlas = true
	local head = {}
	local level = UnitLevel and UnitLevel("player")
	local cur, max = UnitXP and UnitXP("player"), UnitXPMax and UnitXPMax("player")
	if type(level) == "number" and level > 0 then head[#head + 1] = string.format(tr("Level %d"), level) end
	if type(cur) == "number" and type(max) == "number" and max > 0 then head[#head + 1] = math.floor(cur / max * 100) .. "%" end
	local line = Core.xpLine(xp)
	if line then head[#head + 1] = line end
	xp.Text:SetText(table.concat(head, "  \194\183  "))
	xp.Icon:SetTexture(Theme.Media("star"))
	xp.Icon:SetVertexColor(Theme.Accent())
end

-- The XP row is handed over by name only (guidePlace): the layout leaving a
-- window gives the ones it saw in that window their own look back.
local seenXp = setmetatable({}, { __mode = "k" })
on("guidePlace", function(name, part)
	if name == "xp" then
		seenXp[part] = true
		xpLook(part)
	end
end)
onLeave(function(parts, live)
	for xp in pairs(seenXp) do
		if Core.leaves(xp, parts, live) then xpBack(xp) end
	end
end)

---------------------------------------------------------------------------
-- Compact mode: dense. Polestar's own compact mode drops Up next, the tabs
-- and the Journey; Atlas keeps the tip there (its strip at the card's foot)
-- and leaves the XP row out too.
---------------------------------------------------------------------------

on("guideShows", function(what, shown)
	if what == "tip" and compact() then return true end
	return shown
end)

on("guidePlace", function(name, part)
	if compact() and (name == "xp" or name == "upnext") then
		part:Hide()
		return true
	end
end)

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------

local FIRST = { guidePlace = true, guideTakes = true, guideInset = true, guidePerson = true, guideAnchor = true }

local function join(name, list)
	if name == "guideShows" then
		return function(what, shown)
			for i = 1, #list do shown = list[i](what, shown) end
			return shown
		end
	elseif name == "guideLayout" then
		return function(...)
			local room = 0
			for i = 1, #list do
				local v = list[i](...)
				if type(v) == "number" then room = room + v end
			end
			return room
		end
	elseif FIRST[name] then
		return function(...)
			for i = 1, #list do
				local v = list[i](...)
				if v ~= nil and v ~= false then return v end
			end
			return nil
		end
	end
	return function(...)
		for i = 1, #list do list[i](...) end
	end
end

-- The hooks a layout may set (docs/skins/reference.md, "Layouts"). The
-- title bar, the goal rows and the progress came later: a Polestar that
-- refuses them gets the layout without them.
local LAYOUT_HOOKS = { guideLayout = true, guideRender = true, guidePlace = true, guideAnchor = true, guideTakes = true,
	guidePerson = true, guideInset = true, guideUpRow = true, guideShows = true }
local LATER_HOOKS = { guideTitle = true, guideRow = true, guideProgress = true }

local function hooksOf(withLater)
	local hooks = {}
	for _, name in ipairs(order) do
		if (LAYOUT_HOOKS[name] or (withLater and LATER_HOOKS[name])) and has(name) then
			hooks[name] = join(name, chains[name])
		end
	end
	return hooks
end

local function spec(hooks)
	return {
		api = 2,
		name = "Atlas",
		addon = ADDON,
		author = "TTik3r",
		desc = "The step on a timeline, Up next on a rail that fades ahead, cards above the window.",
		hooks = hooks,
		-- The J2 look's starting point. The player's own choices win; a
		-- reset returns to these.
		defaults = {
			["guideWindow.tabs"] = true,
			["guideWindow.tabStyle"] = "switcher",
			["guideWindow.progress"] = false,
			["guideWindow.targetBar"] = false,
			["guideWindow.reportButton"] = false,
			["guideWindow.lastSteps"] = 1,
		},
		-- Its card in the guide window's Presets, beside Polestar's own:
		-- picking it chooses this layout and the Atlas skin. A Polestar
		-- without layout presets gets the layout without it.
		preset = Theme.HasCapability("layouts.preset") and {
			label = "Atlas",
			help = "The step on a timeline, Up next on a rail, cards above the window.",
			set = { ["ui.skin"] = "atlas" },
		} or nil,
		-- Under another layout: Polestar's own parts get their look back; the
		-- pieces Atlas made itself hide.
		-- Called once for each guide window Atlas dressed (the live one, then
		-- each copy drawing with the layout in use), with that window's
		-- parts: its parts get their look back and the pieces Atlas made in
		-- it hide. The live window's call also hides the pieces outside any
		-- guide window (the cards above it).
		onLeave = function(_, parts, live)
			if parts == nil and live ~= false then
				parts, live = Theme.GuideParts and Theme.GuideParts(), true
			end
			if parts then
				for _, fn in ipairs(leaving) do fn(parts, live) end
			end
			for f, s in pairs(stores) do
				if Core.leaves(f, parts, live) then hideAll(s) end
			end
		end,
	}
end

local ok, message = Theme.RegisterLayout("atlas", spec(hooksOf(true)))
if not ok and tostring(message):find("is a skin's", 1, true) then
	ok, message = Theme.RegisterLayout("atlas", spec(hooksOf(false)))
end
check("layout atlas", ok, message)
