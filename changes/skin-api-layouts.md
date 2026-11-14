---
section: contributors
---
- Skin API 2: layouts, the guide window's structure apart from its look.
  `Theme.RegisterLayout(id, spec)` takes only the structure hooks
  (`guideLayout`, `guideRender`, `guidePlace`, `guideAnchor`, `guideTakes`,
  `guidePerson`, `guideInset`, `guideUpRow`, `guideShows`, and
  `guideTitle`, `guideRow` and `guideProgress` for the title bar's parts, a
  goal row's lines and where the progress shows) and sits under
  any skin: the layout's hook answers first, then the skin's, then
  Polestar's own. For `guideTitle`, `guideRow`, `guideRender`,
  `guidePlace` and `guideProgress` the skin's hook runs too, after the
  layout's, to style what the layout laid out; the layout's answer wins
  unless it is nil, and for `guidePlace` the layout alone decides. The choice is `ui.layout` (`Theme.SetLayout(id)`; unset
  is Polestar's own layout). A `Polestar_Layout_<Name>` addon names its
  layouts with `## X-Polestar-Layout`, may load on demand, and is left out
  of the install check's version warning. Capability `layouts`.
- Skin API 2: a layout gives defaults for the guide window's settings
  (`defaults = { ["guideWindow.tabs"] = false, ... }`) instead of hiding
  parts the player can set. A setting reads the player's value, then the
  layout's default, then Polestar's; switching layout changes only the
  settings the player never set, and a reset goes back to the layout's
  default.
