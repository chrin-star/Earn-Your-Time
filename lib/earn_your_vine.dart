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
      0,
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
    final growth = _vineGrowth(widget.productiveSeconds);
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
                  final worldHeight = math.max(constraints.maxHeight, growth + 160).toDouble();
                  final painter = _VineWorldPainter(
                    hours: hours,
                    growth: growth,
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
    if (h > 0) return '$h h ${m.toString().padLeft(2, '0')} min';
    return '$m min';
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

double _vineGrowth(int productiveSeconds) {
  // Logarithmic height keeps the world growing for years without an
  // unmanageably large canvas. Early productive time is deliberately dramatic.
  return 80 + 850 * math.log(1 + productiveSeconds / 60);
}

class _VineWorldPainter extends CustomPainter {
  _VineWorldPainter({required this.hours, required this.growth});
  final double hours;
  final double growth;
  final Paint _paint = Paint()..isAntiAlias = true;

  static const _milestones = [0.0, 2.0, 8.0, 25.0, 60.0, 120.0, 250.0];
  static const _sky = [
    [Color(0xFF101A38), Color(0xFF263B65)],
    [Color(0xFF493C68), Color(0xFFF3A06D)],
    [Color(0xFF72C8E8), Color(0xFFB8E9D1)],
    [Color(0xFF55A9D5), Color(0xFFB5E8F4)],
    [Color(0xFF276C9E), Color(0xFF173B70)],
    [Color(0xFF101A3D), Color(0xFF30245F)],
    [Color(0xFF171A43), Color(0xFF523A79)],
  ];

  Color _mix(Color a, Color b, double t) =>
      Color.lerp(a, b, t.clamp(0.0, 1.0))!;

  void _oval(Canvas c, Rect r, Color color) {
    _paint
      ..shader = null
      ..color = color
      ..style = PaintingStyle.fill;
    c.drawOval(r, _paint);
  }

  void _drawLeaf(Canvas c, Offset base, double angle, double scale,
      {Color color = const Color(0xFF49A968)}) {
    c.save();
    c.translate(base.dx, base.dy);
    c.rotate(angle);
    final leaf = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(12 * scale, -22 * scale, 43 * scale, -17 * scale)
      ..quadraticBezierTo(39 * scale, 7 * scale, 0, 0)
      ..close();
    _paint
      ..shader = null
      ..color = const Color(0xFF286344)
      ..style = PaintingStyle.fill;
    c.drawPath(leaf.shift(const Offset(0, 3)), _paint);
    _paint.color = color;
    c.drawPath(leaf, _paint);
    _paint
      ..color = const Color(0x889DE28A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, 2.5 * scale);
    c.drawLine(Offset(4 * scale, -1 * scale),
        Offset(34 * scale, -13 * scale), _paint);
    _paint.style = PaintingStyle.fill;
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rootY = h - 86.0;
    final tipY = rootY - growth;
    final stage = _milestones.lastIndexWhere((v) => hours >= v).clamp(0, 5).toInt();
    final span = _milestones[stage + 1] - _milestones[stage];
    final blend = ((hours - _milestones[stage]) / span).clamp(0.0, 1.0);
    final top = _mix(_sky[stage][0], _sky[stage + 1][0], blend);
    final bottom = _mix(_sky[stage][1], _sky[stage + 1][1], blend);

    _paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, _mix(top, bottom, .48), bottom],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, _paint);
    _paint.shader = null;

    final random = math.Random(781);
    // The sky continues behind the entire climb, not just a small island.
    if (hours < 8) {
      for (int i = 0; i < (h / 45).ceil().clamp(30, 500); i++) {
        final x = random.nextDouble() * w;
        final y = random.nextDouble() * h;
        final r = .8 + random.nextDouble() * 1.8;
        _oval(canvas, Rect.fromCircle(center: Offset(x, y), radius: r),
            Colors.white.withValues(alpha: .3 + random.nextDouble() * .55));
      }
      if (hours > 2) {
        _oval(canvas, Rect.fromLTWH(w * .73, tipY + 160, 100, 100),
            const Color(0x55FFE7B2));
        _oval(canvas, Rect.fromLTWH(w * .76, tipY + 175, 68, 68),
            const Color(0xFFFFE6B0));
      }
    } else {
      _oval(canvas, Rect.fromLTWH(w * .70, tipY + 130, 130, 130),
          const Color(0x44FFF1C2));
      _oval(canvas, Rect.fromLTWH(w * .74, tipY + 150, 78, 78),
          const Color(0xFFFFE7A3));
    }

    if (hours >= 25) {
      final cloudSpacing = 540.0;
      for (double y = tipY + 360; y < rootY; y += cloudSpacing) {
        final x = (math.sin(y / 700) * .25 + .5) * (w - 150);
        _oval(canvas, Rect.fromLTWH(x, y, 150, 35),
            const Color(0x66FFFFFF));
        _oval(canvas, Rect.fromLTWH(x + 32, y - 24, 88, 58),
            const Color(0x77FFFFFF));
        _oval(canvas, Rect.fromLTWH(x + 84, y - 7, 96, 38),
            const Color(0x66FFFFFF));
      }
    }

    if (hours >= 120) {
      for (int i = 0; i < (h / 36).ceil().clamp(30, 600); i++) {
        final x = random.nextDouble() * w;
        final y = random.nextDouble() * h;
        _oval(canvas, Rect.fromCircle(
          center: Offset(x, y), radius: .8 + random.nextDouble() * 1.7),
          Colors.white.withValues(alpha: .25 + random.nextDouble() * .6));
      }
      for (double y = tipY + 700; y < rootY; y += 1900) {
        final x = w * (.18 + (math.sin(y / 800) + 1) * .28);
        _oval(canvas, Rect.fromLTWH(x, y, 100, 100),
            const Color(0xFF6979C8));
        _oval(canvas, Rect.fromLTWH(x - 10, y - 10, 100, 100),
            const Color(0xFF9A8AD2));
      }
    }

    // Soft distant scenery gives scale to the climb.
    for (double y = tipY + 420; y < rootY; y += 1250) {
      final layer = Path()
        ..moveTo(0, y + 170)
        ..quadraticBezierTo(w * .22, y - 30, w * .48, y + 150)
        ..quadraticBezierTo(w * .76, y - 50, w, y + 130)
        ..lineTo(w, y + 260)
        ..lineTo(0, y + 260)
        ..close();
      _paint
        ..color = hours >= 8
            ? const Color(0x334B8D77)
            : const Color(0x223D456F)
        ..style = PaintingStyle.fill;
      canvas.drawPath(layer, _paint);
    }

    // Main stem: broad, shaded and organic, like a giant beanstalk.
    final stem = Path()..moveTo(w * .50, rootY);
    const sections = 34;
    for (int i = 1; i <= sections; i++) {
      final t0 = (i - 1) / sections;
      final t1 = i / sections;
      final y0 = rootY - growth * t0;
      final y1 = rootY - growth * t1;
      final x0 = w * .5 + math.sin(t0 * math.pi * 5.4) * w * .115;
      final x1 = w * .5 + math.sin(t1 * math.pi * 5.4) * w * .115;
      stem.cubicTo(
        x0 + math.cos(t0 * math.pi * 5.4) * w * .10, y0 - growth / sections * .32,
        x1 - math.cos(t1 * math.pi * 5.4) * w * .10, y1 + growth / sections * .32,
        x1, y1,
      );
    }
    _paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF174D3C)
      ..strokeWidth = 43;
    canvas.drawPath(stem, _paint);
    _paint
      ..color = const Color(0xFF348653)
      ..strokeWidth = 34;
    canvas.drawPath(stem, _paint);
    _paint
      ..color = const Color(0xFF69B96B)
      ..strokeWidth = 12;
    canvas.drawPath(stem, _paint);
    _paint.style = PaintingStyle.fill;

    // Large side branches and paired leaves, spaced along the full plant.
    final branchCount = (growth / 190).ceil().clamp(1, 220);
    for (int i = 0; i < branchCount; i++) {
      final t = (i + .5) / branchCount;
      final y = rootY - growth * t;
      final x = w * .5 + math.sin(t * math.pi * 5.4) * w * .115;
      final side = i.isEven ? -1.0 : 1.0;
      final reach = w * (.20 + .035 * math.sin(i * 2.1));
      final branch = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x + side * reach * .55, y - 18,
            x + side * reach, y - 65);
      _paint
        ..color = const Color(0xFF286344)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(branch, _paint);
      _paint
        ..color = const Color(0xFF58A968)
        ..strokeWidth = 9;
      canvas.drawPath(branch, _paint);
      _paint.style = PaintingStyle.fill;
      _drawLeaf(canvas, Offset(x + side * reach * .40, y - 20),
          side * -.55, 1.05 + (i % 3) * .18,
          color: i % 4 == 0
              ? const Color(0xFF85CE72)
              : const Color(0xFF49A968));
      _drawLeaf(canvas, Offset(x + side * reach * .82, y - 58),
          side * -.12, 1.15 + (i % 2) * .18,
          color: const Color(0xFF63B96C));
      if (i % 5 == 2) {
        _drawLeaf(canvas, Offset(x - side * 8, y - 5),
            -side * 2.1, .92, color: const Color(0xFF9BD77C));
      }
      if (i % 9 == 4 && hours >= 8) {
        _oval(canvas, Rect.fromLTWH(x + side * reach, y - 84, 17, 17),
            const Color(0xFFFFD77C));
      }
    }

    // Small settlements and treetops appear much later along the giant vine.
    if (hours >= 8) {
      final places = (growth / 1050).floor().clamp(1, 80);
      for (int i = 0; i < places; i++) {
        final t = (i + 1) / (places + 1);
        final y = rootY - growth * t;
        final x = w * (i.isEven ? .16 : .76);
        _paint.color = const Color(0xFF76523C);
        canvas.drawRect(Rect.fromLTWH(x + 12, y - 28, 9, 30), _paint);
        _oval(canvas, Rect.fromLTWH(x - 4, y - 62, 42, 43),
            const Color(0xFF3E965E));
        if (i % 2 == 1) {
          final house = Path()
            ..moveTo(x - 5, y - 23)
            ..lineTo(x + 16, y - 49)
            ..lineTo(x + 39, y - 23)
            ..close();
          _paint.color = const Color(0xFFB95E50);
          canvas.drawPath(house, _paint);
          _paint.color = const Color(0xFFFFDDA9);
          canvas.drawRect(Rect.fromLTWH(x + 1, y - 23, 30, 21), _paint);
          _paint.color = const Color(0xFF76523C);
          canvas.drawRect(Rect.fromLTWH(x + 12, y - 15, 8, 13), _paint);
        }
      }
    }

    // Root mound and the first seed remain at the very bottom.
    final mound = Path()
      ..moveTo(0, rootY + 12)
      ..quadraticBezierTo(w * .5, rootY - 72, w, rootY + 12)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    _paint.color = const Color(0xFF5A493D);
    canvas.drawPath(mound, _paint);
    final grass = Path()
      ..moveTo(0, rootY + 12)
      ..quadraticBezierTo(w * .5, rootY - 72, w, rootY + 12)
      ..lineTo(w, rootY + 48)
      ..quadraticBezierTo(w * .5, rootY - 34, 0, rootY + 48)
      ..close();
    _paint.color = const Color(0xFF72A95D);
    canvas.drawPath(grass, _paint);
    _oval(canvas, Rect.fromLTWH(w * .5 - 20, rootY - 22, 40, 38),
        const Color(0xFF9B7046));
    _oval(canvas, Rect.fromLTWH(w * .5 - 12, rootY - 19, 24, 24),
        const Color(0xFFD8B078));
  }

  @override
  bool shouldRepaint(covariant _VineWorldPainter old) =>
      old.hours != hours || old.growth != growth;
}
