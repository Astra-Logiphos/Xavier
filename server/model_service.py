from dataclasses import replace
import os
from .model_config import PROVIDERS, catalog, validate_model_config, free_config
from .model_environment import ENV_LOCK, persist_environment
from .providers.cloud import CloudProvider, ProviderError

class ModelService:
    def __init__(self,app):
        self.app = app

    def public_config(self):
        with ENV_LOCK:
            items=[]
            for name,data in catalog().items():
                refs=PROVIDERS[name]
                items.append(dict(data,provider=name,
                    saved_base_url=os.getenv(refs[0],'').strip() or data['base_url'],
                    saved_model=os.getenv(refs[1],'').strip() or data['models'][0],
                    key_configured=bool(os.getenv(refs[2],'').strip())))
            return {'providers':items,'provider':self.app.config.provider,'api_enabled':self.app.config.api_enabled}

    def selected(self,body):
        name=body.get('provider')
        if not isinstance(name,str) or name not in PROVIDERS:
            raise ValueError('不支持的模型供应商配置')
        for field in ('base_url','model','api_key'):
            if field in body and not isinstance(body[field],str):
                raise ValueError('模型配置字段必须为文本')
        refs=PROVIDERS[name]
        with ENV_LOCK:
            config=validate_model_config(name,body.get('base_url','').strip(),body.get('model','').strip(),body.get('api_key','').strip() or os.getenv(refs[2],'').strip())
        if not free_config(config) and body.get('paid_confirmed') is not True:
            raise ValueError('此模型可能收费；请明确确认后测试或保存')
        return config

    def record_result(self,result,provider):
        if provider not in PROVIDERS:
            return
        usage=result.usage
        with self.app.store.lock:
            self.app.store.set_setting('model_last_error',None)
            if isinstance(usage,dict):
                day=self.app.local_date()
                all_days=self.app.store.setting('model_token_usage',{})
                counts=all_days.get(day,{'prompt_tokens':0,'completion_tokens':0})
                for key in counts:
                    number=usage.get(key,0)
                    if isinstance(number,int) and not isinstance(number,bool) and number>=0:
                        counts[key]+=number
                all_days[day]=counts
                self.app.store.set_setting('model_token_usage',all_days)

    def record_error(self,error,provider):
        safe=error if isinstance(error,ProviderError) else ProviderError('模型配置或服务响应无效；请检查服务端设置',400)
        self.app.store.set_setting('model_last_error',{'provider':provider,'message':str(safe),'status':safe.status})

    def test(self,body):
        candidate=body.get('provider')
        name=candidate if isinstance(candidate,str) and candidate in PROVIDERS else 'unknown'
        try:
            config=self.selected(body)
            self.app.store.reserve_call(self.app.local_date(),self.app.config.max_daily_calls)
            provider=CloudProvider(config)
            provider.name=config.provider
            result=provider.complete([{'role':'user','content':'仅回复连接成功。'}])
            self.record_result(result,config.provider)
            return {'ok':True,'provider':config.provider,'model':config.model,'free_preset':free_config(config)}
        except ValueError as exc:
            self.record_error(exc,name)
            raise

    def save(self,body):
        config=self.selected(body)
        enabled=body.get('api_enabled',False)
        if not isinstance(enabled,bool):
            raise ValueError('启用模型调用必须为布尔值')
        refs=PROVIDERS[config.provider]
        values=dict(zip(refs,(config.base_url,config.model,config.api_key)))
        values.update(ACTIVE_PROVIDER=config.provider,API_ENABLED=str(enabled).lower(),
                      ALLOW_PAID_API=str(body.get('paid_confirmed') is True).lower())
        persist_environment(values)
        with self.app.store.lock:
            self.app.config=replace(self.app.config,provider=config.provider,api_enabled=enabled,allow_paid=body.get('paid_confirmed') is True)
        return {'saved':True,'provider':config.provider,'model':config.model,'key_configured':True}

    def status(self):
        with self.app.store.lock:
            row=self.app.store.db.execute('SELECT calls FROM model_usage WHERE day=?',(self.app.local_date(),)).fetchone()
            tokens=self.app.store.setting('model_token_usage',{}).get(self.app.local_date(),{})
            return {'today_model_calls':row[0] if row else 0,'today_model_tokens':tokens,
                    'last_model_error':self.app.store.setting('model_last_error')}
