#!/usr/bin/env python3
"""Independent ZIP/Mach-O/resource-seal checks for the simple Intel Godot app.

These checks establish ad-hoc signature consistency, NOT Apple publisher trust,
notarization, quarantine approval, Gatekeeper acceptance or a native launch.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import stat
import struct
import zipfile


class BundleError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise BundleError(message)


def _code_directories(binary, info, resources):
    require(len(binary) >= 32 and binary[:4] == bytes.fromhex('cffaedfe'), 'Not a thin 64-bit little-endian Mach-O')
    require(struct.unpack_from('<I', binary, 4)[0] == 0x01000007, 'Executable is not Intel x86_64')
    ncmds, commands_size = struct.unpack_from('<II', binary, 16)
    require(ncmds <= 4096 and 32 + commands_size <= len(binary), 'Invalid Mach-O load commands')
    offset = 32
    signature = None
    minimum_os = []
    for _ in range(ncmds):
        require(offset + 8 <= 32 + commands_size, 'Truncated load command')
        cmd, size = struct.unpack_from('<II', binary, offset)
        require(size >= 8 and offset + size <= 32 + commands_size, 'Invalid load command size')
        if cmd == 0x1d:
            require(size >= 16 and signature is None, 'Invalid/duplicate code-signature command')
            signature = struct.unpack_from('<II', binary, offset + 8)
        if cmd in (0x24, 0x32):
            require(size >= (16 if cmd == 0x24 else 24), 'Truncated OS version command')
            value = struct.unpack_from('<I', binary, offset + (8 if cmd == 0x24 else 12))[0]
            require(value <= 13 << 16, 'Executable minimum macOS is newer than Ventura')
            minimum_os.append([value >> 16, value >> 8 & 255, value & 255])
        offset += size
    require(minimum_os, 'Missing minimum OS version command')
    require(signature is not None, 'Missing embedded code signature')
    start, size = signature
    require(start >= offset and size >= 12 and start + size <= len(binary), 'Invalid signature range')
    blob = binary[start:start + size]
    magic, length, count = struct.unpack_from('>III', blob)
    require(magic == 0xfade0cc0 and 12 + count * 8 <= length <= len(blob), 'Invalid signature superblob')
    slots = {}
    for i in range(count):
        kind, pos = struct.unpack_from('>II', blob, 12 + i * 8)
        require(kind not in slots and pos >= 12 + count * 8 and pos + 8 <= length, 'Invalid signature slot')
        _, amount = struct.unpack_from('>II', blob, pos)
        require(amount >= 8 and pos + amount <= length, 'Truncated signature component')
        slots[kind] = blob[pos:pos + amount]
    require(0 in slots and (65536 not in slots or slots[65536] == struct.pack('>II', 0xfade0b01, 8)), 'Expected ad-hoc signing without a certificate CMS signature')
    directories = []
    for kind, cd in slots.items():
        if struct.unpack_from('>I', cd)[0] != 0xfade0c02:
            continue
        require(len(cd) >= 44, 'Truncated CodeDirectory')
        _, _, version, flags, hash_offset, ident_offset, special, pages, limit = struct.unpack_from('>9I', cd)
        hash_size, hash_type, _, page_power = struct.unpack_from('>4B', cd, 36)
        require(flags & 2, 'CodeDirectory is not ad-hoc signed')
        algorithm = {1: 'sha1', 2: 'sha256', 3: 'sha256', 4: 'sha384'}.get(hash_type)
        require(algorithm is not None and hash_size == (20 if hash_type in (1, 3) else (32 if hash_type == 2 else 48)), 'Unsupported signature digest')
        require(0 < page_power <= 24 and limit == start, 'Unexpected code page size or unsigned executable range')
        page_size = 1 << page_power
        require(pages == (limit + page_size - 1) // page_size, 'Incorrect executable page count')
        require(special >= 3 and 44 <= hash_offset - special * hash_size and hash_offset + pages * hash_size <= len(cd), 'Invalid signature hash table')
        require(44 <= ident_offset < hash_offset - special * hash_size, 'Invalid signing identifier offset')
        identifier = cd[ident_offset:hash_offset - special * hash_size].split(b'\0', 1)[0].decode('utf-8')
        require(identifier == info['CFBundleIdentifier'], 'Signing identifier does not match Aisora bundle identity')
        def digest(value):
            return hashlib.new(algorithm, value).digest()[:hash_size]
        for i in range(pages):
            expected = cd[hash_offset + i * hash_size:hash_offset + (i + 1) * hash_size]
            require(expected == digest(binary[i * page_size:min((i + 1) * page_size, limit)]), f'Executable code page {i} digest mismatch')
        special_data = {1: info['_raw'], 3: resources}
        for i in (2, 5, 7):
            if i in slots:
                special_data[i] = slots[i]
        for i in range(1, special + 1):
            expected = cd[hash_offset - i * hash_size:hash_offset - (i - 1) * hash_size]
            if i in special_data:
                require(any(expected) and expected == digest(special_data[i]), f'Special slot {i} seal mismatch (Info.plist=1, resources=3)')
            else:
                require(not any(expected), f'Unverified nonzero special slot {i}')
        directories.append({'identifier': identifier, 'ad_hoc': True, 'digest': algorithm, 'code_pages_verified': pages, 'special_slots_verified': len(special_data)})
    require(directories, 'No valid CodeDirectory')
    return directories, minimum_os


def verify_zip(path):
    path = Path(path)
    prefix = 'Aisora.app/Contents/'
    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        names = [entry.filename for entry in entries]
        require(len(names) == len(set(names)), 'Duplicate ZIP entries')
        require(sum(entry.file_size for entry in entries) <= 512 * 1024 * 1024, 'Unexpected bundle size')
        for entry in entries:
            name = entry.filename
            parsed = PurePosixPath(name)
            require(not parsed.is_absolute() and '..' not in parsed.parts and '\\' not in name, 'Unsafe ZIP path')
            require(name == parsed.as_posix() + ('/' if entry.is_dir() else ''), 'Noncanonical ZIP path')
            require(name.startswith('Aisora.app/') or name == 'Godot-NOTICES.txt', 'Unexpected archive root')
            require(not stat.S_ISLNK(entry.external_attr >> 16), 'Symlinks require a separate native bundle validation')
        require(archive.testzip() is None, 'ZIP CRC failure')
        def read(name):
            require(name in names, f'Missing bundle file: {name}')
            return archive.read(name)
        info_raw = read(prefix + 'Info.plist')
        info = plistlib.loads(info_raw)
        require(info.get('CFBundleIdentifier') == 'local.aisora.companion' and info.get('CFBundleExecutable') == 'Aisora', 'Incorrect app identity or executable')
        info['_raw'] = info_raw
        executable = prefix + 'MacOS/Aisora'
        require(archive.getinfo(executable).external_attr >> 16 & 0o111, 'Executable permission is missing')
        resources_path = prefix + '_CodeSignature/CodeResources'
        resources = read(resources_path)
        directories, minimum = _code_directories(read(executable), info, resources)
        sealed = plistlib.loads(resources)
        files = sealed.get('files2', {})
        require('Resources/Aisora.pck' in files, 'Character/project resource pack is not sealed')
        checked = 0
        for relative, record in files.items():
            require(isinstance(record, dict) and isinstance(record.get('hash2'), bytes), 'Unverified nested code or resource hash')
            value = read(prefix + relative)
            require(hashlib.sha256(value).digest() == record['hash2'], f'Resource seal mismatch: {relative}')
            if 'hash' in record:
                require(hashlib.sha1(value).digest() == record['hash'], f'Legacy resource seal mismatch: {relative}')
            checked += 1
        exceptions = {'Info.plist', 'PkgInfo', 'MacOS/Aisora', '_CodeSignature/CodeResources'}
        for entry in entries:
            if entry.is_dir() or not entry.filename.startswith(prefix):
                continue
            relative = entry.filename[len(prefix):]
            require(relative in exceptions or relative in files, f'Unsealed file added to signed app: {relative}')
        notice = prefix + 'Resources/Godot-NOTICES.txt' if prefix + 'Resources/Godot-NOTICES.txt' in names else 'Godot-NOTICES.txt'
        require(read(notice), 'Missing engine notices')
    return {'architecture': 'x86_64', 'zip_crc': 'pass', 'executable_permission': 'pass', 'minimum_os': minimum,
            'signature_type': 'ad-hoc', 'code_directories': directories, 'resource_hashes_verified': checked,
            'info_plist_and_resource_seals': 'pass', 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'bytes': path.stat().st_size, 'developer_id_verified': False, 'notarization_verified': False,
            'gatekeeper_assessment_performed': False, 'native_macos_launch_performed': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    try:
        result = verify_zip(args.archive)
    except (BundleError, ValueError, KeyError, struct.error, zipfile.BadZipFile) as error:
        raise SystemExit(f'Bundle validation FAILED: {error}')
    rendered = json.dumps(result, indent=2) + '\n'
    if args.report:
        args.report.write_text(rendered)
    print(rendered, end='')


if __name__ == '__main__':
    main()
