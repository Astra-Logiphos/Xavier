"""Local persona data and a renderer reserved for a later model integration."""
import json
from pathlib import Path
from ..memory.policy import retrievable

ROOT = Path(__file__).resolve().parents[2]


def load_persona():
    path = ROOT / 'assets/persona/xavier_persona.yaml'
    if not path.exists(): path = ROOT / 'client/flutter_app/assets/persona/xavier_persona.yaml'
    return json.loads(path.read_text(encoding='utf-8'))


def render_prompt(memories, mode='chat'):
    template = (Path(__file__).parent / 'xavier_system_prompt.md').read_text(encoding='utf-8')
    approved = [row for row in memories if retrievable(row)]
    return template.replace('{{persona_yaml}}', json.dumps(load_persona(), ensure_ascii=False)).replace(
        '{{approved_memories_json}}', json.dumps(approved, ensure_ascii=False)).replace('{{conversation_mode}}', mode)
