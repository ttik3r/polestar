//! The guide window's tab styles (addon/Polestar/UI/GuideFrameTabStyles.lua and the load-on-demand
//! addon/Polestar_TabStyles, guideWindow.tabStyle): each of
//! underline, switcher, edge and strip draws its own tabs and hides the others, a change of style reaches the
//! live window at once and back, six tabs is the limit in every style, and the window's × never overlaps "…".
//! Against the real Core + Theme + UI manifests and the fake Engine (tests/lua/stub_ui.lua).

use forge_addontest::{emitted, Addon, RunAddon};
use serde_json::{json, Value};

const FILES: [&str; 3] = ["Core/Core.xml", "Theme/Theme.xml", "UI/UI.xml"];

const HELPERS: &str = r#"
local P = GF.parts
local nav = P.nav
local W = Polestar.Widgets
local STYLES = { "underline", "switcher", "edge", "strip" }
local THREE = { { uistub.elwynn, 3 }, { uistub.tailoring, 2 }, { uistub.stormwindRep, 2 } }
local SIX = { { uistub.elwynn, 3 }, { uistub.tailoring, 2 }, { uistub.stormwindRep, 2 },
	{ uistub.elwynn, 4 }, { uistub.tailoring, 3 }, { uistub.stormwindRep, 3 } }
local function style(s)
	Polestar.Set("guideWindow.tabStyle", s)
	stub.advance(1)
end
local function shown(f) return f and f:IsShown() and true or false end
local function count(list) local n = 0 for _, b in ipairs(list or {}) do if b:IsVisible() then n = n + 1 end end return n end
local function visible(f) return f and f:IsVisible() and true or false end
-- Which style's frames show, and how many tabs each draws.
local function drawn()
	return {
		strip = shown(P.strip), switch = shown(P.tabSwitch), edge = shown(P.tabEdge), side = shown(P.tabSide),
		title = shown(nav.Title), x = shown(P.windowClose), edgeClose = visible(P.tabEdge and P.tabEdge.Close),
		edgeTabs = count(P.tabEdge and P.tabEdge.tabs), sideTabs = count(P.tabSide and P.tabSide.tabs),
		badge = P.tabSwitch and visible(P.tabSwitch.Badge) and P.tabSwitch.Badge.Text:GetText() or false,
	}
end
-- Where a frame sits on screen: its anchors resolved up to UIParent (the stub keeps only the points).
local FX = { LEFT = 0, RIGHT = 1 }
local FY = { BOTTOM = 0, TOP = 1 }
local function side(point, t) for k, v in pairs(t) do if point:find(k) then return v end end return 0.5 end
local function rect(f)
	if not f or f == UIParent or #f.points == 0 then return { 0, f and f:GetWidth() or 0, 0, f and f:GetHeight() or 0 } end
	local xs, ys = {}, {}
	for _, p in ipairs(f.points) do
		local r = rect(p.rel or f:GetParent())
		local px = r[1] + side(p.relPoint, FX) * (r[2] - r[1]) + p.x
		local py = r[3] + side(p.relPoint, FY) * (r[4] - r[3]) + p.y
		xs[side(p.point, FX)], ys[side(p.point, FY)] = px, py
	end
	local function span(t, size)
		if t[0] and t[1] then return t[0], t[1] end
		for k, v in pairs(t) do return v - k * size, v - k * size + size end
	end
	local l, r = span(xs, f:GetWidth())
	local b, t = span(ys, f:GetHeight())
	return { l, r, b, t }
end
local function overlap(a, b)
	local ra, rb = rect(a), rect(b)
	if ra[1] == nil or rb[1] == nil then return true end
	return ra[1] < rb[2] and rb[1] < ra[2] and ra[3] < rb[4] and rb[3] < ra[4]
end
-- The switcher's menu, as W.ShowMenu is handed it.
local function switcherMenu()
	local items
	local show = W.ShowMenu
	W.ShowMenu = function(_, list) items = list end
	P.tabSwitch:GetScript("OnClick")(P.tabSwitch, "LeftButton")
	W.ShowMenu = show
	return items or {}
end
"#;

fn run(script: &str) -> Value {
	emitted(&RunAddon {
		stubs: vec!["stub_ui.lua"],
		addons: vec![Addon::files("Polestar", &FILES)],
		script: format!("uistub.install()\nstub.login()\nPolestar.UI.LoadOptions()\nlocal GF = Polestar.UI.GuideFrame\nlocal F = PolestarGuideFrame\n{HELPERS}\n{script}"),
		..Default::default()
	})
	.remove(0)
}

