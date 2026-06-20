#!/usr/bin/env python3
"""Phase 1 — deterministic migration of curated LOCAL memory into the Obsidian
vault in Basic Memory format. NON-DESTRUCTIVE: copies; never edits the sources.

Sources:
  1. ~/.claude/projects/<proj>/memory/*.md   -> Projects/<Name>/Memory (per map)
  2. ~/.claude/memory-compiler/knowledge/{concepts,connections,qa}/*.md -> Compiled/

Run with --apply to write; default is a dry run that prints the plan.
"""
import os, re, sys, pathlib

HOME = pathlib.Path.home()
VAULT = HOME / "ObsidianVault"
APPLY = "--apply" in sys.argv

# Source project dir (basename under ~/.claude/projects) -> vault target subdir + project tag
MAP = {
    "-Users-ggomes-dev-ekoa-dev":            ("Projects/Ekoa/Memory", "ekoa"),
    "-Users-ggomes-dev-ekoa-deploy":         ("Projects/Ekoa/Memory", "ekoa"),
    "-Users-ggomes-dev-ekoa-local":          ("Projects/Ekoa/Memory", "ekoa"),
    "-Users-ggomes-dev-ekoa-mono":           ("Projects/Ekoa/Memory", "ekoa"),
    "-Users-ggomes-dev-ekoa-dev-core":       ("Projects/Ekoa/Memory", "ekoa"),
    "-Users-ggomes-dev-garrison":            ("Projects/Garrison/Memory", "garrison"),
    "-Users-ggomes--garrison-orchestrator":  ("Projects/Garrison/Memory", "garrison"),
    "-Users-ggomes-dev-harmonika-all":       ("Harmonika/Memory", "harmonika"),
    "-Users-ggomes-ekus":                    ("Ekus/Memory", "ekus"),
    "-Users-ggomes-dev-pnmui-mon":           ("Projects/PNMUI-Corporate/Memory", "pnmui"),
    "-Users-ggomes-dev-pnmui-git":           ("Projects/PNMUI-Corporate/Memory", "pnmui"),
    "-Users-ggomes-dev-indy-frontend":       ("Projects/Indy/Memory", "indy"),
    "-Users-ggomes-dev-indy-mobileapps":     ("Projects/Indy/Memory", "indy"),
    "-Users-ggomes-dev-family-money-tracker":("Projects/Family Money Tracker/Memory", "family-money-tracker"),
    "-Users-ggomes-dev-awc":                 ("Projects/AWC/Memory", "awc"),
    "-Users-ggomes-dev-erp-juridico":        ("Projects/ERP-Juridico/Memory", "erp-juridico"),
    "-Users-ggomes-dev-maestric-repo":       ("Projects/Maestric/Memory", "maestric"),
    "-Users-ggomes-dev-probable-palm-tree":  ("Projects/Probable-Palm-Tree/Memory", "probable-palm-tree"),
    "-Users-ggomes-dev-walkthrough":         ("Projects/Walkthrough/Memory", "walkthrough"),
    "-Users-ggomes-dev":                     ("Projects/Dev-General/Memory", "dev"),
    "-Users-ggomes--claude-memory-compiler": ("Projects/Memory-Compiler/Memory", "memory-compiler"),
    "-Users-ggomes--claude":                 ("Personal/Claude-Memory", "claude-setup"),
}

SECRET_RE = re.compile(r'(sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{16,}|xoxb-[A-Za-z0-9-]{8,})')
short = lambda src: src.replace("-Users-ggomes-", "").replace("-Users-ggomes", "root").strip("-") or "root"

def redact(t):
    return SECRET_RE.sub("[REDACTED]", t)

def split_fm(text):
    if text.startswith("---"):
        m = re.match(r'^---\n(.*?)\n---\n?(.*)$', text, re.S)
        if m: return m.group(1), m.group(2)
    return None, text

