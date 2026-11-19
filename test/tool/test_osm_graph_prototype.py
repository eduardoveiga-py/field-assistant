import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tool.map.build_osm_graph_prototype import MAX_INPUT_BYTES, build_file, build_graph


def xml(*elements):
    return ('<osm version="0.6">' + ''.join(elements) + '</osm>').encode()


def node(n, lat, lon, tags=''):
    return f'<node id="{n}" lat="{lat}" lon="{lon}">{tags}</node>'


def way(n, refs, tags):
    return f'<way id="{n}">' + ''.join(f'<nd ref="{x}"/>' for x in refs) + ''.join(f'<tag k="{k}" v="{v}"/>' for k, v in tags.items()) + '</way>'


def graph(data):
    return build_graph(data, source_sha256='a' * 64, source_info='synthetic', license_name='test', attribution='test')


class OsmGraphPrototypeTest(unittest.TestCase):
    def base(self, tags=None, *, lat=-3, lon=-67):
        return xml(node(1, lat, lon), node(2, lat, lon + .001), way(11, [1, 2], tags or {'highway': 'residential'}))

    def test_two_distant_regions_and_source_is_explicitly_research_only(self):
        for lat, lon in [(-3.1, -67.9), (-15.8, -47.9)]:
            output = graph(self.base(lat=lat, lon=lon))
            self.assertEqual(output['status'], 'experimental-not-for-navigation')
            self.assertFalse(output['coverageVerified'])
            self.assertFalse(output['restrictionsSupported'])
            self.assertEqual(len(output['nodes']), 2)
            self.assertEqual(len(output['edges']), 2)
            self.assertGreater(output['edges'][0]['distanceMeters'], 1)
            self.assertTrue(output['edges'][0]['pedestrian'])
            self.assertTrue(output['edges'][0]['vehicle'])

    def test_direction_restrictions_for_each_profile(self):
        forward, backward = graph(self.base({'highway': 'residential', 'oneway': 'yes'}))['edges']
        self.assertEqual((forward['from'], forward['to']), ('1', '2'))
        self.assertTrue(forward['vehicle'])
        self.assertTrue(backward['pedestrian'])
        self.assertFalse(backward['vehicle'])
        reverse = graph(self.base({'highway': 'residential', 'oneway': '-1', 'oneway:foot': '-1'}))['edges']
        self.assertEqual(len(reverse), 1)
        self.assertEqual((reverse[0]['from'], reverse[0]['to']), ('2', '1'))
        self.assertTrue(reverse[0]['vehicle'])
        self.assertTrue(reverse[0]['pedestrian'])
        car_override = graph(self.base({'highway': 'residential', 'oneway': 'yes', 'oneway:motorcar': 'no'}))['edges']
        self.assertTrue(all(edge['vehicle'] for edge in car_override))

    def test_access_specificity_and_implicit_roundabout(self):
        edges = graph(self.base({'highway': 'residential', 'access': 'no', 'foot': 'yes'}))['edges']
        self.assertEqual(len(edges), 2)
        self.assertTrue(all(e['pedestrian'] and not e['vehicle'] for e in edges))
        edges = graph(self.base({'highway': 'residential', 'junction': 'roundabout'}))['edges']
        self.assertTrue(edges[0]['vehicle'])
        self.assertFalse(edges[1]['vehicle'])
        edges = graph(self.base({'highway': 'motorway', 'oneway': 'no'}))['edges']
        self.assertTrue(all(e['vehicle'] and not e['pedestrian'] for e in edges))

    def test_no_false_intersection_without_shared_node(self):
        data = xml(node(1, 0, 0), node(2, 0, .001), node(3, 0, .001), node(4, .001, .001),
                   way(10, [1, 2], {'highway': 'residential'}), way(11, [3, 4], {'highway': 'footway'}))
        edges = graph(data)['edges']
        self.assertNotIn(('2', '3'), {(e['from'], e['to']) for e in edges})

    def test_rejects_unsupported_maneuver_condition_and_access(self):
        relation = '<relation id="1"><tag k="type" v="restriction"/><tag k="restriction" v="no_left_turn"/></relation>'
        data = self.base()[:-6] + relation.encode() + b'</osm>'
        with self.assertRaisesRegex(ValueError, 'manobra'):
            graph(data)
        for tags in (
            {'highway': 'residential', 'access:conditional': 'no @ (Mo-Fr)'},
            {'highway': 'residential', 'motor_vehicle:forward': 'no'},
            {'highway': 'residential', 'motorcar': 'sometimes'},
            {'highway': 'residential', 'oneway': 'reversible'},
            {'highway': 'residential', 'maxweight': '3'},
            {'highway': 'pedestrian', 'area': 'yes'},
            {'highway': 'unknown'},
        ):
            with self.subTest(tags=tags), self.assertRaises(ValueError):
                graph(self.base(tags))

    def test_rejects_barrier_ferry_missing_reference_and_duplicates(self):
        barrier = xml(node(1, 0, 0, '<tag k="barrier" v="gate"/>'), node(2, 0, 1), way(1, [1, 2], {'highway': 'residential'}))
        ferry = xml(node(1, 0, 0), node(2, 0, 1), way(1, [1, 2], {'route': 'ferry'}))
        missing = xml(node(1, 0, 0), way(1, [1, 2], {'highway': 'residential'}))
        duplicate = xml(node(1, 0, 0), node(1, 0, 1), way(1, [1, 2], {'highway': 'residential'}))
        for data in (barrier, ferry, missing, duplicate):
            with self.assertRaises(ValueError):
                graph(data)

    def test_rejects_bad_xml_invalid_coordinates_and_entity(self):
        for data in (b'<osm>', b'<osmChange version="0.6"/>', b'<!DOCTYPE osm [<!ENTITY x "ok">]><osm version="0.6"/>', self.base(lat=float('nan')), self.base(lat=91), '<osm version="0.6"/>'.encode('utf-16')):
            with self.subTest(data=data[:30]), self.assertRaises(ValueError):
                graph(data)
        with self.assertRaises(ValueError):
            graph(b'x' * (MAX_INPUT_BYTES + 1))

    def test_verified_input_gzip_exclusive_output_and_no_temporary_residue(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / 'region.osm.gz'
            source.write_bytes(gzip.compress(self.base()))
            digest = hashlib.sha256(source.read_bytes()).hexdigest()
            target = root / 'graph.json'
            options = dict(expected_sha256=digest, source_info='synthetic', license_name='test', attribution='test')
            result = build_file(source, target, **options)
            self.assertEqual(json.loads(target.read_text()), result)
            self.assertEqual(result['sourceSha256'], digest)
            original = target.read_bytes()
            with self.assertRaises(FileExistsError):
                build_file(source, target, **options)
            self.assertEqual(target.read_bytes(), original)
            self.assertFalse(list(root.glob('.osm-graph-*')))
            with self.assertRaises(ValueError):
                build_file(source, root / 'bad.json', **{**options, 'expected_sha256': '0' * 64})
            self.assertFalse((root / 'bad.json').exists())

    def test_rejects_gzip_bomb_and_corruption_without_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source, target = root / 'sample.gz', root / 'graph.json'
            for data in (gzip.compress(b'x' * (MAX_INPUT_BYTES + 1)), b'\x1f\x8bnot-a-gzip'):
                source.write_bytes(data)
                with self.assertRaises(ValueError):
                    build_file(source, target, expected_sha256=hashlib.sha256(data).hexdigest(),
                               source_info='test', license_name='test', attribution='test')
                self.assertFalse(target.exists())

    def test_cli_rejects_and_does_not_publish_mismatched_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / 'sample.osm'
            source.write_bytes(self.base())
            target = root / 'graph.json'
            cmd = [sys.executable, 'tool/map/build_osm_graph_prototype.py', '--source', str(source), '--source-sha256', '0'*64,
                   '--source-description', 'synthetic', '--license', 'test', '--attribution', 'test', '--output', str(target)]
            run = subprocess.run(cmd, capture_output=True, text=True, check=False)
            self.assertNotEqual(run.returncode, 0)
            self.assertFalse(target.exists())
            cmd[cmd.index('0'*64)] = hashlib.sha256(source.read_bytes()).hexdigest()
            run = subprocess.run(cmd, capture_output=True, text=True, check=False)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual(json.loads(target.read_text())['status'], 'experimental-not-for-navigation')


if __name__ == '__main__':
    unittest.main()
