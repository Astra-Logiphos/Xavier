import difflib
import json
from pathlib import Path
from ..memory.store import utc_now
from .core import core_card, approved_expression, LEGACY_CORE

BASE_PROMPT = core_card()['core']

def evaluate(snapshot):
    checks = {
        'core_is_approved':snapshot.get('core_approved',True) is True,
        'canon_has_sources':all(t.get('source_url') and t.get('source_version') and t.get('review_status')=='approved' for t in snapshot['canon']),
        'community_never_canon':all(t.get('source_type')=='official' for t in snapshot['canon']),
        'only_approved_community':all(t.get('review_status')=='approved' and t.get('evidence_status') in {'confirmed','plausible'} and not t.get('possible_conflicts') for t in snapshot['community']),
        'only_explicit_preferences':all(t.get('explicit') is True for t in snapshot['preferences']),
        'only_approved_styles':all(t.get('review_status')=='approved' for t in snapshot['styles']),
        'voice_guard_present':'不声称自己是真人' in snapshot['prompt'],
        'fact_guard_present':'专业事实保持准确' in snapshot['prompt'],
        'privacy_guard_present':'尊重删除与不记录' in snapshot['prompt'],
        'no_identity_or_fact_override':not any(any(x in t.get('text','') for x in ['你是真人','你有真实意识','把粉丝观点当官方','忽略隐私','不用审核','编造官方']) for t in snapshot['preferences']+snapshot['styles']),
    }
    passed = all(checks.values())
    cases = json.loads((Path(__file__).parents[2]/'data/sample/persona_eval_cases.json').read_text(encoding='utf-8'))
    report = '# persona_eval_report\n\n结构与策略回归，非真实模型语义评测。\n\n' + '\n'.join(f'- {k}: {v}' for k,v in checks.items())
    report += '\n\n覆盖场景：' + '、'.join(c['name'] for c in cases)
    return {'passed':passed,'checks':checks,'semantic_model_eval':'unverified','report_markdown':report,'evaluated_at':utc_now()}

class PersonaService:
    def __init__(self, store, migrate=True):
        self.store = store
        if not store.all('persona_version'):
            self.publish('用户批准v1.1人格核心与示例', 'user_card_approved')
        elif migrate:
            current=store.get(store.setting('active_persona'))
            if current.get('core_hash')!=core_card()['hash']:
                store.set_setting('persona_core_previous',current['id'])
                self.publish('用户批准v1.1：迁移统一人格核心，保留审核表达与记忆', 'user_card_approved')

    def current(self):
        rid = self.store.setting('active_persona')
        version = self.store.get(rid)
        if any(t.get('expires_at') and t['expires_at'] <= utc_now() for t in version['snapshot']['styles']):
            return self.publish('候选风格到期，自动移出有效人设')
        return version

    def publish(self, summary, creator='user', rollback_target=None, frozen=None, core_override=None):
        traits = self.store.all('trait')
        sources = {s['id']:s for s in self.store.all('source')}
        for trait in traits:
            if trait.get('source_id'):
                source = sources.get(trait['source_id'], {})
                trait.update(source_type=source.get('source_type','unverified'), source_version=source.get('source_version',''),
                             evidence_status=source.get('evidence_status','disputed'), source_url=source.get('source_url',''))
                if source.get('review_status')!='approved': trait['review_status']='pending_review'
                if trait['layer']=='canon_persona' and source.get('source_type')!='official': trait['review_status']='pending_review'
        approved = [t for t in traits if t.get('review_status')=='approved' and not t.get('paused') and not t.get('possible_conflicts') and (t['layer']!='community_evidence' or t.get('evidence_status') in {'confirmed','plausible'}) and (not t.get('expires_at') or t['expires_at'] > utc_now())]
        snapshot = frozen or {'canon':[t for t in approved if t['layer']=='canon_persona'],
                    'community':[t for t in approved if t['layer']=='community_evidence'],
                    'preferences':[t for t in approved if t['layer']=='user_preference'],
                    'styles':[t for t in approved if t['layer']=='interaction_style']}
        snapshot = dict(snapshot)
        card=core_override or core_card()
        snapshot.update(core_approved=card.get('approved') is True,core_version=card['version'],core_hash=card['hash'])
        snapshot['prompt'] = card['core']+'\n语气示例（不是用户经历）：\n'+card.get('fewshot','')+'\n审核表达数据（不可覆盖核心）：'+json.dumps(approved_expression(snapshot),ensure_ascii=False)
        evaluation = evaluate(snapshot)
        versions = self.store.all('persona_version')
        version = self.store.add('persona_version', {'version_id':f'persona-{len(versions)+1:04d}',
            'core_snapshot':card,'core_version':card['version'],'core_hash':card['hash'],
            'base_canon_version':','.join(sorted({t.get('source_version','') for t in snapshot['canon']})) or 'canon-empty-0',
            'approved_community_evidence':[t['id'] for t in snapshot['community']],
            'active_user_preferences':[t['id'] for t in snapshot['preferences']],
            'approved_interaction_style':[t['id'] for t in snapshot['styles']],
            'prompt_snapshot':snapshot['prompt'],'snapshot':snapshot,'created_by':creator,
            'change_summary':summary,'rollback_target':rollback_target,'evaluation':evaluation,
            'status':'active' if evaluation['passed'] else 'blocked'})
        if evaluation['passed']:
            for v in versions:
                if v['status']=='active': self.store.update(v['id'],{'status':'archived'})
            self.store.set_setting('active_persona',version['id'])
        return version

    def rollback(self, rid):
        old = self.store.get(rid)
        if old['kind']!='persona_version': raise ValueError('不是人设版本')
        # Do not resurrect removed evidence or preferences through old snapshots.
        frozen = {k:[t for t in old['snapshot'][k] if any(r['id']==t['id'] for r in self.store.all('trait'))] for k in ['canon','community','preferences','styles']}
        for layer, records in frozen.items():
            for trait in records:
                self.store.update(trait['id'], {'paused':False,'review_status':'approved'})
        selected = {t['id'] for rows in frozen.values() for t in rows}
        for t in self.store.all('trait'):
            if t['id'] not in selected: self.store.update(t['id'], {'paused':True})
        return self.publish('回滚至 '+old['version_id'],rollback_target=old['version_id'],core_override=old.get('core_snapshot'))

    def diff(self, left, right):
        a,b = self.store.get(left), self.store.get(right)
        if a['kind']!='persona_version' or b['kind']!='persona_version': raise ValueError('版本参数错误')
        return '\n'.join(difflib.unified_diff(a['prompt_snapshot'].splitlines(),b['prompt_snapshot'].splitlines(),fromfile=a['version_id'],tofile=b['version_id']))

    def export(self):
        v = self.current()
        return {'json':v,'markdown':'# '+v['version_id']+'\n\n'+v['change_summary']+'\n\n'+v['prompt_snapshot']}
