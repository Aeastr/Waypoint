#!/usr/bin/env python3
"""Create a local playback gallery for a completed scripted recording run."""
import argparse
import html
import json
import pathlib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('run', type=pathlib.Path)
root = parser.parse_args().run
manifest = json.loads((root / 'manifest.json').read_text())
catalog = json.loads(pathlib.Path(__file__).with_name('recording-flows.json').read_text())
escape = html.escape
cards, links = [], []
groups = [('B', 'Stacks, tabs, and sheets'), ('C', 'Contextual routing'), ('W', 'Editor')]
index = {prefix: [] for prefix, _ in groups}
for clip in manifest['clips']:
    if clip['status'] != 'passed' or 'file' not in clip:
        continue
    name = clip['file']
    flow = clip['flow']
    info = catalog.get(flow, {'title': pathlib.Path(name).stem.replace('-', ' '), 'description': ''})
    title, description = info['title'], info['description']
    if not name.startswith('https://'):
        assert (root / name).is_file()
    duration = f"{clip['duration']:.1f}s" if 'duration' in clip else ''
    cards.append(
        f'<article id="{escape(flow)}" aria-labelledby="title-{escape(flow)}">'
        f'<header class="card-heading"><span class="flow-id">{escape(flow)}</span>'
        f'<h2 id="title-{escape(flow)}">{escape(title)}</h2></header>'
        f'<div class="player"><video controls preload="metadata" playsinline aria-label="{escape(title)}" '
        f'src="{escape(name, quote=True)}"></video></div>'
        f'<div class="caption"><p>{escape(description)}</p>'
        f'<div class="video-links"><a href="{escape(name, quote=True)}">Download video</a>'
        f'<span>{duration}</span><a href="#flow-index">Back to index ↑</a></div></div></article>'
    )
    if flow[:1] in index:
        index[flow[:1]].append(f'<li><a href="#{escape(flow)}"><code>{escape(flow)}</code> {escape(title)}</a></li>')
    links.append(f'- [{flow} — {title}]({name})' + (f' · {duration}' if duration else '') + '\n  ' + description)
runtime = manifest['runtime'].split('SimRuntime.')[-1].replace('iOS-', 'iOS ').replace('-', '.')
intro = f"{len(cards)} scripted routing flows · {manifest['device']} · {runtime}"
nav = '<nav id="flow-index" aria-label="Flow index"><h2>Flow index</h2><div class="index-grid">'
for prefix, label in groups:
    if index[prefix]:
        nav += f'<section><h3>{label}</h3><ul>' + ''.join(index[prefix]) + '</ul></section>'
nav += '</div></nav>'
style = '''
:root{color-scheme:light dark;--bg:#fff;--subtle:#f6f8fa;--fg:#1f2328;--muted:#59636e;--border:#d1d9e0;--link:#0969da}
@media(prefers-color-scheme:dark){:root{--bg:#0d1117;--subtle:#151b23;--fg:#f0f6fc;--muted:#9198a1;--border:#3d444d;--link:#4493f8}}
*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:24px}
body{margin:0;background:var(--bg);color:var(--fg);font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
a{color:var(--link);text-decoration:none}a:hover{text-decoration:underline}a:focus-visible,video:focus-visible{outline:2px solid var(--link);outline-offset:4px}
.repo-bar{background:var(--subtle);border-bottom:1px solid var(--border);padding:16px 24px;font-size:16px}.repo-bar span{color:var(--muted);margin:0 8px}
main{max-width:1280px;margin:auto;padding:32px 24px 48px}h1{font-size:28px;font-weight:600;line-height:1.25;margin:0 0 8px}.intro{color:var(--muted);margin:0 0 28px}
nav{border:1px solid var(--border);border-radius:6px;margin-bottom:32px;overflow:hidden}nav>h2{background:var(--subtle);border-bottom:1px solid var(--border);font-size:16px;padding:12px 16px;margin:0}
.index-grid{display:grid;grid-template-columns:1.4fr 1fr .8fr;gap:24px;padding:16px}h3{font-size:14px;margin:0 0 12px}ul{list-style:none;margin:0;padding:0}li+li{margin-top:8px}code,.flow-id{font:12px ui-monospace,SFMono-Regular,Consolas,monospace}code{color:var(--muted);margin-right:6px}
.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:24px;align-items:start}article{border:1px solid var(--border);border-radius:6px;overflow:hidden;scroll-margin-top:24px}
.card-heading{padding:12px 16px;display:flex;align-items:baseline;gap:10px;background:var(--subtle);border-bottom:1px solid var(--border)}.flow-id{color:var(--muted)}h2{font-size:14px;font-weight:600;margin:0}
.player{background:var(--subtle);padding:16px;text-align:center}video{display:block;width:100%;max-height:540px;aspect-ratio:1206/2622;object-fit:contain;margin:auto;background:#000;border-radius:4px}
.caption{padding:16px;border-top:1px solid var(--border)}.caption p{margin:0 0 16px}.video-links{display:flex;flex-wrap:wrap;gap:8px 16px;align-items:center;font-size:12px}.video-links span{color:var(--muted)}.video-links a:last-child{margin-left:auto}
footer{border-top:1px solid var(--border);margin-top:32px;padding-top:16px;color:var(--muted)}
@media(max-width:1000px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}.index-grid{grid-template-columns:1fr 1fr}.index-grid section:last-child{grid-column:1/-1}}
@media(max-width:640px){main{padding:24px 16px}.grid,.index-grid{grid-template-columns:1fr}.repo-bar{padding:12px 16px}.index-grid section:last-child{grid-column:auto}}
@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}}
'''
(root / 'index.html').write_text(
    '<!doctype html><html lang="en"><head><meta charset="utf-8">'
    '<meta name="viewport" content="width=device-width,initial-scale=1">'
    '<title>Recordings · Waypoint</title><style>' + style + '</style></head><body>'
    '<header class="repo-bar"><a href="https://github.com/Aeastr/Waypoint">Aeastr / <strong>Waypoint</strong></a>'
    '<span>/</span>Recordings</header><main><h1>iPhone recordings</h1><p class="intro">' + escape(intro)
    + '</p>' + nav + '<div class="grid">' + ''.join(cards) + '</div>'
    '<footer><a href="manifest.json">Run manifest</a> · <a href="steps.jsonl">Step timestamps</a></footer>'
    '</main></body></html>\n'
)
(root / 'README.md').write_text(
    '# Scripted iPhone recordings\n\n' + intro
    + '\n\nOpen [the playback gallery](' + manifest.get('galleryURL', 'index.html') + '), or select a clip:\n\n'
    + '\n'.join(links) + '\n\n[Run manifest](manifest.json) · [Step timestamps](steps.jsonl)\n'
)
print('Published', len(cards), 'gallery entries with descriptions and flow index')
