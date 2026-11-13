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
	if nav.Title.Hit then nav.Title.Hit:SetShown(nav.Title:IsShown()) end
end
on("guideLayout", function(parts) header(parts) end)
-- The render shows Skip again after the layout: it stays in the menu.
on("guideRender", function(view, parts) if parts.nav and parts.nav.Skip then parts.nav.Skip:Hide() end end)

-- With the foot bar off, room under the window's last part.
on("guideLayout", function() return Core.setting("guideWindow.progress") == false and 8 or 0 end)


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
