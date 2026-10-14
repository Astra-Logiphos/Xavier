import json
import os
import sys
import threading

ENV_LOCK = threading.RLock()
REFERENCES = {
    'zhipu': ('ZHIPU_BASE_URL','ZHIPU_MODEL','ZHIPU_API_KEY'),
    'siliconflow': ('SILICONFLOW_BASE_URL','SILICONFLOW_MODEL','SILICONFLOW_API_KEY'),
    'volcengine': ('VOLCENGINE_BASE_URL','VOLCENGINE_MODEL','VOLCENGINE_API_KEY'),
    'dashscope': ('DASHSCOPE_BASE_URL','DASHSCOPE_MODEL','DASHSCOPE_API_KEY'),
    'deepseek': ('DEEPSEEK_BASE_URL','DEEPSEEK_MODEL','DEEPSEEK_API_KEY'),
}
MARKER = 'XINGHUI_MODEL_ENV_NAMES'
ALLOWED = {'ACTIVE_PROVIDER','API_ENABLED','ALLOW_PAID_API','REQUIRE_API_CONFIRMATION'} | {name for refs in REFERENCES.values() for name in refs}
_loaded = False

def load_environment():
    global _loaded
    with ENV_LOCK:
        if _loaded or sys.platform != 'win32':
            return
        _loaded = True
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, 'Environment') as registry:
                names = json.loads(winreg.QueryValueEx(registry, MARKER)[0])
                if not isinstance(names,list):
                    return
                for name in names:
                    if name in ALLOWED:
                        try:
                            value, kind = winreg.QueryValueEx(registry,name)
                            if kind in (winreg.REG_SZ,winreg.REG_EXPAND_SZ):
                                os.environ[name] = value
                        except FileNotFoundError:
                            pass
        except (OSError,ValueError,TypeError):
            pass

def persist_environment(values):
    if set(values)-ALLOWED:
        raise ValueError('不支持的模型环境变量')
    if sys.platform != 'win32':
        raise ValueError('永久保存仅支持本地Windows后端；其他环境请配置服务端环境变量')
    import winreg
    with ENV_LOCK:
        with winreg.CreateKeyEx(winreg.HKEY_CURRENT_USER,'Environment',0,winreg.KEY_QUERY_VALUE|winreg.KEY_SET_VALUE) as registry:
            previous = {}
            for name in (*values, MARKER):
                try:
                    previous[name] = winreg.QueryValueEx(registry,name)
                except FileNotFoundError:
                    previous[name] = None
            try:
                names = json.loads(previous[MARKER][0]) if previous[MARKER] else []
                if not isinstance(names,list):
                    names = []
            except (ValueError,TypeError):
                names = []
            names = sorted((set(names)|set(values)) & ALLOWED)
            try:
                for name,value in {**values,MARKER:json.dumps(names)}.items():
                    winreg.SetValueEx(registry,name,0,winreg.REG_SZ,value)
            except OSError:
                for name,value in previous.items():
                    if value is None:
                        try:
                            winreg.DeleteValue(registry,name)
                        except FileNotFoundError:
                            pass
                    else:
                        winreg.SetValueEx(registry,name,0,value[1],value[0])
                raise ValueError('Windows环境变量保存失败；未启用新模型') from None
        os.environ.update(values)
    import ctypes
    result = ctypes.c_size_t()
    send = ctypes.windll.user32.SendMessageTimeoutW
    send.argtypes = [ctypes.c_void_p,ctypes.c_uint,ctypes.c_size_t,ctypes.c_void_p,ctypes.c_uint,ctypes.c_uint,ctypes.POINTER(ctypes.c_size_t)]
    send.restype = ctypes.c_ssize_t
    pointer = ctypes.cast(ctypes.c_wchar_p('Environment'),ctypes.c_void_p)
    send(65535,26,0,pointer,2,2000,ctypes.byref(result))
