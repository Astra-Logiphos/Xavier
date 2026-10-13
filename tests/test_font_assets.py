import hashlib
import json
from pathlib import Path
import unittest

class FontAssetTests(unittest.TestCase):
    def test_bundled_fonts_and_licenses_match_manifest(self):
        root=Path('client/flutter_app/assets/fonts')
        entries=json.loads((root/'sources.json').read_text(encoding='utf-8'))
        self.assertEqual(len(entries),3)
        for item in entries:
            blob=(root/(item['family']+'-Regular.ttf')).read_bytes()
            self.assertEqual(hashlib.sha256(blob).hexdigest(),item['sha256'])
            self.assertEqual(len(blob),item['bytes'])
            self.assertIn('SIL OPEN FONT LICENSE',(root/(item['family']+'-OFL.txt')).read_text(encoding='utf-8'))
