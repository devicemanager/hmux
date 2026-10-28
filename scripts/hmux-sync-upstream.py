#!/usr/bin/env python3
"""Merge upstream cmux into hmux, renaming cmux to hmux on the way in.

hmux is cmux with every cmux/Cmux/CMUX renamed to hmux/Hmux/HMUX, in file
contents and paths. A plain merge of cmux would conflict on nearly every
changed line, so this script first renames each upstream commit it syncs to
and commits the result on the `upstream-hmux` branch, whose history is one
renamed snapshot per sync. Merging that branch then conflicts only where hmux
changed the same lines itself.

Usage:
  scripts/hmux-sync-upstream.py                  sync to the upstream main and merge it
  scripts/hmux-sync-upstream.py --ref <commit>   sync to a specific upstream commit
  scripts/hmux-sync-upstream.py --no-merge       update upstream-hmux only
  scripts/hmux-sync-upstream.py --init <commit>  first run: record the renamed fork
                                                 point as merged, without changing files
  scripts/hmux-sync-upstream.py --compare <rev>  rename <rev> and diff it against HEAD,
                                                 to check the rename rules

The upstream remote is the one whose URL points at manaflow-ai/cmux.
The rename works on git objects, so it needs no checkout and is unaffected by
case-insensitive file systems.

Kept as cmux by the rename:
  * legal files (licenses, CLA, notices) and submodule contents
  * binary and non-UTF-8 files
  * real external addresses: github.com/manaflow-ai/..., cmux.com, cmux.dev,
    cmux.sh, cmuxterm.com, *cmux*.vercel.app, e-mail addresses at cmux.com
  * versions and branches of the cmux forks of iroh (1.0.2-cmux.7, cmux/v1.2.0-cmux.1)
  * names of external sources and prebuilt binaries, in the files that use
    them (FILE_RULES): the cmux-cua engine and the cmux terminal client
When a sync breaks a download or a build because a new external reference was
renamed, add a rule below and sync again.
"""

import argparse
import fnmatch
import os
import re
import subprocess
import sys
import threading

BRANCH = "upstream-hmux"
UPSTREAM_URL = re.compile(r"github\.com[/:]manaflow-ai/cmux(?:\.git)?/?$")

CASES = {"cmux": "hmux", "Cmux": "Hmux", "CMUX": "HMUX"}
WORD = re.compile(r"cmux|Cmux|CMUX")
LEGAL = re.compile(r"(^|/)(LICENSE[^/]*|CLA\.md|THIRD_PARTY_LICENSES\.md|NOTICE[^/]*|COPYING[^/]*)$")

# Spans kept verbatim in every file.
PROTECT = re.compile(
    r"(?:https?://|git@|ssh://git@)?"
    r"(?:(?:github\.com|raw\.githubusercontent\.com|codeload\.github\.com|api\.github\.com/repos)[/:]manaflow-ai/[A-Za-z0-9._/#?=&%~+-]*"
    r"|[A-Za-z0-9.-]*\bcmux\.(?:com|dev|sh)\b|[A-Za-z0-9.-]*\bcmuxterm\.com\b[A-Za-z0-9._/#?=&%~+:-]*"
    r"|[A-Za-z0-9.-]*cmux[A-Za-z0-9-]*\.vercel\.app\b[A-Za-z0-9._/#?=&%~+:-]*"
    r"|api\.star-history\.com/[^\s\"'<>)`]*)"
    r"|manaflow-ai/[A-Za-z0-9._-]*cmux[A-Za-z0-9._/-]*"
    r"|[A-Za-z0-9._%+-]+@cmux(?:term)?\.com\b"
    # Releases and branches of the cmux forks of iroh and iroh-ffi.
    r"|\bcmux/v\d+\.\d+\.\d+-cmux\.\d+[A-Za-z0-9.]*"
    r"|\bv?\d+\.\d+\.\d+-cmux\.\d+[A-Za-z0-9.]*"
)

