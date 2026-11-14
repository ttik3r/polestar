'use strict';
// The Atlas look: its skin (addon/Polestar_Skin_Atlas, tokens only) and its
// layout (addon/Polestar_Layout_Atlas, structure hooks only). The layout
// registers through Theme.RegisterLayout and is picked with SetLayout, any
// skin's tokens on top. Its hooks are also run here one by one on the live
// window's parts, to show they keep to the parts they are handed.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { runAddon, ADDONS } = require('./helpers/lua');

const LAYOUT = path.join(ADDONS, 'Polestar_Layout_Atlas', 'Atlas.lua');
const luaPath = (p) => JSON.stringify(p);

test('the Atlas skin registers as given and is legible', () => {
	const [out] = runAddon({
		stubs: ['stub_world.lua'],
		addons: ['Polestar', 'Polestar_Skin_Atlas'],
		login: true,
		script: `
local T = Polestar.Theme
local notes = {}
for _, l in ipairs(Polestar.DebugLog(800)) do
	if tostring(l):find("Polestar_Skin_Atlas", 1, true) then notes[#notes + 1] = tostring(l) end
end
Polestar.Set("ui.skin", "atlas")
emit({ inUse = T.SkinId(), notes = #notes, legible = T.Legibility(T.Palette()) >= 1 })`,
	}).emitted;
	assert.deepEqual(out, { inUse: 'atlas', notes: 0, legible: true });
});

// Every hook the layout has, captured from a stand-in RegisterLayout and run
// on the window's own parts.
// A guide of two steps on screen (a test pack, as forge-addontest's).
const GUIDE = `
w = stub.world
w.addMap(1429, { name = "Elwynn Forest", c = 0, left = 1500, right = -1500, top = 500, bottom = -1500 })
w.moveTo(1429, 48, 42)
Polestar.RegisterPack({ addon = "Polestar_Test", id = "test", format = 1, title = "Test", author = "Test", version = "1", license = "MIT" })
Polestar.Set("behavior.suggestFrom", "test")
Polestar.RegisterGuide({
	id = "test/atlas", pack = "test", title = "Atlas", minLevel = 1, maxLevel = 20,
	steps = {
		{ goals = {
			{ t = "accept", quest = 7, title = "Kobold Camp Cleanup", npc = 197, npcName = "Marshal McBride" },
			{ t = "note", text = "The kobolds are north of the abbey." },
		} },
		{ goals = { { t = "turnin", quest = 7, title = "Kobold Camp Cleanup", npc = 197, npcName = "Marshal McBride" } } },
		{ goals = { { t = "accept", quest = 33, title = "Wolves Across the Border" } } },
	},
})
stub.login()
stub.fire("QUEST_LOG_UPDATE"); stub.advance(0.6)`;

const RUN_HOOKS = (compact) => `${GUIDE}
local T = Polestar.Theme
local spec
local register = T.RegisterLayout
T.RegisterLayout = function(id, s) spec = s; spec.id = id; return true end
local chunk = assert(loadfile(${luaPath(LAYOUT)}))
chunk("Polestar_Layout_Atlas", {})
T.RegisterLayout = register
Polestar.Set("ui.skin", "atlas")
Polestar.Set("ui.shown", true)
Polestar.Set("ui.compact", ${compact})
Polestar.UI.GuideFrame.Layout()
stub.advance(1)
local h, parts = spec.hooks, T.GuideParts()
local ran = {}
local function run(name, ...)
	if h[name] then
		local ok, err = pcall(h[name], ...)
		if not ok then error(name .. ": " .. tostring(err), 0) end
		ran[#ran + 1] = name
	end
end
local view = { index = 2, goals = {
	{ index = 1, t = "kill", text = "Kill 8 Kobold Vermin", status = "active", progress = { cur = 3, max = 8 }, quest = 7 },
	{ index = 2, t = "loot", text = "Gather 4 Candles", status = "active", optional = true, map = 1429, x = 0.4, y = 0.6 },
	{ index = 3, t = "note", text = "The candles drop from the kobolds." },
	{ index = 4, t = "turnin", text = "Turn in Kobold Camp Cleanup", status = "pending", quest = 7 },
} }
for _, g in ipairs(view.goals) do run("guideTakes", g) end
run("guideRender", view, parts)
for name, part in pairs({ here = parts.here, upnext = parts.upnext, tip = parts.tip, xp = parts.xp, banner = parts.banner }) do
	run("guidePlace", name, part, 300, 40)
end
run("guideShows", "upnextHead", true)
run("guideInset", "card")
if parts.person then run("guidePerson", parts.person, 300, 20) end
for _, r in ipairs(parts.rows or {}) do run("guideRow", r, view.goals[1], { current = true }) end
if parts.upnext then for i, r in ipairs({ parts.upnext:GetChildren() }) do if rawget(r, "psIndex") then run("guideUpRow", r, view, i) end end end
run("guideLayout", parts, 300, 200)
run("guideProgress", parts.foot, 0.4)
run("guideAnchor")
run("card", nil, "headsupGap")
run("guideTitle", parts.nav, parts)
spec.onLeave()
Polestar.UI.GuideFrame.Layout()
stub.advance(1)
emit({ id = spec.id, api = spec.api, ran = #ran, rows = #(parts.rows or {}), person = parts.person ~= nil })`;

