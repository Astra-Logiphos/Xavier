import 'package:flutter/material.dart';

/// Field editor for user data. Lists use one item per line, no JSON knowledge needed.
class RecordEditor extends StatefulWidget {
  static String labelFor(dynamic value) => _RecordEditorState.names[value] ?? '记录';
  final String title;
  final Map<String, dynamic> initial;
  const RecordEditor({super.key, required this.title, required this.initial});
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  final fields = <String, TextEditingController>{};
  final switches = <String, bool>{};
  final selections = <String, String>{};
  final form = GlobalKey<FormState>();
  static const labels = {
    'text':'内容 / 特征', 'content':'需要记住的内容', 'topic':'学习主题',
    'knowledge_points':'学过的知识点（每行一条）', 'mastered':'已掌握（每行一条）',
    'unmastered':'未掌握（每行一条）', 'mistakes':'错题（每行一条）',
    'user_understanding':'自己的理解', 'consent':'我同意保存这条记录',
    'confidence':'置信度（0–1）', 'kind':'记忆类型', 'layer':'人设层',
    'source_id':'已批准来源的记录 ID', 'url':'原始 HTTPS 链接', 'title':'标题',
    'author':'作者', 'published_at':'发布时间（未知可写“未提供”）', 'platform':'来源平台',
    'content_type':'文字类型', 'source_version':'来源版本（官方资料必填）',
    'source_type':'来源性质', 'evidence_status':'证据状态',
    'possible_conflicts':'尚未解决的冲突（每行一条，解决后清空）',
    'category':'打卡类别', 'local_date':'日期（YYYY-MM-DD）', 'label':'情绪标签',
    'keywords':'搜索关键词（每行一条）', 'exclude_keywords':'排除关键词（每行一条）',
    'platforms':'平台（每行一条）', 'left':'左侧人设记录 ID', 'right':'右侧人设记录 ID',
    'font':'字体', 'theme':'主题', 'overlay':'背景遮罩（0.4–0.98）', 'radius':'圆角（0–32）',
    'textScale':'文字大小（0.85–1.4）',
  };
  static const options = {
    'layer':['user_preference','community_evidence','canon_persona','interaction_style'],
    'kind':['profile_memory','episodic_memory','relationship_memory','learning_memory','user_preference_memory'],
    'platform':['manual','xiaohongshu','bilibili','public_web'],
    'source_type':['unverified','official','fan_opinion','unreliable'],
    'evidence_status':['plausible','confirmed','disputed','rejected'],
    'label':['neutral','happy','sad','anxious','tired','excited','calm'],
    'theme':['星夜','月光','暖春'],
  };
  static const names = {
    'user_preference':'我的明确偏好', 'community_evidence':'社区证据',
    'canon_persona':'官方人设事实', 'interaction_style':'短期互动风格',
    'profile_memory':'个人喜好与资料', 'episodic_memory':'经历',
    'relationship_memory':'相处习惯', 'learning_memory':'学习',
    'user_preference_memory':'用户偏好', 'manual':'手动提供',
    'xiaohongshu':'小红书', 'bilibili':'Bilibili', 'public_web':'公开网页',
    'unverified':'未核对', 'official':'官方（需要核对证据）',
    'fan_opinion':'粉丝观点', 'unreliable':'不可靠',
    'plausible':'可能成立', 'confirmed':'已确认', 'disputed':'有争议', 'rejected':'已拒绝',
    'neutral':'中性', 'happy':'开心', 'sad':'难过', 'anxious':'焦虑',
    'tired':'疲惫', 'excited':'兴奋', 'calm':'平静',
  };
  @override
  void initState() {
    super.initState();
    for (final entry in widget.initial.entries) {
      final value = entry.value;
      if (value is bool) { switches[entry.key] = value; }
      else if (options[entry.key]?.contains(value) == true) { selections[entry.key] = value as String; }
      else { fields[entry.key] = TextEditingController(text: value is List ? value.join('\n') : '${value ?? ''}'); }
    }
  }
  @override
  void dispose() { for (final c in fields.values) { c.dispose(); } super.dispose(); }
  void save() {
    if (!form.currentState!.validate()) return;
    final result = <String, dynamic>{};
    for (final entry in widget.initial.entries) {
      final key = entry.key;
      if (switches.containsKey(key)) { result[key] = switches[key]; }
      else if (selections.containsKey(key)) { result[key] = selections[key]; }
      else {
        final raw = fields[key]!.text.trim();
        result[key] = entry.value is List ? raw.split('\n').map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList() :
          entry.value is num ? num.parse(raw) : raw;
      }
    }
    Navigator.pop(context, result);
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(width: 620, child: SingleChildScrollView(child: Form(key: form,
      child: Column(mainAxisSize: MainAxisSize.min, children: widget.initial.keys.map((key) {
        final label = labels[key] ?? key;
        if (switches.containsKey(key)) { return SwitchListTile(title: Text(label),
          value: switches[key]!, onChanged:(v)=>setState(()=>switches[key]=v)); }
        if (selections.containsKey(key)) { return Padding(padding:const EdgeInsets.only(bottom:16),
          child: DropdownButtonFormField<String>(initialValue: selections[key],
            isExpanded:true, decoration:InputDecoration(labelText:label),
            items:options[key]!.map((v)=>DropdownMenuItem(value:v,child:Text(names[v]??v))).toList(),
            onChanged:(v)=>selections[key]=v!)); }
        final multiline = widget.initial[key] is List || ['content','text','user_understanding'].contains(key);
        return Padding(padding:const EdgeInsets.only(bottom:16), child:TextFormField(
          controller:fields[key],minLines:multiline?3:1,maxLines:multiline?7:1,
          decoration:InputDecoration(labelText:label),
          keyboardType:widget.initial[key] is num ? const TextInputType.numberWithOptions(decimal:true) : TextInputType.multiline,
          validator:(v) { if(widget.initial[key] is num && num.tryParse(v??'')==null) return '请输入数字'; return null; }));
      }).toList())))),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('取消')),
      FilledButton(onPressed:save,child:const Text('保存'))],
  );
}
