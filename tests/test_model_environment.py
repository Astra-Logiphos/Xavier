import json
import os
import types
import unittest
from unittest.mock import patch, Mock
from server import model_environment as environment

class Registry:
    HKEY_CURRENT_USER=0
    KEY_QUERY_VALUE=1
    KEY_SET_VALUE=2
    REG_SZ=1
    REG_EXPAND_SZ=2
    def __init__(self,values=None,fail_at=None):
        self.values=dict(values or {});self.fail_at=fail_at;self.writes=0
    def __enter__(self):return self
    def __exit__(self,*args):pass
    def OpenKey(self,*args):return self
    def CreateKeyEx(self,*args):return self
    def QueryValueEx(self,handle,name):
        if name not in self.values:raise FileNotFoundError
        return self.values[name],1
    def SetValueEx(self,handle,name,reserved,kind,value):
        self.writes+=1
        if self.writes==self.fail_at:raise OSError('fixture failure')
        self.values[name]=value
    def DeleteValue(self,handle,name):
        if name not in self.values:raise FileNotFoundError
        del self.values[name]

class ModelEnvironmentTests(unittest.TestCase):
    def test_registry_persists_and_reload_overrides_stale_parent(self):
        registry=Registry()
        with patch.dict('sys.modules',{'winreg':registry}),patch('server.model_environment.sys.platform','win32'),patch('ctypes.windll',Mock(),create=True),patch.dict(os.environ,{},clear=True):
            environment.persist_environment({'ACTIVE_PROVIDER':'zhipu','ZHIPU_API_KEY':'fixture-only'})
            self.assertEqual(registry.values['ZHIPU_API_KEY'],'fixture-only')
            os.environ['ACTIVE_PROVIDER']='mock';os.environ.pop('ZHIPU_API_KEY')
            with patch.object(environment,'_loaded',False):environment.load_environment()
            self.assertEqual(os.environ['ACTIVE_PROVIDER'],'zhipu')
            self.assertEqual(os.environ['ZHIPU_API_KEY'],'fixture-only')
    def test_partial_registry_failure_restores_previous_and_process(self):
        registry=Registry({'ACTIVE_PROVIDER':'mock'},fail_at=2)
        with patch.dict('sys.modules',{'winreg':registry}),patch('server.model_environment.sys.platform','win32'),patch.dict(os.environ,{'ACTIVE_PROVIDER':'mock'},clear=True):
            with self.assertRaisesRegex(ValueError,'保存失败'):
                environment.persist_environment({'ACTIVE_PROVIDER':'zhipu','ZHIPU_API_KEY':'fixture-only'})
            self.assertEqual(registry.values,{'ACTIVE_PROVIDER':'mock'})
            self.assertNotIn('ZHIPU_API_KEY',os.environ)
    def test_hydration_ignores_unmanaged_names(self):
        registry=Registry({environment.MARKER:json.dumps(['ACTIVE_PROVIDER','PATH']),'ACTIVE_PROVIDER':'zhipu','PATH':'untrusted'})
        with patch.dict('sys.modules',{'winreg':registry}),patch('server.model_environment.sys.platform','win32'),patch.object(environment,'_loaded',False),patch.dict(os.environ,{'PATH':'original'},clear=True):
            environment.load_environment()
            self.assertEqual(os.environ['PATH'],'original')
