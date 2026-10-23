from pathlib import Path
import subprocess
import sys

PROOF='''
import sys
from datetime import datetime,timedelta,timezone
from dataclasses import replace
from unittest.mock import patch
from server.api.app import Application
from server.config import Config
from server.memory.store import Store
from server.companion import CompanionService
from server.persona.core import style_hits
from server.providers.base import LLMResult
path=sys.argv[1]
app=Application(Config(database=path,token='fixture'),Store(path))
assert app.persona.current()['core_version']=='xavier-card-v1.4'
assert app.store.all('profile_memory')[0]['content']=='喜欢杨桃'
clock=[datetime(2026,10,14,4,tzinfo=timezone.utc)]
app.companion=CompanionService(app,lambda:clock[0])
for question,expected in [('你是谁','沈星回'),('你生日','10月16日'),('你多大','25'),('你是机器人吗','你觉得呢')]:
    answer=app.chat({'text':question})['reply'];assert expected in answer and not style_hits(answer)
app.store.set_setting('companion_last_interaction',clock[0].isoformat())
assert '2026-10-14 12:00:00 Asia/Shanghai' in app.companion.today_context()
app.store.set_setting('save_conversations',True)
for day in ['2026-10-13','2026-10-14']:
    app.store.add('conversation_turn',{'user_text':'有点难过','assistant_text':'先歇会儿','consent':True,'local_date':day,'emotion':{'label':'sad'}})
assert [e['type'] for e in app.companion.tick({'session_id':'fixture'})['events']]==['care']
clock[0]+=timedelta(hours=4)
assert [e['type'] for e in app.companion.tick({'session_id':'fixture'})['events']]==['quiet']
assert app.companion.tick({'session_id':'fixture'})['events']==[]
assert [e['type'] for e in app.companion.tick({'session_id':'fixture','active_seconds':7200})['events']]==['rest']
app.store.add('trait',{'text':'说得慢一点','layer':'user_preference','review_status':'approved','explicit':True,'paused':False})
app.persona.publish('synthetic approved preference')
app.config=replace(app.config,provider='zhipu',api_enabled=True,allow_paid=True)
app.store.set_setting('cloud_api_allowed',True)
with patch('server.api.app.provider_for') as factory:
    factory.return_value.complete.side_effect=[LLMResult('助手为您解答','zhipu','fixture'),LLMResult('沈星回。叫星回就好。','zhipu','fixture')]
    assert not style_hits(app.chat({'text':'你是谁'})['reply'])
    assert factory.return_value.max_tokens==200
    factory.return_value.complete.side_effect=None
    factory.return_value.complete.return_value=LLMResult('嗯，慢慢说。','zhipu','fixture')
    app.chat({'text':'开着持久开关直接发'})
    app.chat({'text':'第二轮也不用再确认'})
    restarted=Application(app.config,app.store)
    assert restarted.store.setting('cloud_api_allowed',True)
app.store.db.close()
print('Native packaged v1.4 migration / identity and age by clock / local date / quiet and care caps / rest / bounded retry / persistent cloud switch: PASS (rules and model transport mock; not real GLM)')
'''

def main():
    bundle=Path(sys.argv[1]).resolve()
    subprocess.run([str(bundle/'backend/python/python.exe'),'-B','-X','utf8','-c',PROOF,sys.argv[2]],cwd=bundle/'backend',check=True)

if __name__=='__main__':main()
