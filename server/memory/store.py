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
        self.db.executescript((Path(__file__).parents[1] / 'migrations/001_initial.sql').read_text())
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
