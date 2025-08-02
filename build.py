#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Iterable, List, Optional, Tuple

CURDIR = Path(__file__).resolve().parent
LOCALES: List[str] = ["ru", "en"]

SITE_DIR = CURDIR / "build/site"
ASM_DIR = CURDIR / "build/asm"
PDF_DIR = CURDIR / "build/pdf"
DOCX_DIR = CURDIR / "build/docx"
PANDOC_REF = CURDIR / "docx/reference.docx"
LUA_COVER = CURDIR / "docx/coverpage.lua"

BUILD_SCOPE_DEFAULT = os.getenv("BUILD_SCOPE", "local")  # local | tags
BUILD_REF_DEFAULT = os.getenv("BUILD_REF", "HEAD")

sys.stdout.reconfigure(line_buffering=True)
GREEN, RESET = "\033[92m", "\033[0m"


def run(cmd: list[str], *, cwd: Optional[Path] = None) -> None:
    print(" ➜ " + " ".join(cmd))
    subprocess.check_call(cmd, cwd=cwd or CURDIR)


def ok(tag: str) -> None:
    print(f"{GREEN}[✓] {tag}{RESET}")


def _playbook_localized_copy_and_patch(pb: Path, ref: str) -> Path:
    text = pb.read_text(encoding="utf-8").replace("\r\n", "\n")
    # tags: '*' -> tags: ~
    text = re.sub(r"^([ \t]*tags:[ \t]*)['\"]?\*['\"]?[ \t]*$",
                  r"\1~", text, flags=re.MULTILINE)
    # branches: ~ -> branches: <ref>
    text = re.sub(r"^([ \t]*branches:[ \t]*)~[ \t]*$",
                  rf"\1{ref}", text, flags=re.MULTILINE)
    tmp = CURDIR / f"{pb.stem}.local{pb.suffix}"
    tmp.write_text(text, encoding="utf-8")
    return tmp


def build_html(scope: str = BUILD_SCOPE_DEFAULT, ref: str = BUILD_REF_DEFAULT) -> None:
    print("[html] start")
    for l in LOCALES:
        pb = CURDIR / f"antora-playbook-{l}.yml"
        if scope == "tags":
            run(["npx", "antora", str(pb)])
        else:
            patched = _playbook_localized_copy_and_patch(pb, ref)
            try:
                run(["npx", "antora", str(patched)])
            finally:
                patched.unlink(missing_ok=True)
    print("[html] done")
    ok("html")


def _list_versions(locale: str) -> List[str]:
    root = SITE_DIR / locale
    if not root.exists():
        return []
    return sorted([p.name for p in root.iterdir() if p.is_dir()])


def _find_export_index(locale: str, version: str) -> Tuple[Optional[Path], Optional[Path]]:
    cands = [
        ASM_DIR / locale / version / "_exports" / "index.adoc",
        ASM_DIR / locale / "_exports" / "index.adoc",
        ASM_DIR / "_exports" / locale / version / "index.adoc",
        ASM_DIR / "_exports" / locale / "index.adoc",
    ]
    for c in cands:
        if c.is_file():
            base = c.parent.parent  # .../_exports -> base
            return c, base
    return None, None


def _ensure_images(base: Path, export_index: Path, locale: str, version: str) -> None:
    img_src = base / "_images"
    img_dst = export_index.parent / locale / version / "_images"
    if img_src.exists():
        img_dst.mkdir(parents=True, exist_ok=True)
        for f in img_src.rglob("*"):
            if f.is_file():
                shutil.copy2(f, img_dst / f.name)


def _allowed_version(version: str, scope: str, ref: str) -> bool:
    if scope == "tags":
        return True
    return version in {ref, "current", "main"}


def build_pdf(scope: str = BUILD_SCOPE_DEFAULT, ref: str = BUILD_REF_DEFAULT) -> None:
    build_html(scope, ref)
    for l in LOCALES:
        versions = _list_versions(l)
        for v in versions:
            if not _allowed_version(v, scope, ref):
                continue
            export_index, base = _find_export_index(l, v)
            if not export_index or not base:
                continue
            _ensure_images(base, export_index, l, v)
            outdir = PDF_DIR / l / v
            outdir.mkdir(parents=True, exist_ok=True)
            outfile = outdir / f"adaptadocx-{l}.pdf"
            toc_title = "Содержание" if l == "ru" else "Contents"
            run([
                "asciidoctor-pdf",
                "-a", "pdf-theme=config/default-theme.yml",
                "-a", "pdf-fontsdir=/usr/share/fonts/truetype/dejavu",
                "-a", "toc",
                "-a", f"toc-title={toc_title}",
                "-a", "allow-uri-read",
                "-a", "title-page=true",
                "-a", f"revnumber={v}",
                "-a", "version-label=",
                "-o", str(outfile),
                str(export_index),
            ])
            dl = SITE_DIR / l / v / "_downloads"
            dl.mkdir(parents=True, exist_ok=True)
            shutil.copy2(outfile, dl / f"adaptadocx-{l}.pdf")
    ok("pdf")


