import hashlib
import os
from pathlib import Path
from server.memory.store import Store
from server.persona.service import PersonaService
from server.persona.core import LEGACY_CORE

def restore_core(database):
    if not Path(database).is_file():return False
    store=Store(str(database))
    try:
        service=PersonaService(store,migrate=False)
        current=service.current()
        if current.get('core_version')!='xavier-card-v1.1':return False
        previous=store.setting('persona_core_previous')
        target=store.get(previous) if previous else None
        card=target.get('core_snapshot') if target else None
        if not card:
            card={'version':'legacy-before-m15-b3','approved':True,'core':LEGACY_CORE,'fewshot':'','display':{},'hash':hashlib.sha256(LEGACY_CORE.encode()).hexdigest()}
        service.publish('补丁回退：恢复前置人格核心，保留当前已审核表达与全部个人记录',creator='patch_revert',rollback_target=target['version_id'] if target else None,core_override=card)
        return True
    finally:store.db.close()

def main():
    root=Path(os.environ.get('LOCALAPPDATA',str(Path(__file__).resolve().parents[1]/'runtime')))
    database=Path(os.getenv('DATABASE_PATH',str(root/'XinghuiCompanion/backend/xinghui.db')))
    changed=restore_core(database)
    print('Persona core restored; personal records retained' if changed else 'No persona core change needed')

if __name__=='__main__':main()
