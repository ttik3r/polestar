'use strict';
// The shared menu (W.ShowMenu, addon/Polestar/Theme/Widgets.lua): the popup
// list behind the guide window's buttons, tab options and dropdowns. Against
// the real Core and Theme on the generic fake client.

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { runAddon } = require('./helpers/lua');

function run(script) {
	return runAddon({
		addons: [{ name: 'Polestar', files: ['Core/Core.xml', 'Theme/Theme.xml'] }],
		script: `stub.login()\nlocal W = Polestar.Widgets\n${script}`,
	}).emitted[0];
}

test('opening a menu hides its button\'s hover tip, and leaves another frame\'s tip alone', () => {
	const out = run(`
		local b = W.IconButton(UIParent, "menu", 24, "Menu", function() end)
		b:SetPoint("CENTER")
		stub.RunScript(b, "OnEnter")
		local before = GameTooltip:IsShown() and GameTooltip:GetOwner() == b
		W.ShowMenu(b, { { text = "Choose guide" }, { text = "Skip this step" } })
		local gameTip = GameTooltip:IsShown()
		W.HideMenu()
		-- The settings window's own tip, on its owner.
		W.Tip(b, "Menu", { "Right-click for tab options" })
		W.ShowMenu(b, { { text = "Close tab" } })
		local ownTip = W.TipShown() ~= nil
		W.HideMenu()
		-- A tip that is not the menu's owner's stays.
		local other = CreateFrame("Button", nil, UIParent)
		W.Tooltip(other, "ANCHOR_TOP", "Nearby services")
		W.ShowMenu(b, { { text = "Close tab" } })
		emit({ before = before, gameTip = gameTip, ownTip = ownTip, otherTip = GameTooltip:IsShown() and GameTooltip:GetOwner() == other })`);
	assert.equal(out.before, true, 'hovering the button shows its tip');
	assert.equal(out.gameTip, false, 'the tip goes as its button\'s menu opens');
	assert.equal(out.ownTip, false, 'Polestar\'s own tip goes too');
	assert.equal(out.otherTip, true, 'another frame\'s tip is not the menu\'s to hide');
});

test('a row that asks for a second click fits "Click again to confirm" in any language, and forgets the first click after three seconds', () => {
	const out = run(`
		-- A long translation of the confirm text.
		Polestar.L["Click again to confirm"] = "Нажмите ещё раз, чтобы подтвердить сброс"
		local anchor = CreateFrame("Frame", nil, UIParent)
		anchor:SetSize(100, 20)
		anchor:SetPoint("CENTER")
		local reset = 0
		W.ShowMenu(anchor, { { text = "Rename" }, { text = "Reset", confirm = true, onClick = function() reset = reset + 1 end } })
		local m = PolestarMenu
		local row = m.rows[2]
		local w = m:GetWidth()
		row:Click()
		local armed = { text = row.Text:GetText(), open = m:IsShown(), sameWidth = m:GetWidth() == w,
			fits = row.Text:GetStringWidth() + 12 <= m:GetWidth() }
		stub.advance(3.1)
		local expired = { text = row.Text:GetText(), open = m:IsShown() }
		row:Click()
		local rearmed = { reset = reset, open = m:IsShown() }
		stub.advance(1)
		row:Click()
		emit({ armed = armed, expired = expired, rearmed = rearmed, confirmed = { reset = reset, open = m:IsShown() } })`);
	assert.deepEqual(out.armed, { text: 'Нажмите ещё раз, чтобы подтвердить сброс', open: true, sameWidth: true, fits: true },
		'the first click asks again inside the menu, which already has room for it');
	assert.deepEqual(out.expired, { text: 'Reset', open: true }, 'three seconds on, the row is back to its label');
	assert.deepEqual(out.rearmed, { reset: 0, open: true }, 'a click after that asks again rather than acting');
	assert.deepEqual(out.confirmed, { reset: 1, open: false }, 'a second click in time acts and closes the menu');
});
