#!/usr/bin/env python3
"""stimulus-check: Stimulus コントローラと HTML data-* 属性の整合性検査。

実行モード:
  引数なし        → git diff (unstaged + staged) を対象
  ファイルパス    → 該当ファイルのみ
  --all           → 全 controller + view を横断
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
CONTROLLERS_DIR = PROJECT_ROOT / "app" / "javascript" / "controllers"
VIEW_DIRS = [PROJECT_ROOT / "app" / "views", PROJECT_ROOT / "app" / "components"]
HELPER_DIRS = [PROJECT_ROOT / "app" / "helpers", PROJECT_ROOT / "app" / "components"]


def controller_name_for(path: Path) -> str:
    """foo_bar_controller.js -> foo-bar"""
    base = path.name
    if base.endswith("_controller.js"):
        base = base[: -len("_controller.js")]
    return base.replace("_", "-")


def kebab_to_camel(s: str) -> str:
    parts = s.split("-")
    return parts[0] + "".join(p.capitalize() for p in parts[1:])


def all_controller_files() -> list[Path]:
    if not CONTROLLERS_DIR.exists():
        return []
    return sorted(CONTROLLERS_DIR.rglob("*_controller.js"))


def iter_view_files(dirs: list[Path]):
    for d in dirs:
        if not d.exists():
            continue
        for ext in (".erb", ".html", ".html.erb", ".haml"):
            yield from d.rglob(f"*{ext}")


def iter_ruby_files(dirs: list[Path]):
    seen: set[Path] = set()
    for d in dirs:
        if not d.exists():
            continue
        for rb in d.rglob("*.rb"):
            if rb in seen:
                continue
            seen.add(rb)
            yield rb


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def extract_static_block(src: str, kind: str) -> str | None:
    """kind: 'targets' -> [ ... ], 'values' -> { ... }, 'classes' -> [ ... ]"""
    if kind in ("targets", "classes"):
        m = re.search(rf"static\s+{kind}\s*=\s*\[(.*?)\]", src, re.S)
    else:
        m = re.search(rf"static\s+{kind}\s*=\s*\{{(.*?)\}}", src, re.S)
    return m.group(1) if m else None


def declared_targets(src: str) -> set[str]:
    block = extract_static_block(src, "targets")
    if block is None:
        return set()
    return set(re.findall(r"""["']([^"']+)["']""", block))


def declared_values(src: str) -> set[str]:
    block = extract_static_block(src, "values")
    if block is None:
        return set()
    return set(re.findall(r"(?:^|[,{\s])([A-Za-z_][A-Za-z0-9_]*)\s*:", block))


def declared_classes(src: str) -> set[str]:
    block = extract_static_block(src, "classes")
    if block is None:
        return set()
    return set(re.findall(r"""["']([^"']+)["']""", block))


def controller_methods(src: str) -> set[str]:
    """コントローラ内の method 名を粗く抽出 (アクション名解決用)"""
    methods = set()
    for m in re.finditer(r"^\s*(?:async\s+)?([a-zA-Z_$][\w$]*)\s*\(", src, re.M):
        name = m.group(1)
        if name in {"if", "for", "while", "return", "static", "get", "set"}:
            continue
        methods.add(name)
    return methods


def git_diff_files() -> list[Path]:
    files: set[Path] = set()
    for args in (["git", "diff", "--name-only", "HEAD"], ["git", "diff", "--name-only", "--cached"]):
        try:
            out = subprocess.check_output(args, cwd=PROJECT_ROOT, text=True)
        except subprocess.CalledProcessError:
            continue
        for line in out.splitlines():
            p = PROJECT_ROOT / line.strip()
            if p.exists():
                files.add(p)
    return sorted(files)


CONTROLLER_ATTR = re.compile(r'data-controller="([^"]+)"')
TARGET_ATTR = re.compile(r'data-([a-z0-9-]+)-target="([^"]+)"')
VALUE_ATTR = re.compile(r'data-([a-z0-9-]+?)-([a-z0-9-]+)-value="([^"]*)"')
CLASS_ATTR = re.compile(r'data-([a-z0-9-]+?)-([a-z0-9-]+)-class="([^"]*)"')
ACTION_ATTR = re.compile(r'data-action="([^"]+)"')
OLD_TARGET_ATTR = re.compile(r'data-target="([^"]+)"')
# Ruby helper 経由の動的バインド:
#   tag.span(data: { controller: "favorite-mark", ... })
#   content_tag(:div, ..., data: { controller: "foo bar" })
#   "data-controller" => "baz"
RUBY_CONTROLLER_HASH = re.compile(r"""controller:\s*["']([^"']+)["']""")
RUBY_CONTROLLER_ROCKET = re.compile(r"""["']data-controller["']\s*=>\s*["']([^"']+)["']""")


def collect_references(view_files: list[Path], ruby_files: list[Path]):
    """view (.erb) + Ruby helper (.rb) を走査して data-* 参照を収集"""
    controllers_referenced: set[str] = set()
    references_by_controller: dict[str, dict] = {}
    # references_by_controller[cname] = {"targets": {(name,file), ...}, "values": {(name,file),...}, "classes": {...}, "actions": {(method,file),...}}
    deprecated_target_files: list[Path] = []

    for vf in view_files:
        src = read(vf)
        if not src:
            continue
        for m in CONTROLLER_ATTR.finditer(src):
            for cname in m.group(1).split():
                controllers_referenced.add(cname)
        # erb 内の Ruby ヘルパー呼び出しも捕捉
        for m in RUBY_CONTROLLER_HASH.finditer(src):
            for cname in m.group(1).split():
                controllers_referenced.add(cname)
        for m in RUBY_CONTROLLER_ROCKET.finditer(src):
            for cname in m.group(1).split():
                controllers_referenced.add(cname)
        for m in TARGET_ATTR.finditer(src):
            cname, tname = m.group(1), m.group(2)
            for tn in tname.split():
                references_by_controller.setdefault(cname, {}).setdefault("targets", set()).add((tn, vf))
        for m in VALUE_ATTR.finditer(src):
            cname, vname = m.group(1), m.group(2)
            references_by_controller.setdefault(cname, {}).setdefault("values", set()).add((vname, vf))
        for m in CLASS_ATTR.finditer(src):
            cname, cn = m.group(1), m.group(2)
            references_by_controller.setdefault(cname, {}).setdefault("classes", set()).add((cn, vf))
        for m in ACTION_ATTR.finditer(src):
            for token in m.group(1).split():
                # click->foo#bar または foo#bar
                mm = re.match(r"(?:[^-]+->)?([a-z0-9-]+)#([A-Za-z_$][\w$]*)", token)
                if mm:
                    cname, method = mm.group(1), mm.group(2)
                    references_by_controller.setdefault(cname, {}).setdefault("actions", set()).add((method, vf))
        if OLD_TARGET_ATTR.search(src):
            deprecated_target_files.append(vf)

    # Ruby helper (.rb) からの controller 名だけ収集
    for rf in ruby_files:
        src = read(rf)
        if not src:
            continue
        for m in RUBY_CONTROLLER_HASH.finditer(src):
            for cname in m.group(1).split():
                controllers_referenced.add(cname)
        for m in RUBY_CONTROLLER_ROCKET.finditer(src):
            for cname in m.group(1).split():
                controllers_referenced.add(cname)

    return controllers_referenced, references_by_controller, deprecated_target_files


class Report:
    def __init__(self):
        self.fails: list[str] = []
        self.warns: list[str] = []

    def fail(self, msg: str):
        self.fails.append(msg)

    def warn(self, msg: str):
        self.warns.append(msg)

    def render(self) -> tuple[str, int]:
        out = ["## stimulus-check 結果", ""]
        out.append("| カテゴリ | 件数 | 状態 |")
        out.append("|---------|------|------|")
        out.append(f"| FAIL    | {len(self.fails)} | {'✅' if not self.fails else '❌'} |")
        out.append(f"| WARN    | {len(self.warns)} | {'✅' if not self.warns else '⚠️'} |")
        out.append("")
        if self.fails:
            out.append("### ❌ FAIL")
            for l in self.fails:
                out.append(f"- {l}")
            out.append("")
        if self.warns:
            out.append("### ⚠️ WARN")
            for l in self.warns:
                out.append(f"- {l}")
            out.append("")
        if not self.fails and not self.warns:
            out.append("**結論**: ✅ Stimulus 整合性 OK")
            return "\n".join(out), 0
        if not self.fails:
            out.append(f"**結論**: ✅ FAIL なし / ⚠️ 要確認 {len(self.warns)} 件")
            return "\n".join(out), 0
        out.append(f"**結論**: ❌ FAIL {len(self.fails)} 件 / ⚠️ WARN {len(self.warns)} 件")
        return "\n".join(out), 1


def rel(p: Path) -> str:
    try:
        return str(p.relative_to(PROJECT_ROOT))
    except ValueError:
        return str(p)


def main(argv: list[str]) -> int:
    mode = argv[1] if len(argv) > 1 else "diff"
    all_ctrls = all_controller_files()
    ctrl_by_name = {controller_name_for(c): c for c in all_ctrls}

    # --- Rule 1: filename-mismatch (直下の *.js で _controller.js suffix でない) ---
    report = Report()
    for js in CONTROLLERS_DIR.rglob("*.js"):
        if js.name in {"index.js", "application.js"}:
            continue
        if not js.name.endswith("_controller.js"):
            report.fail(f"filename-mismatch: {rel(js)} — Stimulus 命名規則 (*_controller.js) に反する")

    # 対象決定
    if mode == "--all":
        target_ctrls = all_ctrls
        target_views = list(iter_view_files(VIEW_DIRS))
    elif mode == "diff":
        diffed = git_diff_files()
        target_ctrls = [c for c in all_ctrls if c in diffed]
        target_views = [p for p in diffed if any(str(p).startswith(str(d)) for d in VIEW_DIRS)]
        # diff にビュー含まれる場合、そのビューが参照するコントローラも対象
        for v in target_views:
            src = read(v)
            for m in CONTROLLER_ATTR.finditer(src):
                for cn in m.group(1).split():
                    if cn in ctrl_by_name and ctrl_by_name[cn] not in target_ctrls:
                        target_ctrls.append(ctrl_by_name[cn])
    else:
        p = PROJECT_ROOT / mode if not os.path.isabs(mode) else Path(mode)
        target_ctrls = [p] if p.name.endswith("_controller.js") and p.exists() else []
        target_views = [p] if any(str(p).startswith(str(d)) for d in VIEW_DIRS) and p.exists() else []

    # 参照収集は常に全ビュー + 全 helper (参照解決のため)
    all_views = list(iter_view_files(VIEW_DIRS))
    all_rubies = list(iter_ruby_files(HELPER_DIRS))
    refs_ctrl, refs_by_c, deprecated = collect_references(all_views, all_rubies)

    # --- Rule 2: unknown-controller ---
    for ref in sorted(refs_ctrl):
        if ref not in ctrl_by_name:
            # 参照している最初の view を探す
            first = ""
            for vf in all_views:
                src = read(vf)
                if re.search(rf'data-controller="(?:[^"]*\s)?{re.escape(ref)}(?:\s[^"]*)?"', src):
                    first = rel(vf)
                    break
            report.fail(f"unknown-controller: data-controller=\"{ref}\" 参照 (例: {first}) — {ref.replace('-','_')}_controller.js が無い")

    # --- Rule 3: unused-controller ---
    for cname, cf in ctrl_by_name.items():
        if cname not in refs_ctrl:
            report.warn(f"unused-controller: {rel(cf)} (data-controller=\"{cname}\" が全ビューから参照されていない)")

    # --- Rule 4/5/6/7: targets/values/classes/actions 検査 (対象 controller のみ) ---
    for cf in target_ctrls:
        cname = controller_name_for(cf)
        src = read(cf)
        targets = declared_targets(src)
        values = declared_values(src)
        classes = declared_classes(src)
        methods = controller_methods(src)
        refs = refs_by_c.get(cname, {})

        # target
        for tname, vf in sorted(refs.get("targets", set())):
            if targets and tname not in targets:
                report.fail(
                    f"undeclared-target: data-{cname}-target=\"{tname}\" ({rel(vf)}) — {rel(cf)} の static targets に \"{tname}\" が無い"
                )
        # value: kebab -> camelCase
        for vname, vf in sorted(refs.get("values", set())):
            camel = kebab_to_camel(vname)
            if values and camel not in values:
                report.fail(
                    f"undeclared-value: data-{cname}-{vname}-value ({rel(vf)}) — {rel(cf)} の static values に {camel} が無い"
                )
        # class
        for cn, vf in sorted(refs.get("classes", set())):
            camel = kebab_to_camel(cn)
            if classes and camel not in classes:
                report.fail(
                    f"undeclared-class: data-{cname}-{cn}-class ({rel(vf)}) — {rel(cf)} の static classes に {camel} が無い"
                )
        # action
        for method, vf in sorted(refs.get("actions", set())):
            if method not in methods:
                # 継承・親経由や動的定義の可能性で WARN
                report.warn(
                    f"unresolved-action: data-action \"{cname}#{method}\" ({rel(vf)}) — {rel(cf)} 内で該当メソッドが見当たらない"
                )

    # --- Rule 8: deprecated-target-syntax ---
    for vf in deprecated:
        report.warn(f"deprecated-target-syntax: {rel(vf)} — data-target=\"...\" (旧 Stimulus 構文)。data-<controller>-target を推奨")

    body, code = report.render()
    print(body)
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
