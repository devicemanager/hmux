// Roles, names, states and visibility on the ARIA fixture.
// oracle: skip (snapshot text is hmux-defined)
await page.goto(`${PRIMARY}/aria.html`);
emitHmux("full", (await snapshot()).tree);
emitHmux("interactive", (await snapshot({ interactive: true })).tree);
emitHmux("show-hidden", (await snapshot({ showHidden: true })).tree);
