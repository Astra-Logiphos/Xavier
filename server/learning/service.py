from datetime import datetime, timedelta, timezone

def next_review(reviews=0):
    return (datetime.now(timezone.utc)+timedelta(days=min(30,2**reviews))).isoformat()

def learning_payload(topic, local_date, points=None):
    return {'topic':topic,'learning_date':local_date,'knowledge_points':points or [],
            'mastered':[],'unmastered':[],'mistakes':[],'user_understanding':'',
            'review_count':0,'next_review_at':next_review(),'confidence':1.0,'consent':True,
            'review_status':'approved','source':'explicit_user_learning_record'}
