"""Personal nutrition and activity records; no external estimation calls."""
from datetime import date
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def asset(name):
    path=ROOT/'assets/data'/name
    if not path.exists():path=ROOT/'client/flutter_app/assets/data'/name
    return json.loads(path.read_text(encoding='utf-8'))

def number(value, minimum=0, maximum=100000):
    if isinstance(value,bool):raise ValueError('请填写有效数字')
    try:result=float(value)
    except (TypeError,ValueError):raise ValueError('请填写有效数字') from None
    if not math.isfinite(result) or not minimum<=result<=maximum:raise ValueError('数字超出允许范围')
    return result

class HealthService:
    def __init__(self,store,today):self.store=store;self.today=today
    def foods(self):
        return [dict(row,id=row['foodCode'] or f'unknown-code-{index}',name=row['foodName']) for index,row in enumerate(asset('foods.json'))]+self.store.all('custom_food')
    def day(self,body):
        value=body.get('local_date',self.today())
        if not isinstance(value,str):raise ValueError('日期格式无效')
        return date.fromisoformat(value).isoformat()
    def dispatch(self,method,path,body,query):
        if path=='/foods':
            if method=='GET':
                text=query.get('q',[''])[0].strip().casefold()
                return {'items':[food for food in self.foods() if not text or text in food['name'].casefold()]}
            if method=='POST':
                name=body.get('name','')
                if not isinstance(name,str) or not 0<len(name.strip())<=200:raise ValueError('请输入食物名称')
                return self.store.add('custom_food',{'name':name.strip(),'energyKCal':number(body.get('energyKCal'),maximum=10000),'source':'user_created'})
        if path=='/food-logs':
            if method=='GET':
                day=query.get('date',[self.today()])[0]
                rows=[row for row in self.store.all('food_log') if row['local_date']==day]
                return {'items':rows,'calories':round(sum(row['calories'] for row in rows),2),'local_date':day}
            if method=='POST':
                food=next((row for row in self.foods() if row['id']==body.get('food_id')),None)
                if food is None:raise ValueError('请选择食物')
                energy=food['energyKCal']
                if energy is None:raise ValueError('此食物来源未提供热量，请手动添加已知热量的食物，不自动猜测')
                amount=number(body.get('amount'),minimum=.01,maximum=100000)
                unit=body.get('unit','g')
                if unit not in {'g','份'}:raise ValueError('请选择克或份')
                serving=number(body.get('grams_per_serving',100),minimum=.01,maximum=100000)
                grams=amount if unit=='g' else amount*serving
                return self.store.add('food_log',{'food_id':food['id'],'name':food['name'],'amount':amount,'unit':unit,'grams_per_serving':serving,'grams':grams,'energyKCal':energy,'calories':round(energy*grams/100,2),'local_date':self.day(body),'estimated':False})
        if path.startswith('/food-logs/') and method=='DELETE':
            rid=path.rsplit('/',1)[1]
            if self.store.get(rid)['kind']!='food_log':raise ValueError('记录类型无效')
            self.store.delete(rid);return {'deleted':True}
        raise ValueError('饮食接口不存在')
