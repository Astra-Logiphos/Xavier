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
  Future<void> load() async {final prefs=await SharedPreferences.getInstance();final saved=prefs.getString('local_reminders');config=saved==null?{for(final c in categories)c:{'enabled':false,'hour':20,'minute':0}}:Map<String,dynamic>.from(jsonDecode(saved));}
  Future<void> initialize() async {
    if(ready)return;
    if(!Platform.isWindows&&!Platform.isAndroid)return;
    zones.initializeTimeZones();
    tz.setLocalLocation(resolveLocation(await FlutterTimezone.getLocalTimezone()));
    final initialized=await plugin.initialize(const InitializationSettings(android:AndroidInitializationSettings('@mipmap/ic_launcher'),windows:WindowsInitializationSettings(appName:'星辉 Companion',appUserModelId:'dev.xinghui.companion',guid:'cd41a9bf-2798-42bf-bc75-4a7a34ac2832')));
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
  static const details=NotificationDetails(android:AndroidNotificationDetails('xinghui-checkins','星辉每日打卡',channelDescription:'学习、情绪、陪伴、饮食和运动提醒',importance:Importance.high,priority:Priority.high),windows:WindowsNotificationDetails());
  Future<void> schedule(int id,String category,DateTime at,{bool repeat=false}) async {
    await plugin.zonedSchedule(id,'星辉 · $category',PersonaAssets.line('提醒',category),tz.TZDateTime.from(at,tz.local),details,androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,matchDateTimeComponents:repeat?DateTimeComponents.time:null,payload:category);
  }
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
Register-ScheduledTask -TaskName '$task' -Action \$action -Trigger \$triggers -Settings \$settings -Principal \$principal -Description '星辉本地通知每日补排' -Force | Out-Null
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
 Future<void> action(AsyncCallback action) async {setState(()=>busy=true);try{await action();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('已交给这台设备的本地通知服务。')));}catch(e){service.error='$e';}finally{if(mounted)setState(()=>busy=false);}}
 @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('每日提醒',style:Theme.of(context).textTheme.titleLarge),const Text('五类时间独立保存。Windows 每日计划任务补排；请允许系统通知，勿扰模式会影响横幅。Android 定时可能由系统稍作延后。'),for(final c in ReminderService.categories)ListTile(title:Text(c),leading:Switch(value:service.config[c]?['enabled']==true,onChanged:busy?null:(v)=>action(()async{if(v&&!await service.permission())throw StateError('未获得通知权限');service.config[c]??={'hour':20,'minute':0};service.config[c]['enabled']=v;await service.save();})),trailing:TextButton(onPressed:busy?null:()async{final row=service.config[c]??{'hour':20,'minute':0};final time=await showTimePicker(context:context,initialTime:TimeOfDay(hour:row['hour'],minute:row['minute']));if(time!=null)await action(()async{service.config[c]??={'enabled':false};service.config[c].addAll({'hour':time.hour,'minute':time.minute});await service.save();});},child:Text('${(service.config[c]?['hour']??20).toString().padLeft(2,'0')}:${(service.config[c]?['minute']??0).toString().padLeft(2,'0')}'))),TextButton(onPressed:busy?null:()=>action(service.test),child:const Text('一分钟测试提醒')),if(service.error!=null)Text(service.error!),if(busy)const LinearProgressIndicator()]);
}
