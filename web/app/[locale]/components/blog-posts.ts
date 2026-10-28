import {
  englishFallbackContentLocales,
  fallbackContentLocales,
} from "@/i18n/locale-availability";
import { lawrenceChen, type BlogAuthor } from "./blog-authors";

export type BlogPost = {
  slug: string;
  key: string;
  title: string;
  date: string;
  summary: string;
  author: BlogAuthor;
  locales?: readonly string[];
};

export const blogPosts = [
  {
    slug: "367-billion-tokens",
    key: "tokenMultitasking",
    title: "How I used 367 billion tokens in 30 days",
    date: "2026-07-29",
    summary:
      "My hmux loop is Cmd+Shift+U, review the next finished agent, reply, repeat, then start another task when the notification queue is empty.",
    author: lawrenceChen,
    locales: fallbackContentLocales,
  },
  {
    slug: "claude-code-best-worktree-manager",
    key: "claudeCodeBestWorktreeManager",
    title: "Superrepos and Why Claude Code Is the Best Worktree Manager",
    date: "2026-07-23",
    summary:
      "A lot of people have asked why hmux doesn't have a worktree manager yet. The best manager can choose a worktree, second checkout, sandbox, VM, or GPU cluster.",
    author: lawrenceChen,
    locales: fallbackContentLocales,
  },
  {
    slug: "hmux-fork",
    key: "hmuxFork",
    title: "Introducing hmux Fork",
    date: "2026-07-14",
    summary:
      "Branch an agent conversation into a new split, tab, or workspace without losing its context.",
    author: lawrenceChen,
  },
  {
    slug: "hmux-home",
    key: "hmuxHome",
    title: "hmux home",
    date: "2026-06-23",
    summary:
      "We're not adding worktrees to hmux. It's a primitive, so you can script your own worktrees, multiple checkouts, or remote dev and make it feel like home.",
    author: lawrenceChen,
  },
  {
    slug: "hmux-history",
    key: "hmuxHistory",
    title: "hmux history",
    date: "2026-06-02",
    summary:
      "Reopen closed terminals, browsers, workspaces, and agent sessions with Cmd+Shift+T, and retrace your focus with Cmd+[ and Cmd+].",
    author: lawrenceChen,
  },
  {
    slug: "hmux-finder",
    key: "hmuxFinder",
    title: "Introducing hmux Finder",
    date: "2026-05-22",
    summary:
      "hmux now has a file explorer that previews videos, images, PDFs, and markdown files.",
    author: lawrenceChen,
  },
  {
    slug: "hmux-vault",
    key: "hmuxVault",
    title: "hmux Vault",
    date: "2026-05-22",
    summary:
      "Search Codex, Claude Code, OpenCode, and Pi sessions from the Vault pane and drag them into your workspace.",
    author: lawrenceChen,
  },
  {
    slug: "passkey-auth",
    key: "passkeyAuth",
    title: "Passkey auth in the hmux browser",
    date: "2026-05-22",
    summary:
      "hmux's embedded browser supports passkey authentication and can import cookies from other browsers with hmux browser import.",
    author: lawrenceChen,
  },
  {
    slug: "task-manager",
    key: "taskManager",
    title: "Task Manager in hmux",
    date: "2026-05-22",
    summary:
      "Use hmux top or Task Manager from the command palette to see CPU and RAM usage for your coding agents.",
    author: lawrenceChen,
  },
  {
    slug: "markdown-viewer",
    key: "markdownViewer",
    title: "A better markdown viewer in hmux",
    date: "2026-05-22",
    summary:
      "Open README.md with hmux open or drag markdown files from the right sidebar.",
    author: lawrenceChen,
  },
  {
    slug: "unread-shortcuts",
    key: "unreadShortcuts",
    title: "Unread workspace shortcuts in hmux",
    date: "2026-05-22",
    summary:
      "Cmd+Control+U cycles through unread workspaces while keeping them unread, and Cmd+Option+U toggles read state.",
    author: lawrenceChen,
  },
  {
    slug: "session-restore",
    key: "sessionRestore",
    title: "Session restore in hmux",
    date: "2026-05-13",
    summary:
      "hmux restores layout, scrollback, browser history, and supported agent sessions when hooks have captured a resume token.",
    author: lawrenceChen,
  },
  {
    slug: "hmux-ssh",
    key: "hmuxSsh",
    title: "hmux SSH",
    date: "2026-03-30",
    summary:
      "One command gives you persistent remote sessions, browser panes that reach remote ports, and agent notifications that come home.",
    author: lawrenceChen,
    locales: fallbackContentLocales,
  },
  {
    slug: "hmux-claude-teams",
    key: "hmuxClaudeTeams",
    title: "Claude Code teammate agents as native hmux panes",
    date: "2026-03-30",
    summary:
      "Claude Code's teammate mode requires tmux. hmux fakes it so teammates become native splits with sidebar metadata and notifications.",
    author: lawrenceChen,
    locales: englishFallbackContentLocales,
  },
  {
    slug: "hmux-omo",
    key: "hmuxOmo",
    title: "oh-my-openagent subagents as native hmux panes",
    date: "2026-03-30",
    summary:
      "oh-my-openagent (formerly oh-my-opencode) orchestrates parallel specialist agents across Claude, GPT, and Gemini. hmux omo turns their tmux panes into native splits.",
    author: lawrenceChen,
    locales: englishFallbackContentLocales,
  },
  {
    slug: "gpl",
    key: "gpl",
    title: "hmux is now GPL",
    date: "2026-03-30",
    summary:
      "hmux relicensed from AGPL-3.0 to GPL-3.0.",
    author: lawrenceChen,
    locales: englishFallbackContentLocales,
  },
  {
    slug: "cmd-shift-u",
    key: "cmdShiftU",
    title: "Cmd+Shift+U",
    date: "2026-03-04",
    summary:
      "How Cmd+Shift+U navigates between finished agents across workspaces in hmux.",
    author: lawrenceChen,
  },
  {
    slug: "zen-of-hmux",
    key: "zenOfHmux",
    title: "The Zen of hmux",
    date: "2026-02-27",
    summary:
      "hmux is a primitive, not a solution. It gives you composable pieces and your workflow is up to you.",
    author: lawrenceChen,
  },
  {
    slug: "show-hn-launch",
    key: "showHnLaunch",
    title: "Launching hmux on Show HN",
    date: "2026-02-21",
    summary:
      "hmux hit #2 on Hacker News, got shared by Mitchell Hashimoto, and went viral in Japan.",
    author: lawrenceChen,
  },
  {
    slug: "introducing-hmux",
    key: "introducingHmux",
    title: "Introducing hmux",
    date: "2026-02-12",
    summary:
      "A native macOS terminal built on Ghostty, designed for running multiple AI coding agents side by side.",
    author: lawrenceChen,
  },
] satisfies readonly BlogPost[];

export function blogPostsForLocale(locale: string) {
  return blogPosts.filter(
    (post) => !post.locales || post.locales.some((candidate) => candidate === locale),
  );
}
