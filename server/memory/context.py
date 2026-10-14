"""Only persisted, consented conversation turns enter model history."""
import json
from pathlib import Path

CONFIG_PATH = Path(__file__).resolve().parents[2] / 'config/chat.json'

def history_settings():
    data = json.loads(CONFIG_PATH.read_text(encoding='utf-8'))
    values = (data['history_rounds'], data['history_character_budget'])
    if any(type(value) is not int or value < 0 for value in values):
        raise ValueError('聊天历史轮数和字符预算必须是非负整数')
    return values

def conversation_history(store, rounds, budget):
    if not rounds or not budget:
        return []
    rows = [row for row in store.all('conversation_turn') if row.get('consent') is True
            and isinstance(row.get('user_text'), str) and isinstance(row.get('assistant_text'), str)]
    rows = rows[-rounds:]
    total = sum(len(row['user_text']) + len(row['assistant_text']) for row in rows)
    while rows and total > budget:
        old = rows.pop(0)
        total -= len(old['user_text']) + len(old['assistant_text'])
    return [message for row in rows for message in (
        {'role': 'user', 'content': row['user_text']},
        {'role': 'assistant', 'content': row['assistant_text']})]
