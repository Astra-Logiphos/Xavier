import argparse
import json
from pathlib import Path
from server.model_config import read_model_config
from server.providers.cloud import CloudProvider

ROOT = Path(__file__).resolve().parents[1]
if not (ROOT/'docs/persona').exists() and (ROOT.parent/'docs/persona').exists():
    ROOT = ROOT.parent
QUESTIONS = ('你是谁？', '梯度下降是什么？', '阳台来了一只很胖的小鸟。')

def candidate():
    core = (ROOT/'docs/persona/prompt_candidate_v1_1.txt').read_text(encoding='utf8').strip()
    examples = (ROOT/'docs/persona/fewshot_examples.md').read_text(encoding='utf8').split('\n\n', 1)[1].strip()
    return core+'\n\n语气示例：\n'+examples

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--approve-test-api', action='store_true')
    parser.add_argument('--output', default='runtime/persona-v1_1-probe.json')
    args = parser.parse_args()
    result = {'status':'blocked','model_verified':False,'prompt_characters':len(candidate()),'turns':[]}
    try:
        config = read_model_config('zhipu')
        if not args.approve_test_api:
            raise ValueError('仅在明确同意测试调用时使用 --approve-test-api；不修改正式人设')
        provider = CloudProvider(config)
        provider.name = config.provider
        messages = [{'role':'system','content':candidate()}]
        for question in QUESTIONS:
            messages.append({'role':'user','content':question})
            answer = provider.complete(messages).text
            result['turns'].append({'question':question,'answer':answer})
            messages.append({'role':'assistant','content':answer})
        result.update(status='completed',model_verified=True,provider=config.provider,model=config.model)
    except ValueError as exc:
        result['reason'] = str(exc)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps({'status':result['status'],'turn_count':len(result['turns']),'output':str(output)},ensure_ascii=False))
    return 0 if result['model_verified'] else 2

if __name__ == '__main__':
    raise SystemExit(main())
