export const comparePages = [
  {
    slug: "best-terminal-for-ai-coding-agents",
    key: "bestTerminalForAgents",
    lastModified: "2026-07-04",
  },
  {
    slug: "hmux-vs-alacritty",
    key: "hmuxVsAlacritty",
    lastModified: "2026-07-04",
  },
  {
    slug: "hmux-vs-conductor",
    key: "hmuxVsConductor",
    lastModified: "2026-07-04",
  },
  {
    slug: "hmux-vs-cursor",
    key: "hmuxVsCursor",
    lastModified: "2026-07-04",
  },
  {
    slug: "hmux-vs-devin",
    key: "hmuxVsDevin",
    lastModified: "2026-07-04",
  },
  {
    slug: "hmux-vs-ghostty",
    key: "hmuxVsGhostty",
    lastModified: "2026-07-04",
  },
  {
    slug: "hmux-vs-herdr",
    key: "hmuxVsHerdr",
    lastModified: "2026-07-04",
  },
  {
    slug: "hmux-vs-iterm2",
    key: "hmuxVsIterm2",
    lastModified: "2026-07-04",
  },
  {
    slug: "hmux-vs-kitty",
    key: "hmuxVsKitty",
    lastModified: "2026-07-04",
  },
  {
    slug: "hmux-vs-opencode",
    key: "hmuxVsOpencode",
    lastModified: "2026-07-04",
  },
  {
    slug: "hmux-vs-superset",
    key: "hmuxVsSuperset",
    lastModified: "2026-07-04",
  },
  {
    slug: "hmux-vs-tmux",
    key: "hmuxVsTmux",
    lastModified: "2026-07-04",
  },
  {
    slug: "hmux-vs-vscode",
    key: "hmuxVsVscode",
    lastModified: "2026-07-04",
  },
  {
    slug: "hmux-vs-warp",
    key: "hmuxVsWarp",
    lastModified: "2026-07-04",
  },
  {
    slug: "hmux-vs-wezterm",
    key: "hmuxVsWezterm",
    lastModified: "2026-07-04",
  },
  {
    slug: "hmux-vs-windsurf",
    key: "hmuxVsWindsurf",
    lastModified: "2026-07-04",
  },
  {
    slug: "hmux-vs-zed",
    key: "hmuxVsZed",
    lastModified: "2026-07-04",
  },
  {
    slug: "multiple-claude-code-agents-parallel",
    key: "multipleClaudeAgents",
    lastModified: "2026-07-04",
  },
] as const;

export type ComparePage = (typeof comparePages)[number];
export type ComparePageKey = ComparePage["key"];

export function comparePath(slug: string) {
  return `/compare/${slug}`;
}

export function comparePageForSlug(slug: string): ComparePage | undefined {
  return comparePages.find((page) => page.slug === slug);
}
