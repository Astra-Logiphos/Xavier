import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as zones;
import 'package:timezone/timezone.dart' as tz;
import 'persona_assets.dart';

class ReminderService {
  static final instance=ReminderService();
  static const categories=['学习','情绪','陪伴','饮食','运动'];
  final plugin=FlutterLocalNotificationsPlugin();
  bool ready=false;
  String? error;
  Map<String,dynamic> config={};
  static const int defaultHour=21, defaultMinute=0;
  // 打卡提醒文案三版（用户挑选其一，key 持久化到 local_reminders.reminderText）。
  static const reminderTexts=['今天还没见到你。记录不用长，一句话就好。',
      '今天过得怎么样？来打个卡，我记着呢。',
      '打卡时间到了……就算没什么好说的，我也在。'];
  String get reminderText=>config['reminderText'] is String && (config['reminderText'] as String).isNotEmpty
      ?config['reminderText'] as String:reminderTexts[0];
  Future<void> load() async {final prefs=await SharedPreferences.getInstance();final saved=prefs.getString('local_reminders');config=saved==null?{for(final c in categories)c:{'enabled':false,'hour':defaultHour,'minute':defaultMinute}}:Map<String,dynamic>.from(jsonDecode(saved));}
  Future<void> initialize() async {
    if(ready)return;
    if(!Platform.isWindows&&!Platform.isAndroid)return;
    zones.initializeTimeZones();
    tz.setLocalLocation(resolveLocation(await FlutterTimezone.getLocalTimezone()));
    final initialized=await plugin.initialize(const InitializationSettings(android:AndroidInitializationSettings('@mipmap/ic_launcher'),windows:WindowsInitializationSettings(appName:'星回 Companion',appUserModelId:'dev.xinghui.companion',guid:'cd41a9bf-2798-42bf-bc75-4a7a34ac2832')));
    if(initialized!=true)throw StateError('本地通知初始化失败');
    ready=true;
  }
  static tz.Location resolveLocation(String name)=>['UTC','Etc/UTC','GMT','Etc/GMT'].contains(name)?tz.UTC:tz.getLocation(name);
  Future<bool> permission() async {
    await initialize();
    if(Platform.isAndroid)return await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission()??false;
    return ready;
  }
  static List<DateTime> nextDates(DateTime now,int hour,int minute,int days){
    if(hour<0||hour>23||minute<0||minute>59)throw const FormatException('提醒时间无效');
    return List.generate(days,(i)=>DateTime(now.year,now.month,now.day+i,hour,minute)).where((d)=>d.isAfter(now)).toList();
  }
  static const details=NotificationDetails(android:AndroidNotificationDetails('xinghui-checkins','星回每日打卡',channelDescription:'学习、情绪、陪伴、饮食和运动提醒',importance:Importance.high,priority:Priority.high),windows:WindowsNotificationDetails());
  Future<void> schedule(int id,String category,DateTime at,{bool repeat=false}) async {
    final text=PersonaAssets.line('提醒',category);
    await plugin.zonedSchedule(id,'星回 · $category',text,tz.TZDateTime.from(at,tz.local),details,androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,matchDateTimeComponents:repeat?DateTimeComponents.time:null,payload:category);
  }
  /// 纯本地每日打卡提醒（默认关、默认 21:00、无推送服务无网络）。
  Future<void> scheduleDailyCheckin(DateTime at) async {
    if(!await permission())throw StateError('未获得通知权限；请在系统设置中允许通知');
    await plugin.zonedSchedule(200001,'星回',reminderText,tz.TZDateTime.from(at,tz.local),details,androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,matchDateTimeComponents:DateTimeComponents.time,payload:'daily-checkin');
  }
  Future<void> cancelDailyCheckin() async {await initialize();await plugin.cancel(200001);}
  Future<void> reschedule({bool maintenance=false}) async {
    await initialize();if(!ready)return;
    await plugin.cancelAll();
    var any=false;
    for(var c=0;c<categories.length;c++){
      final row=config[categories[c]] as Map?;if(row?['enabled']!=true)continue;any=true;
      if(Platform.isWindows){final dates=nextDates(DateTime.now(),row!['hour'],row['minute'],8);for(var i=0;i<dates.length;i++){await schedule((c+1)*100+i,categories[c],dates[i]);}}
      else{final date=nextDates(DateTime.now(),row!['hour'],row['minute'],2).first;await schedule((c+1)*100,categories[c],date,repeat:true);}
    }
    if(Platform.isWindows&&!maintenance)await windowsTask(any);
    error=null;
  }
  Future<void> save() async {final prefs=await SharedPreferences.getInstance();await prefs.setString('local_reminders',jsonEncode(config));await reschedule();}
  Future<void> test() async {if(!await permission())throw StateError('请在系统设置允许通知');await schedule(900001,'陪伴',DateTime.now().add(const Duration(minutes:1)));}
  Future<void> smoke() async {
    await initialize();if(!ready)throw StateError('通知插件未初始化');
    final prefs=await SharedPreferences.getInstance();final previous=prefs.getString('local_reminders');
    final testTime=DateTime.now().add(const Duration(minutes:5));
    await prefs.setString('local_reminders',jsonEncode({for(final c in categories)c:{'enabled':c=='陪伴','hour':testTime.hour,'minute':testTime.minute}}));
    await windowsTask(true);
    try{
      final taskCheck=await Process.run('powershell.exe',['-NoProfile','-NonInteractive','-Command',r"$ErrorActionPreference='Stop'; Start-ScheduledTask -TaskName 'XinghuiReminderRefresh'; Start-Sleep -Seconds 2; for($i=0;$i -lt 30;$i++){ $task=Get-ScheduledTask -TaskName 'XinghuiReminderRefresh'; if($task.State -ne 'Running'){break}; Start-Sleep -Milliseconds 500 }; if((Get-ScheduledTaskInfo -TaskName 'XinghuiReminderRefresh').LastTaskResult -ne 0){throw 'Local reminder maintenance failed'}"]);
      if(taskCheck.exitCode!=0)throw StateError('提醒后台补排任务未通过运行检查：${taskCheck.stderr}');
      final replenished=await plugin.pendingNotificationRequests();
      if(!replenished.any((r)=>r.id>=300&&r.id<400))throw StateError('后台补排没有产生陪伴提醒');
    }finally{
      if(previous==null){await prefs.remove('local_reminders');}else{await prefs.setString('local_reminders',previous);}
      await windowsTask(false);await plugin.cancelAll();
    }
    final at=DateTime.now().add(const Duration(minutes:1));
    await schedule(900002,'陪伴',at);
    final pending=await plugin.pendingNotificationRequests();
    if(!pending.any((r)=>r.id==900002))throw StateError('Windows 原生队列没有测试提醒');
    await Future<void>.delayed(const Duration(seconds:63));
    final after=await plugin.pendingNotificationRequests();
    if(after.any((r)=>r.id==900002))throw StateError('到点后原生队列仍保留测试提醒');
    await File('${File(Platform.resolvedExecutable).parent.path}/notification-smoke.json').writeAsString(jsonEncode({'passed':true,'background_maintenance_task_verified':true,'native_schedule_confirmed':true,'due_consumed':true,'scheduled_at':at.toIso8601String(),'text':PersonaAssets.line('提醒','陪伴'),'visual_banner_verified':false}),flush:true);
  }
  Future<void> windowsTask(bool enabled) async {
    // The user-facing switch authorizes the current-user local maintenance task.
    // No elevated principal, remote endpoint or shell-interpolated user text.
    String quoted(String s)=>"'${s.replaceAll("'", "''")}'";
    const task='XinghuiReminderRefresh';
    final script=enabled?'''\$ErrorActionPreference='Stop'
\$action=New-ScheduledTaskAction -Execute ${quoted(Platform.resolvedExecutable)} -Argument '--refresh-reminders'
\$triggers=@((New-ScheduledTaskTrigger -Daily -At '00:05'),(New-ScheduledTaskTrigger -AtLogOn -User ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)))
\$principal=New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
\$settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
Register-ScheduledTask -TaskName '$task' -Action \$action -Trigger \$triggers -Settings \$settings -Principal \$principal -Description '星回本地通知每日补排' -Force | Out-Null
''':'''\$ErrorActionPreference='Stop'
if(Get-ScheduledTask -TaskName '$task' -ErrorAction SilentlyContinue){Unregister-ScheduledTask -TaskName '$task' -Confirm:\$false}
''';
    final result=await Process.run('powershell.exe',['-NoProfile','-NonInteractive','-Command',script]);
    if(result.exitCode!=0)throw StateError('本地计划任务设置失败；请检查 Windows 任务计划程序。${result.stderr}');
  }
}

