import tempfile
from pathlib import Path
import unittest
from server.api.app import Application
from server.config import Config
from server.health.estimation import DisabledFoodEstimator
import test_api

class NutritionTests(unittest.TestCase):
    setUp=test_api.ApiTests.setUp
    tearDown=test_api.ApiTests.tearDown
    call=test_api.ApiTests.call
    create=test_api.ApiTests.create
    def test_builtin_foods_and_serving_math(self):
        rows=self.call('GET','/foods?q=米饭')[1]['items']
        self.assertTrue(rows)
        food=next(row for row in rows if row['energyKCal'] is not None)
        first=self.create('/food-logs',{'food_id':food['id'],'amount':150,'unit':'g'})
        self.assertAlmostEqual(first['calories'],round(food['energyKCal']*1.5,2))
        second=self.create('/food-logs',{'food_id':food['id'],'amount':2,'unit':'份','grams_per_serving':80})
        self.assertEqual(second['grams'],160)
        summary=self.call('GET','/food-logs')[1]
        self.assertAlmostEqual(summary['calories'],round(first['calories']+second['calories'],2))
    def test_custom_food_and_delete(self):
        food=self.create('/foods',{'name':'个人测试食物','energyKCal':200})
        row=self.create('/food-logs',{'food_id':food['id'],'amount':50})
        self.assertEqual(row['calories'],100)
        self.assertEqual(self.call('DELETE','/food-logs/'+row['id'])[0],200)
        self.assertEqual(self.call('GET','/food-logs')[1]['calories'],0)
    def test_unknown_energy_and_invalid_amount_never_guessed(self):
        rows=self.call('GET','/foods')[1]['items']
        self.assertEqual(len(rows),1838)
        self.assertTrue(all(row['energyKCal'] is None or 0<=row['energyKCal']<=1000 for row in rows))
        self.assertEqual(len({row['id'] for row in rows}),len(rows))
        missing=next(row for row in rows if row['energyKCal'] is None)
        self.assertEqual(self.call('POST','/food-logs',{'food_id':missing['id'],'amount':100})[0],400)
        self.assertEqual(self.call('POST','/foods',{'name':'invalid','energyKCal':'nan'})[0],400)
        with self.assertRaises(NotImplementedError):DisabledFoodEstimator().estimate('一碗米饭')
