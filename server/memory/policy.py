import re
MEMORY_KINDS = {'profile_memory','episodic_memory','relationship_memory','learning_memory','user_preference_memory'}
SENSITIVE = re.compile(r'密码|口令|API.?Key|身份证|银行卡|财务|诊断|病历|精确位置|住址|第三方隐私|password|secret|token|\b\d{15,19}\b', re.I)

def sensitive(text):
    return bool(SENSITIVE.search(text))

def retrievable(row):
    return row.get('consent') is True and row.get('review_status') == 'approved' and row.get('confidence',0) >= .8 and not row.get('paused',False)