def fm_get(fm, key):
    if not fm: return None
    m = re.search(rf'^{key}:\s*(.+)$', fm, re.M)
    return m.group(1).strip() if m else None

def humanize(s):
    return re.sub(r'[_-]+', ' ', re.sub(r'\.md$', '', s)).strip().title()

def derive_title(fm, body, fname):
    h1 = re.search(r'^#\s+(.+)$', body, re.M)
    if h1: return h1.group(1).strip()
    name = fm_get(fm, "name")
    return humanize(name) if name else humanize(fname)

def category(fname, fm):
    for p in ("feedback", "lesson", "project", "reference"):
        if fname.startswith(p): return p
    t = fm_get(fm, "type")
    return t if t and t not in ("memory", "note") else "memory"

def yaml_escape(s):
    if s is None: return '""'
    s = s.replace('"', '\\"')
    return f'"{s}"' if re.search(r'[:#\[\]{}\n]', s) or s != s.strip() else s

def build_note(src_rel, ptag, target_name, src_text):
    fm, body = split_fm(src_text)
    body = redact(body)
    title = redact(derive_title(fm, body, target_name))
    cat = category(target_name, fm)
    desc = fm_get(fm, "description")
    tags = sorted({ptag, cat} - {""})
    out = ["---", f"title: {yaml_escape(title)}", "type: note",
           f"tags: [{', '.join(tags)}]"]
    if desc: out.append(f"description: {yaml_escape(redact(desc))}")
    out += [f"source: {yaml_escape(src_rel)}", "---", ""]
    # keep body, but drop a duplicate leading H1 == title (BM shows title from fm)
    b = body.lstrip("\n")
    return "\n".join(out) + b + ("\n" if not b.endswith("\n") else "")

def write(path, content, log):
    log.append(("WRITE" if APPLY else "PLAN ", str(path.relative_to(VAULT))))
    if APPLY:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

def main():
    log, skipped, collisions = [], [], 0
    projroot = HOME / ".claude" / "projects"
    for src, (tgt, ptag) in MAP.items():
        mdir = projroot / src / "memory"
        if not mdir.is_dir():
            skipped.append(f"missing {src}"); continue
        tdir = VAULT / tgt
        for f in sorted(mdir.glob("*.md")):
            text = f.read_text(errors="replace")
            if f.name == "MEMORY.md":
                name = f"_index-{short(src)}.md"
            else:
                name = f.name
            dest = tdir / name
            if dest.exists() or (APPLY and dest.exists()):
                dest = tdir / f"{short(src)}__{name}";
            # collision against already-written this run
            if any(str(dest.relative_to(VAULT)) == r for _, r in log):
                dest = tdir / f"{short(src)}__{name}"
            src_rel = f"~/.claude/projects/{src}/memory/{f.name}"
            write(dest, build_note(src_rel, ptag, f.name, text), log)

    # memory-compiler knowledge -> Compiled/
    kroot = HOME / ".claude" / "memory-compiler" / "knowledge"
    for sub in ("concepts", "connections", "qa"):
        sdir = kroot / sub
        if not sdir.is_dir(): continue
        for f in sorted(sdir.glob("*.md")):
            text = f.read_text(errors="replace")
            dest = VAULT / "Compiled" / sub / f.name
            if dest.exists():
                dest = VAULT / "Compiled" / sub / f"local__{f.name}"
            src_rel = f"~/.claude/memory-compiler/knowledge/{sub}/{f.name}"
            write(dest, build_note(src_rel, "compiled", f.name, text), log)

    for action in ("PLAN ", "WRITE"):
        rows = [r for a, r in log if a == action]
        if rows:
            print(f"\n=== {action} ({len(rows)}) ===")
            for r in rows: print(" ", r)
    if skipped:
        print("\n=== SKIPPED ==="); [print(" ", s) for s in skipped]
    print(f"\nTOTAL: {len(log)} files ({'APPLIED' if APPLY else 'dry run'})")

if __name__ == "__main__":
    main()
