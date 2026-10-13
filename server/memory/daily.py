"""Conservative daily extraction with evidence IDs, never claims semantic certainty."""
import re

def summarize_turns(turns):
    fields={'events':[],'unfinished_topics':[],'promises_and_todos':[],'preferences':[]}
    for turn in turns:
        for sentence in re.split(r'[。！？\n]',turn['user_text']):
            text=sentence.strip()
            if not text: continue
            row={'text':text[:120],'source_turn_id':turn['id'],'confidence':.6,'status':'candidate'}
            if any(w in text for w in ['今天去了','今天发生','今天完成','今天参加','今天见到']):
                fields['events'].append(row)
            if any(w in text for w in ['下次聊','下次继续','以后再聊','还没讲完','还没弄懂']):
                fields['unfinished_topics'].append(row)
            if any(w in text for w in ['明天要','下次要','我答应','我们约好','待办','计划做']):
                fields['promises_and_todos'].append(row)
            if any(w in text for w in ['我喜欢','我不喜欢','我希望你']):
                fields['preferences'].append(row)
    return {k:v[-20:] for k,v in fields.items()}
