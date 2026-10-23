"""Signing/packaging regressions: tampering must fail despite a valid ZIP CRC."""
import hashlib
import importlib.util
from pathlib import Path
import plistlib
import struct
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('macos_bundle', Path(__file__).resolve().parents[1] / 'tools/macos_bundle.py')
bundle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bundle)


def helper_fixture():
    identifier=b'local.aisora.companion.updater\0'
    offset=44+len(identifier)
    length=offset+32
    signature_size=20+length
    code=(struct.pack('<8I',0xfeedfacf,0x01000007,3,2,2,32,0,0)+struct.pack('<4I',0x24,16,0x000d0000,0x000d0000)+struct.pack('<4I',0x1d,16,4096,signature_size)).ljust(4096,b'\0')
    cd=struct.pack('>9I',0xfade0c02,length,0x20001,2,offset,44,0,1,4096)+bytes([32,2,0,12])+bytes(4)+identifier+hashlib.sha256(code).digest()
    return code+struct.pack('>5I',0xfade0cc0,signature_size,1,0,20)+cd,hashlib.sha256(cd).digest()[:20]


def fixture(updater=False):
    """A tiny structural Mach-O signature fixture; never a native launch test."""
    metadata={'CFBundleIdentifier': 'local.aisora.companion', 'CFBundleExecutable': 'Aisora'}
    if updater:metadata.update(AisoraUpdaterProtocol='1',AisoraVersion='6.1.0-rc.1')
    info = plistlib.dumps(metadata)
    pack = b'test project resource'
    notices = b'engine notices'
    files = {'Resources/Aisora.pck': {'hash2': hashlib.sha256(pack).digest()},
             'Resources/Godot-NOTICES.txt': {'hash2': hashlib.sha256(notices).digest()}}
    if updater:
        helper,cdhash=helper_fixture()
        files['Helpers/AisoraUpdater']={'cdhash':cdhash,'requirement':'cdhash H"'+cdhash.hex()+'"'}
        files['Resources/Updater-NOTICES.txt']={'hash2':hashlib.sha256(b'Go notices').digest()}
    resources = plistlib.dumps({'files2': files})
    identifier = b'local.aisora.companion\0'
    hash_offset = 44 + len(identifier) + 3 * 32
    cd_length = hash_offset + 32
    signature_size = 20 + cd_length
    header = struct.pack('<8I', 0xfeedfacf, 0x01000007, 3, 2, 2, 32, 0, 0)
    commands = struct.pack('<4I', 0x24, 16, 0x000a0d00, 0x000d0000) + struct.pack('<4I', 0x1d, 16, 4096, signature_size)
    code = (header + commands).ljust(4096, b'\0')
    cd = struct.pack('>9I', 0xfade0c02, cd_length, 0x20001, 2, hash_offset, 44, 3, 1, 4096)
    cd += bytes([32, 2, 0, 12]) + struct.pack('>I', 0) + identifier
    cd += hashlib.sha256(resources).digest() + bytes(32) + hashlib.sha256(info).digest() + hashlib.sha256(code).digest()
    signature = struct.pack('>5I', 0xfade0cc0, signature_size, 1, 0, 20) + cd
    result={'Aisora.app/Contents/Info.plist': info,
            'Aisora.app/Contents/MacOS/Aisora': code + signature,
            'Aisora.app/Contents/_CodeSignature/CodeResources': resources,
            'Aisora.app/Contents/Resources/Aisora.pck': pack,
            'Aisora.app/Contents/Resources/Godot-NOTICES.txt': notices}
    if updater:
        result['Aisora.app/Contents/Helpers/AisoraUpdater']=helper
        result['Aisora.app/Contents/Resources/Updater-NOTICES.txt']=b'Go notices'
    return result


class BundleTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.archive = Path(self.scratch.name) / 'Aisora.zip'
        self.files = fixture()

    def write(self, executable=True):
        with zipfile.ZipFile(self.archive, 'w') as z:
            for name, data in self.files.items():
                item = zipfile.ZipInfo(name)
                item.create_system = 3
                item.external_attr = (0o100755 if (name.endswith('/MacOS/Aisora') or name.endswith('/Helpers/AisoraUpdater')) and executable else 0o100644) << 16
                z.writestr(item, data)

    def reject(self, pattern):
        self.write()
        with self.assertRaisesRegex(bundle.BundleError, pattern):
            bundle.verify_zip(self.archive)

    def test_consistent_seals_do_not_claim_apple_trust(self):
        self.write()
        result = bundle.verify_zip(self.archive)
        self.assertEqual(result['resource_hashes_verified'], 2)
        self.assertEqual(result['signature_type'], 'ad-hoc')
        self.assertFalse(result['developer_id_verified'])
        self.assertFalse(result['notarization_verified'])
        self.assertFalse(result['gatekeeper_assessment_performed'])
        self.assertFalse(result['native_macos_launch_performed'])

    def test_previous_unsealed_bundle_pattern_rejected(self):
        del self.files['Aisora.app/Contents/_CodeSignature/CodeResources']
        self.reject('Missing bundle file.*CodeResources')

    def test_executable_page_tampering_rejected(self):
        path = 'Aisora.app/Contents/MacOS/Aisora'
        data = bytearray(self.files[path]);data[1024] ^= 1;self.files[path] = bytes(data)
        self.reject('code page 0 digest mismatch')

    def test_info_plist_tampering_rejected(self):
        path = 'Aisora.app/Contents/Info.plist'
        value = plistlib.loads(self.files[path]);value['CFBundleName'] = 'Changed'
        self.files[path] = plistlib.dumps(value)
        self.reject('Special slot 1 seal mismatch')

    def test_resource_directory_tampering_rejected(self):
        path = 'Aisora.app/Contents/_CodeSignature/CodeResources'
        self.files[path] += b'\n'
        self.reject('Special slot 3 seal mismatch')

    def test_project_pack_tampering_rejected(self):
        self.files['Aisora.app/Contents/Resources/Aisora.pck'] += b'changed'
        self.reject('Resource seal mismatch')

    def test_file_added_after_signing_rejected(self):
        self.files['Aisora.app/Contents/Resources/late-notices.txt'] = b'added after signing'
        self.reject('Unsealed file added')

    def test_execute_bit_loss_rejected(self):
        self.write(executable=False)
        with self.assertRaisesRegex(bundle.BundleError, 'Executable permission'):
            bundle.verify_zip(self.archive)

    def test_wrong_architecture_rejected(self):
        path = 'Aisora.app/Contents/MacOS/Aisora'
        data = bytearray(self.files[path]);struct.pack_into('<I', data, 4, 0x0100000c);self.files[path] = bytes(data)
        self.reject('not Intel x86_64')

    def test_unsafe_archive_path_rejected(self):
        self.files['Aisora.app/../escape'] = b'unsafe'
        self.reject('Unsafe ZIP path')

    def test_wrong_bundle_identity_rejected(self):
        path = 'Aisora.app/Contents/Info.plist'
        value = plistlib.loads(self.files[path]);value['CFBundleIdentifier'] = 'org.godotengine.godot'
        self.files[path] = plistlib.dumps(value)
        self.reject('Incorrect app identity')

    def test_nested_updater_seal_verified_without_apple_trust_claim(self):
        self.files=fixture(updater=True)
        self.write()
        report=bundle.verify_zip(self.archive)
        self.assertEqual(report['nested_code_verified'][0]['code_directories'][0]['identifier'],'local.aisora.companion.updater')
        self.assertFalse(report['gatekeeper_assessment_performed'])

    def test_nested_updater_corruption_rejected(self):
        self.files=fixture(updater=True)
        path='Aisora.app/Contents/Helpers/AisoraUpdater'
        value=bytearray(self.files[path]);value[1000]^=1;self.files[path]=bytes(value)
        self.reject('code page 0 digest mismatch')

    def test_missing_nested_updater_rejected(self):
        self.files=fixture(updater=True)
        del self.files['Aisora.app/Contents/Helpers/AisoraUpdater']
        self.write()
        with self.assertRaises((bundle.BundleError,KeyError)):
            bundle.verify_zip(self.archive)


if __name__ == '__main__':
    unittest.main()
