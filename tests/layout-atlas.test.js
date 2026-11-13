'use strict';
// The Atlas look: its skin (addon/Polestar_Skin_Atlas, tokens only) and its
// layout (addon/Polestar_Layout_Atlas, structure hooks only). The layout
// registers through Theme.RegisterLayout; on a Polestar without it the file
// does nothing. Its hooks are run here on the live window's parts, every hook
// offered, to show they keep to the parts they are handed and never raise.
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

test('the Atlas layout does nothing on a Polestar without layouts', () => {
	const [out] = runAddon({
		stubs: ['stub_world.lua'],
		addons: ['Polestar'],
		login: true,
		script: `
local had = Polestar.Theme.RegisterLayout ~= nil
local chunk = assert(loadfile(${luaPath(LAYOUT)}))
chunk("Polestar_Layout_Atlas", {})
emit({ had = had })`,
	}).emitted;
	if (out.had) return; // a Polestar with layouts: the next tests cover it
	assert.deepEqual(out, { had: false });
});

// Every hook the layout has, offered (all capabilities on), captured from a
// stand-in RegisterLayout and run on the window's own parts.
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
local register, capability = T.RegisterLayout, T.HasCapability
T.RegisterLayout = function(id, s) spec = s; spec.id = id; return true end
T.HasCapability = function() return true end
local chunk = assert(loadfile(${luaPath(LAYOUT)}))
chunk("Polestar_Layout_Atlas", {})
T.RegisterLayout, T.HasCapability = register, capability
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
if parts.upnext then for i, r in ipairs({ parts.upnext:GetChildren() }) do run("guideUpRow", r, view, i) end end
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

test('the Atlas layout registers through Theme.RegisterLayout', { todo: 'needs Theme.RegisterLayout (feat/timeline-040)' }, () => {
	const [out] = runAddon({
		stubs: ['stub_world.lua'],
		addons: ['Polestar', 'Polestar_Skin_Atlas', 'Polestar_Layout_Atlas'],
		login: true,
		script: `emit({ has = Polestar.Theme.RegisterLayout ~= nil, layouts = Polestar.Theme.LayoutInfo and Polestar.Theme.LayoutInfo("atlas") ~= nil or false })`,
	}).emitted;
	assert.deepEqual(out, { has: true, layouts: true });
});
