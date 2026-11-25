import 'dart:math' as math;
import 'package:flutter/material.dart';

class EarnYourVineView extends StatefulWidget {
  const EarnYourVineView({super.key, required this.productiveSeconds});
  final int productiveSeconds;

  @override
  State<EarnYourVineView> createState() => _EarnYourVineViewState();
}

class _EarnYourVineViewState extends State<EarnYourVineView> {
  final ScrollController _scroll = ScrollController();
  bool _firstLayout = true;

  @override
  void didUpdateWidget(covariant EarnYourVineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productiveSeconds != widget.productiveSeconds) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _followTip());
    }
  }

  void _followTip() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = widget.productiveSeconds / 3600;
    final stage = _stageFor(hours);
    final next = _nextMilestone(hours);
    final remaining = next == null ? null : ((next - hours) * 3600).ceil();
    final worldHeight = (760 + (100 + math.sqrt(hours) * 155) * 1.35)
        .clamp(760.0, 5600.0).toDouble();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stage.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
                    const SizedBox(height: 3),
                    Text(stage.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatTime(widget.productiveSeconds),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
                    Text('tiempo productivo',
                      style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final painter = _VineWorldPainter(
                    hours: hours,
                    worldHeight: worldHeight,
                  );
                  final world = SizedBox(
                    width: constraints.maxWidth,
                    height: worldHeight,
                    child: CustomPaint(painter: painter),
                  );
                  if (_firstLayout) {
                    _firstLayout = false;
                    WidgetsBinding.instance.addPostFrameCallback((_) => _followTip());
                  }
                  return Stack(
                    children: [
                      SingleChildScrollView(
                        controller: _scroll,
                        physics: const BouncingScrollPhysics(),
                        child: world,
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xAA102A31),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.swipe_vertical_rounded,
                                    color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text('Desliza para explorar',
                                    style: TextStyle(color: Colors.white,
                                      fontSize: 11, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Material(
                          color: const Color(0xCC102A31),
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: _followTip,
                            child: const Padding(
                              padding: EdgeInsets.all(11),
                              child: Icon(Icons.north_rounded,
                                color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: Row(
            children: [
              const Icon(Icons.eco_rounded, color: Color(0xFF62B879), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  remaining == null
                    ? 'Tu enredadera sigue creciendo. No hay un límite.'
                    : 'Próximo cambio de entorno en ${_formatTime(remaining)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h} h ${m.toString().padLeft(2, '0')} min';
    return '${m} min';
  }

  static _VineStage _stageFor(double hours) {
    if (hours < 2) return const _VineStage('Una nueva semilla', 'Todo comienza en la oscuridad');
    if (hours < 8) return const _VineStage('El primer brote', 'La noche empieza a dar paso al amanecer');
    if (hours < 25) return const _VineStage('El jardín despierta', 'La enredadera empieza a llenar de vida su mundo');
    if (hours < 60) return const _VineStage('Por encima de las nubes', 'Tu planta alcanza nuevas alturas');
    if (hours < 120) return const _VineStage('El cielo infinito', 'Cada vez más cerca de las estrellas');
    if (hours < 250) return const _VineStage('Entre las estrellas', 'La enredadera ya toca el espacio');
    return const _VineStage('Nuevos mundos', 'La aventura continúa más allá de los planetas');
  }

  static double? _nextMilestone(double hours) {
    for (final milestone in const [2.0, 8.0, 25.0, 60.0, 120.0, 250.0]) {
      if (hours < milestone) return milestone;
    }
    return null;
  }
}

class _VineStage {
  const _VineStage(this.name, this.subtitle);
  final String name;
  final String subtitle;
}

class _VineWorldPainter extends CustomPainter {
  _VineWorldPainter({required this.hours, required this.worldHeight});
  final double hours;
  final double worldHeight;
  final Paint _p = Paint()..isAntiAlias = true;

  static const _milestones = [0.0, 2.0, 8.0, 25.0, 60.0, 120.0, 250.0];
  static const _palettes = [
    [Color(0xFF101A38), Color(0xFF263B65)],
    [Color(0xFF453B70), Color(0xFFF2A16D)],
    [Color(0xFF75C9E8), Color(0xFFB8E9D1)],
    [Color(0xFF55A9D5), Color(0xFFB5E8F4)],
    [Color(0xFF276C9E), Color(0xFF173B70)],
    [Color(0xFF101A3D), Color(0xFF30245F)],
    [Color(0xFF171A43), Color(0xFF523A79)],
  ];

  Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0.0, 1.0))!;



  void _fill(Canvas c, Rect r, Color color) {
    _p..shader = null..color = color..style = PaintingStyle.fill;
    c.drawRect(r, _p);
  }

  void _oval(Canvas c, Rect r, Color color) {
    _p..shader = null..color = color..style = PaintingStyle.fill;
    c.drawOval(r, _p);
  }

  void _path(Canvas c, Path path, Color color) {
    _p..shader = null..color = color..style = PaintingStyle.fill;
    c.drawPath(path, _p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final baseY = height - 118.0;
    final growth = (105 + math.sqrt(hours) * 155).clamp(105.0, height - 260).toDouble();
    final tipY = baseY - growth;
    final stageIndex = _milestones.lastIndexWhere((v) => hours >= v).clamp(0, 5).toInt();
    final span = _milestones[stageIndex + 1] - _milestones[stageIndex];
    final blend = ((hours - _milestones[stageIndex]) / span).clamp(0.0, 1.0);

    final top = _mix(_palettes[stageIndex][0], _palettes[stageIndex + 1][0], blend);
    final bottom = _mix(_palettes[stageIndex][1], _palettes[stageIndex + 1][1], blend);
    _p.shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [top, _mix(top, bottom, .45), bottom],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, _p);
    _p.shader = null;

    final random = math.Random(41);
    if (hours < 8) {
      for (int i = 0; i < 95; i++) {
        final x = random.nextDouble() * width;
        final y = random.nextDouble() * (height * .72);
        final radius = 0.8 + random.nextDouble() * 1.6;
        _oval(canvas, Rect.fromCircle(center: Offset(x, y), radius: radius),
          Colors.white.withValues(alpha: .28 + random.nextDouble() * .55));
      }
      if (hours > 2) {
        _oval(canvas, Rect.fromLTWH(width * .72, height * .12, 42, 42),
          const Color(0xFFFFE6B0));
        _oval(canvas, Rect.fromLTWH(width * .75, height * .105, 42, 42),
          top);
      }
    } else {
      // Sunlight and distant atmospheric glow.
      _oval(canvas, Rect.fromLTWH(width * .72, height * .10, 76, 76),
        const Color(0x44FFF1C2));
      _oval(canvas, Rect.fromLTWH(width * .77, height * .13, 42, 42),
        const Color(0xFFFFE7A3));
    }

    if (hours >= 25) {
      final cloudY = height * .34;
      for (int i = 0; i < 5; i++) {
        final x = (i * width * .27 + (i.isEven ? 0 : width * .12)) % (width + 120) - 60;
        _oval(canvas, Rect.fromLTWH(x, cloudY + (i % 2) * 90, 150, 34),
          const Color(0x66FFFFFF));
        _oval(canvas, Rect.fromLTWH(x + 30, cloudY - 15 + (i % 2) * 90, 85, 52),
          const Color(0x77FFFFFF));
      }
    }
    if (hours >= 120) {
      for (int i = 0; i < 100; i++) {
        final x = random.nextDouble() * width;
        final y = random.nextDouble() * height * .65;
        final radius = .7 + random.nextDouble() * 1.5;
        _oval(canvas, Rect.fromCircle(center: Offset(x, y), radius: radius),
          Colors.white.withValues(alpha: .25 + random.nextDouble() * .6));
      }
    }
    if (hours >= 250) {
      _oval(canvas, Rect.fromLTWH(width * .08, height * .20, 96, 96),
        const Color(0xFF9A8AD2));
      _oval(canvas, Rect.fromLTWH(width * .04, height * .18, 96, 96),
        const Color(0xFF5D6FC1));
      _oval(canvas, Rect.fromLTWH(width * .70, height * .55, 132, 132),
        const Color(0xFF4E9B8C));
      _oval(canvas, Rect.fromLTWH(width * .67, height * .52, 132, 132),
        const Color(0xFF75BBA0));
    }

    // Distant floating islands, trees and cottages appear as the vine matures.
    if (hours >= 8) {
      final count = (hours / 8).floor().clamp(1, 12);
      for (int i = 0; i < count; i++) {
        final y = baseY - 90 - i * (growth / (count + 1));
        final x = width * (.18 + ((i * 37) % 67) / 100);
        _oval(canvas, Rect.fromLTWH(x - 30, y + 28, 72, 12),
          const Color(0x44314D45));
        _path(canvas, Path()
          ..moveTo(x - 38, y + 12)..lineTo(x - 25, y - 8)
          ..lineTo(x + 23, y - 8)..lineTo(x + 38, y + 12)
          ..close(), const Color(0xFF568A53));
        _fill(canvas, Rect.fromLTWH(x - 5, y - 32, 10, 26),
          const Color(0xFF795239));
        _oval(canvas, Rect.fromLTWH(x - 22, y - 62, 46, 42),
          const Color(0xFF398B59));
        if (i % 3 == 1) {
          _path(canvas, Path()
            ..moveTo(x - 19, y - 8)..lineTo(x, y - 31)
            ..lineTo(x + 22, y - 8)..close(), const Color(0xFFCA7056));
          _fill(canvas, Rect.fromLTWH(x - 15, y - 8, 31, 21),
            const Color(0xFFFFE0AE));
          _fill(canvas, Rect.fromLTWH(x - 4, y + 1, 8, 12),
            const Color(0xFF8A6045));
        }
      }
    }

    // The main vine winds continuously from its rooted seed to the growing tip.
    final vine = Path()..moveTo(width * .5, baseY - 18);
    final segments = 9;
    for (int i = 1; i <= segments; i++) {
      final t = i / segments;
      final y = baseY - 18 - growth * t;
      final x = width * .5 + math.sin(t * math.pi * 4.2) * width * .105;
      final previousT = (i - 1) / segments;
      final previousY = baseY - 18 - growth * previousT;
      final previousX = width * .5 + math.sin(previousT * math.pi * 4.2) * width * .105;
      vine.cubicTo(previousX + width * .10, previousY - growth / segments * .28,
          x - width * .10, y + growth / segments * .28, x, y);
    }
    _p
      ..shader = null
      ..color = const Color(0xFF286344)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(vine, _p);
    _p
      ..color = const Color(0xFF64B96E)
      ..strokeWidth = 9;
    canvas.drawPath(vine, _p);
    _p.style = PaintingStyle.fill;

    // Leaves and occasional blossoms are attached to the vine.
    final leaves = (growth / 27).floor().clamp(2, 90);
    for (int i = 0; i < leaves; i++) {
      final t = (i + 1) / (leaves + 1);
      final y = baseY - 24 - growth * t;
      final x = width * .5 + math.sin(t * math.pi * 4.2) * width * .105;
      final side = i.isEven ? -1.0 : 1.0;
      canvas.save();
      canvas.translate(x + side * 9, y);
      canvas.rotate(side * -.48);
      _oval(canvas, Rect.fromLTWH(side < 0 ? -28 : 0, -10, 29, 17),
        i % 4 == 0 ? const Color(0xFF9BD77C) : const Color(0xFF4EAD68));
      _oval(canvas, Rect.fromLTWH(side < 0 ? -23 : 5, -7, 15, 8),
        const Color(0xFFBDE89B));
      canvas.restore();
      if (i % 11 == 0 && hours >= 8) {
        _oval(canvas, Rect.fromLTWH(x + side * 25, y - 8, 9, 9),
          const Color(0xFFFFD77C));
      }
    }

    // The seed and a patch of living soil remain at the bottom of the journey.
    _oval(canvas, Rect.fromLTWH(width * .18, baseY + 46, width * .64, 34),
      const Color(0x553B3444));
    _path(canvas, Path()
      ..moveTo(0, baseY + 18)..quadraticBezierTo(width * .5, baseY - 4, width, baseY + 18)
      ..lineTo(width, height)..lineTo(0, height)..close(),
      const Color(0xFF5A493D));
    _path(canvas, Path()
      ..moveTo(0, baseY + 18)..quadraticBezierTo(width * .5, baseY - 5, width, baseY + 18)
      ..lineTo(width, baseY + 40)..quadraticBezierTo(width * .5, baseY + 17, 0, baseY + 40)
      ..close(), const Color(0xFF72A95D));
    if (hours < 2) {
      _oval(canvas, Rect.fromLTWH(width * .5 - 13, baseY - 24, 26, 25),
        const Color(0xFFB98A58));
      _oval(canvas, Rect.fromLTWH(width * .5 - 7, baseY - 22, 14, 15),
        const Color(0xFFD7B078));
    } else {
      _path(canvas, Path()
        ..moveTo(width * .5, baseY - 20)
        ..quadraticBezierTo(width * .5 - 20, baseY - 45, width * .5 - 8, baseY - 58)
        ..quadraticBezierTo(width * .5 + 2, baseY - 42, width * .5, baseY - 20)
        ..close(), const Color(0xFF5EB96B));
      _oval(canvas, Rect.fromLTWH(width * .5 - 5, baseY - 35, 10, 15),
        const Color(0xFF9DDD82));
    }
  }

  @override
  bool shouldRepaint(covariant _VineWorldPainter old) =>
      old.hours != hours || old.worldHeight != worldHeight;
}
