import io
import json
import os
from pathlib import Path
import tempfile
import subprocess
import sys
import unittest
from unittest.mock import patch
from server.api.app import Application
from server.config import Config
from scripts.local_backend import prepare, acquire_lock, configure_startup
from scripts import local_backend


def request(app, method, path, body=None, token='test-token'):
    raw = json.dumps(body or {}).encode()
    status = []
    result = b''.join(app({'REQUEST_METHOD': method, 'PATH_INFO': path,
                          'CONTENT_LENGTH': str(len(raw)), 'wsgi.input': io.BytesIO(raw),
                          'HTTP_AUTHORIZATION': 'Bearer ' + token},
                         lambda value, headers: status.append(int(value.split()[0]))))
    return status[0], json.loads(result)


class LocalBackendTests(unittest.TestCase):
    def test_supervisor_children_do_not_write_into_distribution(self):
        # Execute the supervisor's real child command against a disposable API.
        # A short-lived child also exercises all three startup retries.
        with tempfile.TemporaryDirectory() as root:
            project = Path(root) / 'backend'
            api = project / 'server/api'
            api.mkdir(parents=True)
            (project / 'server/__init__.py').write_text('')
            (api / '__init__.py').write_text('')
            (api / 'app.py').write_text('print("启动探针", flush=True)\n', encoding='utf-8')
            real_popen = subprocess.Popen

            def completed_child(*args, **kwargs):
                child = real_popen(*args, **kwargs)
                child.wait(timeout=10)
                return child

            with patch.object(local_backend, 'ROOT', project), \
                    patch.dict(os.environ, {'LOCALAPPDATA': root}), \
                    patch.object(sys, 'argv', ['local_backend.py', '--background']), \
                    patch.object(local_backend, 'healthy', return_value=False), \
                    patch.object(local_backend.time, 'sleep'), \
                    patch.object(local_backend.subprocess, 'Popen', side_effect=completed_child), \
                    patch('sys.stdout', new=io.StringIO()):
                with self.assertRaises(SystemExit):
                    local_backend.main()
            self.assertFalse(list(project.rglob('__pycache__')))
            log = Path(root) / 'XinghuiCompanion/backend/backend.log'
            self.assertEqual(log.read_text(encoding='utf-8').count('启动探针'), 3)

    def test_token_reuse_default_save_and_preserve_opt_out(self):
        with tempfile.TemporaryDirectory() as root:
            env = prepare(Path(root))
            self.assertGreaterEqual(len(env['AUTH_TOKEN']), 32)
            app = Application(Config(database=env['DATABASE_PATH'], token='test-token'))
            self.assertTrue(request(app, 'POST', '/chat', {'text': '你好'})[1]['saved'])
            request(app, 'PATCH', '/settings', {'save_conversations': False})
            app.store.db.close()
            second = prepare(Path(root))
            self.assertEqual(env['AUTH_TOKEN'], second['AUTH_TOKEN'])
            app = Application(Config(database=second['DATABASE_PATH'], token='test-token'))
            self.assertFalse(request(app, 'GET', '/settings')[1]['save_conversations'])
            app.store.db.close()

    def test_chat_and_memory_crud_survive_backend_restart(self):
        with tempfile.TemporaryDirectory() as root:
            env = prepare(Path(root))
            cfg = Config(database=env['DATABASE_PATH'], token='test-token')
            app = Application(cfg)
            request(app, 'POST', '/chat', {'text': '记住这件事：我喜欢星空'})
            memories = request(app, 'GET', '/memories')[1]['items']
            rid = memories[0]['id']
            request(app, 'PATCH', '/memories/' + rid,
                    {'content': '我喜欢星空和小鸟', 'consent': True})
            request(app, 'POST', '/chat', {'text': '私下的话', 'no_save': True})
            app.store.db.close()
            app = Application(cfg)
            turns = request(app, 'GET', '/conversations')[1]['items']
            self.assertEqual(len(turns), 1)
            self.assertEqual(turns[0]['user_text'], '记住这件事：我喜欢星空')
            self.assertEqual(request(app, 'GET', '/conversations', token='wrong')[0], 401)
            self.assertEqual(request(app, 'GET', '/memories')[1]['items'][0]['content'], '我喜欢星空和小鸟')
            self.assertEqual(request(app, 'DELETE', '/memories/' + rid)[0], 200)
            app.store.db.close()
            app = Application(cfg)
            self.assertEqual(request(app, 'GET', '/memories')[1]['items'], [])
            app.store.db.close()

    def test_duplicate_supervisor_lock(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / 'lock'
            first = acquire_lock(path)
            self.assertIsNotNone(first)
            self.assertIsNone(acquire_lock(path))
            first.close()
            second = acquire_lock(path)
            self.assertIsNotNone(second)
            second.close()

    def test_bad_token_fails_without_replacing_it(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / 'auth_token.txt'
            path.write_text('broken')
            with self.assertRaises(ValueError): prepare(Path(root))
            self.assertEqual(path.read_text(), 'broken')

    @unittest.skipUnless(os.name == 'nt', 'Windows login startup folder integration')
    def test_startup_registration_can_be_removed(self):
        with tempfile.TemporaryDirectory() as root, patch.dict(os.environ, {'APPDATA': root}):
            configure_startup(True)
            files = list(Path(root).rglob('*.vbs'))
            self.assertEqual(len(files), 1)
            self.assertIn('--background', files[0].read_text(encoding='utf-16'))
            configure_startup(False)
            self.assertFalse(files[0].exists())
