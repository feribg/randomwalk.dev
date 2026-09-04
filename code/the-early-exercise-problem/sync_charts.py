#!/usr/bin/env python3
"""Splice charts/*.svg into a post, replacing whatever SVG blocks are there now.

    python3 sync_charts.py content/blog/<slug>/index.md

The post path is a required argument. An earlier version hardcoded it, which meant that
after a new version of the post was written the script silently rewrote the OLD one — and
with a stale figure list, so it swapped figures as well. Both failure modes were silent.
Figures are matched positionally, so adding one to a post means adding it to ORDER too.
"""
import pathlib, re, sys

ORDER = ["volbp-scale", "oracle-agreement", "exercise-boundary",
         "smearing-by-side", "input-vs-pricer"]
HERE = pathlib.Path(__file__).parent

def main():
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} <path-to-post/index.md>")
    post = pathlib.Path(sys.argv[1])
    if not post.is_file():
        sys.exit(f"no such post: {post}")
    src = post.read_text()
    svgs = list(re.finditer(r"<svg\b.*?</svg>", src, re.S))
    if len(svgs) != len(ORDER):
        sys.exit(f"{post} has {len(svgs)} svg blocks, expected {len(ORDER)}: {ORDER}")
    out, prev = [], 0
    for m, name in zip(svgs, ORDER):
        svg = HERE / "charts" / f"{name}.svg"
        if not svg.is_file():
            sys.exit(f"missing figure: {svg} (run charts.jl first)")
        out.append(src[prev:m.start()])
        out.append(svg.read_text().strip())
        prev = m.end()
    out.append(src[prev:])
    post.write_text("".join(out))
    print(f"synced {len(ORDER)} figures into {post}")

if __name__ == "__main__":
    main()
