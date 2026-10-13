class EmotionAnalyzer:
    labels = {'neutral','happy','sad','anxious','tired','excited','calm'}
    def analyze(self, text, enabled=True):
        if not enabled: return {'label':'neutral','confidence':0,'method':'disabled'}
        for label, words in {'happy':['开心','高兴'],'sad':['难过','伤心'],'anxious':['焦虑','紧张'],'tired':['疲惫','累'],'excited':['兴奋'],'calm':['平静','安心']}.items():
            if any(w in text for w in words): return {'label':label,'confidence':.55,'method':'keyword_candidate'}
        return {'label':'neutral','confidence':.3,'method':'keyword_candidate'}
