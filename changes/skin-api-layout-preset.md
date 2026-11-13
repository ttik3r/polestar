---
section: contributors
---
- Skin API 2: a layout can put its own card in the guide window's Presets
  (`preset = { label, help, set }`, capability `layouts.preset`). Picking it
  chooses the layout, loading its addon, then writes `set` (look settings
  and the skin it is drawn for); Polestar's own cards go back to Polestar's
  own layout. A layout that loads on demand names its card in its TOC
  (`## X-Polestar-Layout-Preset: ledger = Ledger`). A guide window copy
  draws with a layout of its own (`Theme.SkinHookFor`,
  `Theme.SkinHookValueFor`), so the layout's card shows its layout and
  Polestar's own cards stay Polestar's own layout while another is in use.
  A layout's `onLeave(id, parts, live)` runs once for each guide window it
  dressed, the settings preview too, so leaving a layout gives every window
  Polestar's own layout back.
