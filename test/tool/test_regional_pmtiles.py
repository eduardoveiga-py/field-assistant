import argparse
import struct
import tempfile
import unittest
from pathlib import Path

from tool.map.extract_regional_pmtiles import bbox_arg, inspect_header, sample_arg, tile_for


class RegionalPmtilesValidationTest(unittest.TestCase):
    def test_coordinate_validation_and_tiles(self):
        self.assertEqual(bbox_arg('-68.2,-3.4,-67.7,-3.0'), (-68.2, -3.4, -67.7, -3.0))
        for value in ('0,1,0,2', 'nan,0,1,2', '1,2,3', '1,-90,2,0'):
            with self.assertRaises(argparse.ArgumentTypeError):
                bbox_arg(value)
        self.assertEqual(tile_for(0, 0, 0), (0, 0, 0))
        self.assertEqual(sample_arg('1,-2'), (1, -2))

    def test_header_rejects_empty_synthetic_and_checks_bounds(self):
        bbox = (-68.2, -3.4, -67.7, -3.0)
        header = bytearray(127)
        header[:8] = b'PMTiles\x03'
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'sample.pmtiles'
            path.write_bytes(header)
            with self.assertRaises(ValueError):
                inspect_header(path, bbox, 0, 14)
            header[98], header[99], header[100], header[101] = 2, 1, 0, 14
            for offset in (16, 32, 64, 72, 80, 88):
                struct.pack_into('<Q', header, offset, 1)
            struct.pack_into('<iiii', header, 102, *(round(v * 1e7) for v in bbox))
            path.write_bytes(header)
            self.assertEqual(inspect_header(path, bbox, 0, 14)['tileCompression'], 2)
            with self.assertRaises(ValueError):
                inspect_header(path, (-70, -3.4, -67.7, -3), 0, 14)
            with self.assertRaises(ValueError):
                inspect_header(path, bbox, 0, 15)
