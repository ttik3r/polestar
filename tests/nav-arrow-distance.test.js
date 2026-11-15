'use strict';
// The arrow's distance (addon/Polestar/Nav/Arrow.lua, Nav.ArrowDistance):
// to the yard near the goal, steadier further out so its digits do not
// change several times a second on the run, and from 1000 yd as the Journey
// panel writes it. Runs the real Core/Init.lua + Nav/Nav.xml against
// tests/lua/stub_nav.lua.

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { runAddon } = require('./helpers/lua');

function run(script) {
	return runAddon({
		stubs: ['stub_nav.lua'],
		addons: [{ name: 'Polestar', files: ['Core/Init.lua', 'Nav/Nav.xml'] }],
		login: true,
		script: `local N, nav = Polestar.Nav, stub.nav\n${script}`,
	}).emitted[0];
}

test('the arrow writes a distance to the yard under 100, to 5 from 100, to 10 from 500 and as Journey does from 1000, in yards or metres', () => {
	const out = run(`
		local yards = {}
		for _, d in ipairs({ 42.4, 99.4, 101, 103, 497, 503, 507, 994, 1000, 1240, 8049 }) do yards[#yards + 1] = N.ArrowDistance(d) end
		local same = Polestar.FormatDistance(1240, { compact = true }) == N.ArrowDistance(1240)
		Polestar.Set("nav.distanceUnit", "metres")
		local metres = {}
		-- 42.4 yd = 38.8 m, 120 yd = 109.7 m, 600 yd = 548.6 m, 1240 yd = 1.13 km
		for _, d in ipairs({ 42.4, 120, 600, 1240 }) do metres[#metres + 1] = N.ArrowDistance(d) end
		emit({ yards = yards, same = same, metres = metres })`);
	assert.deepEqual(out.yards, ['42 yd', '99 yd', '100 yd', '105 yd', '495 yd', '500 yd', '510 yd', '990 yd', '1.0k yd', '1.2k yd', '8.0k yd']);
	assert.equal(out.same, true, 'from 1000 yd the arrow and the Journey panel show the same number');
	assert.deepEqual(out.metres, ['39 m', '110 m', '550 m', '1.1 km']);
});

test('walking toward the target, the arrow redraws its distance only when the number it shows changes', () => {
	const out = run(`
		local m, x, y = nav.mapPoint(0, 700)
		N.SetTarget(m, x, y, "T")
		nav.place(0, 0)
		stub.advance(0.2)
		local A = N.arrow
		local sets, texts = 0, {}
		local set = A.distText.SetText
		A.distText.SetText = function(self, text)
			sets = sets + 1
			texts[#texts + 1] = text
			return set(self, text)
		end
		-- 40 yd at a yard a sample (20 a second): 700 yd down to 660.
		for i = 1, 40 do
			nav.place(0, i)
			stub.advance(0.05)
		end
		-- Near the goal it counts every yard.
		for i = 1, 5 do
			nav.place(0, 640 + i)
			stub.advance(0.05)
		end
		emit({ sets = sets, texts = texts, last = A.distText:GetText() })`);
	assert.deepEqual(out.texts.slice(0, 4), ['690 yd', '680 yd', '670 yd', '660 yd'], 'from 500 yd, a new number every 10 yd');
	assert.equal(out.sets, 9, `four redraws on the 40 yd run and one a yard near the goal: ${out.texts.join(', ')}`);
	assert.equal(out.last, '55 yd');
});
