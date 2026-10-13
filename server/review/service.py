LAYERS = {'canon_persona','community_evidence','user_preference','interaction_style'}
ACTIONS = {'approve','reject','defer','conflict'}

def validate_approval(item, layer):
    if layer not in LAYERS: raise ValueError('未知人设层')
    if layer=='canon_persona' and (item.get('source_type')!='official' or not item.get('source_url') or not item.get('source_version')):
        raise ValueError('canon 必须人工标记官方，并提供来源及版本')
    if layer=='user_preference' and not item.get('explicit'):
        raise ValueError('必须由用户明确创建偏好，不能把社区内容冒充用户偏好')
    if layer=='community_evidence' and item.get('evidence_status') not in {'confirmed','plausible'}:
        raise ValueError('有争议或被拒证据不得升级为人设')
    if item.get('possible_conflicts'): raise ValueError('请先处理冲突后再批准')
