// Snapshot format on the form fixture: header, full tree, interactive tree,
// scoping by ref and by locator, combobox options, and the maxChars print budget.
// oracle: skip (snapshot text is hmux-defined)
await page.goto(`${PRIMARY}/`);
const s1 = await snapshot();
emitHmux("full", s1.tree);
emitHmux("prints-tree-first", String(s1) === s1.tree);
emitHmux("interactive", (await snapshot({ interactive: true })).tree);
const nav = s1.tree.match(/navigation "Main" \[ref=(\w+)\]/)[1];
emitHmux("scoped-ref", (await snapshot(nav)).tree);
emitHmux("scoped-locator", (await snapshot(page.locator("form"))).tree);
emitHmux("options", (await snapshot({ options: true })).tree.split("\n").filter((l) => /combobox|option/.test(l)));
// maxChars limits what prints (condensed, with a note); .tree stays complete.
// A new scope has no previous snapshot, so the tree prints.
const small = await snapshot(page.locator("body"), { maxChars: 500 });
emitHmux("max-chars", String(small));
emitHmux("max-chars-tree-complete", small.tree.split("\n").length === s1.tree.split("\n").length);
emitHmux("page-arg", (await snapshot(page, { interactive: true })).tree === (await snapshot({ interactive: true })).tree);
