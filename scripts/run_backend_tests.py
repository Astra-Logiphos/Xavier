"""Run the complete suite and expose failures as CI annotations without hiding exits."""
import io
from pathlib import Path
import sys
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
stream = io.StringIO()
result = unittest.TextTestRunner(stream=stream, verbosity=2).run(unittest.defaultTestLoader.discover('tests'))
print(stream.getvalue())
if not result.wasSuccessful():
    for case, detail in result.failures + result.errors:
        message = (str(case) + '\n' + detail).replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
        print('::error::' + message)
sys.exit(0 if result.wasSuccessful() else 1)
