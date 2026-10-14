import 'package:flutter/material.dart';
import 'api_client.dart';

class ModelPanel extends StatefulWidget {
  final ApiClient api;
  final Future<void> Function() onSaved;
  const ModelPanel({super.key, required this.api, required this.onSaved});
  @override
  State<ModelPanel> createState() => _ModelPanelState();
}

class _ModelPanelState extends State<ModelPanel> {
  final base = TextEditingController();
  final keyInput = TextEditingController();
  final customModel = TextEditingController();
  List<Map<String, dynamic>> providers = [];
  String? provider, model;
  bool working = false, tested = false, paid = false, enabled = false;
  String message = '';
  Map<String, dynamic> get selected =>
      providers.firstWhere((p) => p['provider'] == provider);
  List<String> get models {
    final values = List<String>.from(selected['models']);
    if (model != null && !values.contains(model)) values.add(model!);
    return values;
  }

  bool get free =>
      selected['free_models'].contains(
          customModel.text.trim().isEmpty ? model : customModel.text.trim()) &&
      base.text.trim().replaceAll(RegExp(r'/+$'), '') == selected['base_url'];

  @override
  void initState() {
    super.initState();
    if (widget.api.baseUrl.isNotEmpty) load();
  }

  @override
  void dispose() {
    base.dispose();
    keyInput.clear();
    keyInput.dispose();
    customModel.dispose();
    super.dispose();
  }

  void choose(String name) {
    provider = name;
    base.text = selected['saved_base_url'];
    model = selected['saved_model'];
    keyInput.clear();
    customModel.clear();
    tested = false;
    paid = false;
    message = '';
  }

  Future<void> load() async {
    try {
      final data = await widget.api.request('GET', '/model/config');
      if (!mounted) return;
      if (data['providers'] is! List) {
        throw const FormatException('本地模型配置暂不可用，请应用补丁并重启后端。');
      }
      setState(() {
        providers = List<Map<String, dynamic>>.from(data['providers']);
        enabled = data['api_enabled'] == true;
        if (providers.isNotEmpty) {
          final active = '${data['provider']}';
          choose(providers.any((p) => p['provider'] == active)
              ? active
              : providers.first['provider']);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => message = e is ApiException
            ? e.message
            : e is FormatException
                ? e.message.toString()
                : '读取本地模型配置失败，请重启后端后再试。');
      }
    }
  }

  void changed({bool resetPaid = false}) => setState(() {
        tested = false;
        if (resetPaid) paid = false;
      });
  Future<void> submit(bool save) async {
    setState(() {
      working = true;
      message = '';
    });
    try {
      final data = <String, dynamic>{
        'provider': provider,
        'base_url': base.text.trim(),
        'model':
            customModel.text.trim().isEmpty ? model : customModel.text.trim(),
        'api_key': keyInput.text.trim(),
        'paid_confirmed': paid,
        'api_enabled': enabled,
      };
      await widget.api
          .request('POST', save ? '/model/config' : '/model/test', data);
      if (!mounted) return;
      setState(() {
        tested = true;
        message = save ? '已保存到本机后端环境变量，重启仍有效。' : '连接测试通过。';
        if (save) {
          keyInput.clear();
          selected['key_configured'] = true;
          selected['saved_base_url'] = data['base_url'];
          selected['saved_model'] = data['model'];
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          tested = false;
          message = '$e';
        });
      }
    } finally {
      if (mounted) setState(() => working = false);
      await widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.api.baseUrl.isEmpty) return const Text('连接本地后端后配置模型。');
    if (providers.isEmpty) {
      return Column(children: [
        Text(message.isEmpty ? '正在读取本地模型配置…' : message),
        TextButton(onPressed: load, child: const Text('重新读取'))
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DropdownButtonFormField<String>(
          key: const ValueKey('model-provider'),
          initialValue: provider,
          decoration: const InputDecoration(labelText: '1 · 选择平台'),
          items: providers
              .map((p) => DropdownMenuItem<String>(
                  value: p['provider'], child: Text(p['label'])))
              .toList(),
          onChanged: working ? null : (v) => setState(() => choose(v!))),
      Text('${selected['hint']}'),
      TextField(
          controller: base,
          enabled: !working,
          onChanged: (_) => changed(resetPaid: true),
          decoration: const InputDecoration(labelText: '2 · 模型接口地址（自动预填）')),
      TextField(
          key: const ValueKey('model-key'),
          controller: keyInput,
          obscureText: true,
          enabled: !working,
          enableSuggestions: false,
          autocorrect: false,
          onChanged: (_) => changed(),
          decoration: InputDecoration(
              labelText: '3 · API Key',
              hintText: selected['key_configured'] == true
                  ? '已在后端配置，留空保留原Key'
                  : '仅发送到本机后端，不在App保存')),
      if (!free)
        CheckboxListTile(
            value: paid,
            title: const Text('明确同意此模型可能产生费用'),
            onChanged: working
                ? null
                : (v) => setState(() {
                      paid = v!;
                      tested = false;
                    })),
      if (free) const Text('预设免费模型无需费用确认；平台额度以实际为准。'),
      FilledButton.tonal(
          onPressed: working || (!free && !paid) ? null : () => submit(false),
          child: const Text('4 · 测试连接')),
      DropdownButtonFormField<String>(
          key: ValueKey('model-name-$provider-$model'),
          initialValue: model,
          decoration: const InputDecoration(labelText: '5 · 选择模型'),
          items: models
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: working
              ? null
              : (v) => setState(() {
                    model = v;
                    customModel.clear();
                    tested = false;
                    paid = false;
                  })),
      TextField(
          controller: customModel,
          enabled: !working,
          onChanged: (_) => changed(resetPaid: true),
          decoration: const InputDecoration(labelText: '自定义模型或接入点ID（可留空）')),
      SwitchListTile(
          value: enabled,
          title: const Text('启用模型调用'),
          onChanged: working ? null : (v) => setState(() => enabled = v)),
      FilledButton(
          onPressed: working || !tested || (!free && !paid)
              ? null
              : () => submit(true),
          child: const Text('6 · 保存到本机后端')),
      if (message.isNotEmpty) Text(message),
    ]);
  }
}
