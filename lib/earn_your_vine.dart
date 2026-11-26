import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class EarnYourVineView extends StatefulWidget {
  const EarnYourVineView({super.key, required this.productiveSeconds});
  final int productiveSeconds;

  @override
  State<EarnYourVineView> createState() => _EarnYourVineViewState();
}

class _EarnYourVineViewState extends State<EarnYourVineView> {
  final ScrollController _scroll = ScrollController();
  bool _firstLayout = true;
  final Set<String> _ownedItems = <String>{};
  int _spentCoins = 0;
  bool _shopLoaded = false;
  static const MethodChannel _shopChannel = MethodChannel('focusfeed/earn_time');
  static const List<Map<String, Object>> _shopItems = [
    {'id': 'pink_blossoms', 'name': 'Flores rosadas', 'description': 'Una variante delicada para las flores de tu enredadera.', 'price': 3, 'icon': Icons.local_florist_rounded},
    {'id': 'blue_blossoms', 'name': 'Flores azules', 'description': 'Flores de tonos azules para las ramas maduras.', 'price': 4, 'icon': Icons.spa_rounded},
    {'id': 'butterflies', 'name': 'Mariposas', 'description': 'Pequeñas mariposas que visitan las ramas con flores.', 'price': 6, 'icon': Icons.flutter_dash_rounded},
    {'id': 'glowing_fruit', 'name': 'Frutos luminosos', 'description': 'Un brillo sutil alrededor de los frutos que vayan apareciendo.', 'price': 8, 'icon': Icons.auto_awesome_rounded},
  ];