class ReminderPanel extends StatefulWidget {
 const ReminderPanel({super.key});
 @override State<ReminderPanel> createState()=>_ReminderPanelState();
}
class _ReminderPanelState extends State<ReminderPanel>{
 final service=ReminderService.instance;
 bool busy=false;
 @override void initState(){super.initState();service.load().then((_){if(mounted)setState((){});});}
 bool get dailyOn=>service.config['daily_checkin']==true;
 Future<void> action(AsyncCallback action) async {setState(()=>busy=true);try{await action();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('已交给这台设备的本地通知服务。')));}catch(e){service.error='$e';}finally{if(mounted)setState(()=>busy=false);}}
 @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('每日提醒',style:Theme.of(context).textTheme.titleLarge),const Text('五类时间独立保存。Windows 每日计划任务补排；请允许系统通知，勿扰模式会影响横幅。Android 定时可能由系统稍作延后。'),SwitchListTile(title:const Text('每日打卡提醒（本地通知，默认关）'),subtitle:const Text('纯本地调度，无推送服务、无网络；权限被拒时会明确提示。'),value:dailyOn,onChanged:busy?null:(v)=>action(()async{if(v){final now=DateTime.now();final at=DateTime(now.year,now.month,now.day,(service.config['daily_hour'] as int?)??ReminderService.defaultHour,(service.config['daily_minute'] as int?)??ReminderService.defaultMinute);await service.scheduleDailyCheckin(at.isAfter(now)?at:at.add(const Duration(days:1)));}else{await service.cancelDailyCheckin();}service.config['daily_checkin']=v;await service.save();})),ListTile(title:const Text('打卡提醒时间（默认 21:00）'),trailing:TextButton(onPressed:busy?null:()async{final time=await showTimePicker(context:context,initialTime:TimeOfDay(hour:(service.config['daily_hour'] as int?)??ReminderService.defaultHour,minute:(service.config['daily_minute'] as int?)??ReminderService.defaultMinute));if(time!=null)await action(()async{service.config['daily_hour']=time.hour;service.config['daily_minute']=time.minute;if(dailyOn){await service.scheduleDailyCheckin(DateTime.now().copyWith(hour:time.hour,minute:time.minute).isAfter(DateTime.now())?DateTime.now().copyWith(hour:time.hour,minute:time.minute):DateTime.now().add(const Duration(days:1)).copyWith(hour:time.hour,minute:time.minute));}await service.save();});},child:Text('${((service.config['daily_hour'] as int?)??ReminderService.defaultHour).toString().padLeft(2,'0')}:${((service.config['daily_minute'] as int?)??ReminderService.defaultMinute).toString().padLeft(2,'0')}'))),Wrap(children:[for(var i=0;i<ReminderService.reminderTexts.length;i++)ChoiceChip(label:Text('文案${i+1}'),selected:service.reminderText==ReminderService.reminderTexts[i],onSelected:busy?null:(_)=>setState(()=>service.config['reminderText']=ReminderService.reminderTexts[i]))]),Text('当前文案：${service.reminderText}',style:Theme.of(context).textTheme.bodySmall),for(final c in ReminderService.categories)ListTile(title:Text(c),leading:Switch(value:service.config[c]?['enabled']==true,onChanged:busy?null:(v)=>action(()async{if(v&&!await service.permission())throw StateError('未获得通知权限');service.config[c]??={'hour':ReminderService.defaultHour,'minute':ReminderService.defaultMinute};service.config[c]['enabled']=v;await service.save();})),trailing:TextButton(onPressed:busy?null:()async{final row=service.config[c]??{'hour':ReminderService.defaultHour,'minute':ReminderService.defaultMinute};final time=await showTimePicker(context:context,initialTime:TimeOfDay(hour:row['hour'],minute:row['minute']));if(time!=null)await action(()async{service.config[c]??={'enabled':false};service.config[c].addAll({'hour':time.hour,'minute':time.minute});await service.save();});},child:Text('${(service.config[c]?['hour']??ReminderService.defaultHour).toString().padLeft(2,'0')}:${(service.config[c]?['minute']??ReminderService.defaultMinute).toString().padLeft(2,'0')}'))),TextButton(onPressed:busy?null:()=>action(service.test),child:const Text('一分钟测试提醒')),if(service.error!=null)Text(service.error!),if(busy)const LinearProgressIndicator()]);
}
