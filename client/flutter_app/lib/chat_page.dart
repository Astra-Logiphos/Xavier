import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;
import 'theme_config.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'bubble_config.dart';

class ChatMessage {
  final String id, role, text;
  final DateTime time;
  final Map<String, dynamic> turn;
  const ChatMessage(
      {required this.id,
      required this.role,
      required this.text,
      required this.time,
      required this.turn});
  static List<Map<String, dynamic>> mergeHistory(
      List<Map<String, dynamic>> local,
      List<dynamic> remote,
      int sequenceBeforeFetch) {
    final ids = remote.map((row) => row['id']).toSet();
    final retained = local
        .where((row) =>
            row['saved'] != true ||
            ((row['event_sequence'] as int? ?? 0) > sequenceBeforeFetch &&
                !ids.contains(row['turn_id'])))
        .toList();
    return [
      ...remote.map((row) => <String, dynamic>{
            'user': row['user_text'],
            'reply': row['assistant_text'],
            'saved': true,
            'emotion': row['emotion'],
            'turn_id': row['id'],
            'created_at': row['created_at'],
            'assistant_only': row['assistant_only'] == true
          }),
      ...retained,
    ];
  }

  static List<ChatMessage> fromTurns(List<Map<String, dynamic>> rows) {
    final result = <ChatMessage>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i],
          id = '${rows[i]['local_id'] ?? rows[i]['turn_id'] ?? i}';
      final time =
          DateTime.tryParse('${row['created_at'] ?? row['utc_time'] ?? ''}')
                  ?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0);
      if (row['assistant_only'] != true) {
        result.add(ChatMessage(
            id: '$id-user',
            role: 'user',
            text: '${row['user']}',
            time: time,
            turn: row));
      }
      if (row['reply'] != null) {
        result.add(ChatMessage(
            id: '$id-companion',
            role: 'companion',
            text: '${row['reply']}',
            time: DateTime.tryParse('${row['assistant_time'] ?? ''}')
                    ?.toLocal() ??
                time,
            turn: row));
      }
    }
    return result;
  }
}