# Spans kept verbatim only in matching files (globs on the renamed path).
CUA = re.compile(r"\blibs/cmux-cua\b|-p cmux-cua\b|\brelease/cmux-cua\b")
TERMINAL_CLIENT = re.compile(
    r"\bcmux_(?:terminal_client|wireguard_net)_\w+|\bCmuxTerminalClient(?:FFI\b|\.xcframework)"
    r"|\bcmux-terminal-client-v[0-9A-Za-z.+]+"
)
FILE_RULES = [
    # The Computer Use engine builds from manaflow-ai/cmux-cua.
    (["scripts/build-hmux-cua.sh", "tests/test_hmux_cua_build_cache_safety.py"], CUA),
    # The terminal client links the prebuilt upstream release and its C API.
    (["Packages/Shared/HmuxTerminalClient/*", ".gitignore"], TERMINAL_CLIENT),
]
# Files whose contents stay as upstream wrote them (only their paths move).
VERBATIM = ["scripts/*cua*.patch"]


def git(*args, input=None, check=True):
    result = subprocess.run(["git", *args], input=input, capture_output=True, check=False)
    if check and result.returncode != 0:
        sys.exit(f"error: git {' '.join(args)}\n{result.stderr.decode(errors='replace')}")
    return result.stdout


def git_text(*args, **kwargs):
    return git(*args, **kwargs).decode().strip()


def is_ancestor(ancestor, descendant):
    return subprocess.run(["git", "merge-base", "--is-ancestor", ancestor, descendant]).returncode == 0


def rename_path(path):
    return WORD.sub(lambda m: CASES[m.group(0)], path)


def rename_text(text, extra=None):
    spans = [m.span() for m in PROTECT.finditer(text)]
    if extra is not None:
        spans += [m.span() for m in extra.finditer(text)]
    spans.sort()
    out, last = [], 0
    for start, end in spans:
        if start < last:
            start = last
        if end <= start:
            continue
        out.append(WORD.sub(lambda m: CASES[m.group(0)], text[last:start]))
        out.append(text[start:end])
        last = end
    out.append(WORD.sub(lambda m: CASES[m.group(0)], text[last:]))
    return "".join(out)


def matches(path, globs):
    return any(fnmatch.fnmatchcase(path, g) for g in globs)


def semver_key(version):
    core, _, pre = version.partition("-")
    nums = tuple(int(p) if p.isdigit() else 0 for p in core.split("+")[0].split("."))
    if not pre:
        return nums, 1, ()
    return nums, 0, tuple((0, int(p), "") if p.isdigit() else (1, 0, p) for p in pre.split("."))


def sort_cargo_lock(text):
    """Re-sort a Cargo.lock the way cargo writes it, after package names changed."""
    blocks = text.rstrip("\n").split("\n\n")
    head, packages, tail = [], [], []
    for block in blocks:
        if block.startswith("[[package]]"):
            packages.append(block)
        elif packages:
            tail.append(block)
        else:
            head.append(block)

    def field(block, name):
        m = re.search(rf'^{name} = "([^"]*)"', block, re.M)
        return m.group(1) if m else ""

    def dep_key(line):
        name, _, rest = line.strip().strip('",').partition(" ")
        version, _, source = rest.partition(" ")
        return name, version, source

    def sort_deps(block):
        def repl(m):
            lines = sorted(m.group(2).splitlines(), key=dep_key)
            return m.group(1) + "\n".join(lines) + m.group(3)
        return re.sub(r"(^dependencies = \[\n)(.*?)(\n\])", repl, block, flags=re.M | re.S)

    packages = [sort_deps(b) for b in packages]
    packages.sort(key=lambda b: (field(b, "name"), semver_key(field(b, "version")), field(b, "source")))
    return "\n\n".join(head + packages + tail) + "\n"


