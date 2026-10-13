"""Opt-in evolution rules: extraction proposes; human approval promotes."""
import re
from datetime import datetime, timedelta, timezone
from ..memory.policy import sensitive
from ..memory.store import utc_now
from ..source_search.connectors import KEYWORDS

DEFAULT_RULES = [
    {'rule_id':'persona_search','name':'搜寻人设资料','type':'source_search','enabled':False,
     'keywords':KEYWORDS,'exclude_keywords':[],'platforms':['xiaohongshu','bilibili','public_web'],
     'approval_required':True,'notice':'外部连接器尚未授权；运行只创建待处理任务，不自动抓取或改人设'},
    {'rule_id':'manual_add','name':'自行添加资料与偏好','type':'manual_import','enabled':True,
     'keywords':[],'exclude_keywords':[],'platforms':['manual'],'approval_required':True,
     'notice':'通过来源导入或显式偏好入口添加，正式人设仍需审核'},
    {'rule_id':'interaction_learning','name':'从相处中提出记忆候选','type':'interaction_learning','enabled':False,
     'keywords':[],'exclude_keywords':[],'platforms':[],'approval_required':True,
     'notice':'仅分析你同意保存且不敏感的对话；只生成候选，批准后才进入长期记忆'}]

class RuleService:
    def __init__(self,store): self.store=store
    def all(self):
        stored={r['rule_id']:r for r in self.store.all('evolution_rule')}
        return [dict(default,**{k:v for k,v in stored.get(default['rule_id'],{}).items()}) for default in DEFAULT_RULES]
    def get(self,rule_id):
        for row in self.all():
            if row['rule_id']==rule_id: return row
        raise ValueError('未知学习规则')
    def update(self,rule_id,body):
        current=self.get(rule_id)
        allowed={'enabled','keywords','exclude_keywords','platforms'}
        if set(body)-allowed: raise ValueError('不支持的规则字段；不能取消人工审核')
        if 'enabled' in body and not isinstance(body['enabled'],bool): raise ValueError('规则开关须为布尔值')
        for k in ['keywords','exclude_keywords','platforms']:
            if k in body and (not isinstance(body[k],list) or len(body[k])>20 or any(not isinstance(v,str) or len(v)>80 or sensitive(v) for v in body[k])):
                raise ValueError('规则列表格式或敏感信息不支持')
        if any(p not in {'xiaohongshu','bilibili','public_web','manual'} for p in body.get('platforms',[])): raise ValueError('未知来源平台')
        if rule_id=='interaction_learning' and body.get('enabled') and not self.store.setting('save_conversations',False):
            raise ValueError('先明确开启保存聊天；候选仅分析已同意保存的对话')
        changes=dict(body,approval_required=True)
        if current.get('id'): return self.store.update(current['id'],changes)
        return self.store.add('evolution_rule',dict(current,**changes))
    def run_search(self):
        rule=self.get('persona_search')
        if not rule['enabled']: raise ValueError('搜寻人设规则已关闭')
        return self.store.add('source_search_task',{'rule_id':'persona_search','keywords':rule['keywords'],
            'exclude_keywords':rule['exclude_keywords'],'platforms':rule['platforms'],'status':'awaiting_connector_authorization',
            'notice':'未执行外部搜索。可自行提供链接或必要授权摘录，进入人工审核。'})
    def extract(self,turn):
        if not self.get('interaction_learning')['enabled'] or not turn.get('consent'): return []
        text=turn['user_text']
        if sensitive(text) or any(w in text for w in ['不要记住','不要记录','别记住','别记录']): return []
        rule=self.get('interaction_learning')
        if any(w in text for w in rule['exclude_keywords']): return []
        expiry=(datetime.now(timezone.utc)+timedelta(days=30)).isoformat()
        proposals=[]
        patterns=[(r'我(?:很)?喜欢([^。！？\n]{1,100})','profile_memory'),
                  (r'我(?:正在|最近在)学习([^。！？\n]{1,100})','learning_memory'),
                  (r'我(?:习惯|通常)([^。！？\n]{1,100})','relationship_memory')]
        for pattern,kind in patterns:
            found=re.search(pattern,text)
            if not found: continue
            excerpt=found.group(0)
            if any(c.get('source_turn_id')==turn['id'] and c.get('memory_kind')==kind for c in self.store.all('memory_candidate')): continue
            proposals.append(self.store.add('memory_candidate',{'content':excerpt,'memory_kind':kind,'source_turn_id':turn['id'],
                'supporting_excerpt':excerpt[:120],'confidence':.6,'extracted_confidence':.6,
                'review_status':'pending_review','consent_to_extract':True,'consent_to_long_term':False,
                'scope':'personal_only','expires_at':expiry,'local_date':turn['local_date'],
                'reason':'关键词候选；可能误解，须由你确认，不能当作官方事实'}))
        # Repeated positive style feedback across days proposes a style; it never activates.
        for marker, trait in [('这样温柔的语气让我安心','更温柔的安慰表达'),('这样克制的语气让我舒服','保持克制的互动表达')]:
            if marker not in text: continue
            matching=[r for r in self.store.all('conversation_turn') if r.get('consent') and marker in r.get('user_text','') and not sensitive(r['user_text'])]
            if len(matching)<3 or len({r['local_date'] for r in matching})<2: continue
            if any(t.get('learning_rule_marker')==marker for t in self.store.all('trait')): continue
            proposals.append(self.store.add('trait',{'text':trait,'layer':'interaction_style','source_type':'interaction_candidate',
                'source_url':'','source_version':'','review_status':'pending_review','confidence':.7,'possible_conflicts':[],
                'paused':False,'trigger_turn_id':turn['id'],'supporting_turn_ids':[r['id'] for r in matching[-5:]],
                'learning_rule_marker':marker,'scope':'comfort_expression','expires_at':expiry,
                'reason':'跨日期反复出现的明确反馈；仍需批准，不能改变官方事实'}))
        return proposals
    def review_candidate(self,rid,action):
        row=self.store.get(rid)
        if row['kind']!='memory_candidate': raise ValueError('不是记忆候选')
        if action not in {'approve','reject','defer'}: raise ValueError('候选审核操作不支持')
        if row.get('review_status')=='approved': raise ValueError('候选已批准，不能重复写入记忆')
        if action=='approve':
            if row['expires_at']<=utc_now(): raise ValueError('候选已过期，请重新明确添加')
            if sensitive(row['content']): raise ValueError('敏感信息不从对话候选自动升级')
            payload={'content':row['content'],'confidence':1.0,'extracted_confidence':row['extracted_confidence'],
                'consent':True,'review_status':'approved','source':'user_confirmed_candidate',
                'source_turn_id':row['source_turn_id'],'source_candidate_id':rid,'local_date':row['local_date']}
            if row['memory_kind']=='learning_memory':
                from ..learning.service import learning_payload
                payload.update(learning_payload(row['content'],row['local_date']))
            memory=self.store.add(row['memory_kind'],payload)
            row=self.store.update(rid,{'review_status':'approved','consent_to_long_term':True,'memory_id':memory['id']})
            return {'candidate':row,'memory':memory}
        return {'candidate':self.store.update(rid,{'review_status':'rejected' if action=='reject' else 'deferred'})}
