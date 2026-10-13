import json
import sqlite3
import threading
from pathlib import Path
from datetime import datetime, timezone
from uuid import uuid4

def utc_now():
    return datetime.now(timezone.utc).isoformat()

class Store:
    def __init__(self, path):
        if path != ':memory:':
            Path(path).parent.mkdir(parents=True, exist_ok=True)
        self.lock = threading.RLock()
        self.db = sqlite3.connect(path, check_same_thread=False)
        self.db.row_factory = sqlite3.Row
        self.db.executescript((Path(__file__).parents[1] / 'migrations/001_initial.sql').read_text(encoding='utf-8'))
        self.db.execute('PRAGMA secure_delete=ON')

    def add(self, kind, payload):
        with self.lock:
            now = utc_now()
            row = dict(payload, id=uuid4().hex, kind=kind, created_at=now, updated_at=now)
            self.db.execute('INSERT INTO records VALUES(?,?,?,?,?)',
                            (row['id'], kind, json.dumps(row, ensure_ascii=False), now, now))
            self.db.commit()
            return row

    def all(self, kind=None):
        with self.lock:
            rows = self.db.execute('SELECT payload FROM records WHERE kind=? ORDER BY created_at', (kind,)) if kind else self.db.execute('SELECT payload FROM records ORDER BY created_at')
            return [json.loads(r[0]) for r in rows.fetchall()]

    def get(self, rid):
        with self.lock:
            row = self.db.execute('SELECT payload FROM records WHERE id=?', (rid,)).fetchone()
            if row is None: raise ValueError('记录不存在')
            return json.loads(row[0])

    def update(self, rid, changes):
        with self.lock:
            row = self.get(rid)
            row.update(changes)
            row['id'] = rid
            row['updated_at'] = utc_now()
            self.db.execute('UPDATE records SET payload=?,updated_at=? WHERE id=?',
                            (json.dumps(row, ensure_ascii=False), row['updated_at'], rid))
            self.db.commit()
            return row

    def delete(self, rid):
        with self.lock:
            self.get(rid)
            self.db.execute('DELETE FROM records WHERE id=?', (rid,))
            self.db.commit()

    def setting(self, key, default=None):
        with self.lock:
            row = self.db.execute('SELECT value FROM settings WHERE key=?', (key,)).fetchone()
            return json.loads(row[0]) if row else default

    def set_setting(self, key, value):
        with self.lock:
            self.db.execute('INSERT OR REPLACE INTO settings VALUES(?,?)', (key, json.dumps(value)))
            self.db.commit()

    def reserve_call(self, day, limit):
        with self.lock:
            self.db.execute('INSERT OR IGNORE INTO model_usage VALUES(?,0)', (day,))
            used = self.db.execute('SELECT calls FROM model_usage WHERE day=?', (day,)).fetchone()[0]
            if used >= limit: raise ValueError('今日模型调用次数已到上限')
            self.db.execute('UPDATE model_usage SET calls=calls+1 WHERE day=?', (day,))
            self.db.commit()

    def erase_personal(self):
        with self.lock:
            # Persona snapshots can contain personal preferences: remove them too.
            self.db.execute('DELETE FROM records')
            self.db.execute('DELETE FROM settings')
            self.db.execute('DELETE FROM model_usage')
            self.db.commit()
            self.db.execute('VACUUM')

    def export_personal(self):
        with self.lock:
            return {'format':'xinghui-backend-1','exported_at':utc_now(),'records':self.all(),
                    'settings':{r[0]:json.loads(r[1]) for r in self.db.execute('SELECT key,value FROM settings')},
                    'model_usage':[dict(r) for r in self.db.execute('SELECT day,calls FROM model_usage')]}

    def restore_personal(self, data):
        if data.get('format')!='xinghui-backend-1':raise ValueError('备份版本无效')
        records=data.get('records');settings=data.get('settings');usage=data.get('model_usage',[])
        if not isinstance(records,list) or not isinstance(settings,dict) or not isinstance(usage,list):raise ValueError('备份格式无效')
        ids=set(); prepared=[]
        for row in records:
            if not isinstance(row,dict):raise ValueError('备份记录无效')
            if any(not isinstance(row.get(k),str) or not row[k] for k in ['id','kind','created_at','updated_at']):raise ValueError('备份记录字段无效')
            if row['id'] in ids:raise ValueError('备份包含重复 ID')
            ids.add(row['id']);prepared.append((row['id'],row['kind'],json.dumps(row,ensure_ascii=False,allow_nan=False),row['created_at'],row['updated_at']))
        active=settings.get('active_persona')
        if records and (active not in ids or not any(r['id']==active and r['kind']=='persona_version' for r in records)):raise ValueError('备份缺少有效人设引用')
        if records:
            from ..persona.service import evaluate
            version=next(r for r in records if r['id']==active)
            try:passed=version.get('status')=='active' and evaluate(version['snapshot'])['passed']
            except (KeyError,TypeError,AttributeError):raise ValueError('备份人设格式无效') from None
            if not passed:raise ValueError('备份人设未通过门禁')
        setting_rows=[]
        for key,value in settings.items():
            if not isinstance(key,str) or not key or any(x in key.lower() for x in ('token','secret','api_key','password')):raise ValueError('备份设置键无效或包含凭据')
            setting_rows.append((key,json.dumps(value,ensure_ascii=False,allow_nan=False)))
        usage_rows=[]
        for row in usage:
            if not isinstance(row,dict) or not isinstance(row.get('day'),str) or type(row.get('calls')) is not int or row['calls']<0:raise ValueError('使用记录无效')
            usage_rows.append((row['day'],row['calls']))
        with self.lock:
            # Transaction restores IDs and relationships together; failures leave
            # the current database intact. No unsafe pickle or executable import.
            with self.db:
                self.db.execute('DELETE FROM records');self.db.execute('DELETE FROM settings');self.db.execute('DELETE FROM model_usage')
                self.db.executemany('INSERT INTO records VALUES(?,?,?,?,?)',prepared)
                self.db.executemany('INSERT INTO settings VALUES(?,?)',setting_rows)
                self.db.executemany('INSERT INTO model_usage VALUES(?,?)',usage_rows)
        return {'restored_records':len(prepared),'restored_settings':len(setting_rows)}