class ChatPage extends StatelessWidget {
  final List<ChatMessage> messages;
  final TextEditingController controller;
  final ScrollController? scrollController;
  final bool busy, dark;
  final bool blurEnabled;
  final Color primary, textColor;
  final String emptyText;
  final String? userAvatarPath, companionAvatarPath;
  static int listBuilds = 0;
  final VoidCallback onSend;
  final Future<void> Function(String action, ChatMessage? selected) onAction;
  const ChatPage(
      {super.key,
      this.scrollController,
      this.userAvatarPath,
      this.companionAvatarPath,
      this.blurEnabled = true,
      required this.messages,
      required this.controller,
      required this.busy,
      required this.dark,
      required this.primary,
      required this.textColor,
      required this.emptyText,
      required this.onSend,
      required this.onAction});
  static bool timestampBefore(ChatMessage current, ChatMessage? previous,
          Map<String, dynamic> style) =>
      previous == null ||
      current.time.difference(previous.time).inMilliseconds >
          Duration(
                  minutes:
                      (style['timestamp']['intervalMinutes'] as num).toInt())
              .inMilliseconds ||
      current.time.year != previous.time.year ||
      current.time.month != previous.time.month ||
      current.time.day != previous.time.day;
  Future<void> menu(
      BuildContext context, Offset position, ChatMessage? selected) async {
    final style = BubbleConfig.skin,
        theme = Theme.of(context),
        settings = BubbleConfig.skin['menu'] as Map<String, dynamic>;
    final icons = {
      'copy': Icons.copy,
      'memory': Icons.psychology_outlined,
      'read': Icons.volume_up_outlined,
      'privacy': Icons.visibility_off_outlined,
      'learning': Icons.school_outlined
    };
    final action = await showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
            position.dx, position.dy, position.dx, position.dy),
        color: BubbleConfig.color(
            settings['background'], theme, primary, textColor),
        constraints:
            BoxConstraints(maxWidth: BubbleConfig.number(settings, 'maxWidth')),
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(BubbleConfig.number(settings, 'radius'))),
        items: (settings['items'] as List)
            .map((item) => PopupMenuItem<String>(
                height: BubbleConfig.number(settings, 'itemHeight'),
                value: item['id'],
                child: Row(children: [
                  Icon(icons[item['icon']],
                      size: BubbleConfig.number(settings, 'iconSize')),
                  SizedBox(width: BubbleConfig.number(style, 'rowGap')),
                  Text(item['label'],
                      style:
                          BubbleConfig.textStyle(theme, settings['textStyle']))
                ])))
            .toList());
    if (action != null) await onAction(action, selected);
  }

  Widget avatar(BuildContext context, bool mine, bool visible) {
    final config = BubbleConfig.skin['avatar'] as Map<String, dynamic>,
        size = BubbleConfig.number(BubbleConfig.skin['avatar'], 'size'),
        theme = Theme.of(context);
    if (!visible) return SizedBox(width: size, height: size);
    final uploaded = mine ? userAvatarPath : companionAvatarPath;
    final path =
        uploaded ?? config[mine ? 'userPath' : 'companionPath'] as String;
    Widget fallback() => ColoredBox(
        color:
            BubbleConfig.color(config['background'], theme, primary, textColor),
        child: Center(
            child: Text(config[mine ? 'userFallback' : 'companionFallback'],
                style: BubbleConfig.textStyle(
                        theme, BubbleConfig.skin['textStyle'])
                    ?.copyWith(
                        color: BubbleConfig.color(config['foreground'], theme,
                            primary, textColor)))));
    final external = File(
        path.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(path)
            ? path
            : '${File(Platform.resolvedExecutable).parent.path}/$path');
    final child = external.existsSync()
        ? Image.file(external,
            fit: BoxFit.cover, errorBuilder: (_, e, s) => fallback())
        : Image.asset(path,
            fit: BoxFit.cover, errorBuilder: (_, e, s) => fallback());
    final framed = ColoredBox(
        color:
            BubbleConfig.color(config['background'], theme, primary, textColor),
        child: child);
    return SizedBox(
        key: ValueKey('avatar-${mine ? 'user' : 'companion'}'),
        width: size,
        height: size,
        child: config['shape'] == 'circle'
            ? ClipOval(child: framed)
            : ClipRRect(
                borderRadius: BorderRadius.circular(
                    BubbleConfig.number(config, 'radius')),
                child: child));
  }

  Widget row(BuildContext context, ChatMessage entry, ChatMessage? previous) {
    final style = BubbleConfig.skin,
        theme = Theme.of(context),
        mine = entry.role == 'user',
        right = style[entry.role == 'user'
                ? 'userAlignment'
                : 'companionAlignment'] ==
            'right';
    final timestamp = timestampBefore(entry, previous, style),
        visible = previous == null || previous.role != entry.role || timestamp;
    final foreground = BubbleConfig.color(
        style[mine
            ? 'userText'
            : dark
                ? 'companionDarkText'
                : 'companionLightText'],
        theme,
        primary,
        textColor);
    final color = mine
        ? BubbleConfig.userColor(primary, foreground, style)
        : BubbleConfig.color(
            style[dark ? 'companionDarkColor' : 'companionLightColor'],
            theme,
            primary,
            textColor);
    final shadow = style['shadow'] as Map<String, dynamic>;
    return Padding(
        padding: EdgeInsets.only(bottom: BubbleConfig.number(style, 'rowGap')),
        child: Column(children: [
          if (timestamp)
            Padding(
                key: ValueKey('timestamp-${entry.id}'),
                padding: EdgeInsets.symmetric(
                    vertical: BubbleConfig.number(
                        style['timestamp'], 'paddingVertical')),
                child: Text(
                    '${entry.time.month}/${entry.time.day} ${entry.time.hour.toString().padLeft(2, '0')}:${entry.time.minute.toString().padLeft(2, '0')}',
                    style: BubbleConfig.textStyle(
                            theme, style['timestamp']['textStyle'])
                        ?.copyWith(
                            color: BubbleConfig.color(
                                style['timestamp']['color'],
                                theme,
                                primary,
                                textColor)))),
          LayoutBuilder(builder: (context, box) {
            final bubble = GestureDetector(
                onLongPressStart: (d) => menu(context, d.globalPosition, entry),
                onSecondaryTapUp: (d) => menu(context, d.globalPosition, entry),
                child: Container(
                    key: ValueKey('bubble-${entry.id}'),
                    constraints: BoxConstraints(
                        maxWidth: math.min(
                            box.maxWidth *
                                BubbleConfig.number(style, 'maxWidthFraction'),
                            box.maxWidth -
                                BubbleConfig.number(style['avatar'], 'size') -
                                BubbleConfig.number(style['avatar'], 'gap'))),
                    padding: EdgeInsets.symmetric(
                        horizontal:
                            BubbleConfig.number(style, 'paddingHorizontal'),
                        vertical:
                            BubbleConfig.number(style, 'paddingVertical')),
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(
                            BubbleConfig.number(style, 'radius')),
                        boxShadow: [
                          BoxShadow(
                              color: BubbleConfig.color(shadow['color'], theme,
                                      primary, textColor)
                                  .withOpacity(
                                      BubbleConfig.number(shadow, 'opacity')),
                              blurRadius: blurEnabled
                                  ? BubbleConfig.number(shadow, 'blur')
                                  : 0,
                              offset: Offset(
                                  BubbleConfig.number(shadow, 'offsetX'),
                                  BubbleConfig.number(shadow, 'offsetY')))
                        ]),
                    child: Text(entry.text,
                        style: BubbleConfig.textStyle(theme, style['textStyle'])
                            ?.copyWith(color: foreground))));
            final gap =
                SizedBox(width: BubbleConfig.number(style['avatar'], 'gap'));
            return Row(
                key: ValueKey('message-${entry.id}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: right
                    ? [
                        const Spacer(),
                        bubble,
                        gap,
                        avatar(context, mine, visible)
                      ]
                    : [
                        avatar(context, mine, visible),
                        gap,
                        bubble,
                        const Spacer()
                      ]);
          })
        ]));
  }

  @override
  Widget build(BuildContext context) {
    if (!BubbleConfig.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final style = BubbleConfig.skin,
        composer = BubbleConfig.skin['composer'] as Map<String, dynamic>,
        theme = Theme.of(context);
    return Column(children: [
      Expanded(
          child: _HistoryBoundary(
              fingerprint: Object.hashAll([
                Theme.of(context).textTheme,
                MediaQuery.textScalerOf(context),
                dark,
                primary,
                textColor,
                userAvatarPath,
                companionAvatarPath,
                blurEnabled,
                BubbleConfig.values,
                ...messages.map((m) => Object.hash(m.id, m.text, m.time))
              ]),
              builder: () {
                listBuilds++;
                developer.Timeline.instantSync('chat_list_build');
                return messages.isEmpty
                    ? Center(
                        child: Text(emptyText,
                            style: BubbleConfig.textStyle(
                                theme, style['textStyle'])))
                    : ListView.builder(
                        key: const ValueKey('chat-list'),
                        controller: scrollController,
                        padding: EdgeInsets.all(
                            BubbleConfig.number(style, 'listPadding')),
                        itemCount: messages.length,
                        itemBuilder: (context, i) => KeyedSubtree(
                            key: ValueKey(messages[i].id),
                            child: row(context, messages[i],
                                i == 0 ? null : messages[i - 1])));
              })),
      Padding(
          padding: EdgeInsets.all(BubbleConfig.number(composer, 'padding')),
          child: Row(children: [
            Expanded(
                child: GestureDetector(
                    onLongPressStart: (d) =>
                        menu(context, d.globalPosition, null),
                    onSecondaryTapUp: (d) =>
                        menu(context, d.globalPosition, null),
                    child: _DebouncedInput(
                        controller: controller,
                        child: TextField(
                            key: const ValueKey('chat-input'),
                            controller: controller,
                            minLines: (composer['minLines'] as num).toInt(),
                            maxLines: (composer['maxLines'] as num).toInt(),
                            keyboardType: TextInputType.multiline,
                            contextMenuBuilder: (context, editable) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                editable.hideToolbar();
                                menu(
                                    context,
                                    editable.contextMenuAnchors.primaryAnchor,
                                    null);
                              });
                              return const SizedBox.shrink();
                            },
                            style: BubbleConfig.textStyle(
                                theme, composer['textStyle']),
                            decoration: InputDecoration(
                                hintText: composer['hint'],
                                filled: true,
                                fillColor: BubbleConfig.color(
                                    composer['background'],
                                    theme,
                                    primary,
                                    textColor),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: BubbleConfig.number(
                                        style, 'paddingHorizontal'),
                                    vertical: BubbleConfig.number(
                                        style, 'paddingVertical')),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        BubbleConfig.number(
                                            composer, 'radius')),
                                    borderSide: BorderSide(
                                        color: BubbleConfig.color(
                                            composer['borderColor'],
                                            theme,
                                            primary,
                                            textColor),
                                        width: BubbleConfig.number(composer, 'borderWidth'))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BubbleConfig.number(composer, 'radius')), borderSide: BorderSide(color: BubbleConfig.color(composer['borderColor'], theme, primary, textColor), width: BubbleConfig.number(composer, 'borderWidth'))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BubbleConfig.number(composer, 'radius')), borderSide: BorderSide(color: BubbleConfig.color(composer['borderColor'], theme, primary, textColor), width: BubbleConfig.number(composer, 'borderWidth')))),
                            onSubmitted: (_) => onSend())))),
            SizedBox(width: BubbleConfig.number(composer, 'gap')),
            SizedBox(
                width: BubbleConfig.number(composer, 'sendButtonSize'),
                height: BubbleConfig.number(composer, 'sendButtonSize'),
                child: IconButton(
                    key: const ValueKey('chat-send'),
                    tooltip: '发送',
                    onPressed: busy ? null : onSend,
                    icon: Icon(Icons.send_rounded,
                        size: BubbleConfig.number(composer, 'sendIconSize'))))
          ]))
    ]);
  }
}

