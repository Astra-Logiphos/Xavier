import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'appearance.dart';
import 'theme_config.dart';

Color configuredColor(String value) => Color(int.parse(value.replaceFirst('#', 'ff'), radix: 16));

class AmbientBackground extends StatefulWidget {
  final Appearance appearance;
  const AmbientBackground({super.key, required this.appearance});
  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}
class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController clock;
  bool foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    clock = AnimationController(vsync: this, duration: Duration(seconds: ThemeConfig.number('animation', 'cycleSeconds').round()));
  }
  void sync() {
    if (widget.appearance.animated && foreground && TickerMode.of(context) && (ModalRoute.of(context)?.isCurrent ?? true)) {
      if (!clock.isAnimating) clock.repeat();
    } else { clock.stop(); }
  }
  @override
  void didChangeDependencies() { super.didChangeDependencies(); sync(); }
  @override
  void didUpdateWidget(covariant AmbientBackground oldWidget) { super.didUpdateWidget(oldWidget); sync(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { foreground = state == AppLifecycleState.resumed; sync(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); clock.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: clock, builder: (context, child) => Stack(fit: StackFit.expand, children: [
    CustomPaint(painter: AmbientPainter(widget.appearance, clock.value)),
    if (widget.appearance.backgroundPath != null) Image.file(File(widget.appearance.backgroundPath!), fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
    ColoredBox(color: widget.appearance.skinColor('background').withOpacity(widget.appearance.overlay)),
  ]));
}

class AmbientPainter extends CustomPainter {
  final Appearance appearance;
  final double time;
  AmbientPainter(this.appearance, this.time);
  @override
  void paint(Canvas canvas, Size size) {
    final theme = appearance.background;
    final colors = (theme['colors'] as List).map((value) => configuredColor(value as String)).toList();
    canvas.drawRect(Offset.zero & size, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors).createShader(Offset.zero & size));
    if(theme['motion']=='reflection') {
      final water=size.height*(theme['waterline'] as num);
      final bottom=Rect.fromLTRB(0,water,size.width,size.height);
      canvas.drawRect(bottom,Paint()..shader=LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:colors.reversed.toList()).createShader(bottom));
    }
    if (appearance.backgroundPath != null) return;
    final primary = theme['primary'] as String;
    if (primary != 'none') _paintPlugin(primary, canvas, size, theme);
    final secondary = theme['secondary'] as String?;
    if (secondary == 'birds') {
      final period = (theme['meteorPeriod'] as num).toDouble();
      final phase = (time * ThemeConfig.number('animation', 'cycleSeconds') / period) % 1;
      if (phase < (theme['meteorVisibleFraction'] as num)) {
        final x = phase / (theme['meteorVisibleFraction'] as num) * size.width;
        final paint = Paint()..color = appearance.skinColor('text').withOpacity((theme['secondaryOpacity'] as num).toDouble())
          ..style = PaintingStyle.stroke..strokeWidth = (theme['strokeWidth'] as num).toDouble();
        final wing = (theme['size'] as num).toDouble();
        final y = size.height * (theme['waterline'] as num);
        final path = Path()..moveTo(x-wing, y)..quadraticBezierTo(x-wing/2, y-wing, x, y)..quadraticBezierTo(x+wing/2, y-wing, x+wing, y);
        canvas.drawPath(path, paint);
      }
    } else if (secondary != null) { _paintPlugin(secondary, canvas, size, theme); }
  }
  void _paintPlugin(String type, Canvas canvas, Size size, Map<String, dynamic> theme) {
    final config = appearance.pluginConfig(type);
    if (config['enabled'] != true) return;
    final plugin = DecorationPlugin.registry[type];
    plugin?.paint(canvas, size, time, config, theme);
  }
  @override
  bool shouldRepaint(covariant AmbientPainter oldDelegate) => true;
}
abstract class DecorationPlugin {
  const DecorationPlugin();
  static const registry = <String, DecorationPlugin>{'stars': StarPlugin(), 'flowers': FlowerPlugin(), 'petals': PetalPlugin(), 'meteors': MeteorPlugin(), 'dust': DustPlugin()};
  void paint(Canvas canvas, Size size, double time, Map<String, dynamic> config, Map<String, dynamic> theme);
  void particles(Canvas canvas, Size size, double time, Map<String, dynamic> config, Map<String, dynamic> theme,
      void Function(Canvas, double, Paint, double) draw) {
    final count = (config['count'] as num).round();
    for (var index = 0; index < count; index++) {
      final random = math.Random((config['seed'] as num).round() + index);
      final phase = random.nextDouble() * (config['rotation'] as num);
      final speed = (config['speed'] as num).toDouble();
      final motion = theme['motion'];
      final x = random.nextDouble() + math.sin(time * (config['rotation'] as num) + phase) * (config['sway'] as num);
      final y = (random.nextDouble() + (motion == 'fall' || motion == 'starfruit' ? time * speed : -time * speed)) % 1;
      final colors = (theme['particleColors'] as List).cast<String>();
      final opacity = (config['opacity'] as num).toDouble() * (motion == 'bloom' ? math.sin(phase + time * (config['rotation'] as num)).abs() : 1);
      final paint = Paint()..color = configuredColor(colors[index % colors.length]).withOpacity(opacity.clamp(0,1));
      canvas.save(); canvas.translate(x * size.width, y * size.height);
      canvas.rotate(time * (config['rotation'] as num) * speed + phase);
      draw(canvas, (config['size'] as num).toDouble(), paint, opacity);
      canvas.restore();
    }
  }
}
class StarPlugin extends DecorationPlugin {
  const StarPlugin();
  @override
  void paint(Canvas canvas, Size size, double time, Map<String, dynamic> config, Map<String, dynamic> theme) => particles(canvas,size,time,config,theme,(c,r,p,a) {
    final path = Path()..moveTo(0,-r)..lineTo(r/4,0)..lineTo(0,r)..lineTo(-r/4,0)..close();
    c.drawPath(path,p);
  });
}
class FlowerPlugin extends DecorationPlugin {
  const FlowerPlugin();
  @override
  void paint(Canvas canvas, Size size, double time, Map<String, dynamic> config, Map<String, dynamic> theme) => particles(canvas,size,time,config,theme,(c,r,p,a) {
    if (theme['motion'] == 'bloom') c.drawCircle(Offset.zero,r,Paint()..color=p.color..maskFilter=MaskFilter.blur(BlurStyle.normal,r*(config['glowBlur'] as num)));
    final petals = (config['petals'] as num).round();
    for (var i=0;i<petals;i++) {
      c.save(); c.rotate(i*math.pi*2/petals); c.drawOval(Rect.fromLTRB(-r/3,-r,r/3,0),p); c.restore();
    }
    c.drawCircle(Offset.zero,r/4,Paint()..color=configuredColor(config['centerColor'] as String).withOpacity(a.clamp(0,1)));
  });
}
class PetalPlugin extends DecorationPlugin {
  const PetalPlugin();
  @override
  void paint(Canvas canvas, Size size, double time, Map<String, dynamic> config, Map<String, dynamic> theme) => particles(canvas,size,time,config,theme,(c,r,p,a) {
    if (theme['motion']=='starfruit') {
      final path=Path(); final points=(config['petals'] as num).round()*2;
      for(var i=0;i<points;i++) {final radius=i.isEven?r:r/2;final angle=i*math.pi*2/points; final point=Offset(math.cos(angle)*radius,math.sin(angle)*radius); if(i==0){path.moveTo(point.dx,point.dy);}else{path.lineTo(point.dx,point.dy);}}
      path.close(); c.drawPath(path,p);
    } else {c.drawOval(Rect.fromLTRB(-r/2,-r,r/2,r),p);}
  });
}
class DustPlugin extends DecorationPlugin {
  const DustPlugin();
  @override
  void paint(Canvas canvas, Size size, double time, Map<String, dynamic> config, Map<String, dynamic> theme) => particles(canvas,size,time,config,theme,(c,r,p,a)=>c.drawCircle(Offset.zero,r,p));
}
class MeteorPlugin extends DecorationPlugin {
  const MeteorPlugin();
  @override
  void paint(Canvas canvas, Size size, double time, Map<String, dynamic> config, Map<String, dynamic> theme) {
    final seconds=time*ThemeConfig.number('animation','cycleSeconds');
    for(var i=0;i<(config['count'] as num).round();i++) {
      final random=math.Random((config['seed'] as num).round()+i);
      final phase=(seconds/(theme['meteorPeriod'] as num)+random.nextDouble())%1;
      final visible=(theme['meteorVisibleFraction'] as num).toDouble(); if(phase>visible)continue;
      final progress=phase/visible;
      final start=Offset(random.nextDouble()*size.width,random.nextDouble()*size.height*(theme['waterline'] as num));
      final end=Offset(start.dx+progress*size.width*(config['sway'] as num)*config['size'],start.dy+progress*size.height*(config['speed'] as num));
      final color=configuredColor((theme['particleColors'] as List).first as String);
      final paint=Paint()..color=color.withOpacity(((config['opacity'] as num)*(1-progress)).clamp(0,1).toDouble())..strokeWidth=(config['strokeWidth'] as num).toDouble()..style=PaintingStyle.stroke;
      if(theme['motion']=='arc') {final path=Path()..moveTo(start.dx,start.dy)..quadraticBezierTo(start.dx,end.dy,end.dx,end.dy);canvas.drawPath(path,paint);}else{canvas.drawLine(start,end,paint);}
      if(theme['motion']=='reflection') {final water=size.height*(theme['waterline'] as num);paint.color=color.withOpacity((theme['reflectionOpacity'] as num).toDouble()*(1-progress));canvas.drawLine(Offset(start.dx,water+(water-start.dy)),Offset(end.dx,water+(water-end.dy)),paint);}
    }
  }
}
