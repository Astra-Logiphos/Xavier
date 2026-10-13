import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_client.dart';
import 'health_store.dart';
import 'persona_assets.dart';

class NutritionPage extends StatefulWidget {
  final ApiClient api;
  final bool connected;
  final VoidCallback? onChanged;
  const NutritionPage({super.key,required this.api,required this.connected,this.onChanged});
  @override
  State<NutritionPage> createState()=>_NutritionPageState();
}
class _NutritionPageState extends State<NutritionPage> {
  final store=HealthStore.instance;
  List<Map<String,dynamic>> foods=[],exercises=[];
  final search=TextEditingController(),amount=TextEditingController(text:'100'),serving=TextEditingController(text:'100'),exerciseSearch=TextEditingController(),minutes=TextEditingController(text:'30');
  int? selected;
  String? exercise;
  String unit='g',category='有氧';
  String day=HealthStore.date(DateTime.now());
  int range=7,exerciseLimit=40;
  bool loading=true;
  @override
  void initState(){super.initState();load();}
  @override
  void dispose(){for(final c in [search,amount,serving,exerciseSearch,minutes]){c.dispose();}super.dispose();}
  void notice(String text){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));}
  Future<void> load() async {
    try {
      foods=(jsonDecode(await rootBundle.loadString('assets/data/foods.json')) as List).cast<Map<String,dynamic>>();
      exercises=(jsonDecode(await rootBundle.loadString('assets/data/exercises.json')) as List).cast<Map<String,dynamic>>();
    }catch(error){notice('记录读取失败：$error');}
    if(mounted)setState(()=>loading=false);
  }
  void changed(){if(mounted)setState((){});widget.onChanged?.call();}
  double? positive(String text){final n=double.tryParse(text);return n!=null&&n.isFinite&&n>0&&n<=100000?n:null;}
  Future<void> saveFood() async {
    if(selected==null){notice('请先选择食物。');return;}
    final food=[...foods,...store.customFoods][selected!];
    final value=positive(amount.text),grams=positive(serving.text),energy=food['energyKCal'];
    if(value==null||grams==null){notice('请输入有效份量。');return;}
    if(energy is! num){notice('来源未提供热量，请手动添加已知热量的食物。');return;}
    final actual=unit=='g'?value:value*grams;
    try{await store.add(day,'foods',{'foodCode':food['foodCode'],'name':food['foodName'],'grams':actual,'energyKCal':energy,'calories':HealthStore.intake(energy.toDouble(),actual),'estimated':false});changed();notice(PersonaAssets.line('鼓励','饮食'));}catch(e){notice('保存失败：$e');}
  }
  Future<void> saveExercise() async {
    if(exercise==null){notice('请先选择运动。');return;}
    if(store.weight<=0){notice('请先在设置填写体重、基础代谢与活动系数。');return;}
    final duration=positive(minutes.text);if(duration==null||duration>1440){notice('时长须为 0–1440 分钟。');return;}
    final row=exercises.firstWhere((r)=>r['code']==exercise);
    try{await store.add(day,'exercises',{'code':row['code'],'name':label(row),'metValue':row['metValue'],'weight':store.weight,'minutes':duration,'calories':HealthStore.expenditure((row['metValue'] as num).toDouble(),store.weight,duration),'estimated':true});changed();notice(PersonaAssets.line('鼓励','运动'));}catch(e){notice('保存失败：$e');}
  }
  Future<void> custom() async {
    final name=TextEditingController(),energy=TextEditingController();
    final row=await showDialog<Map<String,dynamic>>(context:context,builder:(context)=>AlertDialog(title:const Text('手动添加食物'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'食物名称')),TextField(controller:energy,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'每 100 克热量（千卡）'))]),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('取消')),FilledButton(onPressed:(){final n=double.tryParse(energy.text);if(name.text.trim().isNotEmpty&&n!=null&&n.isFinite&&n>=0&&n<=10000)Navigator.pop(context,{'name':name.text.trim(),'energy':n});},child:const Text('添加'))]));
    name.dispose();energy.dispose();if(row==null)return;
    try{await store.custom(row['name'],row['energy']);search.text=row['name'];selected=foods.length+store.customFoods.length-1;changed();notice('已保存到这台电脑。');}catch(e){notice('$e');}
  }
  String group(Map<String,dynamic> row){final c=row['category'];if(c=='Sports'){final text=(row['description'] as String).toLowerCase();return ['ball','badminton','tennis','soccer','volley','hockey','golf','squash','cricket'].any(text.contains)?'球类':'有氧';}if(c=='Conditioning Exercise')return '力量';if(['Bicycling','Running','Walking','Dancing','Water Activities','Winter Activities'].contains(c))return '有氧';return '日常';}
  String label(Map<String,dynamic> row)=>switch(row['code']){'12020'=>'慢跑 · 自选配速','17190'=>'步行 · 中等速度','01010'=>'骑车 · 休闲','02050'=>'力量训练 · 大重量',_=>row['description'] as String};
  Widget logList(String kind)=>Column(children:[if(store.rows(day,kind).isEmpty)Text(PersonaAssets.empty(kind=='foods'?'饮食':'运动')),...store.rows(day,kind).map((r)=>ListTile(title:Text(r['name']),subtitle:Text('${kind=='foods'?'${r['grams']} 克':'${r['minutes']} 分钟 · ${r['weight']} kg'} · ${(r['calories'] as num).toStringAsFixed(1)} 千卡${kind=='exercises'?'（估算）':''}'),trailing:IconButton(tooltip:'删除记录',icon:const Icon(Icons.delete_outline),onPressed:()async{try{await store.remove(day,kind,r['id']);changed();}catch(e){notice('$e');}})))]);
  Widget foodTab(){final all=[...foods,...store.customFoods];final query=search.text.trim().toLowerCase();final matches=all.asMap().entries.where((e)=>query.isNotEmpty&&(e.value['foodName'] as String).toLowerCase().contains(query)).take(30);
    return ListView(children:[Text(PersonaAssets.empty('饮食')),const SizedBox(height:8),TextField(controller:search,decoration:const InputDecoration(labelText:'搜索食物，例如米饭'),onChanged:(_)=>setState(()=>selected=null)),...matches.map((e)=>RadioListTile<int>(value:e.key,groupValue:selected,onChanged:(v)=>setState(()=>selected=v),title:Text(e.value['foodName']),subtitle:Text(e.value['energyKCal']==null?'热量缺失，请手动补充':'${e.value['energyKCal']} 千卡 / 100 克'))),const SizedBox(height:8),Row(children:[Expanded(child:TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'实际摄入份量'))),DropdownButton<String>(value:unit,items:const[DropdownMenuItem(value:'g',child:Text('克')),DropdownMenuItem(value:'份',child:Text('份'))],onChanged:(v)=>setState(()=>unit=v!))]),if(unit=='份')TextField(controller:serving,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'每份克数')),Wrap(spacing:8,children:[FilledButton(onPressed:loading?null:saveFood,child:const Text('记录饮食')),TextButton(onPressed:custom,child:const Text('手动添加食物'))]),logList('foods'),const Text('按实际可食用克数计算，不再乘可食部比例。OCR 数据可能有误；缺失热量不自动猜测。AI 估算尚未启用。')]);}
  Widget exerciseTab(){final q=exerciseSearch.text.toLowerCase().trim();final rows=exercises.where((r)=>group(r)==category&&(q.isEmpty||label(r).toLowerCase().contains(q)||(q=='慢跑'&&r['code']=='12020'))).take(exerciseLimit);
    return ListView(children:[const Text('先选运动，再记下时长。我陪你慢慢来。'),Wrap(spacing:8,children:['有氧','力量','球类','日常'].map((c)=>ChoiceChip(label:Text(c),selected:category==c,onSelected:(_)=>setState((){category=c;exercise=null;exerciseLimit=40;}))).toList()),TextField(controller:exerciseSearch,decoration:const InputDecoration(labelText:'搜索运动（支持慢跑或英文原名）'),onChanged:(_)=>setState(()=>exercise=null)),...rows.map((r)=>RadioListTile<String>(value:r['code'],groupValue:exercise,onChanged:(v)=>setState(()=>exercise=v),title:Text(label(r)),subtitle:Text('MET ${r['metValue']} · ${r['category']}'))),TextButton(onPressed:()=>setState(()=>exerciseLimit+=40),child:const Text('查看更多运动')),TextField(controller:minutes,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'运动分钟数')),Text('当前体重 ${store.weight>0?'${store.weight} kg':'未设置'}；消耗为估算值。'),FilledButton(onPressed:loading?null:saveExercise,child:const Text('记录运动')),logList('exercises')]);}
  Widget trend(){final end=DateTime.parse(day);final dates=List.generate(range,(i)=>HealthStore.date(end.subtract(Duration(days:range-1-i))));final maximum=dates.map((d)=>store.net(d).abs()).fold<double>(1,(a,b)=>a>b?a:b);
    return ExpansionTile(title:const Text('周 / 月趋势与历史'),children:[SegmentedButton<int>(segments:const[ButtonSegment(value:7,label:Text('7 天')),ButtonSegment(value:30,label:Text('30 天'))],selected:{range},onSelectionChanged:(v)=>setState(()=>range=v.first)),...dates.map((d)=>ListTile(title:Text('$d · 净 ${store.net(d).toStringAsFixed(1)} 千卡'),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[LinearProgressIndicator(value:store.net(d).abs()/maximum,color:store.net(d)>=0?Theme.of(context).colorScheme.primary:Theme.of(context).colorScheme.secondary),Text('摄入 ${store.total(d,'foods').toStringAsFixed(1)} / 消耗 ${store.total(d,'exercises').toStringAsFixed(1)}')]),onTap:()=>setState(()=>day=d)))]);}
  @override
  Widget build(BuildContext context)=>DefaultTabController(length:2,child:Column(children:[Text('饮食与运动',style:Theme.of(context).textTheme.titleLarge),TextButton.icon(onPressed:()async{final date=await showDatePicker(context:context,initialDate:DateTime.parse(day),firstDate:DateTime(2020),lastDate:DateTime.now());if(date!=null)setState(()=>day=HealthStore.date(date));},icon:const Icon(Icons.calendar_month),label:Text(day)),Text('摄入 ${store.total(day,'foods').toStringAsFixed(1)} · 消耗 ${store.total(day,'exercises').toStringAsFixed(1)} · 净 ${store.net(day).toStringAsFixed(1)} 千卡'),Text(store.target>0?'目标 ${store.target.toStringAsFixed(1)} · 目标缺口 ${(store.target-store.net(day)).toStringAsFixed(1)} 千卡':'请在设置填写基础代谢与活动系数，目标 = 基础代谢 × 活动系数'),if(loading)const LinearProgressIndicator(),const TabBar(tabs:[Tab(text:'饮食'),Tab(text:'运动')]),Expanded(child:TabBarView(children:[foodTab(),exerciseTab()])),SizedBox(height:160,child:SingleChildScrollView(child:trend()))]));
}
