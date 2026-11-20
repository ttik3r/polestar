'use strict';
// The default guide window's audit fixes, in
// addon/Polestar/UI/GuideFrame*.lua. Against the real Core, Theme and UI and
// the fakes of tests/lua/stub_ui.lua.

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { runAddon } = require('./helpers/lua');

const FILES = ['Core/Core.xml', 'Theme/Theme.xml', 'UI/UI.xml'];

function run(script) {
	return runAddon({
		stubs: ['stub_ui.lua'],
		addons: [{ name: 'Polestar', files: FILES }],
		script: `uistub.install()\nstub.login()\nlocal GF = Polestar.UI.GuideFrame\n${script}`,
	}).emitted;
}

test('opening a "Then:" line brings it and its goals into sight', () => {
	const [out] = run(`
		uistub.setGuide(uistub.elwynn, 4)
		Polestar.Set("ui.wholeStep", false)
		Polestar.Set("ui.maxHeight", 0.01)
		GF.Render() GF.Layout()
		local goals = GF.parts.goals
		local line
		for _, o in ipairs(GF.CardItems()) do
			if o.psKey and o.psKey ~= "done" and o:IsShown() and o.psTitle == "Brother Neals" then line = o end
		end
		line:GetScript("OnClick")(line)
		stub.advance(1)
		local top, view = goals:GetVerticalScroll(), goals.psViewH
		local items, last = GF.CardItems(), nil
		for i, o in ipairs(items) do if o == line then last = items[i + 1] end end
		local y = GF.ItemTop(line)
		emit({ over = goals.psOver, top = top, view = view, y = y, rowY = last and GF.ItemTop(last), rowGoal = last and last.psGoal ~= nil })`);
	assert.equal(out.over, true, 'the goals area scrolls');
	assert.equal(out.rowGoal, true, 'the opened line has its goal under it');
	assert.ok(out.y >= out.top - 0.5, `the line is in sight: ${out.y} from ${out.top}`);
	assert.ok(out.rowY < out.top + out.view, `its goal is in sight: ${out.rowY} in ${out.top}+${out.view}`);
});

test('banners tint by their kind and resting glyphs are dim; the accent stays the live goal\'s', () => {
	const [out] = run(`
		uistub.setGuide(uistub.elwynn, 3)
		local T, banner = Polestar.Theme, GF.parts.banner
		local function same(tex, role)
			local r, g, b = tex:GetVertexColor()
			local R, G, B = T.Color(role)
			return math.abs(r - R) < 0.01 and math.abs(g - G) < 0.01 and math.abs(b - B) < 0.01
		end
		local out = {}
		GF.LayoutBanner(400, true, "bags", { free = 0, need = 2 })
		out.bagsIcon, out.bagsFill = same(banner.Icon, "warning"), same(banner.Fill, "warning")
		GF.LayoutBanner(400, true, "lost", { title = "Kobold Camp Cleanup" })
		out.lostIcon, out.lostFill = same(banner.Icon, "textDim"), same(banner.Fill, "textDim")
		out.lostLink = same(banner.Jump.Arrow, "accent")
		for _, r in ipairs(GF.rows) do
			if r:IsShown() and r.psGoal and r.psGoal.status ~= "done" then
				out[#out + 1] = { live = r.psRowInfo.current, accent = same(r.Icon, "accent"), dim = same(r.Icon, "textDim") }
			end
		end
		emit(out)`);
	assert.deepEqual([out.bagsIcon, out.bagsFill], [true, true], 'the bags banner in the warning colour');
	assert.deepEqual([out.lostIcon, out.lostFill], [true, true], 'another kind neutral');
	assert.equal(out.lostLink, true, 'its main action keeps the accent');
	const rows = Object.keys(out).filter((k) => /^\d+$/.test(k)).map((k) => out[k]);
	assert.ok(rows.length >= 2, 'open goals on the card');
	for (const r of rows) assert.deepEqual([r.accent, r.dim], r.live ? [true, false] : [false, true]);
});
