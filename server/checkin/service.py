from datetime import date, timedelta

def streak(records, today, category):
    dates = {r['local_date'] for r in records if r['category']==category}
    cursor = date.fromisoformat(today)
    if cursor.isoformat() not in dates: cursor -= timedelta(days=1)
    count=0
    while cursor.isoformat() in dates:
        count += 1
        cursor -= timedelta(days=1)
    return count
