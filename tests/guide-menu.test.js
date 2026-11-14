'use strict';
// The guide window's menu (UI/GuideFrameMenu.lua): its entries in groups,
// each group after a separator, with no separator first, last or doubled.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { runAddon } = require('./helpers/lua');

const SCRIPT = `
w = stub.world
w.addMap(1429, { name = "Elwynn Forest", c = 0, left = 1500, right = -1500, top = 500, bottom = -1500 })
w.moveTo(1429, 48, 42)
Polestar.RegisterPack({ addon = "Polestar_Test", id = "test", format = 1, title = "Test", author = "Test", version = "1", license = "MIT" })
Polestar.Set("behavior.suggestFrom", "test")
Polestar.RegisterGuide({ id = "test/menu", pack = "test", title = "Menu", minLevel = 1, maxLevel = 20,
	steps = { { goals = { { t = "accept", quest = 7, title = "Kobold Camp Cleanup", npc = 197, npcName = "Marshal McBride" } } } } })
stub.login()
stub.fire("QUEST_LOG_UPDATE"); stub.advance(0.6)
Polestar.Set("ui.shown", true)
local GF = Polestar.UI.GuideFrame
GF.Layout(); stub.advance(1)
local W = Polestar.Widgets
local got
local show = W.ShowMenu
W.ShowMenu = function(_, items) got = items end
GF.OpenMenu(CreateFrame("Button", nil, UIParent))
W.ShowMenu = show
local out = {}
for _, it in ipairs(got or {}) do out[#out + 1] = it.separator and "-" or it.text end
emit(out)`;

test('the guide menu is in groups: guide, step, window, settings, tools, then the reset alone', () => {
	const [items] = runAddon({ stubs: ['stub_world.lua'], addons: ['Polestar'], script: SCRIPT }).emitted;
	assert.ok(items.length > 8, JSON.stringify(items));
	assert.notEqual(items[0], '-');
	assert.notEqual(items[items.length - 1], '-');
	for (let i = 1; i < items.length; i++) assert.ok(!(items[i] === '-' && items[i - 1] === '-'), `doubled separator: ${items}`);
	const groups = items.join('|').split('|-|').map((g) => g.split('|'));
	const where = (t) => groups.findIndex((g) => g.includes(t));
	assert.equal(where('Choose guide'), 0);
	assert.equal(where('Open in new tab'), 0);
	assert.equal(where('Skip this step'), where('All steps'));
	assert.equal(where('Compact mode'), where('Hide window'));
	assert.equal(where('Options'), where('Quick settings') === -1 ? where('Options') : where('Quick settings'));
	assert.deepEqual(groups[groups.length - 1], ['Reset guide progress'], 'the reset stands alone, last');
	assert.ok(where('Report a problem') > where('Options'));
});
