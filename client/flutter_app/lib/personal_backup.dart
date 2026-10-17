import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'background_library.dart';
import 'health_store.dart';
import 'appearance.dart';
import 'reminder_service.dart';

class PersonalBackup {
 static const format='xinghui-personal-1';
 static Future<Map<String,dynamic>> export(ApiClient api) async {
   if(api.baseUrl.isEmpty)throw StateError('请连接本地后端，才能完整备份聊天与记忆');
   final backend=await api.request('GET','/data/export');
   final prefs=await SharedPreferences.getInstance();
   final photos=await BackgroundLibrary.load();
   return {'format':format,'exported_at':DateTime.now().toIso8601String(),'backend':backend,'health':HealthStore.instance.export(),
    'preferences':{for(final key in ['appearance','local_reminders','weekly_backup_suggested'])if(prefs.containsKey(key))key:prefs.get(key)},
    'photos':[for(final photo in photos){'id':photo.path.replaceAll('\\','/').split('/').last.replaceAll('.jpg',''),'originalPath':photo.path,'image':base64Encode(await File(photo.path).readAsBytes()),'thumbnail':base64Encode(await File(photo.thumbnail).readAsBytes())}]};
 }
 static Future<void> restore(ApiClient api,Map<String,dynamic> data,{String? directory}) async {
   if(api.baseUrl.isEmpty)throw StateError('请连接本地后端后恢复完整备份');
   if(data['format']!=format||data['backend'] is! Map||data['health'] is! Map||data['preferences'] is! Map||data['photos'] is! List)throw const FormatException('不是有效的星回备份');
   final validation=HealthStore();await validation.restore(Map<String,dynamic>.from(data['health']));
   final preferences=Map<String,dynamic>.from(data['preferences']);
   if(preferences.keys.any((k)=>!['appearance','local_reminders','weekly_backup_suggested'].contains(k)))throw const FormatException('备份设置无效');
   for(final key in ['appearance','local_reminders']){if(preferences.containsKey(key)){if(preferences[key] is! String||jsonDecode(preferences[key]) is! Map)throw const FormatException('设置格式无效');}}
   if(preferences['appearance']!=null){Appearance.fromJson(Map<String,dynamic>.from(jsonDecode(preferences['appearance'])));}
   if(preferences['local_reminders']!=null){final reminders=jsonDecode(preferences['local_reminders']) as Map;for(final c in ReminderService.categories){final row=reminders[c];if(row is! Map||row['enabled'] is! bool||row['hour'] is! int||row['minute'] is! int)throw const FormatException('提醒设置无效');ReminderService.nextDates(DateTime.now(),row['hour'],row['minute'],2);}}
   if(preferences.containsKey('weekly_backup_suggested')&&preferences['weekly_backup_suggested'] is! bool)throw const FormatException('备份提示设置无效');
   final photoBytes=<Map<String,dynamic>>[];final ids=<String>{};
   for(final value in data['photos']){
     if(value is! Map||value['id'] is! String||!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value['id'])||!ids.add(value['id']))throw const FormatException('背景 ID 无效');
     final image=base64Decode(value['image']),thumbnail=base64Decode(value['thumbnail']);
     if(image.isEmpty||image.length>50*1024*1024||thumbnail.isEmpty||thumbnail.length>5*1024*1024)throw const FormatException('背景文件大小无效');
     photoBytes.add({'id':value['id'],'image':image,'thumbnail':thumbnail});
   }
   final location=directory??(await getApplicationDocumentsDirectory()).path;
   final root=Directory('$location/xinghui-backgrounds');await root.create(recursive:true);
   // Stage media before touching the database. New filenames preserve the old
   // gallery until the complete restore has succeeded.
   final nonce=DateTime.now().microsecondsSinceEpoch;
   final staged=<GalleryPhoto>[];
   final previous=await api.request('GET','/data/export');
   final oldHealth=HealthStore.instance.export();final prefs=await SharedPreferences.getInstance();
   final oldPrefs={for(final key in ['appearance','local_reminders','weekly_backup_suggested','background_gallery'])key:prefs.get(key)};
   try{
     for(final value in photoBytes){final id='${nonce}_${value['id']}';final path='${root.path}/$id.jpg',thumb='${root.path}/$id-thumb.jpg';await File(path).writeAsBytes(value['image'],flush:true);await File(thumb).writeAsBytes(value['thumbnail'],flush:true);staged.add(GalleryPhoto(path,thumb));}
     await api.request('POST','/data/import',Map<String,dynamic>.from(data['backend']));
     await HealthStore.instance.restore(Map<String,dynamic>.from(data['health']));
     for(final key in ['appearance','local_reminders','weekly_backup_suggested']){await prefs.remove(key);}
     for(final e in preferences.entries){if(e.value is bool){await prefs.setBool(e.key,e.value);}else{await prefs.setString(e.key,e.value as String);}}
     if(preferences['appearance']!=null){final appearance=Map<String,dynamic>.from(jsonDecode(preferences['appearance']));final oldPath=appearance['backgroundPath'];final originals=data['photos'] as List;for(var i=0;i<originals.length;i++){if(oldPath==originals[i]['originalPath'])appearance['backgroundPath']=staged[i].path;}await prefs.setString('appearance',jsonEncode(appearance));}
     await prefs.setString('background_gallery',jsonEncode(staged.map((p)=>p.toJson()).toList()));
   }catch(error){
     await api.request('POST','/data/import',previous);
     await HealthStore.instance.restore(oldHealth);
     for(final e in oldPrefs.entries){await prefs.remove(e.key);if(e.value is String){await prefs.setString(e.key,e.value as String);}else if(e.value is bool){await prefs.setBool(e.key,e.value as bool);}}
     for(final photo in staged){for(final path in [photo.path,photo.thumbnail]){final file=File(path);if(await file.exists())await file.delete();}}
     rethrow;
   }
 }
}