test('the Atlas layout hooks run on the window parts without raising', () => {
	const [out] = runAddon({ stubs: ['stub_world.lua'], addons: ['Polestar', 'Polestar_Skin_Atlas'], script: RUN_HOOKS(false) }).emitted;
	assert.equal(out.id, 'atlas');
	assert.equal(out.api, 2);
	assert.ok(out.ran > 5, `hooks ran: ${out.ran}`);
	assert.ok(out.person && out.rows > 0, 'the window shows a step with its goals');
});

test('the Atlas layout hooks run in compact mode without raising', () => {
	const [out] = runAddon({ stubs: ['stub_world.lua'], addons: ['Polestar', 'Polestar_Skin_Atlas'], script: RUN_HOOKS(true) }).emitted;
	assert.ok(out.ran > 5, `hooks ran: ${out.ran}`);
});

// The real thing: the layout addon registers, SetLayout picks it, the window
// draws in normal and compact mode with nothing failed, another skin's tokens
// colour it, and SetLayout() gives Polestar's own layout back.
test('the Atlas layout registers, draws under another skin and leaves', () => {
	const [out] = runAddon({
		stubs: ['stub_world.lua'],
		addons: ['Polestar', 'Polestar_Skin_Atlas', 'Polestar_Skin_Beacon', 'Polestar_Layout_Atlas'],
		script: `${GUIDE}
local T = Polestar.Theme
local function hex(c) return string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end
local function draw()
	Polestar.UI.GuideFrame.Layout()
	if Polestar.UI.GuideFrame.Render then Polestar.UI.GuideFrame.Render() end
	stub.advance(1)
end
local refused = {}
for _, l in ipairs(Polestar.DebugLog(800)) do
	if tostring(l):find("Polestar_Layout_Atlas", 1, true) then refused[#refused + 1] = tostring(l) end
end
Polestar.Set("ui.shown", true)
Polestar.Set("ui.skin", "beacon")
draw()
local beacon = hex(T.Palette().accent)
local info = T.LayoutInfo("atlas")
local out = { registered = info ~= nil, refused = #refused, hooks = info and table.concat(info.hooks, ",") or "" }
out.set = T.SetLayout("atlas") and true or false
draw()
out.inUse = { T.LayoutId() or false, T.SkinId(), hex(T.Palette().accent) == beacon }
local nav = T.GuideParts().nav
local function rule() return nav.Rule:IsShown() and true or false end
out.rule = { rule() }
-- The player's switches hold under Atlas: the rule, Skip and Report.
local function skip() return nav.Skip:IsShown() and true or false end
local function report() return nav.Report:IsShown() and true or false end
out.switches = { skip(), report() }
-- Atlas's defaults (spec.defaults) start Report off; the player's choice wins.
Polestar.Set("guideWindow.reportButton", true)
draw()
out.switches[3] = report()
-- Atlas starts with tabs on, as the title switcher; the player's style wins.
out.tabs = { Polestar.Get("guideWindow.tabs"), Polestar.Get("guideWindow.tabStyle") }
Polestar.Set("guideWindow.tabStyle", "edge")
out.tabs[3] = Polestar.Get("guideWindow.tabStyle")
Polestar.Set("guideWindow.tabStyle", "switcher")
Polestar.Set("guideWindow.rules", false)
Polestar.Set("guideWindow.skipButton", false)
Polestar.Set("guideWindow.reportButton", false)
draw()
out.off = { rule(), skip(), report() }
Polestar.Set("guideWindow.rules", true)
Polestar.Set("guideWindow.skipButton", true)
Polestar.Set("guideWindow.reportButton", true)
draw()
out.skipLabel = nav.Skip.Label:IsShown() and true or false
Polestar.Set("ui.compact", true)
draw()
Polestar.Set("ui.compact", false)
Polestar.Set("ui.skin", "atlas")
draw()
out.atlasAccent = hex(T.Palette().accent)
out.failed = T.LayoutInfo("atlas").failed or false
T.SetLayout()
Polestar.Set("ui.skin", "beacon")
draw()
out.back = T.LayoutId() or false
out.rule[2] = rule()
emit(out)`,
	}).emitted;
	assert.equal(out.registered, true);
	assert.equal(out.refused, 0, 'registered as given');
	for (const h of ['guideLayout', 'guideRender', 'guidePlace', 'guideRow', 'guideTitle', 'guideProgress']) {
		assert.ok(out.hooks.split(',').includes(h), `hooks ${h}: ${out.hooks}`);
	}
	assert.equal(out.set, true);
	assert.deepEqual(out.inUse, ['atlas', 'beacon', true], "the layout in use, Beacon's tokens on top");
	assert.equal(out.atlasAccent, 'e6ba66', "the Atlas skin's own accent");
	assert.equal(out.failed, false, 'no hook failed in normal or compact mode');
	assert.equal(out.back, false, "Polestar's own layout again");
	assert.deepEqual(out.rule, [true, true], 'the header keeps its rule (guideWindow.rules) under Atlas and after');
	assert.deepEqual(out.switches, [true, false, true], "Skip shows, Report starts off by Atlas's default, the player's choice turns it on");
	assert.deepEqual(out.tabs, [true, 'switcher', 'edge'], "tabs on as the title switcher by Atlas's default, the player's style wins");
	assert.deepEqual(out.off, [false, false, false], 'switched off, they stay off under Atlas');
	assert.equal(out.skipLabel, false, 'Skip is its glyph alone under Atlas');
});

