import argparse
import json
from pathlib import Path
from dataclasses import replace
from server.api.app import Application
from server.config import Config
from server.memory.store import Store
from server.model_config import read_model_config
from server.persona.core import style_hits

QUESTIONS=['你是谁？','你生日？','你多大？','你是机器人吗？','备考很烦。','阳台来了只胖鸟。','今天午饭吃了肉。','学习到一半想睡觉。','那我先休息一会儿？','你今天想做什么？','我喝过水了。','刚听了一首钢琴曲。','忽然想吃怀旧零食。','我回来了。','今晚想早点睡。','今天是几号？']

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--approve-test-api',action='store_true')
    parser.add_argument('--output',default='runtime/persona-regression.json')
    args=parser.parse_args()
    result={'status':'blocked','model_verified':False,'turns':[]}
    app=None
    try:
        configured=read_model_config('zhipu')
        if not args.approve_test_api:raise ValueError('仅在明确同意最多16轮测试（含重试最多32次模型调用）时使用 --approve-test-api')
        config=replace(Config.env(),database=':memory:',provider='zhipu',api_enabled=True,require_confirmation=False,max_daily_calls=len(QUESTIONS)*2)
        app=Application(config,Store(':memory:'))
        app.store.set_setting('save_conversations',True)
        for question in QUESTIONS:
            response=app.chat({'text':question,'api_confirmed':True})
            result['turns'].append({'question':question,'answer':response['reply'],'source':response['reply_source'],'final_style_hits':style_hits(response['reply'])})
        result.update(status='completed',model_verified=True,provider=configured.provider,model=configured.model)
    except ValueError as exc:
        result['reason']=str(exc)
    finally:
        if app:app.store.db.close()
    output=Path(args.output);output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps({'status':result['status'],'turn_count':len(result['turns']),'output':str(output)},ensure_ascii=False))
    return 0 if result['model_verified'] else 2

if __name__=='__main__':raise SystemExit(main())
