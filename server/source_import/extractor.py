import re
from ..memory.policy import sensitive

def extract_claims(text, url, platform):
    # Conservative lexical candidates, never asserts that classifier output is truth.
    result = []
    for sentence in re.split(r'[。！？\n]', text)[:20]:
        sentence = sentence.strip()
        if not sentence or sensitive(sentence): continue
        kind = 'speculation' if any(w in sentence for w in ['可能','猜测','或许']) else 'opinion' if any(w in sentence for w in ['我觉得','我喜欢']) else 'interpretation' if any(w in sentence for w in ['解读','说明','意味着']) else 'fact'
        result.append({'claim':sentence[:180], 'claim_type':kind,
                       'mentioned_trait':next((w for w in ['温柔','主动','克制','保护欲','口是心非'] if w in sentence),'未分类'),
                       'supporting_excerpt':sentence[:120], 'source_url':url,'source_platform':platform,
                       'confidence':.45,'possible_conflicts':[],'review_status':'pending_review'})
    return result
