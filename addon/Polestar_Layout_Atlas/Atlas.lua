-- Atlas: a layout for Polestar's guide window (Skin API 2, Theme.RegisterLayout).
-- The step is a node on a timeline: its title and area, its goals with their
-- action icons and quests, the tip under them; Up next is a rail that fades
-- ahead. While you're here, Optional and Training due are cards stacked above
-- the window, the class quest is a heads-up above them, and the Journey is a
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

-- XP-to-next read: Polestar's own line on the XP row ("about 9 min to 5").
function Core.xpLine(xp) return xp and xp.psLine or nil end

-- Tip pager read: the step's tips, one per page (a list of strings), and
-- whether the tip is opened; nil while this Polestar keeps one tip.
function Core.tipPages(tip)
	local list = tip and tip.psTips
	return type(list) == "table" and #list > 1 and list or nil
end
function Core.tipOpen(tip) return tip and tip.psOpen and true or false end

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
-- left, the step count with its arrows and the menu on the right. Skip,
-- Report, Nearby and Lookup are in the menu.
---------------------------------------------------------------------------

on("guideTitle", function(nav, parts)
	if parts.rule then parts.rule:Hide() end
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
	if nav.Skip.Label then
		nav.Skip.Label:Show()
		nav.Skip:SetWidth(math.floor(7 + 11 + 5 + nav.Skip.Label:GetStringWidth() + 8 + 0.5))
	end
	nav.Lookup:Show()
	nav.Nearby:SetShown(Core.setting("nav.nearbyButton") ~= false)
	Theme.Font(nav.Title, "small")
end
onLeave(function(parts) navBack(parts.nav) end)

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
	for _, b in ipairs({ nav.Report, nav.Nearby, nav.Lookup, nav.Skip }) do b:Hide() end
	local path, size, flags = probe("note")
	nav.Steps.Count:SetFont(path, size + 2, flags)
	local cw = math.max(40, math.ceil(nav.Steps.Count:GetUnboundedStringWidth()) + 1)
	nav.Steps.Count:SetWidth(cw)
	nav.Steps:SetWidth(24 + cw + 24)
	nav.Steps:ClearAllPoints()
	nav.Steps:SetPoint("RIGHT", nav.Menu, "LEFT", -2, 0)
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
-- The render shows Skip again after the layout: it stays in the menu.
on("guideRender", function(view, parts) if parts.nav and parts.nav.Skip then parts.nav.Skip:Hide() end end)

-- With the foot bar off, room under the window's last part.
on("guideLayout", function() return Core.setting("guideWindow.progress") == false and 8 or 0 end)

---------------------------------------------------------------------------
-- The cards above the window, bottom up: Training due, Optional, While
-- you're here, the class quest card; 5 apart, each on the window's own
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
onLeave(function(parts) if parts.here then hereLook(parts.here, false) end end)

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
		part:SetHeight(height)
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
end)

local function layoutStack(parts)
	local window = parts.window
	local stack = stackFrame(window)
	local step = stepOf[window]
	if closedOn.here and closedOn.here ~= step then closedOn.here = nil end
	if closedOn.opt and closedOn.opt ~= step then closedOn.opt = nil end
	local list = {}
	local function add(f, close) list[#list + 1] = { f = f, close = close } end
	local function relay() Core.relayout() end
	local s = slots
	if s.class and isUnder(s.class, window) then
		local key = s.classKey
		add(s.class, function() if key then classShut[key] = true end relay() end)
	end
	if s.here and isUnder(s.here, window) then
		if closedOn.here == step then s.here:Hide() else add(s.here, function() closedOn.here = step relay() end) end
	end
	local optional = layoutOptional(stack, window, step)
	if optional then add(optional, function() closedOn.opt = step relay() end) end
	if s.train and isUnder(s.train, window) then
		add(fillTrain(trainCard(stack), window:GetWidth() or 300), Core.laterNotice)
	elseif stack.train then
		stack.train:Hide()
	end
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
		b.Close:Show()
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

-- The heads-up card's questions (where Polestar asks them): compact, 5 above
-- the window, above it only, the class glyph on its reward.
on("card", function(_, kind)
	if kind == "headsupCompact" or kind == "hereCompact" or kind == "headsupAboveOnly" then return true end
	if kind == "headsupGap" then return GAP end
	if kind == "headsupRewardGlyph" then return Theme.Media("icon-train") end
end)

-- The class quest card's own "Later" row: the × does it.
on("guideShows", function(what, shown)
	if what == "classCardLater" then return false end
	return shown
end)

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------

local FIRST = { guidePlace = true, guideTakes = true, guideInset = true, guidePerson = true, guideAnchor = true, card = true }

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

local hooks = {}
for _, name in ipairs(order) do
	if has(name) then hooks[name] = join(name, chains[name]) end
end

check("layout atlas", Theme.RegisterLayout("atlas", {
	api = 2,
	name = "Atlas",
	addon = ADDON,
	hooks = hooks,
	-- Under another layout: Polestar's own parts get their look back; the
	-- pieces Atlas made itself hide.
	onLeave = function()
		local parts = Theme.GuideParts and Theme.GuideParts()
		if parts then
			for _, fn in ipairs(leaving) do fn(parts) end
		end
		for _, s in pairs(stores) do hideAll(s) end
	end,
}))
