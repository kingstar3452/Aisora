#!/usr/bin/env python3
"""Prepare inert release metadata for review. NEVER publishes a release.

The release body is the authenticated-by-GitHub source of the manifest. The
archive may be a release asset or an immutable commit in the same repository.
An arbitrary external download URL is deliberately not accepted.
"""
import argparse
import json
from pathlib import Path
import re
import plistlib
import zipfile
from urllib.parse import urlparse

from macos_bundle import verify_zip
from prepare_updater import version


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive',required=True,type=Path)
    parser.add_argument('--tag',required=True)
    parser.add_argument('--notes',required=True,type=Path)
    parser.add_argument('--download-url')
    parser.add_argument('--output-dir',type=Path,default=Path('.local/update-release'))
    args=parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,95}',args.tag):
        parser.error('Use a simple versioned release tag.')
    repo=Path(__file__).resolve().parents[1]
    report=verify_zip(args.archive)
    with zipfile.ZipFile(args.archive) as package:
        info=plistlib.loads(package.read('Aisora.app/Contents/Info.plist'))
    if info.get('AisoraVersion')!=version(repo):
        parser.error('Built ZIP version differs from source; rebuild before preparing a release.')
    if len(report['nested_code_verified'])!=1:
        parser.error('This ZIP does not contain the sealed native updater.')
    download=args.download_url or f'https://github.com/kingstar3452/Aisora/releases/download/{args.tag}/Aisora-phase6-macos.zip'
    parsed=urlparse(download)
    asset=f'https://github.com/kingstar3452/Aisora/releases/download/{args.tag}/Aisora-phase6-macos.zip'
    immutable=re.fullmatch(r'https://raw\.githubusercontent\.com/kingstar3452/Aisora/[a-f0-9]{40}/Aisora-phase6-macos.zip',download)
    if download!=asset and not immutable:
        parser.error('Archive must be this release asset or an immutable artifact commit in the same repository.')
    if parsed.query or parsed.fragment:
        parser.error('No query or fragment is permitted.')
    manifest={'schema':1,'version':version(repo),'tag':args.tag,'url':download,
              'sha256':report['sha256'],'bytes':report['bytes'],'architecture':'x86_64',
              'bundle_id':'local.aisora.companion','min_macos':'13.0','updater_protocol':1}
    notes=args.notes.read_text()
    if 'AISORA_UPDATE_V1' in notes:
        parser.error('Notes already contain update metadata.')
    body=notes.rstrip()+'\n\n<!-- AISORA_UPDATE_V1\n'+json.dumps(manifest,indent=2)+'\nAISORA_UPDATE_V1 -->\n'
    args.output_dir.mkdir(parents=True,exist_ok=True)
    (args.output_dir/'Aisora-update.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (args.output_dir/'release-notes.md').write_text(body)
    print('Prepared release notes/metadata for review. Nothing published.')


if __name__=='__main__':
    main()
