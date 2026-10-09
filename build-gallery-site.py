#!/usr/bin/env python3
"""Assemble the hosted gallery with checksum-verified MP4s from release assets."""
import argparse
import concurrent.futures
import hashlib
import html
import json
import pathlib
import shutil
import urllib.parse
import urllib.request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=pathlib.Path, required=True)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    args = parser.parse_args()
    source, output = args.source.resolve(), args.output.resolve()
    if output == source or output in source.parents:
        raise ValueError('Output must be separate from source')
    output.mkdir(parents=True, exist_ok=True)
    videos = output / 'videos'
    videos.mkdir(exist_ok=True)
    manifest = json.loads((source / 'manifest.json').read_text())

    def download(clip):
        url = clip['file']
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != 'https' or parsed.netloc != 'github.com' or '/releases/download/' not in parsed.path:
            raise ValueError('Expected a GitHub Release asset URL')
        name = pathlib.PurePosixPath(parsed.path).name
        if not name.endswith('.mp4'):
            raise ValueError('Expected an MP4 asset')
        request = urllib.request.Request(url, headers={'User-Agent': 'Waypoint-Gallery'})
        with urllib.request.urlopen(request, timeout=120) as response:
            data = response.read()
        if hashlib.sha256(data).hexdigest() != clip['sha256']:
            raise ValueError('Asset checksum mismatch: ' + name)
        (videos / name).write_bytes(data)
        return url, 'videos/' + name

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        replacements = dict(executor.map(download, manifest['clips']))
    page = (source / 'index.html').read_text()
    for url, relative in replacements.items():
        page = page.replace('src="' + html.escape(url, quote=True) + '"', 'src="' + relative + '"')
    (output / 'index.html').write_text(page)
    for clip in manifest['clips']:
        clip['file'] = replacements[clip['file']]
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    for name in ['media-validation.json', 'steps.jsonl']:
        shutil.copy2(source / name, output / name)
    print('Built gallery with', len(replacements), 'verified videos')


if __name__ == '__main__':
    main()
