"""Generate offline initial-policy evaluation report without creating a database file."""
from pathlib import Path
from server.persona.service import PersonaService
from server.memory.store import Store
store=Store(':memory:')
v=PersonaService(store).current()
Path('docs/persona_eval_report.md').write_text(v['evaluation']['report_markdown']+'\n',encoding='utf-8')
store.db.close()
if not v['evaluation']['passed']: raise SystemExit(1)
print(v['version_id'], 'policy checks passed; model semantic eval unverified')