def read_blobs(shas):
    """Read blobs through one cat-file process."""
    proc = subprocess.Popen(["git", "cat-file", "--batch"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)

    # Write from a thread: cat-file answers while it reads, so a single
    # thread that writes everything first fills both pipes and deadlocks.
    def feed():
        proc.stdin.write("".join(f"{s}\n" for s in shas).encode())
        proc.stdin.close()

    writer = threading.Thread(target=feed)
    writer.start()
    blobs = {}
    for sha in shas:
        header = proc.stdout.readline().split()
        size = int(header[2])
        blobs[sha] = proc.stdout.read(size)
        proc.stdout.read(1)
    writer.join()
    proc.wait()
    return blobs


def renamed_tree_entries(rev):
    """Yield (mode, sha or None, path, data or None) for the renamed tree of rev."""
    entries = []
    for record in git("ls-tree", "-r", "-z", "--full-tree", rev).split(b"\0"):
        if not record:
            continue
        meta, path = record.split(b"\t", 1)
        mode, kind, sha = meta.decode().split()
        entries.append((mode, kind, sha, path.decode()))

    grep = git("grep", "-I", "-l", "-z", "-E", "cmux|Cmux|CMUX", rev, "--", check=False)
    prefix = f"{rev}:"
    candidates = {p.decode()[len(prefix):] for p in grep.split(b"\0") if p}
    wanted = [sha for mode, kind, sha, path in entries
              if kind == "blob" and (path in candidates or mode == "120000") and not LEGAL.search(path)]
    blobs = read_blobs(sorted(set(wanted)))

    seen = {}
    for mode, kind, sha, path in entries:
        new_path = rename_path(path)
        if new_path in seen:
            sys.exit(f"error: {path} and {seen[new_path]} both rename to {new_path}")
        seen[new_path] = path
        data = None
        if sha in blobs and kind == "blob":
            raw = blobs[sha]
            if mode == "120000":
                target = rename_path(raw.decode())
                data = target.encode() if target != raw.decode() else None
            elif not matches(new_path, VERBATIM):
                try:
                    text = raw.decode("utf-8")
                except UnicodeDecodeError:
                    text = None
                if text is not None:
                    extra = None
                    for globs, pattern in FILE_RULES:
                        if matches(new_path, globs):
                            extra = pattern
                    new = rename_text(text, extra)
                    if new != text and new_path.endswith("Cargo.lock"):
                        new = sort_cargo_lock(new)
                    if new != text:
                        data = new.encode("utf-8")
        yield mode, sha, new_path, data


def write_commit(rev, ref, message, parents):
    """Commit the renamed tree of rev to ref with fast-import; return the commit."""
    ident = git_text("var", "GIT_COMMITTER_IDENT")
    chunks = [f"commit {ref}\nauthor {ident}\ncommitter {ident}\n".encode()]
    msg = message.encode()
    chunks.append(f"data {len(msg)}\n".encode() + msg + b"\n")
    if parents:
        chunks.append(f"from {parents[0]}\n".encode())
        for parent in parents[1:]:
            chunks.append(f"merge {parent}\n".encode())
    chunks.append(b"deleteall\n")
    count = changed = 0
    for mode, sha, path, data in renamed_tree_entries(rev):
        if "\n" in path or path.startswith('"'):
            sys.exit(f"error: unsupported path {path!r}")
        count += 1
        if data is None:
            chunks.append(f"M {mode} {sha} {path}\n".encode())
        else:
            changed += 1
            chunks.append(f"M {mode} inline {path}\ndata {len(data)}\n".encode() + data + b"\n")
    chunks.append(b"done\n")
    git("update-ref", "-d", ref, check=False)
    # With core.ignorecase, fast-import folds examples/ into Examples/.
    git("-c", "core.ignorecase=false", "fast-import", "--quiet", "--done", input=b"".join(chunks))
    print(f"==> Renamed {rev[:12]}: {count} files, {changed} with changed contents")
    return git_text("rev-parse", ref)


def upstream_remote():
    for name in git_text("remote").split():
        url = git_text("remote", "get-url", name)
        if UPSTREAM_URL.search(url):
            return name
    sys.exit("error: no remote points at github.com/manaflow-ai/cmux; add one:\n"
             "  git remote add upstream https://github.com/manaflow-ai/cmux.git")


def require_clean():
    if git_text("status", "--porcelain", "--untracked-files=no"):
        sys.exit("error: commit or stash your changes first")
    if git("rev-parse", "-q", "--verify", "MERGE_HEAD", check=False).strip():
        sys.exit("error: a merge is in progress; finish it with `git commit` or `git merge --abort`")


SUSPECT = re.compile(
    r"https?://\S*hmux|\bhmux[\w-]*\.(?:com|dev|sh|io|app|net|org)\b|\d+\.\d+\.\d+-hmux\."
    r"|releases/download/\S*hmux|manaflow-ai/\S*hmux"
)


def report_suspects(old, new):
    """Show added lines whose renamed name may point at something external."""
    diff = git("diff", "--unified=0", "--no-color", old, new, "--", ".", ":!*.lock").decode(errors="replace")
    path, hits = None, []
    for line in diff.splitlines():
        if line.startswith("+++ "):
            path = line[6:]
        elif line.startswith("+") and SUSPECT.search(line):
            hits.append(f"  {path}: {line[1:].strip()[:140]}")
    if hits:
        print(f"==> {len(hits)} added lines name hmux where an external address or release may need cmux.")
        print("    Check them; add a rule to scripts/hmux-sync-upstream.py when one must stay cmux:")
        print("\n".join(hits[:40]))
        if len(hits) > 40:
            print(f"  ... and {len(hits) - 40} more: git diff {old[:12]} {new[:12]}")


def upstream_of(commit):
    m = re.search(r"^Upstream-Commit: ([0-9a-f]{40})$", git_text("log", "-1", "--format=%B", commit), re.M)
    return m.group(1) if m else None


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--ref", help="upstream commit to sync to (default: <upstream>/main)")
    parser.add_argument("--no-merge", action="store_true", help=f"update {BRANCH} only")
    parser.add_argument("--init", metavar="COMMIT", help="record the renamed fork point as merged")
    parser.add_argument("--compare", metavar="REV", help="rename REV and diff it against HEAD")
    args = parser.parse_args()
    os.chdir(git_text("rev-parse", "--show-toplevel"))
    branch_ref = f"refs/heads/{BRANCH}"
    tmp_ref = "refs/hmux-sync/tmp"

    if args.compare:
        rev = git_text("rev-parse", f"{args.compare}^{{commit}}")
        commit = write_commit(rev, tmp_ref, f"Renamed {rev}", [])
        print(git_text("diff", "--stat=200", commit, "HEAD") or "identical to HEAD")
        print(f"==> Full diff: git diff {commit[:12]} HEAD")
        return

    require_clean()
    tip = git_text("rev-parse", "-q", "--verify", branch_ref, check=False)

    if args.init:
        if tip:
            sys.exit(f"error: {BRANCH} already exists")
        base = git_text("rev-parse", f"{args.init}^{{commit}}")
        if not is_ancestor(base, "HEAD"):
            sys.exit(f"error: {base[:12]} is not in the history of HEAD")
        commit = write_commit(base, tmp_ref, f"Upstream cmux {base[:12]}, renamed to hmux\n\nUpstream-Commit: {base}\n", [base])
        git("update-ref", branch_ref, commit)
        git("update-ref", "-d", tmp_ref)
        git("merge", "-s", "ours", "--no-ff", "-m",
            f"Merge {BRANCH} at cmux {base[:12]}\n\nRecords the renamed fork point as merged; no files change.", BRANCH)
        print(f"==> {BRANCH} starts at cmux {base[:12]}; HEAD records it as merged")
        return

    if not tip:
        sys.exit(f"error: no {BRANCH} branch; run --init <fork point> first")
    remote = upstream_remote()
    if args.ref:
        git("fetch", "-q", remote)
        target = git_text("rev-parse", f"{args.ref}^{{commit}}")
    else:
        git("fetch", "-q", remote, "main")
        target = git_text("rev-parse", "FETCH_HEAD")

    previous = upstream_of(tip)
    if previous == target:
        print(f"==> {BRANCH} is already at cmux {target[:12]}")
    else:
        if previous:
            count = git_text("rev-list", "--count", f"{previous}..{target}")
            print(f"==> {count} upstream commits since cmux {previous[:12]}")
        commit = write_commit(target, tmp_ref,
                              f"Upstream cmux {target[:12]}, renamed to hmux\n\nUpstream-Commit: {target}\n",
                              [tip, target])
        git("update-ref", branch_ref, commit, tip)
        git("update-ref", "-d", tmp_ref)
        report_suspects(tip, commit)

    if args.no_merge:
        return
    if is_ancestor(branch_ref, "HEAD"):
        print("==> Already merged")
        return
    result = subprocess.run(["git", "merge", "--no-ff", "-m",
                             f"Merge cmux {target[:12]} (renamed) into hmux", BRANCH])
    if result.returncode != 0:
        print("\n==> The merge stopped on conflicts: these are lines both cmux and hmux changed.")
        print("    Resolve them, `git add` the files and run `git commit`; or `git merge --abort`.")
        sys.exit(1)
    print(f"==> Merged cmux {target[:12]}. Next: git submodule update --init, build, then push.")


if __name__ == "__main__":
    main()
