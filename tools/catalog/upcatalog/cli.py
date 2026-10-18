"""入库管线命令行：python3 -m upcatalog <fetch|analyze|slice|pack|preview|publish|build|list> …"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from . import layout, publish as pub, preview as prev, rust
from .model import Song
from .paths import Ctx

SOURCES = ("synth", "album", "online")


def _source_mod(name: str):
    if name == "synth":
        from .sources import synth as m
    elif name == "album":
        from .sources import album as m
    elif name == "online":
        from .sources import online as m
    else:
        raise SystemExit(f"未知来源 {name}（{', '.join(SOURCES)}）")
    return m


def _sources(arg: str) -> list[str]:
    return list(SOURCES) if arg == "all" else [arg]


def _ids(ctx: Ctx, args) -> list[str]:
    if getattr(args, "id", None):
        return args.id
    ids = sorted(p.parent.name for p in ctx.work.glob("*/song.json"))
    if getattr(args, "source", None) and args.source != "all":
        prefix = {"synth": "synth-", "album": "album-", "online": "online-"}[args.source]
        ids = [i for i in ids if i.startswith(prefix)]
    return ids


def cmd_fetch(ctx, args):
    for s in _sources(args.source):
        print(f"[fetch:{s}]", json.dumps(_source_mod(s).fetch(ctx), ensure_ascii=False))


def cmd_analyze(ctx, args):
    for s in _sources(args.source):
        built = _source_mod(s).build(ctx, only=set(args.id) if args.id else None, **({"limit": args.limit} if args.limit and s != "synth" else {}))
        print(f"[analyze:{s}] {len(built)} 首：{', '.join(built[:6])}{' …' if len(built) > 6 else ''}")


def cmd_slice(ctx, args):
    for id_ in _ids(ctx, args):
        song, stems = Song.load(ctx.work, id_)
        stats = layout.build_kit_dir(song, stems, ctx.out / "kitdirs" / id_)
        (ctx.out / "items" / f"{id_}.json").write_text(json.dumps(layout.item_json(song, stats), ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"[slice] {id_}: {stats['group_count']} 组 / {stats['pad_count']} pad")


def cmd_pack(ctx, args):
    for id_ in _ids(ctx, args):
        up = rust.pack(ctx.out / "kitdirs" / id_, ctx.out / "kits" / f"{id_}.upkit")
        info = rust.verify(up)
        (ctx.out / "items" / f"{id_}.verify.json").write_text(json.dumps(info), encoding="utf-8")
        print(f"[pack] {id_}: {info['bytes'] / 1e6:.1f} MB, {info['samples']} 个样本, {info['pad_count']} pad, 警告 {info['warnings']}")


def cmd_preview(ctx, args):
    ids = _ids(ctx, args)
    print("[preview]", prev.build(ctx, ids), f"({len(ids)} 条)")


def cmd_qa(ctx, args):
    from . import qa

    res = qa.run(ctx, _ids(ctx, args))
    bad = {k: v for k, v in res.items() if v}
    for k, v in bad.items():
        print(f"[qa] {k}: " + "；".join(v))
    print(f"[qa] {len(res) - len(bad)}/{len(res)} 通过")
    return 1 if bad and args.strict else 0


def cmd_publish(ctx, args):
    for r in pub.publish(ctx, _ids(ctx, args), make_published=args.publish, dry_run=args.dry_run):
        print("[publish]", json.dumps(r))


def cmd_build(ctx, args):
    cmd_fetch(ctx, args)
    cmd_analyze(ctx, args)
    cmd_slice(ctx, args)
    cmd_pack(ctx, args)
    cmd_preview(ctx, args)


def cmd_list(ctx, args):
    for id_ in _ids(ctx, args):
        it = json.loads((ctx.out / "items" / f"{id_}.json").read_text(encoding="utf-8")) if (ctx.out / "items" / f"{id_}.json").exists() else {}
        print(f"{id_:48} {it.get('origin', '?'):6} {it.get('license', '?'):16} {it.get('bpm', '?')}")


def main(argv=None):
    ap = argparse.ArgumentParser(prog="upcatalog", description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)

    def add(name, fn, source=True, ids=True, **kw):
        p = sub.add_parser(name, **kw)
        if source:
            p.add_argument("--source", default="all", choices=("all", *SOURCES))
        if ids:
            p.add_argument("--id", action="append", help="只处理指定条目（可重复）")
        p.set_defaults(fn=fn)
        return p

    add("fetch", cmd_fetch, ids=False, help="拉取并校验来源（含许可证原文检查）")
    a = add("analyze", cmd_analyze, help="synth：作曲 + 渲染；album / online：节拍分析 + 选段，产出对齐到小节的分轨")
    a.add_argument("--limit", type=int, help="album / online 最多处理几条")
    add("slice", cmd_slice, help="切片并生成 .upkit 目录与条目元数据")
    add("pack", cmd_pack, help="打包 .upkit 并验证（导入 + 解码全部样本）")
    p = add("qa", cmd_qa, help="自动质检（静音 / 削波 / 节拍对齐 / 循环首尾跳变）")
    p.add_argument("--strict", action="store_true", help="有问题则退出码为 1")
    add("preview", cmd_preview, help="生成试听 mp3 与人工抽检 HTML")
    p = add("publish", cmd_publish, help="上传到数据服务（默认 draft）")
    p.add_argument("--publish", action="store_true", help="上传后改为 published（需先人工抽检）")
    p.add_argument("--dry-run", action="store_true")
    a = add("build", cmd_build, help="fetch → analyze → slice → pack → preview")
    a.add_argument("--limit", type=int)
    add("list", cmd_list, ids=True, help="列出已处理条目")
    args = ap.parse_args(argv)
    ctx = Ctx().ensure()
    return args.fn(ctx, args) or 0


if __name__ == "__main__":
    sys.exit(main())
