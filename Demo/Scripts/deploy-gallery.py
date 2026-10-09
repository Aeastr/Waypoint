#!/usr/bin/env python3
"""Publish the gallery and metadata to the GitHub Pages branch using gh."""
import argparse
import json
import pathlib
import subprocess


def api(repo, endpoint, method='GET', data=None, missing_ok=False):
    command = ['gh', 'api', f'repos/{repo}/{endpoint}', '--method', method]
    if data is not None:
        command += ['--input', '-']
    result = subprocess.run(command, input=json.dumps(data) if data is not None else None,
                            text=True, capture_output=True)
    if result.returncode:
        if missing_ok and 'HTTP 404' in result.stderr:
            return None
        raise RuntimeError(result.stderr.strip())
    return json.loads(result.stdout) if result.stdout.strip() else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', default='Aeastr/Waypoint')
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[2] / 'Resources/Recordings'
    manifest = json.loads((root / 'manifest.json').read_text())
    if not all(c['file'].startswith('https://') for c in manifest['clips']):
        raise RuntimeError('Publish the videos as release assets before deploying the gallery')
    entries = [{'path': name, 'mode': '100644', 'type': 'blob', 'content': (root / name).read_text()}
               for name in ['index.html', 'manifest.json', 'media-validation.json', 'steps.jsonl']]
    entries.append({'path': '.nojekyll', 'mode': '100644', 'type': 'blob', 'content': ''})
    branch = api(args.repo, 'git/ref/heads/gh-pages', missing_ok=True)
    parents = []
    tree_request = {'tree': entries}
    if branch:
        parents = [branch['object']['sha']]
        previous = api(args.repo, 'git/commits/' + parents[0])
        tree_request['base_tree'] = previous['tree']['sha']
    tree = api(args.repo, 'git/trees', 'POST', tree_request)
    if branch and tree['sha'] == previous['tree']['sha']:
        print('Gallery is already up to date')
        return
    commit = api(args.repo, 'git/commits', 'POST', {
        'message': 'Publish Waypoint recording gallery', 'tree': tree['sha'], 'parents': parents})
    if branch:
        api(args.repo, 'git/refs/heads/gh-pages', 'PATCH', {'sha': commit['sha'], 'force': False})
    else:
        api(args.repo, 'git/refs', 'POST', {'ref': 'refs/heads/gh-pages', 'sha': commit['sha']})
    print('Published gallery commit', commit['sha'])


if __name__ == '__main__':
    main()
