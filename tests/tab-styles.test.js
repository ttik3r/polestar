'use strict';
// Tab styles (addon/Polestar_TabStyles): with edge tabs the window's lines
// along the tabs' edge are cut under the active tab (drawn again as two
// pieces), and come back whole with another style.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { runAddon } = require('./helpers/lua');

const SCRIPT = `
w = stub.world
w.addMap(1429, { name = "Elwynn Forest", c = 0, left = 1500, right = -1500, top = 500, bottom = -1500 })
w.moveTo(1429, 48, 42)
Polestar.RegisterPack({ addon = "Polestar_Test", id = "test", format = 1, title = "Test", author = "Test", version = "1", license = "MIT" })
Polestar.Set("behavior.suggestFrom", "test")
Polestar.RegisterGuide({ id = "test/tabs", pack = "test", title = "Tabs", minLevel = 1, maxLevel = 20,
	steps = { { goals = { { t = "accept", quest = 7, title = "Kobold Camp Cleanup", npc = 197, npcName = "Marshal McBride" } } } } })
stub.login()
stub.fire("QUEST_LOG_UPDATE"); stub.advance(0.6)
Polestar.Set("ui.shown", true)
Polestar.Set("ui.border", true)
Polestar.Set("guideWindow.border", true)
Polestar.Set("guideWindow.tabs", true)
local GF = Polestar.UI.GuideFrame
local function draw() GF.Layout(); if GF.Render then GF.Render() end; stub.advance(1) end
local F = _G.PolestarGuideFrame
local function state()
	local top = F.psBorder and F.psBorder[1]
	local pieces = 0
	for _, r in ipairs({ F:GetRegions() }) do
		if r ~= top and r:IsShown() and r.GetVertexColor and top and r:GetHeight() == top:GetHeight() and r:GetAlpha() ~= 0 then
			local a, b = { r:GetVertexColor() }, { top:GetVertexColor() }
			if a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and r:GetDrawLayer() == top:GetDrawLayer() and select(2, r:GetDrawLayer()) == select(2, top:GetDrawLayer()) then pieces = pieces + 1 end
		end
	end
	return { border = top ~= nil and top:IsShown(), alpha = top and top:GetAlpha(), pieces = pieces }
end
Polestar.Set("guideWindow.tabStyle", "edge"); draw()
local edge = state()
Polestar.Set("guideWindow.tabStyle", "underline"); draw()
emit({ edge = edge, underline = state() })`;

test('edge tabs cut the window border under the active tab; another style gives it back whole', () => {
	const [out] = runAddon({ stubs: ['stub_world.lua'], addons: ['Polestar'], script: SCRIPT }).emitted;
	assert.equal(out.edge.border, true, JSON.stringify(out));
	assert.equal(out.edge.alpha, 0, 'the whole line is hidden under edge tabs');
	assert.ok(out.edge.pieces >= 2, `two pieces stand for it: ${JSON.stringify(out)}`);
	assert.equal(out.underline.alpha, 1, 'whole again with another style');
});
