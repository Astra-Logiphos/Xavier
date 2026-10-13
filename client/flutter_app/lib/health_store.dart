import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';

/// One local record per calendar day. Values are snapshots, not recomputed from
/// a later body weight or a later food database revision.
class HealthStore extends ChangeNotifier {
  static final instance = HealthStore();
  GetStorage? _box;
  Map<String, dynamic> _data = {'days': <String,dynamic>{}, 'customFoods': <dynamic>[], 'weight':0.0, 'bmr':0.0, 'activityFactor':1.2};
  Future<void> open({String? directory}) async {
    final location=directory??(await getApplicationDocumentsDirectory()).path;
    _box=GetStorage('xinghui-health',location);
    await _box!.initStorage;
    final saved=_box!.read<Map<String,dynamic>>('data');
    if(saved!=null)_data=saved;
    notifyListeners();
  }
  static String date(DateTime value)=>value.toIso8601String().substring(0,10);
  static double intake(double per100,double grams)=>per100*grams/100;
  static double expenditure(double met,double weight,double minutes)=>met*weight*minutes/60;
  double get weight=>(_data['weight'] as num).toDouble();
  double get bmr=>(_data['bmr'] as num).toDouble();
  double get factor=>(_data['activityFactor'] as num).toDouble();
  double get target=>bmr*factor;
  List<Map<String,dynamic>> get customFoods=>(_data['customFoods'] as List).map((r)=>Map<String,dynamic>.from(r)).toList();
  Map<String,dynamic> day(String date)=>Map<String,dynamic>.from((_data['days'] as Map)[date]??{'date':date,'foods':<dynamic>[],'exercises':<dynamic>[]});
  List<Map<String,dynamic>> rows(String date,String kind)=>(day(date)[kind] as List).map((r)=>Map<String,dynamic>.from(r)).toList();
  double total(String date,String kind)=>rows(date,kind).fold(0,(sum,r)=>sum+(r['calories'] as num));
  double net(String date)=>total(date,'foods')-total(date,'exercises');
  Map<String,dynamic> export()=>jsonDecode(jsonEncode(_data)) as Map<String,dynamic>;
  Future<void> _save() async {if(_box!=null){await _box!.write('data',export());await _box!.save();await _box!.queue.add(() async {});}notifyListeners();}
  Future<void> profile(double weight,double bmr,double factor) async {
    if(!weight.isFinite||weight<1||weight>500||!bmr.isFinite||bmr<1||bmr>10000||!factor.isFinite||factor<1||factor>3)throw const FormatException('请填写有效体重、基础代谢与活动系数');
    _data.addAll({'weight':weight,'bmr':bmr,'activityFactor':factor});await _save();
  }
  Future<void> add(String date,String kind,Map<String,dynamic> row) async {
    final parsed=DateTime.tryParse(date);
    if(!['foods','exercises'].contains(kind)||parsed==null||HealthStore.date(parsed)!=date||parsed.isAfter(DateTime.now()))throw const FormatException('记录日期无效');
    final entry=day(date);final list=List<dynamic>.from(entry[kind]);list.add({...row,'id':DateTime.now().microsecondsSinceEpoch.toString()});entry[kind]=list;(_data['days'] as Map)[date]=entry;await _save();
  }
  Future<void> remove(String date,String kind,String id) async {final entry=day(date);(entry[kind] as List).removeWhere((r)=>r['id']==id);(_data['days'] as Map)[date]=entry;await _save();}
  Future<void> custom(String name,double energy) async {
    if(name.trim().isEmpty||!energy.isFinite||energy<0||energy>10000)throw const FormatException('食物名称或热量无效');
    (_data['customFoods'] as List).add({'foodCode':'custom-${DateTime.now().microsecondsSinceEpoch}','foodName':name.trim(),'energyKCal':energy,'edible':100,'protein':null,'fat':null,'CHO':null});await _save();
  }
  Future<void> restore(Map<String,dynamic> data) async {
    if(data['days'] is! Map||data['customFoods'] is! List)throw const FormatException('热量备份格式无效');
    for(final entry in (data['days'] as Map).values){for(final kind in ['foods','exercises']){for(final row in entry[kind]){final value=row['calories'];if(value is! num||!value.isFinite||value<0)throw const FormatException('热量记录无效');}}}
    for(final key in ['weight','bmr','activityFactor']){if(data[key] is! num||!(data[key] as num).isFinite)throw const FormatException('个人设置无效');}
    _data=jsonDecode(jsonEncode(data));await _save();
  }
}