// The layout's hooks, captured from a stand-in RegisterLayout, with the
// window on screen: `h` the hooks, `parts` the window's parts.
const HOOKS = `${GUIDE}
local T = Polestar.Theme
local spec
local register = T.RegisterLayout
T.RegisterLayout = function(id, s) spec = s; return true end
assert(loadfile(${luaPath(LAYOUT)}))("Polestar_Layout_Atlas", {})
T.RegisterLayout = register
Polestar.Set("ui.skin", "atlas")
Polestar.Set("ui.shown", true)
Polestar.UI.GuideFrame.Layout()
stub.advance(1)
local h, parts = spec.hooks, T.GuideParts()`;

const hooks = (script) => runAddon({ stubs: ['stub_world.lua'], addons: ['Polestar', 'Polestar_Skin_Atlas'], script: `${HOOKS}\n${script}` }).emitted[0];

test('an area goal loses its spots line, and on the rail its next-spot button', () => {
	const out = hooks(`
local row = parts.rows[1]
local goal = { index = 1, t = "kill", text = "Kill Rockjaw Trogg", subject = "Rockjaw Trogg", spots = 12, spread = true, status = "active", quest = 7 }
local area = Polestar.UI.AreaLine(goal)
row.Sub:SetText("Ask the guard first\\n" .. area)
row.Sub:Show()
row.Alt:Show()
h.guideRow(row, goal, { current = true })
local railSub, railAlt = row.Sub:GetText(), row.Alt:IsShown()
Polestar.Set("ui.compact", true)
row.Sub:SetText(area)
row.Sub:Show()
row.Alt:Show()
h.guideRow(row, goal, { current = true })
emit({ area = area ~= nil, sub = railSub, rail = railAlt, compactAlt = row.Alt:IsShown(), compactSub = row.Sub:IsShown() and row.Sub:GetText() or false })`);
	assert.equal(out.area, true);
	assert.ok(!/spots/.test(out.sub) && /Ask the guard first/.test(out.sub), `sub: ${out.sub}`);
	assert.equal(out.rail, false, 'the next-spot button is off on the rail');
	assert.equal(out.compactAlt, true, 'compact mode keeps it');
	assert.ok(!/spots/.test(String(out.compactSub)), `compact sub: ${out.compactSub}`);
});

