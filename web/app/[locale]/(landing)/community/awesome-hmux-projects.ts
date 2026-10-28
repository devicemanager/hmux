export type AwesomeHmuxProject = {
  name: string;
  url: string;
  agent?: string;
  descriptionKey: string;
  language?: string;
  stars?: number;
  categories: readonly string[];
};

export const awesomeHmuxSourceUrl = "https://github.com/manaflow-ai/awesome-cmux";
export const awesomeHmuxCuratedProjectRows = 150;

export const awesomeHmuxCategoryOrder = [
  "Sidebar & Status Pills",
  "Progress Bars & Estimation",
  "Sidebar Logs & Activity Feed",
  "Desktop Notifications",
  "Multi-Agent Orchestration",
  "Browser Automation",
  "Worktrees & Workspace Management",
  "Monitoring & Session Restore",
  "Remote & Mobile Access",
  "Themes, Layouts & Config",
  "Claude Code",
  "Pi",
  "OpenCode",
  "Copilot & Amp",
  "Multi-Agent / Agent-Agnostic",
  "Build & Distribution"
] as const;

export const awesomeHmuxProjects = [
  {
    "name": "Yeachan-Heo/oh-my-claudecode",
    "url": "https://github.com/Yeachan-Heo/oh-my-claudecode",
    "agent": "Claude Code",
    "descriptionKey": "p001",
    "language": "TypeScript",
    "stars": 32659,
    "categories": [
      "Multi-Agent Orchestration",
      "Sidebar Logs & Activity Feed",
      "Claude Code"
    ]
  },
  {
    "name": "kdcokenny/opencode-worktree",
    "url": "https://github.com/kdcokenny/opencode-worktree",
    "agent": "OpenCode",
    "descriptionKey": "p002",
    "language": "TypeScript",
    "stars": 504,
    "categories": [
      "Worktrees & Workspace Management",
      "OpenCode"
    ]
  },
  {
    "name": "HazAT/pi-interactive-subagents",
    "url": "https://github.com/HazAT/pi-interactive-subagents",
    "agent": "Multi",
    "descriptionKey": "p003",
    "language": "TypeScript",
    "stars": 429,
    "categories": [
      "Progress Bars & Estimation",
      "Multi-Agent Orchestration",
      "Monitoring & Session Restore",
      "Pi",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "kdcokenny/opencode-workspace",
    "url": "https://github.com/kdcokenny/opencode-workspace",
    "agent": "OpenCode",
    "descriptionKey": "p004",
    "language": "TypeScript",
    "stars": 402,
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Worktrees & Workspace Management",
      "OpenCode"
    ]
  },
  {
    "name": "aannoo/hcom",
    "url": "https://github.com/aannoo/hcom",
    "agent": "Multi",
    "descriptionKey": "p005",
    "language": "Rust",
    "stars": 252,
    "categories": [
      "Multi-Agent Orchestration",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "kdcokenny/opencode-notify",
    "url": "https://github.com/kdcokenny/opencode-notify",
    "agent": "OpenCode",
    "descriptionKey": "p006",
    "language": "TypeScript",
    "stars": 184,
    "categories": [
      "Desktop Notifications",
      "OpenCode"
    ]
  },
  {
    "name": "espennilsen/pi",
    "url": "https://github.com/espennilsen/pi",
    "agent": "Pi",
    "descriptionKey": "p007",
    "language": "TypeScript",
    "stars": 102,
    "categories": [
      "Sidebar & Status Pills",
      "Multi-Agent Orchestration",
      "Pi"
    ]
  },
  {
    "name": "w-winter/dot314",
    "url": "https://github.com/w-winter/dot314",
    "agent": "Pi",
    "descriptionKey": "p008",
    "language": "TypeScript",
    "stars": 95,
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Multi-Agent Orchestration",
      "Pi"
    ]
  },
  {
    "name": "burggraf/pi-teams",
    "url": "https://github.com/burggraf/pi-teams",
    "agent": "Pi",
    "descriptionKey": "p009",
    "language": "TypeScript",
    "stars": 91,
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Pi"
    ]
  },
  {
    "name": "0xCaso/opencode-hmux",
    "url": "https://github.com/0xCaso/opencode-hmux",
    "agent": "OpenCode",
    "descriptionKey": "p010",
    "language": "TypeScript",
    "stars": 42,
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Desktop Notifications",
      "OpenCode"
    ]
  },
  {
    "name": "hummer98/using-hmux",
    "url": "https://github.com/hummer98/using-hmux",
    "agent": "Claude Code",
    "descriptionKey": "p011",
    "language": "Shell",
    "stars": 33,
    "categories": [
      "Progress Bars & Estimation",
      "Desktop Notifications",
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "drolosoft/hmux-resurrect",
    "url": "https://github.com/drolosoft/hmux-resurrect",
    "descriptionKey": "p012",
    "language": "Go",
    "stars": 31,
    "categories": [
      "Monitoring & Session Restore",
      "Themes, Layouts & Config"
    ]
  },
  {
    "name": "AtAFork/ghostty-claude-code-session-restore",
    "url": "https://github.com/AtAFork/ghostty-claude-code-session-restore",
    "agent": "Claude Code",
    "descriptionKey": "p013",
    "language": "Python",
    "stars": 23,
    "categories": [
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "azu/hmux-hub",
    "url": "https://github.com/azu/hmux-hub",
    "agent": "Claude Code",
    "descriptionKey": "p014",
    "language": "TypeScript",
    "stars": 23,
    "categories": [
      "Sidebar & Status Pills",
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "untra/operator",
    "url": "https://github.com/untra/operator",
    "agent": "Multi",
    "descriptionKey": "p015",
    "language": "Rust",
    "stars": 17,
    "categories": [
      "Multi-Agent Orchestration",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "javiermolinar/pi-hmux",
    "url": "https://github.com/javiermolinar/pi-hmux",
    "agent": "Pi",
    "descriptionKey": "p016",
    "language": "TypeScript",
    "stars": 16,
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Desktop Notifications",
      "Browser Automation",
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config",
      "Pi"
    ]
  },
  {
    "name": "gonzaloserrano/streamdeck-hmux",
    "url": "https://github.com/gonzaloserrano/streamdeck-hmux",
    "descriptionKey": "p017",
    "language": "TypeScript",
    "stars": 14,
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Monitoring & Session Restore"
    ]
  },
  {
    "name": "sasha-computer/pi-hmux",
    "url": "https://github.com/sasha-computer/pi-hmux",
    "agent": "Pi",
    "descriptionKey": "p018",
    "language": "TypeScript",
    "stars": 14,
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Browser Automation",
      "Pi"
    ]
  },
  {
    "name": "hummer98/hmux-team",
    "url": "https://github.com/hummer98/hmux-team",
    "agent": "Claude Code",
    "descriptionKey": "p019",
    "language": "TypeScript",
    "stars": 10,
    "categories": [
      "Progress Bars & Estimation",
      "Multi-Agent Orchestration",
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "joelhooks/pi-hmux",
    "url": "https://github.com/joelhooks/pi-hmux",
    "agent": "Pi",
    "descriptionKey": "p020",
    "language": "TypeScript",
    "stars": 10,
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Multi-Agent Orchestration",
      "Pi"
    ]
  },
  {
    "name": "jasonraz/hmux-browser-mcp",
    "url": "https://github.com/jasonraz/hmux-browser-mcp",
    "agent": "Claude Code",
    "descriptionKey": "p021",
    "language": "JavaScript",
    "stars": 8,
    "categories": [
      "Browser Automation",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "darkspock/hmux-skill",
    "url": "https://github.com/darkspock/hmux-skill",
    "agent": "Multi",
    "descriptionKey": "p022",
    "language": "Markdown",
    "stars": 7,
    "categories": [
      "Browser Automation",
      "Claude Code",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "yigitkonur/hmux-claude-pro",
    "url": "https://github.com/yigitkonur/hmux-claude-pro",
    "agent": "Claude Code",
    "descriptionKey": "p023",
    "language": "TypeScript",
    "stars": 7,
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Desktop Notifications",
      "Claude Code"
    ]
  },
  {
    "name": "hummer98/hmux-remote",
    "url": "https://github.com/hummer98/hmux-remote",
    "descriptionKey": "p024",
    "language": "TypeScript",
    "stars": 6,
    "categories": [
      "Remote & Mobile Access"
    ]
  },
  {
    "name": "mikasalikh/hmux-wf",
    "url": "https://github.com/mikasalikh/hmux-wf",
    "agent": "Claude Code",
    "descriptionKey": "p025",
    "language": "Shell",
    "stars": 6,
    "categories": [
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "EtanHey/hmuxlayer",
    "url": "https://github.com/EtanHey/hmuxlayer",
    "agent": "Multi",
    "descriptionKey": "p026",
    "language": "TypeScript",
    "stars": 5,
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Multi-Agent Orchestration",
      "Browser Automation",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "itsmaleen/hmux-companion",
    "url": "https://github.com/itsmaleen/hmux-companion",
    "descriptionKey": "p027",
    "language": "Go / Swift",
    "stars": 5,
    "categories": [
      "Desktop Notifications",
      "Remote & Mobile Access"
    ]
  },
  {
    "name": "monzou/mo-hmux",
    "url": "https://github.com/monzou/mo-hmux",
    "agent": "Claude Code",
    "descriptionKey": "p028",
    "language": "Shell",
    "stars": 5,
    "categories": [
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "ttalkkag/hmux-agent",
    "url": "https://github.com/ttalkkag/hmux-agent",
    "agent": "Multi",
    "descriptionKey": "p029",
    "language": "Python",
    "stars": 5,
    "categories": [
      "Multi-Agent Orchestration",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "0xNekr/hmux-bus",
    "url": "https://github.com/0xNekr/hmux-bus",
    "agent": "Multi",
    "descriptionKey": "p030",
    "language": "Shell",
    "categories": [
      "Multi-Agent Orchestration",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "alaasdk/hmux-ctl",
    "url": "https://github.com/alaasdk/hmux-ctl",
    "agent": "Claude Code",
    "descriptionKey": "p031",
    "language": "Python",
    "categories": [
      "Multi-Agent Orchestration",
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "albertlieyingadrian/hmux-multiplexer",
    "url": "https://github.com/albertlieyingadrian/hmux-multiplexer",
    "agent": "Claude Code",
    "descriptionKey": "p032",
    "language": "Python",
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Claude Code"
    ]
  },
  {
    "name": "alevental/cccp",
    "url": "https://github.com/alevental/cccp",
    "agent": "Claude Code",
    "descriptionKey": "p033",
    "language": "TypeScript",
    "categories": [
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "anhoder/homebrew-repo",
    "url": "https://github.com/anhoder/homebrew-repo",
    "descriptionKey": "p034",
    "language": "Ruby",
    "categories": [
      "Build & Distribution"
    ]
  },
  {
    "name": "aschreifels/cwt",
    "url": "https://github.com/aschreifels/cwt",
    "agent": "Claude Code",
    "descriptionKey": "p035",
    "language": "Go",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Desktop Notifications",
      "Worktrees & Workspace Management",
      "Claude Code"
    ]
  },
  {
    "name": "Attamusc/copilot-hmux",
    "url": "https://github.com/Attamusc/copilot-hmux",
    "agent": "Copilot",
    "descriptionKey": "p036",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Desktop Notifications",
      "Copilot & Amp"
    ]
  },
  {
    "name": "Attamusc/opencode-hmux",
    "url": "https://github.com/Attamusc/opencode-hmux",
    "agent": "OpenCode",
    "descriptionKey": "p037",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Desktop Notifications",
      "OpenCode"
    ]
  },
  {
    "name": "Attamusc/pi-hmux",
    "url": "https://github.com/Attamusc/pi-hmux",
    "agent": "Pi",
    "descriptionKey": "p038",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Desktop Notifications",
      "Pi"
    ]
  },
  {
    "name": "baixianger/claude-orchestration-in-hmux",
    "url": "https://github.com/baixianger/claude-orchestration-in-hmux",
    "agent": "Claude Code",
    "descriptionKey": "p039",
    "language": "Markdown",
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Claude Code"
    ]
  },
  {
    "name": "basedcorp99/claude-worktree-zsh",
    "url": "https://github.com/basedcorp99/claude-worktree-zsh",
    "agent": "Multi",
    "descriptionKey": "p040",
    "language": "Shell",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "bhandeland/fleet",
    "url": "https://github.com/bhandeland/fleet",
    "agent": "Claude Code",
    "descriptionKey": "p041",
    "language": "Shell",
    "categories": [
      "Worktrees & Workspace Management",
      "Claude Code"
    ]
  },
  {
    "name": "bjacobso/pimux",
    "url": "https://github.com/bjacobso/pimux",
    "agent": "Pi",
    "descriptionKey": "p042",
    "language": "TypeScript",
    "categories": [
      "Desktop Notifications",
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Pi"
    ]
  },
  {
    "name": "block/hmux-amp",
    "url": "https://github.com/block/hmux-amp",
    "agent": "Amp",
    "descriptionKey": "p043",
    "language": "TypeScript",
    "categories": [
      "Desktop Notifications",
      "Monitoring & Session Restore",
      "Copilot & Amp"
    ]
  },
  {
    "name": "bocktae80/hmux-pilot",
    "url": "https://github.com/bocktae80/hmux-pilot",
    "agent": "Claude Code",
    "descriptionKey": "p044",
    "language": "Shell",
    "categories": [
      "Sidebar & Status Pills",
      "Multi-Agent Orchestration",
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "budah1987/hmux-script",
    "url": "https://github.com/budah1987/hmux-script",
    "agent": "Claude Code",
    "descriptionKey": "p045",
    "language": "Shell",
    "categories": [
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "budah1987/homebrew-tools",
    "url": "https://github.com/budah1987/homebrew-tools",
    "agent": "Claude Code",
    "descriptionKey": "p046",
    "language": "Ruby",
    "categories": [
      "Themes, Layouts & Config",
      "Claude Code",
      "Build & Distribution"
    ]
  },
  {
    "name": "chsm04/hmux-tower",
    "url": "https://github.com/chsm04/hmux-tower",
    "agent": "Claude Code",
    "descriptionKey": "p047",
    "language": "Shell",
    "categories": [
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "dd7200/pomo-tui",
    "url": "https://github.com/dd7200/pomo-tui",
    "descriptionKey": "p048",
    "language": "Go",
    "categories": [
      "Desktop Notifications"
    ]
  },
  {
    "name": "dmallory42/pi-hmux",
    "url": "https://github.com/dmallory42/pi-hmux",
    "agent": "Pi",
    "descriptionKey": "p049",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Desktop Notifications",
      "Browser Automation",
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config",
      "Pi"
    ]
  },
  {
    "name": "dongsik93/crosstalk",
    "url": "https://github.com/dongsik93/crosstalk",
    "agent": "Multi",
    "descriptionKey": "p050",
    "language": "Shell",
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "doublezz10/figure-viewer",
    "url": "https://github.com/doublezz10/figure-viewer",
    "agent": "OpenCode",
    "descriptionKey": "p051",
    "language": "JavaScript",
    "categories": [
      "Browser Automation"
    ]
  },
  {
    "name": "earchibald/hmux-layout",
    "url": "https://github.com/earchibald/hmux-layout",
    "descriptionKey": "p052",
    "language": "Swift",
    "categories": [
      "Themes, Layouts & Config"
    ]
  },
  {
    "name": "eduwass/cru",
    "url": "https://github.com/eduwass/cru",
    "agent": "Claude Code",
    "descriptionKey": "p053",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "ensarkovankaya/hmux-mirror",
    "url": "https://github.com/ensarkovankaya/hmux-mirror",
    "descriptionKey": "p054",
    "language": "Python",
    "categories": [
      "Monitoring & Session Restore",
      "Remote & Mobile Access"
    ]
  },
  {
    "name": "erikhazzard/hmux-remote",
    "url": "https://github.com/erikhazzard/hmux-remote",
    "descriptionKey": "p055",
    "language": "TypeScript",
    "categories": [
      "Remote & Mobile Access"
    ]
  },
  {
    "name": "eunjae-lee/hmux-worktree",
    "url": "https://github.com/eunjae-lee/hmux-worktree",
    "descriptionKey": "p056",
    "language": "TypeScript",
    "categories": [
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config"
    ]
  },
  {
    "name": "EverybodyBusiness/hmux-browser-first",
    "url": "https://github.com/EverybodyBusiness/hmux-browser-first",
    "agent": "Claude Code",
    "descriptionKey": "p057",
    "categories": [
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "goddaehee/hmux-claude-skill",
    "url": "https://github.com/goddaehee/hmux-claude-skill",
    "agent": "Claude Code",
    "descriptionKey": "p058",
    "language": "Markdown",
    "categories": [
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "gomipapa/hmux-sidecar",
    "url": "https://github.com/gomipapa/hmux-sidecar",
    "agent": "Multi",
    "descriptionKey": "p059",
    "language": "Shell",
    "categories": [
      "Browser Automation",
      "Themes, Layouts & Config",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "halindrome/hmux-tmux-mapping-for-cc",
    "url": "https://github.com/halindrome/hmux-tmux-mapping-for-cc",
    "agent": "Claude Code",
    "descriptionKey": "p060",
    "language": "Shell",
    "categories": [
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "hashangit/hmux-skill",
    "url": "https://github.com/hashangit/hmux-skill",
    "agent": "Claude Code",
    "descriptionKey": "p061",
    "language": "Shell",
    "categories": [
      "Desktop Notifications",
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "hoonkim/hmux-skills-plugin",
    "url": "https://github.com/hoonkim/hmux-skills-plugin",
    "agent": "Claude Code",
    "descriptionKey": "p062",
    "language": "Markdown",
    "categories": [
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "hopchouinard/hmux-plugin",
    "url": "https://github.com/hopchouinard/hmux-plugin",
    "agent": "Claude Code",
    "descriptionKey": "p063",
    "language": "Shell",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Desktop Notifications",
      "Browser Automation",
      "Worktrees & Workspace Management",
      "Claude Code"
    ]
  },
  {
    "name": "Islanders-Treasure0969/claude-pilot",
    "url": "https://github.com/Islanders-Treasure0969/claude-pilot",
    "agent": "Claude Code",
    "descriptionKey": "p064",
    "language": "JavaScript",
    "categories": [
      "Multi-Agent Orchestration",
      "Browser Automation",
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "JacianLiu/hmux-claude-session",
    "url": "https://github.com/JacianLiu/hmux-claude-session",
    "agent": "Claude Code",
    "descriptionKey": "p065",
    "language": "Shell",
    "categories": [
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "jacobtellep/hmux-setup",
    "url": "https://github.com/jacobtellep/hmux-setup",
    "agent": "Claude Code",
    "descriptionKey": "p066",
    "language": "Shell",
    "categories": [
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "jaequery/hmux-diff",
    "url": "https://github.com/jaequery/hmux-diff",
    "agent": "Claude Code",
    "descriptionKey": "p067",
    "language": "TypeScript",
    "categories": [
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "jhta/hmux-skill",
    "url": "https://github.com/jhta/hmux-skill",
    "agent": "Claude Code",
    "descriptionKey": "p068",
    "language": "Shell",
    "categories": [
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "Joehoel/opencode-hmux",
    "url": "https://github.com/Joehoel/opencode-hmux",
    "agent": "OpenCode",
    "descriptionKey": "p069",
    "language": "Shell",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Desktop Notifications",
      "OpenCode"
    ]
  },
  {
    "name": "KyleJamesWalker/cc-hmux-plugin",
    "url": "https://github.com/KyleJamesWalker/cc-hmux-plugin",
    "agent": "Claude Code",
    "descriptionKey": "p070",
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "KyubumShin/hmux-skills",
    "url": "https://github.com/KyubumShin/hmux-skills",
    "agent": "Claude Code",
    "descriptionKey": "p071",
    "language": "JavaScript",
    "categories": [
      "Multi-Agent Orchestration",
      "Browser Automation",
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "LattyCat/hmux-workspace",
    "url": "https://github.com/LattyCat/hmux-workspace",
    "agent": "Multi",
    "descriptionKey": "p072",
    "language": "Shell",
    "categories": [
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "lawrencecchen/hmux-proxy",
    "url": "https://github.com/lawrencecchen/hmux-proxy",
    "descriptionKey": "p073",
    "language": "Rust",
    "categories": [
      "Remote & Mobile Access"
    ]
  },
  {
    "name": "Lumiwealth/hmux-agent-recovery",
    "url": "https://github.com/Lumiwealth/hmux-agent-recovery",
    "agent": "Multi",
    "descriptionKey": "p074",
    "language": "Python",
    "categories": [
      "Monitoring & Session Restore",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "madlouse/homebrew-ghostty",
    "url": "https://github.com/madlouse/homebrew-ghostty",
    "descriptionKey": "p075",
    "language": "Ruby",
    "categories": [
      "Build & Distribution"
    ]
  },
  {
    "name": "manaflow-ai/chromium",
    "url": "https://github.com/manaflow-ai/chromium",
    "descriptionKey": "p076",
    "language": "Obj-C++",
    "categories": [
      "Build & Distribution"
    ]
  },
  {
    "name": "manaflow-ai/cmux-skills",
    "url": "https://github.com/manaflow-ai/cmux-skills",
    "agent": "Multi",
    "descriptionKey": "p077",
    "language": "Python",
    "categories": [
      "Multi-Agent Orchestration",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "manaflow-ai/homebrew-cmux",
    "url": "https://github.com/manaflow-ai/homebrew-cmux",
    "descriptionKey": "p078",
    "language": "Ruby",
    "categories": [
      "Build & Distribution"
    ]
  },
  {
    "name": "mangledmonkey/hmux-skills",
    "url": "https://github.com/mangledmonkey/hmux-skills",
    "agent": "Claude Code",
    "descriptionKey": "p079",
    "language": "Shell",
    "categories": [
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "mangledmonkey/devmux",
    "url": "https://github.com/mangledmonkey/devmux",
    "agent": "Claude Code",
    "descriptionKey": "p080",
    "language": "Shell",
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Claude Code"
    ]
  },
  {
    "name": "Marmalade118/gsd-wmux",
    "url": "https://github.com/Marmalade118/gsd-wmux",
    "agent": "Pi",
    "descriptionKey": "p081",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Desktop Notifications",
      "Themes, Layouts & Config",
      "Pi"
    ]
  },
  {
    "name": "mastertyko/pi-hmux-preview",
    "url": "https://github.com/mastertyko/pi-hmux-preview",
    "agent": "Pi",
    "descriptionKey": "p082",
    "language": "TypeScript",
    "categories": [
      "Browser Automation",
      "Pi"
    ]
  },
  {
    "name": "mateusduraes/ramo",
    "url": "https://github.com/mateusduraes/ramo",
    "descriptionKey": "p083",
    "language": "Go",
    "categories": [
      "Worktrees & Workspace Management"
    ]
  },
  {
    "name": "meengi07/hmux-agent-observer-skill",
    "url": "https://github.com/meengi07/hmux-agent-observer-skill",
    "agent": "Multi",
    "descriptionKey": "p084",
    "language": "Shell",
    "categories": [
      "Multi-Agent Orchestration",
      "Monitoring & Session Restore",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "Michael-Z-Freeman/antigravity-hmux-notify",
    "url": "https://github.com/Michael-Z-Freeman/antigravity-hmux-notify",
    "agent": "Antigravity",
    "descriptionKey": "p085",
    "language": "Shell",
    "categories": [
      "Desktop Notifications",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "mikecfisher/hmux-skill",
    "url": "https://github.com/mikecfisher/hmux-skill",
    "agent": "Claude Code",
    "descriptionKey": "p086",
    "language": "Markdown",
    "categories": [
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "Minoo7/hmux-hooks",
    "url": "https://github.com/Minoo7/hmux-hooks",
    "agent": "Multi",
    "descriptionKey": "p087",
    "language": "Shell",
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Monitoring & Session Restore",
      "Remote & Mobile Access",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "miraoto/hmux-cheatsheet",
    "url": "https://github.com/miraoto/hmux-cheatsheet",
    "descriptionKey": "p088",
    "language": "Shell",
    "categories": [
      "Themes, Layouts & Config"
    ]
  },
  {
    "name": "Mirksen/hmux-toolkit",
    "url": "https://github.com/Mirksen/hmux-toolkit",
    "agent": "Claude Code",
    "descriptionKey": "p089",
    "language": "Shell",
    "categories": [
      "Browser Automation",
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "morrisclay/ws",
    "url": "https://github.com/morrisclay/ws",
    "agent": "Claude Code",
    "descriptionKey": "p090",
    "language": "Shell",
    "categories": [
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "mspiegel31/opencode-hmux",
    "url": "https://github.com/mspiegel31/opencode-hmux",
    "agent": "OpenCode",
    "descriptionKey": "p091",
    "language": "TypeScript",
    "categories": [
      "Desktop Notifications",
      "Browser Automation",
      "OpenCode"
    ]
  },
  {
    "name": "multiagentcognition/hmux-agent-mcp",
    "url": "https://github.com/multiagentcognition/hmux-agent-mcp",
    "agent": "Multi",
    "descriptionKey": "p092",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Multi-Agent Orchestration",
      "Browser Automation",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "n-filatov/hmux-workspace",
    "url": "https://github.com/n-filatov/hmux-workspace",
    "agent": "Multi",
    "descriptionKey": "p093",
    "language": "TypeScript",
    "categories": [
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "NewTurn2017/hmux-remote",
    "url": "https://github.com/NewTurn2017/hmux-remote",
    "agent": "Multi",
    "descriptionKey": "p094",
    "language": "Swift",
    "categories": [
      "Remote & Mobile Access",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "niaeee/hmux_skill",
    "url": "https://github.com/niaeee/hmux_skill",
    "agent": "Claude Code",
    "descriptionKey": "p095",
    "categories": [
      "Sidebar & Status Pills",
      "Multi-Agent Orchestration",
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "ogallotti/hmux-tmux-shim",
    "url": "https://github.com/ogallotti/hmux-tmux-shim",
    "agent": "Claude Code",
    "descriptionKey": "p096",
    "language": "Shell",
    "categories": [
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "owizdom/context-brdige-for-hmux",
    "url": "https://github.com/owizdom/context-brdige-for-hmux",
    "agent": "Multi",
    "descriptionKey": "p097",
    "language": "Go",
    "categories": [
      "Multi-Agent Orchestration",
      "Monitoring & Session Restore",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "pallidev/hmux-relay",
    "url": "https://github.com/pallidev/hmux-relay",
    "agent": "Multi",
    "descriptionKey": "p098",
    "language": "TypeScript",
    "categories": [
      "Remote & Mobile Access",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "rappdw/zen-term",
    "url": "https://github.com/rappdw/zen-term",
    "agent": "Claude Code",
    "descriptionKey": "p099",
    "language": "Shell",
    "categories": [
      "Desktop Notifications",
      "Remote & Mobile Access",
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "richardhowes/hmux-jump",
    "url": "https://github.com/richardhowes/hmux-jump",
    "descriptionKey": "p100",
    "language": "Shell",
    "categories": [
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config"
    ]
  },
  {
    "name": "richardhowes/hmux-mobile",
    "url": "https://github.com/richardhowes/hmux-mobile",
    "descriptionKey": "p101",
    "language": "TypeScript",
    "categories": [
      "Desktop Notifications",
      "Remote & Mobile Access"
    ]
  },
  {
    "name": "Ridgeio/swarm",
    "url": "https://github.com/Ridgeio/swarm",
    "agent": "Multi",
    "descriptionKey": "p102",
    "language": "TypeScript",
    "categories": [
      "Multi-Agent Orchestration",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "flotilla-org/flotilla",
    "url": "https://github.com/flotilla-org/flotilla",
    "agent": "Multi",
    "descriptionKey": "p103",
    "language": "Rust",
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Monitoring & Session Restore",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "RyoHirota68/hmux-pencil-preview",
    "url": "https://github.com/RyoHirota68/hmux-pencil-preview",
    "agent": "Claude Code",
    "descriptionKey": "p104",
    "language": "Shell",
    "categories": [
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "RyoHirota68/difit-hmux",
    "url": "https://github.com/RyoHirota68/difit-hmux",
    "agent": "Claude Code",
    "descriptionKey": "p105",
    "language": "Shell",
    "categories": [
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "sanurb/pi-hmux",
    "url": "https://github.com/sanurb/pi-hmux",
    "agent": "Pi",
    "descriptionKey": "p106",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Pi"
    ]
  },
  {
    "name": "sanurb/pi-hmux-browser",
    "url": "https://github.com/sanurb/pi-hmux-browser",
    "agent": "Pi",
    "descriptionKey": "p107",
    "language": "TypeScript",
    "categories": [
      "Browser Automation",
      "Pi"
    ]
  },
  {
    "name": "sanurb/pi-hmux-workflows",
    "url": "https://github.com/sanurb/pi-hmux-workflows",
    "agent": "Pi",
    "descriptionKey": "p108",
    "language": "TypeScript",
    "categories": [
      "Multi-Agent Orchestration",
      "Browser Automation",
      "Pi"
    ]
  },
  {
    "name": "sdgranger/will-public-claude",
    "url": "https://github.com/sdgranger/will-public-claude",
    "agent": "Claude Code",
    "descriptionKey": "p109",
    "language": "Shell",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Multi-Agent Orchestration",
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "Seungwoo321/hmux-setup",
    "url": "https://github.com/Seungwoo321/hmux-setup",
    "descriptionKey": "p110",
    "language": "TypeScript",
    "categories": [
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config"
    ]
  },
  {
    "name": "simonjohansson/pi-hmux",
    "url": "https://github.com/simonjohansson/pi-hmux",
    "agent": "Pi",
    "descriptionKey": "p111",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Sidebar Logs & Activity Feed",
      "Pi"
    ]
  },
  {
    "name": "Stealinglight/hmux-claude-code-skill",
    "url": "https://github.com/Stealinglight/hmux-claude-code-skill",
    "agent": "Claude Code",
    "descriptionKey": "p112",
    "language": "Shell",
    "categories": [
      "Browser Automation",
      "Worktrees & Workspace Management",
      "Claude Code"
    ]
  },
  {
    "name": "stegmannb/pi-agent-hmux",
    "url": "https://github.com/stegmannb/pi-agent-hmux",
    "agent": "Pi",
    "descriptionKey": "p113",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Pi"
    ]
  },
  {
    "name": "stevenocchipinti/raycast-hmux",
    "url": "https://github.com/stevenocchipinti/raycast-hmux",
    "descriptionKey": "p114",
    "language": "TypeScript",
    "categories": [
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config"
    ]
  },
  {
    "name": "storelayer/pi-hmux-browser",
    "url": "https://github.com/storelayer/pi-hmux-browser",
    "agent": "Pi",
    "descriptionKey": "p115",
    "language": "JavaScript",
    "categories": [
      "Browser Automation",
      "Pi"
    ]
  },
  {
    "name": "STRML/hmux-restore",
    "url": "https://github.com/STRML/hmux-restore",
    "agent": "Claude Code",
    "descriptionKey": "p116",
    "language": "Shell",
    "categories": [
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "tadashi-aikawa/copilot-plugin-notify",
    "url": "https://github.com/tadashi-aikawa/copilot-plugin-notify",
    "agent": "Copilot",
    "descriptionKey": "p117",
    "language": "Shell",
    "categories": [
      "Desktop Notifications",
      "Copilot & Amp"
    ]
  },
  {
    "name": "taichiiwamoto-s/hmux-context",
    "url": "https://github.com/taichiiwamoto-s/hmux-context",
    "agent": "Claude Code",
    "descriptionKey": "p118",
    "language": "Shell",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "take0x/hmux-skills",
    "url": "https://github.com/take0x/hmux-skills",
    "agent": "Claude Code",
    "descriptionKey": "p119",
    "language": "Shell",
    "categories": [
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "tasuku43/kra",
    "url": "https://github.com/tasuku43/kra",
    "descriptionKey": "p120",
    "language": "Go",
    "categories": [
      "Worktrees & Workspace Management"
    ]
  },
  {
    "name": "Th3Sp3ct3R/hmux-claude-agents",
    "url": "https://github.com/Th3Sp3ct3R/hmux-claude-agents",
    "agent": "Claude Code",
    "descriptionKey": "p121",
    "language": "Shell",
    "categories": [
      "Desktop Notifications",
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "theodaguier/wt",
    "url": "https://github.com/theodaguier/wt",
    "agent": "Claude Code",
    "descriptionKey": "p122",
    "language": "Shell",
    "categories": [
      "Worktrees & Workspace Management",
      "Claude Code"
    ]
  },
  {
    "name": "TimoKruth/hmux-t3code",
    "url": "https://github.com/TimoKruth/hmux-t3code",
    "agent": "Multi",
    "descriptionKey": "p123",
    "categories": [
      "Multi-Agent Orchestration",
      "Browser Automation",
      "Worktrees & Workspace Management",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "tslateman/hmux-claude-code",
    "url": "https://github.com/tslateman/hmux-claude-code",
    "agent": "Claude Code",
    "descriptionKey": "p124",
    "language": "Shell",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Desktop Notifications",
      "Claude Code"
    ]
  },
  {
    "name": "tully-8888/opencode-hmux-notify-plugin",
    "url": "https://github.com/tully-8888/opencode-hmux-notify-plugin",
    "agent": "OpenCode",
    "descriptionKey": "p125",
    "language": "Shell",
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "OpenCode"
    ]
  },
  {
    "name": "umitaltintas/hmux-agent-toolkit",
    "url": "https://github.com/umitaltintas/hmux-agent-toolkit",
    "agent": "Claude Code",
    "descriptionKey": "p126",
    "language": "Markdown",
    "categories": [
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "wangyuxinwhy/agent-skills",
    "url": "https://github.com/wangyuxinwhy/agent-skills",
    "agent": "Multi",
    "descriptionKey": "p127",
    "categories": [
      "Multi-Agent Orchestration",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "webkaz/hmux-intel-builds",
    "url": "https://github.com/webkaz/hmux-intel-builds",
    "descriptionKey": "p128",
    "categories": [
      "Build & Distribution"
    ]
  },
  {
    "name": "wwaIII/proj",
    "url": "https://github.com/wwaIII/proj",
    "agent": "Claude Code",
    "descriptionKey": "p129",
    "language": "Rust",
    "categories": [
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "ygrec-app/offload-task-skill",
    "url": "https://github.com/ygrec-app/offload-task-skill",
    "agent": "Claude Code",
    "descriptionKey": "p130",
    "language": "Markdown",
    "categories": [
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "ygrec-app/supreme-leader-skill",
    "url": "https://github.com/ygrec-app/supreme-leader-skill",
    "agent": "Claude Code",
    "descriptionKey": "p131",
    "language": "Markdown",
    "categories": [
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "feritzcan2/termloop",
    "url": "https://github.com/feritzcan2/termloop",
    "agent": "Multi",
    "descriptionKey": "p132",
    "language": "Swift",
    "stars": 29,
    "categories": [
      "Build & Distribution",
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Remote & Mobile Access",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "sanghun0724/hmux-claude-skills",
    "url": "https://github.com/sanghun0724/hmux-claude-skills",
    "agent": "Claude Code",
    "descriptionKey": "p133",
    "language": "Python",
    "stars": 28,
    "categories": [
      "Browser Automation",
      "Monitoring & Session Restore",
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "pawel-cell/hmux-ai-agents-bundle",
    "url": "https://github.com/pawel-cell/hmux-ai-agents-bundle",
    "agent": "Multi",
    "descriptionKey": "p134",
    "language": "Shell / Python",
    "stars": 20,
    "categories": [
      "Multi-Agent Orchestration",
      "Browser Automation",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "ericblue/hmux-session-manager",
    "url": "https://github.com/ericblue/hmux-session-manager",
    "agent": "Claude Code",
    "descriptionKey": "p135",
    "language": "Python",
    "stars": 12,
    "categories": [
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "freestyle-sh/rigkit",
    "url": "https://github.com/freestyle-sh/rigkit",
    "agent": "Multi",
    "descriptionKey": "p136",
    "language": "TypeScript",
    "stars": 7,
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "ph3on1x/claude-hmux-skill",
    "url": "https://github.com/ph3on1x/claude-hmux-skill",
    "agent": "Claude Code",
    "descriptionKey": "p137",
    "language": "Markdown",
    "stars": 7,
    "categories": [
      "Sidebar & Status Pills",
      "Multi-Agent Orchestration",
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "sinozu/hmux-git-diff",
    "url": "https://github.com/sinozu/hmux-git-diff",
    "descriptionKey": "p138",
    "language": "Go",
    "stars": 5,
    "categories": [
      "Browser Automation"
    ]
  },
  {
    "name": "jiahao-shao1/hmux-skill",
    "url": "https://github.com/jiahao-shao1/hmux-skill",
    "agent": "Claude Code",
    "descriptionKey": "p139",
    "language": "Markdown",
    "stars": 5,
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "devnazim/pi-hmux",
    "url": "https://github.com/devnazim/pi-hmux",
    "agent": "Pi",
    "descriptionKey": "p140",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Pi"
    ]
  },
  {
    "name": "Catdaemon/pi-extensions",
    "url": "https://github.com/Catdaemon/pi-extensions",
    "agent": "Pi",
    "descriptionKey": "p141",
    "language": "TypeScript",
    "stars": 3,
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Pi"
    ]
  },
  {
    "name": "flyflor/hmux-codex-worktree",
    "url": "https://github.com/flyflor/hmux-codex-worktree",
    "agent": "Codex",
    "descriptionKey": "p142",
    "language": "Shell",
    "stars": 3,
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management"
    ]
  },
  {
    "name": "tanabee/hmux.vim",
    "url": "https://github.com/tanabee/hmux.vim",
    "agent": "Multi",
    "descriptionKey": "p143",
    "language": "Vim Script",
    "stars": 3,
    "categories": [
      "Browser Automation",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "alpeshvas/hmuxinator",
    "url": "https://github.com/alpeshvas/hmuxinator",
    "agent": "Multi",
    "descriptionKey": "p144",
    "language": "Rust",
    "stars": 2,
    "categories": [
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "sttts/skills",
    "url": "https://github.com/sttts/skills",
    "agent": "Multi",
    "descriptionKey": "p145",
    "language": "Shell",
    "stars": 2,
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "yigitkonur/hmux-codex",
    "url": "https://github.com/yigitkonur/hmux-codex",
    "agent": "Codex",
    "descriptionKey": "p146",
    "language": "TypeScript",
    "stars": 1,
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Desktop Notifications"
    ]
  },
  {
    "name": "mimen/claude-sessions",
    "url": "https://github.com/mimen/claude-sessions",
    "agent": "Claude Code",
    "descriptionKey": "p147",
    "language": "TypeScript",
    "categories": [
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "tanaka-yui/yui-cc-plugins",
    "url": "https://github.com/tanaka-yui/yui-cc-plugins",
    "agent": "Multi",
    "descriptionKey": "p148",
    "language": "TypeScript",
    "stars": 2,
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Remote & Mobile Access",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "talldan/hmux-opencode-agent-comm",
    "url": "https://github.com/talldan/hmux-opencode-agent-comm",
    "agent": "OpenCode",
    "descriptionKey": "p149",
    "language": "TypeScript",
    "categories": [
      "Multi-Agent Orchestration",
      "OpenCode"
    ]
  },
  {
    "name": "LuisUrrutia/opencode-hmux",
    "url": "https://github.com/LuisUrrutia/opencode-hmux",
    "agent": "OpenCode",
    "descriptionKey": "p150",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "OpenCode"
    ]
  }
] as const satisfies readonly AwesomeHmuxProject[];