  int get _earnedCoins => widget.productiveSeconds ~/ 600;
  int get _coinBalance => math.max(0, _earnedCoins - _spentCoins);
  int get _heightMeters => (850 * math.log(1 + widget.productiveSeconds / 60) / 10).floor();

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  Future<void> _loadShop() async {
    try {
      final raw = await _shopChannel.invokeMethod<String>('loadVineShop');
      final data = jsonDecode(raw ?? '{}') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _spentCoins = (data['spentCoins'] as num?)?.toInt() ?? 0;
        _ownedItems
          ..clear()
          ..addAll((data['ownedItems'] as List<dynamic>? ?? const []).whereType<String>());
        _shopLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _shopLoaded = true);
    }
  }

  Future<bool> _saveShop(Set<String> owned, int spent) async {
    try {
      final ok = await _shopChannel.invokeMethod<bool>('saveVineShop', {
        'state': jsonEncode({'spentCoins': spent, 'ownedItems': owned.toList()}),
      });
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _buyShopItem(Map<String, Object> item, StateSetter refreshSheet) async {
    final id = item['id']! as String;
    final price = item['price']! as int;
    if (_ownedItems.contains(id) || _coinBalance < price) return;
    final nextOwned = Set<String>.from(_ownedItems)..add(id);
    final nextSpent = _spentCoins + price;
    final saved = await _saveShop(nextOwned, nextSpent);
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la compra. Inténtalo de nuevo.')),
      );
      return;
    }
    setState(() {
      _ownedItems
        ..clear()
        ..addAll(nextOwned);
      _spentCoins = nextSpent;
    });
    refreshSheet(() {});
  }

  void _openShop() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refreshSheet) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .72),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text('Tienda de la enredadera', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [const Icon(Icons.toll_rounded, size: 18), const SizedBox(width: 6), Text('$_coinBalance', style: const TextStyle(fontWeight: FontWeight.w800))]),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text('Ganas 1 moneda por cada 10 minutos productivos. El tiempo inactivo no genera monedas.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 14),
                  Flexible(child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _shopItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final item = _shopItems[index];
                      final id = item['id']! as String;
                      final price = item['price']! as int;
                      final owned = _ownedItems.contains(id);
                      final canBuy = _coinBalance >= price && !owned && _shopLoaded;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .55), borderRadius: BorderRadius.circular(17)),
                        child: Row(children: [
                          Container(
                            width: 66, height: 66,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Theme.of(context).colorScheme.primaryContainer, Theme.of(context).colorScheme.secondaryContainer],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(child: Icon(
                              item['icon']! as IconData,
                              size: 35,
                              color: id == 'pink_blossoms' ? const Color(0xFFD95F98)
                                : id == 'blue_blossoms' ? const Color(0xFF4789C8)
                                : id == 'butterflies' ? const Color(0xFF9A6CC8)
                                : const Color(0xFFD5A72F),
                            )),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(item['name']! as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(item['description']! as String, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 3),
                            Text(owned ? 'Adquirido · aparecerá al desbloquear su etapa' : 'Vista previa del adorno', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                          ])),
                          const SizedBox(width: 8),
                          if (owned)
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF45A66A))
                          else
                            FilledButton.tonal(
                              onPressed: canBuy ? () => _buyShopItem(item, refreshSheet) : null,
                              child: Text('$price  •'),
                            ),
                        ]),
                      );
                    },
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
              const SizedBox(width: 8),
              Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: _openShop,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.storefront_rounded, size: 17),
                        const SizedBox(width: 4),
                        Text('$_coinBalance', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ]),
                      Text('tienda', style: Theme.of(context).textTheme.labelSmall),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 7),
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
                    ownedItems: Set<String>.unmodifiable(_ownedItems),
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
                  'Altura: $_heightMeters m  ·  ${remaining == null ? 'Crecimiento ilimitado' : 'Próximo entorno en ${_formatTime(remaining)}'}',
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
    if (hours < 1) return const _VineStage('Una nueva semilla', 'Todo comienza en la oscuridad');
    if (hours < 4) return const _VineStage('El primer brote', 'Una pequeña señal de vida bajo la noche');
    if (hours < 12) return const _VineStage('La primera luz', 'El horizonte comienza a iluminarse');
    if (hours < 30) return const _VineStage('A la luz del día', 'La enredadera empieza a fortalecerse');
    if (hours < 80) return const _VineStage('Una planta frondosa', 'Nuevas hojas empiezan a desplegarse');
    if (hours < 160) return const _VineStage('Un jardín en las alturas', 'Aparecen flores y nueva vegetación');
    if (hours < 300) return const _VineStage('Por encima de las nubes', 'El mundo queda cada vez más abajo');
    if (hours < 600) return const _VineStage('Hacia las estrellas', 'La atmósfera comienza a quedar atrás');
    if (hours < 1000) return const _VineStage('Entre las estrellas', 'La enredadera alcanza el espacio');
    return const _VineStage('Nuevos mundos', 'La aventura continúa hacia otros planetas');
  }

  static double? _nextMilestone(double hours) {
    for (final milestone in const [1.0, 4.0, 12.0, 30.0, 80.0, 160.0, 300.0, 600.0, 1000.0]) {
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
  _VineWorldPainter({required this.hours, required this.growth, required this.ownedItems});
  final double hours;
  final double growth;
  final Set<String> ownedItems;
  final Paint _paint = Paint()..isAntiAlias = true;

  static const _milestones = [0.0, 1.0, 4.0, 12.0, 30.0, 80.0, 160.0, 300.0, 600.0, 1000.0];
  static const _sky = [
    [Color(0xFF101A38), Color(0xFF263B65)],
    [Color(0xFF182443), Color(0xFF51466A)],
    [Color(0xFF493C68), Color(0xFFF3A06D)],
    [Color(0xFF72C8E8), Color(0xFFB8E9D1)],
    [Color(0xFF55A9D5), Color(0xFFB5E8F4)],
    [Color(0xFF276C9E), Color(0xFF173B70)],
    [Color(0xFF101A3D), Color(0xFF30245F)],
    [Color(0xFF171A43), Color(0xFF523A79)],
    [Color(0xFF171A43), Color(0xFF523A79)],
    [Color(0xFF201C50), Color(0xFF5D477F)],
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

  void _drawFlower(Canvas c, Offset center, double scale, int variant) {
    c.save();
    c.translate(center.dx, center.dy);
    final petal = ownedItems.contains('blue_blossoms')
        ? const Color(0xFF9DCBFF)
        : ownedItems.contains('pink_blossoms')
            ? const Color(0xFFFFB6D0)
            : variant.isEven
                ? const Color(0xFFFFE9F0)
                : const Color(0xFFFFDDA0);
    for (int p = 0; p < 5; p++) {
      final angle = p * math.pi * 2 / 5;
      c.save();
      c.rotate(angle);
      _oval(c, Rect.fromCenter(
        center: Offset(0, -7 * scale),
        width: 7 * scale, height: 11 * scale,
      ), petal);
      c.restore();
    }
    _oval(c, Rect.fromCircle(
      center: Offset.zero, radius: 3.6 * scale,
    ), const Color(0xFFFFC83D));
    c.restore();
  }

  void _drawFruit(Canvas c, Offset center, double scale, int kind) {
    final colors = [
      const Color(0xFFD94B43), // apple
      const Color(0xFFFFB36B), // peach
      const Color(0xFFE9C84C), // golden pear
      const Color(0xFF9D75D6), // star fruit / exotic fruit
    ];
    final color = colors[kind.clamp(0, colors.length - 1)];
    c.save();
    c.translate(center.dx, center.dy);
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * scale
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF76513A);
    c.drawLine(Offset(0, -5 * scale), Offset(1 * scale, -11 * scale), _paint);
    _paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF64A957);
    final leaf = Path()
      ..moveTo(0, -8 * scale)
      ..quadraticBezierTo(8 * scale, -15 * scale, 10 * scale, -7 * scale)
      ..quadraticBezierTo(5 * scale, -3 * scale, 0, -8 * scale)
      ..close();
    c.drawPath(leaf, _paint);
    _oval(c, Rect.fromCenter(
      center: Offset.zero,
      width: (kind == 2 ? 13 : 15) * scale,
      height: (kind == 2 ? 19 : 15) * scale,
    ), color);
    _oval(c, Rect.fromCircle(
      center: Offset(-3 * scale, -3 * scale), radius: 2 * scale,
    ), const Color(0x66FFFFFF));
    if (ownedItems.contains('glowing_fruit')) {
      _oval(c, Rect.fromCircle(center: Offset.zero, radius: 12 * scale), const Color(0x33FFF4A8));
    }
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rootY = h - 86.0;
    final tipY = rootY - growth;
    final heightMeters = (growth - 80).clamp(0.0, double.infinity) / 10;
    final stage = _milestones.lastIndexWhere((v) => hours >= v).clamp(0, _milestones.length - 2).toInt();
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
    if (hours < 4) {
      for (int i = 0; i < (h / 45).ceil().clamp(30, 500); i++) {
        final x = random.nextDouble() * w;
        final y = random.nextDouble() * h;
        final r = .8 + random.nextDouble() * 1.8;
        _oval(canvas, Rect.fromCircle(center: Offset(x, y), radius: r),
            Colors.white.withValues(alpha: .3 + random.nextDouble() * .55));
      }
      if (hours >= 1) {
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

    if (hours >= 80) {
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

    if (hours >= 600) {
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
    // Layered stem shading: deep edge, living green body and a soft raised ridge.
    // The stem becomes broader and more richly coloured as the plant matures.
    final maturity = (hours / 80).clamp(0.0, 1.0);
    final stemWidth = 25.0 + maturity * 19.0;
    _paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF123F35)
      ..strokeWidth = stemWidth + 12;
    canvas.drawPath(stem, _paint);
    _paint
      ..color = _mix(const Color(0xFF28764C), const Color(0xFF276344), maturity)
      ..strokeWidth = stemWidth;
    canvas.drawPath(stem, _paint);
    _paint
      ..color = _mix(const Color(0xFF63B96B), const Color(0xFF4F9D5D), maturity)
      ..strokeWidth = stemWidth * .57;
    canvas.drawPath(stem, _paint);

    // A narrow off-centre highlight gives the stem a rounded, organic surface.
    final ridge = Path();
    for (int i = 0; i <= 80; i++) {
      final t = i / 80;
      final y = rootY - growth * t;
      final x = w * .5 + math.sin(t * math.pi * 5.4) * w * .115;
      final offset = math.sin(t * math.pi * 21) * 2.4;
      final point = Offset(x - stemWidth * .13 + offset, y);
      if (i == 0) {
        ridge.moveTo(point.dx, point.dy);
      } else {
        ridge.lineTo(point.dx, point.dy);
      }
    }
    _paint
      ..color = const Color(0x668FE08A)
      ..strokeWidth = math.max(2.5, stemWidth * .105)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(ridge, _paint);

    // Fine longitudinal grooves and subtle growth nodes break up the smooth tube.
    final groove = Path();
    for (int i = 0; i <= 80; i++) {
      final t = i / 80;
      final y = rootY - growth * t;
      final x = w * .5 + math.sin(t * math.pi * 5.4) * w * .115;
      final offset = math.sin(t * math.pi * 21 + 1.2) * 2.0;
      final point = Offset(x + stemWidth * .20 + offset, y);
      if (i == 0) {
        groove.moveTo(point.dx, point.dy);
      } else {
        groove.lineTo(point.dx, point.dy);
      }
    }
    _paint
      ..color = const Color(0x44305C3E)
      ..strokeWidth = math.max(1.8, stemWidth * .07);
    canvas.drawPath(groove, _paint);

    // Small raised nodes appear at intervals along the vine, like real stem joints.
    final nodeCount = (growth / 185).floor().clamp(1, 120);
    for (int i = 1; i <= nodeCount; i++) {
      final t = i / (nodeCount + 1);
      final y = rootY - growth * t;
      final x = w * .5 + math.sin(t * math.pi * 5.4) * w * .115;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.cos(t * math.pi * 5.4) * .28);
      _paint
        ..color = const Color(0x55305C3E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, stemWidth * .10);
      canvas.drawArc(
        Rect.fromCenter(center: Offset.zero, width: stemWidth * .78, height: 9),
        .12, math.pi - .24, false, _paint,
      );
      _paint
        ..color = const Color(0x448FE08A)
        ..strokeWidth = math.max(1.5, stemWidth * .055);
      canvas.drawArc(
        Rect.fromCenter(center: Offset(0, -2), width: stemWidth * .58, height: 5),
        .15, math.pi - .3, false, _paint,
      );
      canvas.restore();
    }
    _paint.style = PaintingStyle.fill;

    // Height markers: one discreet label every 200 metres.
    final markerCount = (heightMeters / 200).floor().clamp(0, 500);
    for (int marker = 1; marker <= markerCount; marker++) {
      final markerMeters = marker * 200;
      final markerY = rootY - markerMeters * 10;
      if (markerY < 12 || markerY > h - 12) continue;
      final vineX = w * .5 + math.sin((markerMeters * 10 / growth) * math.pi * 5.4) * w * .115;
      final side = vineX < w * .5 ? 1.0 : -1.0;
      _paint
        ..shader = null
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0x99FFFFFF);
      canvas.drawLine(Offset(vineX + side * 25, markerY), Offset(vineX + side * 54, markerY), _paint);
      _paint.style = PaintingStyle.fill;
      final label = TextPainter(
        text: TextSpan(text: '${markerMeters} m', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, shadows: [Shadow(color: Color(0xAA102A31), blurRadius: 4)])),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelX = side > 0 ? vineX + 60 : vineX - 60 - label.width;
      label.paint(canvas, Offset(labelX, markerY - label.height / 2));
    }

    // Large side branches and paired leaves, spaced along the full plant.
    final branchCount = hours < 1
        ? 0
        : hours < 4
            ? 1
            : hours < 12
                ? 2
                : hours < 30
                    ? 5
                    : (math.sqrt(hours - 29) * 3).ceil().clamp(5, 220);
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
      // Blossoms arrive first and spread gradually through the older branches.
      if (hours >= 80 && i % 4 == 1) {
        _drawFlower(canvas,
            Offset(x + side * reach * .96, y - 83),
            hours >= 160 ? 1.0 : .78, i);
      }
      if (hours >= 80 && ownedItems.contains('butterflies') && i % 6 == 2) {
        final flutter = Offset(x + side * reach * 1.08, y - 112);
        _oval(canvas, Rect.fromCenter(center: flutter.translate(-4, 0), width: 9, height: 7), const Color(0xFFFFD36E));
        _oval(canvas, Rect.fromCenter(center: flutter.translate(4, 0), width: 9, height: 7), const Color(0xFFFFA6C8));
        _paint..color = const Color(0xFF5A4638)..strokeWidth = 1.4..style = PaintingStyle.stroke;
        canvas.drawLine(flutter.translate(0, -3), flutter.translate(0, 4), _paint);
        _paint.style = PaintingStyle.fill;
      }

      // Fruits appear in successive families, never all at the same time.
      // A few branches bear each new fruit type while flowers remain elsewhere.
      if (hours >= 160 && i % 7 == 3) {
        _drawFruit(canvas, Offset(x + side * reach * .98, y - 87), .88, 0);
      }
      if (hours >= 300 && i % 11 == 5) {
        _drawFruit(canvas, Offset(x + side * reach * .98, y - 88), .94, 1);
      }
      if (hours >= 500 && i % 13 == 7) {
        _drawFruit(canvas, Offset(x + side * reach * .98, y - 88), 1.0, 2);
      }
      if (hours >= 800 && i % 17 == 9) {
        _drawFruit(canvas, Offset(x + side * reach * .98, y - 89), 1.04, 3);
      }
    }

    // Purchased butterflies can be previewed at the current growing tip too,
    // so early purchases never feel invisible while the garden matures.
    if (ownedItems.contains('butterflies') && hours < 80) {
      final flutter = Offset(w * .67, tipY + 36);
      _oval(canvas, Rect.fromCenter(center: flutter.translate(-5, 0), width: 11, height: 8), const Color(0xFFFFD36E));
      _oval(canvas, Rect.fromCenter(center: flutter.translate(5, 0), width: 11, height: 8), const Color(0xFFFFA6C8));
      _paint..color = const Color(0xFF5A4638)..strokeWidth = 1.4..style = PaintingStyle.stroke;
      canvas.drawLine(flutter.translate(0, -3), flutter.translate(0, 4), _paint);
      _paint.style = PaintingStyle.fill;
    }

    // Small settlements and treetops appear much later along the giant vine.
    if (hours >= 300) {
      final places = ((hours - 299) / 120).floor().clamp(1, 80);
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
      old.hours != hours || old.growth != growth || !setEquals(old.ownedItems, ownedItems);
}
