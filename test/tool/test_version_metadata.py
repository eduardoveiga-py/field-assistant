import copy
import unittest

from tool.verify_version_metadata import validate

PUBSPEC = 'version: 2.0.0+14\n'
APP = "static const String version = '2.0.0';\nstatic const int buildNumber = 14;"
URL = 'https://example.com/releases/download/v1.3.5/app.ipa'
ICON = 'https://cdn.example.com/repo@v1.3.5/icon.png'
CATALOG = {'iconURL': ICON, 'headerURL': ICON, 'sourceURL': 'https://example.com/releases/latest/download/apps.json', 'apps': [{'version': '1.3.5', 'size': 123, 'downloadURL': URL, 'iconURL': ICON, 'versions': [{'version': '1.3.5', 'size': 123, 'downloadURL': URL}]}]}


class VersionMetadataTest(unittest.TestCase):
    def test_development_build_can_reference_earlier_catalog(self):
        self.assertIn('2.0.0+14', validate(PUBSPEC, APP, CATALOG, 'refs/heads/arena/example'))

    def test_release_tag_requires_matching_manifest(self):
        with self.assertRaises(ValueError):
            validate(PUBSPEC, APP, CATALOG, 'refs/tags/v2.0.0')

    def test_rejects_unknown_size_and_future_version(self):
        catalog = copy.deepcopy(CATALOG)
        catalog['apps'][0]['size'] = 0
        with self.assertRaises(ValueError):
            validate(PUBSPEC, APP, catalog, '')
        catalog = copy.deepcopy(CATALOG)
        catalog['apps'][0]['version'] = '2.1.0'
        with self.assertRaises(ValueError):
            validate(PUBSPEC, APP, catalog, '')

    def test_rejects_mismatched_version(self):
        with self.assertRaises(ValueError):
            validate(PUBSPEC, APP.replace('14;', '13;'), CATALOG, '')
