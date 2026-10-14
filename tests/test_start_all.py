import unittest
from scripts.start_all import wait_ready
class StartAllTests(unittest.TestCase):
    def test_waits_until_ready(self):
        times=[0];checks=[]
        def check():checks.append(times[0]);return times[0]>=.75
        wait_ready(check,clock=lambda:times[0],pause=lambda seconds:times.__setitem__(0,times[0]+seconds))
        self.assertEqual(checks,[0,.25,.5,.75])
    def test_timeout_does_not_launch(self):
        times=[0]
        with self.assertRaises(TimeoutError):wait_ready(lambda:False,timeout=1,clock=lambda:times[0],pause=lambda seconds:times.__setitem__(0,times[0]+seconds))
