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
	assert.deepEqual(out.rule, [false, true], 'the header has no rule under Atlas, its rule back after');
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