#[test]
fn each_style_draws_its_own_tabs_and_hides_the_others() {
	let out = run(r#"
		uistub.openTabs(THREE, 1)
		stub.advance(1)
		local out = { default = Polestar.Get("guideWindow.tabStyle") }
		for _, s in ipairs(STYLES) do style(s); out[s] = drawn() end
		emit(out)"#);
	assert_eq!(out["default"], "underline", "the strip above the step bar is the default");
	let common = |strip, switch, edge, side| json!([strip, switch, edge, side]);
	for (s, want) in [
		("underline", common(true, false, false, false)),
		("switcher", common(false, true, false, false)),
		("edge", common(false, false, true, false)),
		("strip", common(false, false, false, true)),
	] {
		let d = &out[s];
		assert_eq!(json!([d["strip"], d["switch"], d["edge"], d["side"]]), want, "{s}: only its own frames show");
	}
	assert_eq!(out["switcher"]["title"], false, "the switcher stands in for the guide's title");
	assert_eq!(out["switcher"]["badge"], "3", "the switcher's badge counts the open tabs");
	assert_eq!(out["edge"]["edgeTabs"], 3, "one edge tab per open guide");
	assert_eq!(out["edge"]["edgeClose"], true, "the edge style's × is a tab of its own");
	assert_eq!(out["edge"]["x"], false, "and the step bar has none");
	assert_eq!(out["strip"]["sideTabs"], 3, "one side tab per open guide");
	for s in ["underline", "switcher", "strip"] {
		assert_eq!(out[s]["x"], true, "{s}: the window's × sits right of the menu");
	}
}

#[test]
fn a_style_s_frames_are_made_the_first_time_it_is_drawn() {
	let out = run(r#"
		local T = Polestar.Theme
		-- A skin's guideLayout sees the edge row from the first layout it shows in.
		local seen = {}
		T.RegisterSkin("watcher", { name = "Watcher", addon = "Test_Watcher", base = "polestar",
			hooks = { guideLayout = function(parts) if parts.tabEdge and parts.tabEdge:IsShown() == false then seen[#seen + 1] = parts.tabEdge end end } })
		uistub.openTabs(THREE, 1)
		stub.advance(1)
		local function made() return { P.tabSwitch ~= nil, P.tabEdge ~= nil, P.tabSide ~= nil } end
		local out = { login = made(), guideParts = T.GuideParts().tabEdge == nil, close = P.windowClose ~= nil }
		Polestar.Set("ui.skin", "watcher")
		stub.advance(1)
		style("edge")
		out.edge = made()
		out.handed = T.GuideParts().tabEdge == P.tabEdge
		out.skinSaw = seen[1] == P.tabEdge
		out.edgeShown = shown(P.tabEdge)
		local edge = P.tabEdge
		style("underline")
		out.back = { made(), shown(P.tabEdge), P.tabEdge == edge, shown(P.strip) }
		Polestar.Set("ui.skin", "polestar")
		emit(out)"#);
	assert_eq!(out["login"], json!([false, false, false]), "on underline at login, no style's frames are made");
	assert_eq!(out["guideParts"], true, "Theme.GuideParts() has no tabEdge before the style is used");
	assert_eq!(out["close"], true, "underline with tabs on has the window's own ×");
	assert_eq!(out["edge"], json!([false, true, false]), "picking edge makes the edge row alone");
	assert_eq!(out["handed"], true, "Theme.GuideParts() hands it out once made");
	assert_eq!(out["skinSaw"], true, "a skin's guideLayout gets it in the layout that made it, before it shows");
	assert_eq!(out["edgeShown"], true);
	assert_eq!(out["back"], json!([[false, true, false], false, true, true]), "back on underline, the edge row is kept, hidden");
}

#[test]
fn a_change_of_style_reaches_the_live_window_and_back() {
	let out = run(r#"
		uistub.openTabs(THREE, 2)
		stub.advance(1)
		local before = { drawn(), math.floor(F:GetHeight() + 0.5), nav.Title:GetText() }
		local seen = {}
		for _, s in ipairs({ "switcher", "edge", "strip", "switcher", "edge" }) do style(s); seen[#seen + 1] = drawn() end
		style("underline")
		local after = { drawn(), math.floor(F:GetHeight() + 0.5), nav.Title:GetText() }
		-- Tabs off: no style draws, whichever is picked.
		style("edge")
		Polestar.Set("guideWindow.tabs", false)
		stub.advance(1)
		local off = drawn()
		Polestar.Set("guideWindow.tabs", true)
		stub.advance(1)
		emit({ before = before, after = after, seen = seen, off = off, on = drawn(), stripH = before[2] })"#);
	assert_eq!(out["before"], out["after"], "back on underline, the window is as it was");
	assert_eq!(out["seen"][0], out["seen"][3], "switcher twice draws the same");
	assert_eq!(out["seen"][1], out["seen"][4], "edge twice draws the same");
	let off = &out["off"];
	assert_eq!(json!([off["strip"], off["switch"], off["edge"], off["side"], off["x"]]), json!([false, false, false, false, false]), "tabs off: no style draws");
	assert_eq!(out["on"]["edge"], true, "tabs on again: the picked style comes back");
}

#[test]
fn six_tabs_is_the_limit_in_every_style() {
	let out = run(r#"
		local out = {}
		for _, list in ipairs({ THREE, SIX }) do
			uistub.openTabs(list, 1)
			stub.advance(1)
			local r = {}
			style("underline")
			r.underline = { P.strip.Add.psTip, P.strip.Add:IsEnabled() and true or false }
			style("edge")
			r.edge = { P.tabEdge.Add.psTip, P.tabEdge.Add:IsEnabled() and true or false, count(P.tabEdge.tabs) }
			style("strip")
			r.strip = { P.tabSide.Add.psTip, P.tabSide.Add:IsEnabled() and true or false, count(P.tabSide.tabs) }
			style("switcher")
			local add
			for _, it in ipairs(switcherMenu()) do if it.icon == "plus" then add = it end end
			r.switcher = { add and add.tip or false, add and not add.disabled or false, P.tabSwitch.Badge.Text:GetText() }
			out[#out + 1] = r
		end
		emit(out)"#);
	let three = &out[0];
	let six = &out[1];
	for s in ["edge", "strip"] {
		assert_eq!(three[s][0], "Open a guide in a new tab", "{s}: room for more");
		assert_eq!(three[s][1], true);
		assert_eq!(six[s][0], "Six tabs is the limit", "{s}: full at six");
		assert_eq!(six[s][1], false, "{s}: + is off at six");
		assert_eq!(six[s][2], 6, "{s}: all six drawn");
	}
	assert_eq!(three["underline"][0], "Open a guide in a new tab");
	assert_eq!(six["underline"][0], "Six tabs is the limit");
	assert_eq!(six["underline"][1], false, "underline: + is off at six");
	assert_eq!(three["switcher"], json!([false, true, "3"]), "switcher: the menu's new-tab item is on below six");
	assert_eq!(six["switcher"], json!(["Six tabs is the limit", false, "6"]), "switcher: off at six, with the limit's tip");
}

#[test]
fn the_window_close_never_overlaps_the_menu() {
	let out = run(r#"
		local out = {}
		for _, list in ipairs({ THREE, SIX }) do
			uistub.openTabs(list, 1)
			stub.advance(1)
			for _, w in ipairs({ 300, 420 }) do
				Polestar.Set("ui.width", w)
				for _, s in ipairs(STYLES) do
					style(s)
					local close = P.windowClose:IsShown() and P.windowClose or P.tabEdge.Close
					local m, c = rect(nav.Menu), rect(close)
					out[#out + 1] = { s .. " " .. #list .. " tabs " .. w, close:IsShown() and true or false,
						not overlap(close, nav.Menu), s == "edge" or c[1] >= m[2], table.concat(m, ","), table.concat(c, ",") }
				end
			end
		end
		emit(out)"#);
	for row in out.as_array().unwrap() {
		assert_eq!(row[1], true, "{}: a × shows", row[0]);
		assert_eq!(row[2], true, "{}: the × and \"…\" do not overlap {} {}", row[0], row[4], row[5]);
		assert_eq!(row[3], true, "{}: the × is right of \"…\"", row[0]);
	}
}

// Switcher, edge and strip live in their own addon (Polestar_TabStyles, load on demand): on underline at login
// nothing of it is loaded, the first of its styles picked loads it once and draws, and back on underline it
// stays loaded with its frames hidden.
#[test]
fn the_other_styles_load_with_the_first_of_them_picked() {
	let out = run(r#"
		local loads = 0
		local load = C_AddOns.LoadAddOn
		function C_AddOns.LoadAddOn(name, ...)
			if name == "Polestar_TabStyles" then loads = loads + 1 end
			return load(name, ...)
		end
		uistub.openTabs(THREE, 1)
		stub.advance(1)
		local function state()
			return { loaded = stub.addonsLoaded.Polestar_TabStyles == true, build = GF.TabStyleBuild ~= nil, menu = W.MenuRows ~= nil, loads = loads }
		end
		local out = { login = state(), x = shown(P.windowClose) }
		style("edge")
		out.edge = state()
		out.drawn = drawn()
		style("strip")
		out.strip = drawn()
		style("underline")
		out.back = state()
		out.underline = drawn()
		emit(out)"#);
	assert_eq!(out["login"], json!({ "loaded": false, "build": false, "menu": false, "loads": 0 }), "underline at login loads nothing of the other styles");
	assert_eq!(out["x"], true, "underline keeps the window's ×");
	assert_eq!(out["edge"], json!({ "loaded": true, "build": true, "menu": true, "loads": 1 }), "picking edge loads them");
	assert_eq!(out["drawn"]["edge"], true);
	assert_eq!(out["drawn"]["edgeTabs"], 3, "and draws its tabs");
	assert_eq!(out["strip"]["sideTabs"], 3, "a second style needs no second load");
	assert_eq!(out["back"]["loads"], 1);
	assert_eq!(json!([out["underline"]["strip"], out["underline"]["edge"], out["underline"]["side"]]), json!([true, false, false]));
}

// The settings preview's copy, made before the styles' addon loads, draws them once it does.
#[test]
fn a_copy_made_before_the_load_draws_the_other_styles() {
	let out = run(r#"
		uistub.openTabs(THREE, 1)
		stub.advance(1)
		local content = {}
		for _, k in ipairs(GF.CONTENT) do
			content[k] = function(...) local E = Polestar.Engine; if E[k] then return E[k](...) end end
		end
		local copy = GF.Copy(UIParent, content)
		local before = copy.TabStyleBuild ~= nil
		style("strip")
		copy.Draw()
		emit({ before = before, after = copy.TabStyleBuild ~= nil, live = shown(P.tabSide),
			copy = copy.parts.tabSide ~= nil and copy.parts.tabSide ~= P.tabSide and copy.parts.tabSide:IsShown() })"#);
	assert_eq!(out["before"], false);
	assert_eq!(out["after"], true, "the late part joins the copy");
	assert_eq!(out["live"], true);
	assert_eq!(out["copy"], true, "and the copy draws the style in frames of its own");
}

// Without the addon (missing or turned off in the AddOns list), the window keeps the underline strip and the
// chat says so once.
#[test]
fn without_the_styles_addon_the_tabs_stay_above_the_step_bar_and_the_chat_says_so_once() {
	let out = run(r#"
		local load = C_AddOns.LoadAddOn
		function C_AddOns.LoadAddOn(name, ...)
			if name == "Polestar_TabStyles" then return false, "DISABLED" end
			return load(name, ...)
		end
		uistub.openTabs(THREE, 1)
		stub.advance(1)
		local before = #stub.messages
		style("edge")
		local d = drawn()
		style("switcher")
		style("strip")
		local said = {}
		for i = before + 1, #stub.messages do said[#said + 1] = stub.messages[i] end
		emit({ picked = Polestar.Get("guideWindow.tabStyle"), style = GF.TabStyle(), strip = d.strip, x = d.x, said = said, outside = { GF.TabsOutside() } })"#);
	assert_eq!(out["picked"], "strip", "the choice is kept for when the addon is back");
	assert_eq!(out["style"], "underline");
	assert_eq!(out["strip"], true, "the tabs stay above the step bar");
	assert_eq!(out["x"], true);
	assert_eq!(out["outside"], json!([0, 0]));
	let said = out["said"].as_array().unwrap();
	assert_eq!(said.len(), 1, "one line: {said:?}");
	assert!(said[0].as_str().unwrap().contains("Polestar_TabStyles"), "{}", said[0]);
}
