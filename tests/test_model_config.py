import os
import unittest
from unittest.mock import patch
from server.config import Config
from server.model_config import read_model_config, active_provider

class ModelConfigurationTests(unittest.TestCase):
    def env(self,**changes):
        values={'ACTIVE_PROVIDER':'zhipu','ZHIPU_BASE_URL':'https://fixture.invalid/v4','ZHIPU_MODEL':'glm-4-flash','ZHIPU_API_KEY':'fixture-secret'}
        values.update(changes);return patch.dict(os.environ,values,clear=True)
    def test_reads_environment_and_key_reference(self):
        with self.env():
            config=read_model_config();self.assertEqual(config.provider,'zhipu')
            self.assertEqual(config.endpoint,'https://fixture.invalid/v4/chat/completions')
            self.assertEqual(config.model,'glm-4-flash');self.assertEqual(config.key_reference,'ZHIPU_API_KEY')
            self.assertNotIn('fixture-secret',repr(config));self.assertEqual(Config.env().provider,'zhipu')
    def test_missing_key_model_or_base_fails(self):
        for variable in ['ZHIPU_API_KEY','ZHIPU_MODEL','ZHIPU_BASE_URL']:
            with self.subTest(variable=variable),self.env(**{variable:''}):
                with self.assertRaisesRegex(ValueError,'未配置'):read_model_config()
    def test_invalid_base_and_unknown_provider(self):
        for base in ['http://fixture.invalid','https://u:p@fixture.invalid','https://fixture.invalid?q=x','https://fixture.invalid/#x','https://fixture.invalid:bad']:
            with self.subTest(base=base),self.env(ZHIPU_BASE_URL=base):
                with self.assertRaisesRegex(ValueError,'地址无效'):read_model_config()
        with self.env(ACTIVE_PROVIDER='other'):
            with self.assertRaisesRegex(ValueError,'不支持'):read_model_config()
    def test_provider_isolation_and_safe_default(self):
        with self.env(DEEPSEEK_BASE_URL='https://second.invalid',DEEPSEEK_MODEL='second',DEEPSEEK_API_KEY='other'):
            self.assertEqual(read_model_config('deepseek').model,'second')
            self.assertEqual(read_model_config('zhipu').model,'glm-4-flash')
        with patch.dict(os.environ,{},clear=True):self.assertEqual(active_provider(),'mock')
