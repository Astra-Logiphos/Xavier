"""Windows local backend supervisor; credentials and data stay on this computer."""
import argparse
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def prepare(data_dir):
    data_dir.mkdir(parents=True, exist_ok=True)
    token_path = data_dir / 'auth_token.txt'
    try:
        with token_path.open('x', encoding='utf-8') as out:
            out.write(secrets.token_urlsafe(32))
        if os.name != 'nt': token_path.chmod(0o600)
    except FileExistsError:
        pass
    token = token_path.read_text(encoding='utf-8').strip()
    if len(token) < 32:
        raise ValueError('auth_token.txt 无效，请从备份恢复或删除该文件后重新连接应用。')
    database = data_dir / 'xinghui.db'
    # Initialize only once. Never reset a user's later choice to stop saving.
    from server.memory.store import Store
    store = Store(str(database))
    if store.setting('save_conversations') is None:
        store.set_setting('save_conversations', True)
    store.db.close()
    return dict(os.environ, AUTH_TOKEN=token, DATABASE_PATH=str(database),
                HOST='127.0.0.1', PORT='8080', USER_TIMEZONE='Asia/Shanghai')


def startup_file():
    return Path(os.environ['APPDATA']) / 'Microsoft/Windows/Start Menu/Programs/Startup/XinghuiBackend.vbs'


def configure_startup(enable):
    if os.name != 'nt': raise ValueError('开机启动配置仅适用于 Windows。')
    path = startup_file()
    if not enable:
        path.unlink(missing_ok=True)
        return
    launcher = (ROOT.parent if ROOT.name == 'backend' else ROOT) / 'start_backend.bat'
    # Use the current user's login startup folder; no administrator rights required.
    command = 'cmd.exe /d /c ""' + str(launcher) + '" --background"'
    escaped = command.replace('"', '""')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('Set shell = CreateObject("WScript.Shell")\r\nshell.Run "' + escaped + '", 0, False\r\n', encoding='utf-16')


def acquire_lock(path):
    handle = path.open('a+b')
    handle.seek(0, os.SEEK_END)
    if handle.tell() == 0:
        handle.write(b'0')
        handle.flush()
    handle.seek(0)
    try:
        if os.name == 'nt':
            import msvcrt
            msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        handle.close()
        return None
    return handle


def healthy():
    try:
        # Loopback must not go through any configured external proxy.
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open('http://127.0.0.1:8080/health', timeout=2) as response:
            return json.load(response).get('ok') is True
    except (OSError, ValueError):
        return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--install-autostart', action='store_true')
    parser.add_argument('--remove-autostart', action='store_true')
    parser.add_argument('--background', action='store_true')
    args = parser.parse_args()
    if args.install_autostart or args.remove_autostart:
        configure_startup(args.install_autostart)
        print('已启用登录自启。' if args.install_autostart else '已取消登录自启。')
        return
    data_dir = Path(os.environ.get('LOCALAPPDATA', str(ROOT / 'runtime'))) / 'XinghuiCompanion/backend'
    env = prepare(data_dir)
    lock = acquire_lock(data_dir / 'supervisor.lock')
    if lock is None:
        print('本地后端监督程序已运行，请在应用设置中连接。')
        return
    if healthy():
        raise SystemExit('8080 端口已有服务；请先关闭已有后端，再运行本启动器。')
    print('本地后端地址：http://127.0.0.1:8080', flush=True)
    print('令牌文件：' + str(data_dir / 'auth_token.txt'), flush=True)
    print('聊天默认保存到本机；可在应用设置关闭保存。Ctrl+C 停止后端。', flush=True)
    child = None
    failures = 0
    log_path = data_dir / 'backend.log'
    try:
        while True:
            if log_path.exists() and log_path.stat().st_size > 2 * 1024 * 1024:
                log_path.replace(data_dir / 'backend.previous.log')
            with log_path.open('a', encoding='utf-8') as log:
                flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' and args.background else 0
                child = subprocess.Popen([sys.executable, '-X', 'utf8', '-m', 'server.api.app'], cwd=ROOT,
                                         env=env, stdout=log, stderr=log, creationflags=flags)
                ready = False
                for _ in range(30):
                    if child.poll() is not None: break
                    if healthy():
                        ready = True
                        print('本地后端已就绪。打开应用 → 设置 → 连接本地后端。', flush=True)
                        break
                    time.sleep(0.5)
                if not ready:
                    if child.poll() is None: child.terminate()
                    child.wait()
                    failures += 1
                    if failures >= 3:
                        raise SystemExit('连续三次启动失败。请查看 backend.log；检查 8080 端口和 Python 版本。')
                else:
                    failures = 0
                    child.wait()
            print('后端已退出，5 秒后自动重启。', flush=True)
            time.sleep(5)
    except KeyboardInterrupt:
        print('已停止本地后端。', flush=True)
    finally:
        if child is not None and child.poll() is None:
            child.terminate()
            child.wait()
        lock.close()


if __name__ == '__main__':
    sys.path.insert(0, str(ROOT))
    main()