/// Typing stays immediate inside EditableText. Only settled draft processing is
/// debounced; it never invokes setState or rebuilds the message list.
class _DebouncedInput extends StatefulWidget {
  final TextEditingController controller;
  final Widget child;
  const _DebouncedInput({required this.controller, required this.child});
  @override
  State<_DebouncedInput> createState() => _DebouncedInputState();
}

class _DebouncedInputState extends State<_DebouncedInput> {
  Timer? timer;
  String settled = '';
  void changed() {
    timer?.cancel();
    timer = Timer(
        Duration(
            milliseconds:
                (ThemeConfig.values['performance']['inputDebounceMs'] as num)
                    .toInt()), () {
      settled = widget.controller.text.trim();
      developer.Timeline.instantSync('chat_draft_settled',
          arguments: {'characters': settled.length});
    });
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(changed);
  }

  @override
  void didUpdateWidget(covariant _DebouncedInput old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(changed);
      widget.controller.addListener(changed);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    widget.controller.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _HistoryBoundary extends StatefulWidget {
  final int fingerprint;
  final Widget Function() builder;
  const _HistoryBoundary({required this.fingerprint, required this.builder});
  @override
  State<_HistoryBoundary> createState() => _HistoryBoundaryState();
}

class _HistoryBoundaryState extends State<_HistoryBoundary> {
  Widget? cached;
  @override
  void didUpdateWidget(covariant _HistoryBoundary old) {
    super.didUpdateWidget(old);
    if (old.fingerprint != widget.fingerprint) cached = null;
  }

  @override
  Widget build(BuildContext context) => cached ??= widget.builder();
}
