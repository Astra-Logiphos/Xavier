from datetime import datetime,timedelta,timezone
from zoneinfo import ZoneInfo
import secrets
import json
import threading
import logging
from .persona.core import core_card,companion_config

class CompanionService:
    def __init__(self,app,clock=None):
        self.app=app
        self.clock=clock or (lambda:datetime.now(timezone.utc))
        self.started=self.clock()
        self.sessions={}
        self.last_interaction=None
        self.pending=[]
        self.stopped=threading.Event()
    def now(self):
        return self.clock().astimezone(ZoneInfo(self.app.config.timezone))
    def today_context(self):
        now=self.now();day=now.date().isoformat()
        with self.app.store.lock:
            saved=self.app.store.setting('companion_daily_state',{})
            if saved.get('date')!=day:
                saved={'date':day,'state':secrets.choice(companion_config()['daily_states'])}
                self.app.store.set_setting('companion_daily_state',saved)
        return '本地当前日期时间：'+now.strftime('%Y-%m-%d %H:%M:%S')+' '+self.app.config.timezone+'。今日轻微状态：'+saved['state']+'；只轻微影响语气。'
    def on_chat(self,persist=True):
        self.last_interaction=self.clock().isoformat()
        if persist:
            self.app.store.set_setting('companion_last_interaction',self.last_interaction)
    def tick(self,body,consume=True):
        event=body.get('event','tick');session=body.get('session_id','')
        if event not in ('open','tick') or not isinstance(session,str) or not session or len(session)>100:
            raise ValueError('陪伴事件参数无效')
        seconds=body.get('active_seconds',0)
        if isinstance(seconds,bool) or not isinstance(seconds,(int,float)) or not 0<=seconds<=864000:
            raise ValueError('陪伴时长无效')
        with self.app.store.lock:
            if not self.app.store.setting('proactive_enabled',True):
                self.pending.clear()
                return {'events':[],'next_check_seconds':86400}
            if session not in self.sessions:
                if len(self.sessions)>=64:self.sessions.pop(next(iter(self.sessions)))
                self.sessions[session]={'opened':False,'rested':False}
            state=self.sessions[session]
            now=self.now();day=now.date().isoformat();config=companion_config();lines=core_card()['static']
            usage=self.app.store.setting('companion_event_usage',{})
            saved=usage.get(day,{'count':0,'care':False,'quiet_after':None})
            events=[]
            def emit(kind,text,scene):
                if saved['count']>=config['daily_message_limit']:return False
                item={'type':kind,'text':text,'voice_scene':scene,'created_at':self.clock().isoformat(),'assistant_only':True}
                if self.app.store.setting('save_conversations',False):
                    item=self.app.store.add('companion_event',dict(item,assistant_text=text,user_text='',consent=True,local_date=day))
                events.append(item);saved['count']+=1
                return True
            if event=='open' and not state['opened']:
                greeting=next(slot for slot in lines['greetings'] if slot['start']<=now.hour<slot['end'])
                emit('greeting',greeting['line'],greeting['voice_scene']);state['opened']=True
            previous=(now.date()-timedelta(days=1)).isoformat()
            rows=self.app.store.db.execute("SELECT DISTINCT json_extract(payload,'$.local_date') AS day FROM records WHERE kind='conversation_turn' AND json_extract(payload,'$.consent')=1 AND json_extract(payload,'$.local_date') IN (?,?) AND json_extract(payload,'$.emotion.label') IN ('sad','anxious','tired')",(day,previous))
            negative={row['day'] for row in rows}
            if day in negative and previous in negative and not saved['care']:
                if emit('care',lines['care'],'care'):saved['care']=True
            last=self.last_interaction or self.app.store.setting('companion_last_interaction',self.started.isoformat())
            try:last_time=datetime.fromisoformat(last)
            except (TypeError,ValueError):last_time=self.started
            if last_time.tzinfo is None:last_time=self.started
            if (self.clock()-last_time).total_seconds()>=config['quiet_seconds'] and saved['quiet_after']!=last:
                if emit('quiet',lines['quiet'],'care'):saved['quiet_after']=last
            if seconds>=config['rest_seconds'] and not state['rested']:
                events.append({'type':'rest','text':lines['rest'],'voice_scene':'rest','created_at':self.clock().isoformat()});state['rested']=True
            usage={date:data for date,data in usage.items() if date>=previous}
            usage[day]=saved
            self.app.store.set_setting('companion_event_usage',usage)
            midnight=datetime.combine(now.date()+timedelta(days=1),datetime.min.time(),tzinfo=now.tzinfo)
            due=[max(1,(midnight-now).total_seconds())]
            if saved['count']<config['daily_message_limit'] and saved['quiet_after']!=last:
                due.append(max(1,config['quiet_seconds']-(self.clock()-last_time).total_seconds()))
            if not state['rested']:
                due.append(max(1,config['rest_seconds']-seconds))
            self.pending.extend(event for event in events if event['type']!='rest')
            self.pending=self.pending[-128:]
            delivered=self.pending+[event for event in events if event['type']=='rest'] if consume else []
            if consume:self.pending.clear()
            return {'events':delivered,'today_count':saved['count'],'next_check_seconds':min(due)}

    def start(self):
        def run():
            while not self.stopped.wait(companion_config()['tick_seconds']):
                try:self.tick({'session_id':'backend-scheduler'},consume=False)
                except Exception:
                    logging.getLogger('xinghui.companion').warning('companion_scheduler_check_failed')
        threading.Thread(target=run,daemon=True,name='companion-scheduler').start()

    def stop(self):
        self.stopped.set()
