"""Generate SDK-owned runners and apply tracked security/signing configuration.
Run inside a cloud workspace or GitHub hosted runner, never requires user PC.
"""
from pathlib import Path
import subprocess
import shutil
import os
import re

ROOT=Path(__file__).resolve().parents[1]
APP=ROOT/'client/flutter_app'
def flutter_command(executable, windows=None):
    windows = os.name == "nt" if windows is None else windows
    return [os.environ.get("COMSPEC", "cmd.exe"), "/d", "/c", executable] if windows else [executable]

def bootstrap():
    flutter_executable=shutil.which('flutter')
    if flutter_executable is None: raise SystemExit('Flutter SDK 不存在；请在 GitHub Actions 运行构建')
    # Generate into a disposable staging folder so tracked app files are never overwritten.
    staging=ROOT/'runtime/flutter_runner'
    staging.parent.mkdir(parents=True,exist_ok=True)
    subprocess.run(flutter_command(flutter_executable)+['create','--platforms=android,windows','--project-name','xinghui_companion','--org','dev.xinghui',str(staging)],check=True)
    for platform in ['android','windows']:
        target=APP/platform
        if not target.exists(): shutil.copytree(staging/platform,target)
    manifest=APP/'android/app/src/main/AndroidManifest.xml'
    text=manifest.read_text(encoding='utf-8')
    if 'android.permission.INTERNET' not in text:
        text=text.replace('<application','<uses-permission android:name="android.permission.INTERNET"/>\n    <application',1)
    text=text.replace('android:label="xinghui_companion"','android:label="星回" android:usesCleartextTraffic="false"')
    manifest.write_text(text,encoding='utf-8')
    gradle=APP/'android/app/build.gradle.kts'
    if not gradle.exists(): raise SystemExit('SDK runner Gradle 格式改变；需要人工检查，不继续假签名')
    code=gradle.read_text(encoding='utf-8')
    marker='// Xinghui release signing'
    if marker not in code:
        signing='''
    // Xinghui release signing: never include a key in source control.
    signingConfigs {
        create("xinghuiRelease") {
            storeFile = file(System.getenv("ANDROID_KEYSTORE_PATH") ?: "missing-release-keystore.jks")
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("ANDROID_KEY_ALIAS")
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
        }
    }
'''
        if 'buildTypes {' not in code: raise SystemExit('找不到 buildTypes，停止构建')
        code=code.replace('buildTypes {',signing+'\n    buildTypes {\n        getByName("debug") { applicationIdSuffix = ".preview" }',1)
        old='signingConfig = signingConfigs.getByName("debug")'
        if old not in code: raise SystemExit('SDK 默认签名模板改变；停止构建，请审核')
        code=code.replace(old,'signingConfig = signingConfigs.getByName("xinghuiRelease")')
        gradle.write_text(code,encoding='utf-8')
    shutil.rmtree(staging)
if __name__=='__main__': bootstrap()
