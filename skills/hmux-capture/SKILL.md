---
name: hmux-capture
description: Screenshot or record a hmux window from the CLI, for a pull request, a bug report, or to see what the app actually looks like right now. Use when a change is visual, when a drag or an animation cannot be described in text, or when a reviewer needs evidence rather than a claim.
---

# Screenshots and clips of hmux

`hmux shot` writes a png or a jpeg of a hmux window. `hmux record` writes an mp4
or a gif of one. Both capture only hmux's own windows, both go through the
same permission-free path, and both work in a release build and inside CI. No
Screen Recording permission is involved and none is ever requested.

```bash
hmux shot --label settings-sheet                  # png of the frontmost window
hmux shot --jpg --max-width 1200 --out ~/before.jpg
hmux record start --gif --max-seconds 8 --label sidebar-drag
hmux record note "dragging the workspace"         # caption, drawn into the clip
hmux record stop
```

`shot` prints `<width>x<height> <bytes> <path>`. `record` prints
`<id> <state> <frames> <path>`. Both take `--json` for the whole response.

## Which one

Take a screenshot when the thing is still: a sheet, a menu, a layout, a label,
a color. Record when the thing is a change over time: a drag, an animation, a
reorder, two views settling in an order, a spinner that should stop. A
screenshot of a drag shows nothing, and a clip of a static sheet is a large file
a reviewer has to click to play.

## Working from a clip to a still

`--region x,y,w,h` is the same rectangle in both commands, in window points from
the window's top left. So a detail noticed in a clip can be shot with the same
four numbers:

```bash
hmux record start --region 0,0,420,900 --max-seconds 6   # watch the sidebar
hmux shot --region 0,0,420,900 --label sidebar-final     # keep the end state
```

## Notes for an agent recording its own hmux

- A recording **stops itself** at `--max-seconds` (default 15, maximum 120), so
  a clip is never left running by an agent that stops paying attention. Set it
  above the time the actions take or the clip ends early.
- **One at a time.** A second `record start` is refused with `conflict` while
  one is running. `hmux record list` says whether anything is going, and
  `hmux record status` reports the frame count, with the effective frame rate
  in `--json`.
- **Caption as you go.** `hmux record note "<text>"` draws text into the clip
  from that moment on. A clip has no step list beside it, so one note before
  each thing a reviewer should notice is worth more than a longer clip.
  `--no-captions` turns them off.
- **The clip is only hmux.** Another app in front of the hmux window does not
  appear in the frames, so a capture does not have to own the screen.
- **Frames are timed by when they were captured**, so a clip plays at the speed
  things happened even when the sampler fell behind the requested rate. Check
  `fps_effective` in `--json` if a clip looks slower than expected.
- A `gif` is the shape to paste into a pull request, and `--gif` already picks
  the 8 fps and half scale that keep one small; an mp4 is sharper and needs a
  click to play. `scripts/pr-media.py` uploads either and converts an mp4 to a
  gif on the way.
- Neither command replaces a directory or destroys an existing file before the
  new one is closed. `--out` on a path that is not a file is refused, and so is
  one whose extension does not match the format: `--out clip.gif` needs `--gif`.

## In a CI dogfood tour

A dogfood scenario records with a `record` step wrapping the steps that matter,
and captions with `note`, rather than by calling the CLI. The step table and the
options are in
[hmux-testing/references/dogfood-scenarios.md](../hmux-testing/references/dogfood-scenarios.md).

## Deep-dive references

| Reference | When to use |
| --- | --- |
| [references/commands.md](references/commands.md) | Every flag, the response shape, the error codes, window selection, limits |
