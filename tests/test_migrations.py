"""m15-b3a 后迁移基线：alembic 可用性、新库/旧库/内存库三条引导路径。"""
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from server.memory.store import Store
from server import migrations

HAS_ALEMBIC = migrations._alembic_available()


class FallbackBootstrapTests(unittest.TestCase):
    def test_memory_database_always_uses_sql_baseline(self):
        store = Store(':memory:')
        self.addCleanup(store.db.close)
        self.assertEqual(store.schema_mode, 'sql-baseline')
        store.add('profile_memory', {'content': 'x', 'consent': True})
        self.assertEqual(len(store.all('profile_memory')), 1)

    def test_file_database_without_alembic_falls_back_to_sql(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = str(Path(tmp) / 'fallback.db')
            with mock.patch.object(migrations, '_alembic_available',
                                   return_value=False):
                store = Store(path)
            try:
                self.assertEqual(store.schema_mode, 'sql-baseline')
                tables = {r[0] for r in store.db.execute(
                    "SELECT name FROM sqlite_master WHERE type='table'")}
                self.assertIn('records', tables)
                self.assertIn('schema_migrations', tables)
            finally:
                store.db.close()


@unittest.skipUnless(HAS_ALEMBIC, 'alembic 未安装（离线打包运行时走 SQL 兜底）')
class AlembicBootstrapTests(unittest.TestCase):
    def test_new_database_runs_versioned_baseline(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = str(Path(tmp) / 'fresh.db')
            store = Store(path)
            try:
                self.assertEqual(store.schema_mode, 'alembic-baseline')
                version = store.db.execute(
                    'SELECT version_num FROM alembic_version').fetchone()[0]
                self.assertEqual(version, migrations.BASELINE_REVISION)
                self.assertEqual(store.db.execute(
                    'SELECT MAX(version) FROM schema_migrations').fetchone()[0], 1)
                store.add('profile_memory', {'content': 'y', 'consent': True})
                self.assertEqual(len(store.all('profile_memory')), 1)
            finally:
                store.db.close()

    def test_existing_database_is_stamped_not_recreated(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = str(Path(tmp) / 'legacy.db')
            with mock.patch.object(migrations, '_alembic_available',
                                   return_value=False):
                legacy = Store(path)
            legacy.add('profile_memory', {'content': 'keep', 'consent': True})
            legacy.db.close()
            reopened = Store(path)
            try:
                self.assertEqual(reopened.schema_mode, 'stamped-existing')
                self.assertEqual(
                    reopened.all('profile_memory')[0]['content'], 'keep')
            finally:
                reopened.db.close()
            again = Store(path)
            try:
                self.assertEqual(again.schema_mode, 'already-managed')
            finally:
                again.db.close()


if __name__ == '__main__':
    unittest.main()