test("While you're here keeps its line: no step line or × of its own, the count by the distance", () => {
	const out = hooks(`
local GF = Polestar.UI.GuideFrame
local r = GF.HereRow(1)
r.psView, r.psOff = { step = 7, index = 1 }, nil
Polestar.UI.SetCounted(r.Text, "Kill Small Crag Boar 2/12")
r.Sub:SetText("Step 7")
r.Sub:Show()
r.Dist:SetText("80 yd")
r:Show()
parts.here:Show()
local h0 = GF.LayoutHere(300)
h.guidePlace("here", parts.here, 300, h0)
local first = { r.Text:GetText(), r.Sub:IsShown(), r.Close:IsShown() }
-- A second layout finds the count it took out at the first.
local h1 = GF.LayoutHere(300)
h.guidePlace("here", parts.here, 300, h1)
local own
for _, region in ipairs({ r:GetRegions() }) do
	if region.GetText and region ~= r.Text and region ~= r.Sub and region ~= r.Dist and region:IsShown() and (region:GetText() or ""):find("2/12", 1, true) then own = region:GetText() end
end
emit({ text = first[1], sub = first[2], close = first[3], count = own or false, shorter = parts.here:GetHeight() < h0 })`);
	assert.equal(out.text, 'Kill Small Crag Boar');
	assert.equal(out.sub, false, 'no step line');
	assert.equal(out.close, false, "no × of the row's own");
	assert.equal(out.count, '2/12  ·  ', 'the count left of the distance');
	assert.equal(out.shorter, true, 'the card gives up the step line');
});

test('an Up next row not laid out yet takes Up next width, not the narrowest', () => {
	const out = hooks(`
Polestar.Set("ui.upcoming", 3)
Polestar.UI.GuideFrame.Layout()
stub.advance(1)
local rows = {}
for _, r in ipairs({ parts.upnext:GetChildren() }) do if rawget(r, "psIndex") then rows[#rows + 1] = r end end
local r = rows[1]
if not r then return emit({ rows = 0 }) end
r:Show()
parts.upnext:Show()
r.GetWidth = function() return 0 end
h.guideUpRow(r, { goals = { { t = "turnin", text = "Turn in A New Threat", status = "pending" } } }, 1)
h.guidePlace("upnext", parts.upnext, 320, 60)
emit({ rows = #rows, text = math.floor(r.Text:GetWidth() + 0.5) })`);
	assert.ok(out.rows > 0, 'Up next has rows');
	assert.ok(out.text > 200, `the text is ${out.text} wide`);
});