def _validate_xml(xml_file: Path) -> None:
    try:
        ET.parse(xml_file)
    except ET.ParseError as e:
        raise RuntimeError(f"DocBook validation failed: {e}") from e


def build_docx(scope: str = BUILD_SCOPE_DEFAULT, ref: str = BUILD_REF_DEFAULT) -> None:
    build_html(scope, ref)
    svg_filter: list[str] = []
    if shutil.which("rsvg-convert"):
        svg_filter = ["--lua-filter", str(CURDIR / "docx/svg2png.lua")]

    for l in LOCALES:
        versions = _list_versions(l)
        for v in versions:
            if not _allowed_version(v, scope, ref):
                continue
            export_index, base = _find_export_index(l, v)
            if not export_index or not base:
                continue
            _ensure_images(base, export_index, l, v)

            outdir = DOCX_DIR / l / v
            outdir.mkdir(parents=True, exist_ok=True)
            outfile = outdir / f"adaptadocx-{l}.docx"

            exports_dir = export_index.parent
            with tempfile.NamedTemporaryFile(dir=exports_dir, suffix=".xml", delete=False) as tmp:
                docbook_path = Path(tmp.name)

            run([
                "asciidoctor", "-b", "docbook5",
                "-r", str(CURDIR / "extensions/collapsible_tree_processor.rb"),
                "-a", "allow-uri-read", "-a", "revdate!", "-a", "revnumber!",
                "-a", "docdate!", "-a", "docdatetime!",
                "-o", str(docbook_path), "index.adoc",
            ], cwd=exports_dir)
            _validate_xml(docbook_path)

            tmp_meta = outdir / f"meta-{l}-{v}.yml"
            meta_src = (CURDIR / "config" / f"meta-{l}.yml").read_text(encoding="utf-8")
            tmp_meta.write_text(meta_src.replace("{page-version}", v), encoding="utf-8")

            run([
                "pandoc", "--from=docbook", "--to=docx",
                f"--reference-doc={PANDOC_REF}",
                f"--metadata-file={tmp_meta}",
                *svg_filter,
                "--lua-filter", str(LUA_COVER),
                "-o", str(outfile), str(docbook_path)
            ])
            docbook_path.unlink(missing_ok=True)
            tmp_meta.unlink(missing_ok=True)

            dl = SITE_DIR / l / v / "_downloads"
            dl.mkdir(parents=True, exist_ok=True)
            shutil.copy2(outfile, dl / f"adaptadocx-{l}.docx")
    ok("docx")


def build_site(scope: str = BUILD_SCOPE_DEFAULT, ref: str = BUILD_REF_DEFAULT) -> None:
    build_html(scope, ref)
    build_pdf(scope, ref)
    build_docx(scope, ref)
    ok("site")


def clean() -> None:
    shutil.rmtree(CURDIR / "build", ignore_errors=True)
    ok("clean")


def test() -> None:
    if SITE_DIR.exists():
        run(["htmltest", "-c", ".htmltest.yml", str(SITE_DIR)])
    else:
        print("[test] Skipping htmltest - no site built")
    run(["vale", "--config=.vale.ini", "docs/"])
    scripts = list((CURDIR / "scripts").rglob("*.sh")) if (CURDIR / "scripts").exists() else []
    for s in scripts:
        run(["bash", "-lc", f"tr -d '\\r' < '{s}' | shellcheck -"])
    ok("test")


def main() -> None:
    parser = argparse.ArgumentParser(description="Adaptadocx builder (Python)")
    parser.add_argument("--scope", choices=["local", "tags"], default=BUILD_SCOPE_DEFAULT)
    parser.add_argument("--ref", default=BUILD_REF_DEFAULT)
    sub = parser.add_subparsers(dest="cmd", required=True)
    for t in ("build-html", "build-pdf", "build-docx", "build-site", "build-all", "test", "clean"):
        sub.add_parser(t)
    args = parser.parse_args()

    scope: str = args.scope
    ref: str = args.ref

    actions = {
        "build-html": lambda: build_html(scope, ref),
        "build-pdf": lambda: build_pdf(scope, ref),
        "build-docx": lambda: build_docx(scope, ref),
        "build-site": lambda: build_site(scope, ref),
        "build-all": lambda: build_site(scope, ref),
        "test": test,
        "clean": clean,
    }
    try:
        actions[args.cmd]()
    except subprocess.CalledProcessError as e:
        sys.exit(e.returncode)


if __name__ == "__main__":
    main()