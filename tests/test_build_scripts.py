import unittest
from scripts.bootstrap_flutter import flutter_command
class BuildScriptTests(unittest.TestCase):
    def test_windows_uses_explicit_batch_launcher(self):
        command=flutter_command('C:\\sdk\\bin\\flutter.bat',windows=True)
        self.assertEqual(command[-1],'C:\\sdk\\bin\\flutter.bat')
        self.assertEqual(command[1:3],['/d','/c'])
    def test_posix_invokes_resolved_executable(self):
        self.assertEqual(flutter_command('/opt/flutter/bin/flutter',windows=False),['/opt/flutter/bin/flutter'])