// The steps before (guideWindow.lastSteps, Polestar's part `last`): 1 by
// Atlas's default, each row on the rail with a node of its own, done or
// skipped, the oldest on top; never more than come before; the player's count
// wins, a reset goes back to Atlas's; none in compact mode or under
// Polestar's own layout (0 by default).
test('the steps before show on the rail: as many as asked and come before, done or skipped, oldest on top', () => {
	const [out] = runAddon({
		stubs: ['stub_world.lua'],
		addons: ['Polestar', 'Polestar_Skin_Atlas', 'Polestar_Layout_Atlas'],
		script: `
w = stub.world
w.addMap(1429, { name = "Elwynn Forest", c = 0, left = 1500, right = -1500, top = 500, bottom = -1500 })
w.moveTo(1429, 48, 42)
Polestar.RegisterPack({ addon = "Polestar_Test", id = "test", format = 1, title = "Test", author = "Test", version = "1", license = "MIT" })
Polestar.Set("behavior.suggestFrom", "test")
Polestar.RegisterGuide({
	id = "test/before", pack = "test", title = "Before", minLevel = 1, maxLevel = 20,
	steps = {
		{ goals = { { t = "accept", quest = 7, title = "Kobold Camp Cleanup", npc = 197, npcName = "Marshal McBride" } } },
		{ goals = { { t = "accept", quest = 33, title = "Wolves Across the Border", npc = 196, npcName = "Eagan Peltskinner" } } },
		{ goals = { { t = "accept", quest = 18, title = "Brotherhood of Thieves", npc = 823, npcName = "Deputy Willem" } } },
		{ goals = { { t = "accept", quest = 783, title = "A Threat Within", npc = 823, npcName = "Deputy Willem" } } },
		{ goals = { { t = "accept", quest = 5261, title = "Eagan Peltskinner", npc = 823, npcName = "Deputy Willem" } } },
	},
})
stub.login()
stub.fire("QUEST_LOG_UPDATE"); stub.advance(0.6)
local T, E = Polestar.Theme, Polestar.Engine
local function draw()
	Polestar.UI.GuideFrame.Layout()
	if Polestar.UI.GuideFrame.Render then Polestar.UI.GuideFrame.Render() end
	stub.advance(1)
end
local function accept(q, title)
	stub.world.accept(q, {}, title)
	stub.fire("QUEST_LOG_UPDATE"); stub.advance(0.6)
end
Polestar.Set("ui.shown", true)
Polestar.Set("ui.skin", "atlas")
T.SetLayout("atlas")
draw()
local parts = T.GuideParts()
local last = parts.last
-- The rows shown, top to bottom: step, status, number, "skipped" said, a
-- rail node beside it; and whether they stack oldest on top.
local function state()
	local rows, nodes = {}, {}
	for _, region in ipairs({ parts.window:GetChildren() }) do
		for _, t in ipairs({ region:GetRegions() }) do
			local p = t.GetPoint and { t:GetPoint(1) }
			if p and p[2] and t:IsShown() then nodes[p[2]] = true end
		end
	end
	local n = last:IsShown() and (last.psCount or 0) or 0
	local tops = {}
	for i = 1, n do
		local r = last.Rows[i]
		local text = r.Text:GetText() or ""
		rows[#rows + 1] = { index = r.psIndex, status = r.psStatus, num = r.Num:GetText(),
			skipped = text:find("skipped", 1, true) ~= nil, node = nodes[r] or false }
		local _, _, _, _, y = r:GetPoint(1)
		tops[#tops + 1] = y
	end
	local stacked = true
	for i = 2, #tops do if not (tops[i] < tops[i - 1]) then stacked = false end end
	return { n = n, rows = rows, stacked = stacked }
end
local out = { first = state() }
accept(7, "Kobold Camp Cleanup")
draw()
out.atlas = state()
Polestar.Set("guideWindow.lastSteps", 3)
draw()
out.two = state()
accept(33, "Wolves Across the Border")
E.Skip(); stub.advance(0.6)
accept(783, "A Threat Within")
draw()
out.step = E.GetStepIndex()
out.three = state()
Polestar.Set("guideWindow.lastSteps", 0)
draw()
out.zero = state()
Polestar.Set("guideWindow.lastSteps", nil)
draw()
out.back = state()
Polestar.Set("ui.compact", true)
draw()
out.compact = state()
Polestar.Set("ui.compact", false)
T.SetLayout()
draw()
out.house = state()
out.failed = T.LayoutInfo("atlas").failed or false
emit(out)`,
	}).emitted;
	assert.equal(out.failed, false, 'no hook failed');
	assert.equal(out.first.n, 0, 'nothing before step 1');
	assert.deepEqual(out.atlas.rows, [{ index: 1, status: 'done', num: '1', skipped: false, node: true }], "Atlas's 1: step 1 done, on a node");
	assert.equal(out.two.n, 1, 'three asked at step 2: the one there is');
	assert.equal(out.step, 5);
	assert.deepEqual(out.three.rows.map((r) => [r.index, r.status, r.skipped, r.node]),
		[[2, 'done', false, true], [3, 'skipped', true, true], [4, 'done', false, true]], 'three, the oldest on top, the skipped one in the middle');
	assert.equal(out.three.stacked, true, 'each row under the one before');
	assert.equal(out.zero.n, 0, '0 turns them off');
	assert.deepEqual(out.back.rows.map((r) => r.index), [4], "reset: Atlas's 1, the newest");
	assert.equal(out.compact.n, 0, 'compact mode leaves them out');
	assert.equal(out.house.n, 0, "Polestar's own layout: 0 by default");
});

// Under Atlas nothing extra sits in the window: Along the way, a banner
// notice (Looking ahead) and the party line each go on a card above it, and
// leave no heading or gap behind; under Polestar's own layout each stays in
// the window as before.
const OUTSIDE = (layout) => `${GUIDE}
local T, GF = Polestar.Theme, Polestar.UI.GuideFrame
local E = Polestar.Engine
E.GetAlong = function()
	return { { index = 1, title = "Boars", goals = {
		{ index = 1, step = 1, t = "loot", text = "Collect Chunk of Boar Meat", status = "active", optional = true, progress = { cur = 6, max = 10 }, map = 1429, x = 0.48, y = 0.44 },
		{ index = 2, step = 1, t = "loot", text = "Collect Stolen Blasting Powder", status = "active", progress = { cur = 3, max = 16 }, map = 1429, x = 0.5, y = 0.5 },
	} } }
end
Polestar.Party = Polestar.Party or {}
Polestar.Party.StepLine = function() return "2 of 3 on this step" end
Polestar.Set("ui.shown", true)
${layout ? `T.SetLayout("${layout}")` : 'T.SetLayout()'}
E.Goto(3)
local function draw()
	GF.Layout()
	if GF.Render then GF.Render() end
	GF.UpdateParty()
	GF.Layout()
	stub.advance(1)
	GF.Layout()
end
draw()
local parts = T.GuideParts()
local placed = {}
for _, p in ipairs(GF.Placed()) do placed[p[1]] = true end
local rows = {}
for _, r in ipairs(GF.alongRows) do
	if r:IsShown() then
		local meta
		for _, c in ipairs({ r:GetChildren() }) do
			if rawget(c, "Text") and c:IsShown() then meta = c.Text:GetText() end
		end
		rows[#rows + 1] = { r.Text:GetText(), meta or false }
	end
end
local stack = {}
local own = parts.window
for _, c in ipairs({ own:GetChildren() }) do
	if rawget(c, "cards") then for _, b in ipairs(c.cards) do if b:IsShown() then stack[#stack + 1] = b end end end
end
emit({
	along = { placed.along or false, parts.along:IsShown(), parts.along.Label:GetText() },
	banner = { placed.banner or false, parts.banner:IsShown(), parts.banner.psKind or false, parts.banner.Text:GetText() or "" },
	party = { placed.party or false, GF.party:IsShown() },
	rows = rows, cards = #stack,
})`;

const outside = (layout) => runAddon({
	stubs: ['stub_world.lua'],
	addons: ['Polestar', 'Polestar_Skin_Atlas', 'Polestar_Layout_Atlas'],
	script: OUTSIDE(layout),
}).emitted[0];

test('under Atlas Along the way is a card above the window: no heading in it, the count by the distance, optional kept', () => {
	const out = outside('atlas');
	assert.equal(out.along[0], false, 'not in the window');
	assert.equal(out.along[1], true, 'shown on its card');
	assert.equal(out.along[2], 'ALONG THE WAY');
	assert.equal(out.rows.length, 2);
	assert.match(out.rows[0][0], /Chunk of Boar Meat/);
	assert.doesNotMatch(out.rows[0][0], /6\/10/, 'the count leaves the line');
	assert.match(out.rows[0][0], /optional/, 'the optional tag stays');
	assert.match(String(out.rows[0][1]), /^6\/10  ·  \d+ yd$/, `meta: ${out.rows[0][1]}`);
	assert.ok(out.cards >= 3, `cards above: ${out.cards}`);
});

test('under Atlas the Looking ahead banner is a heads-up card above the window', () => {
	const out = outside('atlas');
	assert.deepEqual(out.banner.slice(0, 3), [false, true, 'away']);
	assert.match(out.banner[3], /Looking ahead/);
});

test('under Atlas the party line is a card above the window', () => {
	assert.deepEqual(outside('atlas').party, [false, true]);
});

test("Polestar's own layout keeps Along the way, the banner and the party line in the window", () => {
	const out = outside(null);
	assert.deepEqual(out.along, [true, true, 'Along the way']);
	assert.match(out.rows[0][0], /6\/10/, 'the count stays in the line');
	assert.deepEqual(out.banner.slice(0, 3), [true, true, 'away']);
	assert.deepEqual(out.party, [true, true]);
	assert.equal(out.cards, 0);
});
