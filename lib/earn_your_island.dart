import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EarnYourIslandView extends StatefulWidget {
  const EarnYourIslandView({super.key, required this.productiveSeconds});
  final int productiveSeconds;
  @override
  State<EarnYourIslandView> createState() => _EarnYourIslandViewState();
}

class _EarnYourIslandViewState extends State<EarnYourIslandView> with SingleTickerProviderStateMixin {
  static const _channel = MethodChannel('focusfeed/island');
  int coins=40, energy=0, claimed=0, lastIncome=DateTime.now().millisecondsSinceEpoch;
  int land=1, houses=0, trees=1, layout=0;
  List<String> residents=[];
  static const _characters = <String, Map<String, Object>>{
    'luma': {'name': 'Luma', 'role': 'Exploradora', 'price': 60, 'color': 0xFFE8A85B, 'icon': 'explore'},
    'tilo': {'name': 'Tilo', 'role': 'Jardinero', 'price': 90, 'color': 0xFF65AD72, 'icon': 'yard'},
    'nori': {'name': 'Nori', 'role': 'Inventora', 'price': 120, 'color': 0xFF719ED8, 'icon': 'lightbulb'},
  };
  bool loaded=false, busy=false;
  Timer? ticker;
  late final AnimationController _cloudController;

  @override
  void initState(){super.initState(); _cloudController=AnimationController(vsync:this,duration:const Duration(seconds:58))..repeat(); _load(); ticker=Timer.periodic(const Duration(seconds:30),(_)=>_tick());}
  @override
  void didUpdateWidget(covariant EarnYourIslandView old){super.didUpdateWidget(old);if(old.productiveSeconds!=widget.productiveSeconds)_claim();}
  @override
  void dispose(){ticker?.cancel();_cloudController.dispose();super.dispose();}

  Future<void> _load() async {
    try {
      final raw=await _channel.invokeMethod<String>('load');
      if(raw!=null){final d=jsonDecode(raw) as Map<String,dynamic>;
        coins=(d['coins'] as num?)?.toInt()??0; energy=(d['energy'] as num?)?.toInt()??0;
        claimed=(d['claimed'] as num?)?.toInt()??0; lastIncome=(d['lastIncome'] as num?)?.toInt()??lastIncome;
        land=(d['land'] as num?)?.toInt()??1; houses=(d['houses'] as num?)?.toInt()??0; trees=(d['trees'] as num?)?.toInt()??1; layout=((d['layout'] as num?)?.toInt()??0).clamp(0,2);
        residents=(d['residents'] as List<dynamic>?)?.whereType<String>().toSet().toList()??[];
      }
    } catch (_) {}
    if(!mounted)return;setState(()=>loaded=true);await _tick();await _claim();
  }
  Future<void> _save() async {
    try {await _channel.invokeMethod<void>('save',{'state':jsonEncode({'coins':coins,'energy':energy,'claimed':claimed,'lastIncome':lastIncome,'land':land,'houses':houses,'trees':trees,'layout':layout,'residents':residents})});}
    catch(_){if(mounted)_msg('No se pudo guardar la isla.');}
  }
  Future<void> _tick() async {
    if(!loaded)return;final now=DateTime.now().millisecondsSinceEpoch;
    final elapsed=((now-lastIncome)/1000).floor().clamp(0,28800);
    final gain=elapsed*houses~/60;
    if(elapsed>0){setState((){coins+=gain;lastIncome=now;});await _save();}
  }
  Future<void> _claim() async {
    if(!loaded)return;final diff=widget.productiveSeconds-claimed;
    if(diff<300)return;final units=diff~/300;
    setState((){energy+=units;claimed+=units*300;});await _save();
  }
  Future<void> _changeLayout() async { if(busy)return; setState(()=>layout=(layout+1)%3); await _save(); _msg('Distribución de la isla actualizada.'); }
  void _msg(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  Future<void> _buy(String type) async {
    if(busy)return;String? error;
    setState(()=>busy=true);
    if(type=='land'){if(energy<12){error='Necesitas 12 de energía.';}else{energy-=12;land++;}}
    if(type=='house'){if(coins<40){error='Necesitas 40 monedas.';}else if(houses>=land*2){error='Amplía el terreno para construir más casas.';}else{coins-=40;houses++;}}
    if(type=='tree'){if(coins<12){error='Necesitas 12 monedas.';}else{coins-=12;trees++;}}
    if(type.startsWith('resident:')){
      final id=type.substring(9);final character=_characters[id];
      if(character==null){error='Este personaje no está disponible.';}
      else if(residents.contains(id)){error='Este personaje ya vive en tu isla.';}
      else {final price=character['price'] as int;if(coins<price){error='Necesitas $price monedas.';}else{coins-=price;residents.add(id);}}
    }
    await _save();if(mounted)setState(()=>busy=false);if(error!=null)_msg(error);
  }

  @override
  Widget build(BuildContext context){
    final t=Theme.of(context);final c=t.colorScheme;
    if(!loaded)return const Center(child:CircularProgressIndicator());
    return ListView(padding:const EdgeInsets.fromLTRB(16,14,16,28),children:[
      Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Earn Your Island',style:t.textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),
        Text('Un pequeño mundo que crece contigo',style:t.textTheme.bodySmall?.copyWith(color:c.onSurfaceVariant)),
      ])),Icon(Icons.wb_sunny_rounded,color:c.tertiary,size:28)]),
      const SizedBox(height:14),
      Row(children:[
        Expanded(child:_resource(context,'Monedas',coins.toString(),Icons.monetization_on_rounded,const Color(0xFFE9B949))),
        const SizedBox(width:10),
        Expanded(child:_resource(context,'Energía',energy.toString(),Icons.bolt_rounded,const Color(0xFF42B9C5))),
      ]),
      const SizedBox(height:14),
      AnimatedBuilder(animation:_cloudController,builder:(context,child)=>AspectRatio(aspectRatio:1,child:ClipRRect(borderRadius:BorderRadius.circular(24),child:CustomPaint(painter:_IslandPainter(land,houses,trees,residents.length,layout,_cloudController.value),child:const SizedBox.expand())))), 
      Center(child:Text('Zona $land · $houses casas · $trees árboles · ${residents.length} habitantes',style:t.textTheme.labelLarge?.copyWith(color:c.onSurfaceVariant))),
      const SizedBox(height:7),
      Center(child:OutlinedButton.icon(onPressed:busy?null:_changeLayout, icon:const Icon(Icons.swap_horiz_rounded), label:const Text('Cambiar distribución'))),
      const SizedBox(height:14),
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Haz crecer tu isla',style:t.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),
        const SizedBox(height:4),
        Text('Tu tiempo productivo genera energía. Las casas producen monedas incluso cuando no estás jugando.',style:t.textTheme.bodySmall?.copyWith(color:c.onSurfaceVariant)),
        const SizedBox(height:12),
        _buyRow(context,Icons.landscape_rounded,'Ampliar terreno','Desbloquea una nueva zona','12 energía',energy>=12,()=>_buy('land')),
        const Divider(height:18),
        _buyRow(context,Icons.cottage_rounded,'Construir casa','Produce 1 moneda por minuto','40 monedas',coins>=40&&houses<land*2,()=>_buy('house')),
        const Divider(height:18),
        _buyRow(context,Icons.park_rounded,'Plantar árbol','Decora tu isla','12 monedas',coins>=12,()=>_buy('tree')),
      ]))),
      const SizedBox(height:8),
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Habitantes de la isla',style:t.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),
        const SizedBox(height:4),
        Text('Conoce personajes originales y haz que tu isla tenga más vida. Son compras únicas y no necesitan atención diaria.',style:t.textTheme.bodySmall?.copyWith(color:c.onSurfaceVariant)),
        const SizedBox(height:10),
        ..._characters.entries.map((entry){final id=entry.key;final data=entry.value;final owned=residents.contains(id);final price=data['price'] as int;final color=Color(data['color'] as int);return Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(children:[
          Container(width:44,height:44,decoration:BoxDecoration(color:color.withValues(alpha:.18),borderRadius:BorderRadius.circular(14)),child:Icon(id=='luma'?Icons.explore_rounded:id=='tilo'?Icons.yard_rounded:Icons.lightbulb_rounded,color:color)),
          const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(data['name'] as String,style:const TextStyle(fontWeight:FontWeight.w800)),Text(data['role'] as String,style:t.textTheme.bodySmall?.copyWith(color:c.onSurfaceVariant))])),
          if(owned) const Chip(avatar:Icon(Icons.check_circle_rounded,size:16),label:Text('Vive aquí')) else FilledButton.tonal(onPressed:!busy&&coins>=price?()=>_buy('resident:$id'):null,child:Text('$price monedas',style:const TextStyle(fontSize:11))),
        ]));}),
      ]))),
      const SizedBox(height:8),
      Text('1 energía por cada 5 minutos productivos · Producción offline limitada a 8 horas',textAlign:TextAlign.center,style:t.textTheme.labelSmall?.copyWith(color:c.onSurfaceVariant)),
    ]);
  }
  Widget _resource(BuildContext context,String label,String value,IconData icon,Color color)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[
    Container(width:38,height:38,decoration:BoxDecoration(color:color.withValues(alpha:.18),borderRadius:BorderRadius.circular(13)),child:Icon(icon,color:color)),
    const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:Theme.of(context).textTheme.labelMedium),Text(value,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900))])),
  ])));
  Widget _buyRow(BuildContext context,IconData icon,String title,String subtitle,String cost,bool enabled,VoidCallback tap)=>Row(children:[
    Icon(icon,size:28,color:Theme.of(context).colorScheme.primary),const SizedBox(width:10),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),Text(subtitle,style:Theme.of(context).textTheme.bodySmall)])),
    FilledButton.tonal(onPressed:enabled&&!busy?tap:null,child:Text(cost,style:const TextStyle(fontSize:11))),
  ]);
}

class _IslandPainter extends CustomPainter {
  _IslandPainter(this.land, this.houses, this.trees, this.residentCount, this.layout, this.cloudPhase);
  final int land, houses, trees, residentCount, layout;
  final double cloudPhase;

  final Paint _paint = Paint()..isAntiAlias = true;

  void _rect(Canvas c, double x, double y, double w, double h, Color color,
      {double radius = 0}) {
    _paint
      ..shader = null
      ..color = color
      ..style = PaintingStyle.fill;
    final rect = Rect.fromLTWH(x, y, w, h);
    if (radius > 0) {
      c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), _paint);
    } else {
      c.drawRect(rect, _paint);
    }
  }

  void _oval(Canvas c, double x, double y, double w, double h, Color color) {
    _paint
      ..shader = null
      ..color = color
      ..style = PaintingStyle.fill;
    c.drawOval(Rect.fromLTWH(x, y, w, h), _paint);
  }

  void _polygon(Canvas c, List<Offset> points, Color color) {
    _paint
      ..shader = null
      ..color = color
      ..style = PaintingStyle.fill;
    c.drawPath(Path()..addPolygon(points, true), _paint);
  }

  void _gradientRect(Canvas c, Rect rect, Color top, Color bottom,
      {double radius = 0}) {
    _paint
      ..shader = LinearGradient(colors: [top, bottom]).createShader(rect)
      ..style = PaintingStyle.fill;
    if (radius > 0) {
      c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), _paint);
    } else {
      c.drawRect(rect, _paint);
    }
    _paint.shader = null;
  }

  Offset _arrange(Offset p, double cx, double cy) {
    final x = p.dx - cx, y = p.dy - cy;
    switch (layout) {
      case 1: return Offset(cx - y, cy + x);
      case 2: return Offset(cx - x, cy - y);
      default: return p;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 180, size.height / 180);
    _paintScene(canvas, const Size(180, 180));
    canvas.restore();
  }

  void _paintScene(Canvas canvas, Size size) {
    const skyTop = Color(0xFF65CDEB);
    const skyBottom = Color(0xFFB5EDF0);
    _gradientRect(canvas, Offset.zero & size, skyTop, skyBottom);

    final u = size.shortestSide / 36;
    final cx = size.width / 2;
    final cy = size.height * .51;
    final r = 11.3 + (land - 1).clamp(0, 5) * .72;

    // Calm water with soft, clean reflections.
    for (int i = 0; i < 19; i++) {
      final x = ((i * 47 + 13) % 101) / 101 * size.width;
      final y = ((i * 31 + 9) % 97) / 97 * size.height;
      _rect(canvas, x, y, u * (1.0 + (i % 3) * .55), u * .12,
          const Color(0x66E8FFFF), radius: u * .08);
    }
    for (int i = 0; i < 7; i++) {
      final x = (i * 29.0 + 8) % 160;
      final y = 25.0 + (i * 37.0) % 125;
      _oval(canvas, x, y, u * 1.2, u * .22, const Color(0x22317EAB));
    }

    // Floating shadow and deep underside.
    _oval(canvas, cx - r * 1.02, cy - r * .60 + u * 2.2,
        r * 2.05, r * 1.18, const Color(0x55305F79));
    final outline = <Offset>[
      Offset(cx-r*.28*u,cy-r*.91*u), Offset(cx+r*.25*u,cy-r*.91*u),
      Offset(cx+r*.43*u,cy-r*.78*u), Offset(cx+r*.78*u,cy-r*.77*u),
      Offset(cx+r*.88*u,cy-r*.53*u), Offset(cx+r*1.02*u,cy-r*.24*u),
      Offset(cx+r*.98*u,cy+r*.30*u), Offset(cx+r*.78*u,cy+r*.57*u),
      Offset(cx+r*.60*u,cy+r*.80*u), Offset(cx+r*.22*u,cy+r*.91*u),
      Offset(cx-r*.28*u,cy+r*.88*u), Offset(cx-r*.55*u,cy+r*.72*u),
      Offset(cx-r*.87*u,cy+r*.62*u), Offset(cx-r*1.00*u,cy+r*.25*u),
      Offset(cx-r*.94*u,cy-r*.27*u), Offset(cx-r*.76*u,cy-r*.59*u),
      Offset(cx-r*.48*u,cy-r*.72*u)
    ];
    final lower = outline.map((p) => Offset(p.dx, p.dy + u * 2.65)).toList();
    _polygon(canvas, lower.map((p) => Offset(p.dx, p.dy + u * .85)).toList(),
        const Color(0xFF70432F));

    // Faceted voxel-like cliff: each side panel is a distinct block face.
    for (int i = 0; i < outline.length; i++) {
      final a = outline[i];
      final b = outline[(i + 1) % outline.length];
      final a2 = lower[i];
      final b2 = lower[(i + 1) % outline.length];
      final shade = i % 4 == 0
          ? const Color(0xFFB87543)
          : i % 4 == 1
              ? const Color(0xFF965632)
              : i % 4 == 2
                  ? const Color(0xFF80482D)
                  : const Color(0xFFA9663B);
      _polygon(canvas, [a, b, b2, a2], shade);
      if (i % 3 == 0) {
        _polygon(canvas, [
          Offset(a.dx, a.dy + u * .5),
          Offset(b.dx, b.dy + u * .5),
          Offset(b.dx, b.dy + u * 1.0),
          Offset(a.dx, a.dy + u * 1.0)
        ], const Color(0x337A3D25));
      }
    }
    _polygon(canvas, lower, const Color(0xFF593A2B));

    // Top grass slab with a bright bevel.
    final top = outline.map((p) => Offset(p.dx, p.dy - u * .55)).toList();
    _polygon(canvas, top.map((p) => Offset(p.dx, p.dy + u * .30)).toList(),
        const Color(0xFF397B3C));
    _polygon(canvas, top, const Color(0xFF70C94B));
    _polygon(canvas, [
      Offset(cx-r*.75*u,cy-r*.20*u), Offset(cx-r*.61*u,cy-r*.57*u),
      Offset(cx-r*.31*u,cy-r*.73*u), Offset(cx+r*.12*u,cy-r*.73*u),
      Offset(cx+r*.36*u,cy-r*.60*u), Offset(cx+r*.70*u,cy-r*.55*u),
      Offset(cx+r*.87*u,cy-r*.19*u), Offset(cx+r*.82*u,cy+r*.24*u),
      Offset(cx+r*.54*u,cy+r*.57*u), Offset(cx+r*.08*u,cy+r*.70*u),
      Offset(cx-r*.42*u,cy+r*.55*u), Offset(cx-r*.76*u,cy+r*.28*u)
    ], const Color(0xFF83D957));

    // Subtle terrain light and shade, with smooth edges rather than pixel noise.
    _oval(canvas, cx-r*.65*u, cy-r*.12*u, r*1.12*u, r*.93*u,
        const Color(0x1EBAF17A));
    _oval(canvas, cx-r*.02*u, cy-r*.05*u, r*1.00*u, r*.95*u,
        const Color(0x1D398E36));

    // Animated cloud shadows slide across the island.
    final cloudXs = <double>[
      ((cloudPhase * (size.width + 92) - 46) % (size.width + 92)) - 46,
      (((cloudPhase + .52) % 1) * (size.width + 92) - 46) - 46,
    ];
    final landClip = Path()..addPolygon(top, true);
    canvas.save();
    canvas.clipPath(landClip);
    for (int i = 0; i < cloudXs.length; i++) {
      final x = cloudXs[i];
      final y = cy - r * u * (.42 - i * .12);
      _oval(canvas, x, y, u * 8.8, u * 3.2, const Color(0x263B5870));
      _oval(canvas, x + u * 1.1, y + u * .3, u * 6.0, u * 2.2,
          const Color(0x183B5870));
    }
    canvas.restore();

    // Winding sandy path with a darker edge and a warm center.
    final path = Path()
      ..moveTo(cx-r*.46*u, cy+r*.62*u)
      ..cubicTo(cx-r*.39*u, cy+r*.18*u, cx-r*.47*u, cy-r*.16*u,
          cx-r*.24*u, cy-r*.42*u)
      ..cubicTo(cx-r*.05*u, cy-r*.62*u, cx+r*.03*u, cy-r*.38*u,
          cx+r*.22*u, cy-r*.25*u);
    _paint
      ..shader = null
      ..color = const Color(0xFF9D633D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 2.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, _paint);
    _paint
      ..color = const Color(0xFFE2A66A)
      ..strokeWidth = u * 2.15;
    canvas.drawPath(path, _paint);
    _paint.style = PaintingStyle.fill;
    for (int i = 0; i < 17; i++) {
      final x = cx-r*.40*u + (i%4)*u*.19 + (i%3)*u*.10;
      final y = cy+r*.50*u-i*u*.48;
      _oval(canvas,x,y,u*.20,u*.12,const Color(0x99F4C58A));
    }

    // Small grass tufts and flowers, spaced with intentional composition.
    final tufts = <Offset>[
      Offset(cx-r*.60*u,cy-r*.28*u), Offset(cx-r*.55*u,cy+r*.20*u),
      Offset(cx-r*.20*u,cy-r*.70*u), Offset(cx+r*.46*u,cy-r*.48*u),
      Offset(cx+r*.69*u,cy-r*.10*u), Offset(cx+r*.48*u,cy+r*.50*u),
      Offset(cx-r*.22*u,cy+r*.65*u), Offset(cx-r*.72*u,cy+r*.42*u),
      Offset(cx+r*.12*u,cy-r*.57*u), Offset(cx+r*.72*u,cy+r*.27*u)
    ];
    for (int i = 0; i < tufts.length; i++) {
      final p = tufts[i];
      _oval(canvas,p.dx,p.dy,u*.34,u*.13,const Color(0x553E8E36));
      _polygon(canvas,[
        Offset(p.dx,p.dy),Offset(p.dx-u*.08,p.dy-u*.42),
        Offset(p.dx+u*.12,p.dy-u*.12),Offset(p.dx+u*.24,p.dy-u*.36),
        Offset(p.dx+u*.25,p.dy)
      ],const Color(0xFF4C9F3D));
      if (i % 3 == 0) {
        _oval(canvas,p.dx+u*.48,p.dy-u*.20,u*.30,u*.30,
            const Color(0xFFFFD66D));
        _oval(canvas,p.dx+u*.55,p.dy-u*.13,u*.13,u*.13,
            const Color(0xFFFFF0A5));
      }
    }

    // Trees are built from stacked cuboids with visible top and side faces.
    final treeSpots = <Offset>[
      Offset(cx+r*.48*u,cy-r*.42*u), Offset(cx-r*.55*u,cy+r*.20*u),
      Offset(cx+r*.58*u,cy+r*.34*u), Offset(cx-r*.15*u,cy-r*.62*u),
      Offset(cx+r*.08*u,cy+r*.60*u), Offset(cx-r*.65*u,cy-r*.35*u)
    ];
    for (int i = 0; i < trees.clamp(0, treeSpots.length); i++) {
      final p = _arrange(treeSpots[i],cx,cy);
      _oval(canvas,p.dx-u*.92,p.dy+u*.30,u*1.85,u*.55,
          const Color(0x55324F35));
      _rect(canvas,p.dx-u*.22,p.dy-u*.05,u*.44,u*.98,
          const Color(0xFF80502F));
      _polygon(canvas,[
        Offset(p.dx-u*.22,p.dy+u*.05),Offset(p.dx,p.dy+u*.18),
        Offset(p.dx,p.dy+u*.98),Offset(p.dx-u*.22,p.dy+.84*u)
      ],const Color(0xFF633E2B));
      // Three staggered foliage blocks, each with a top highlight.
      void foliage(double x,double y,double w,double h,Color front,Color side) {
        _polygon(canvas,[
          Offset(x,y),Offset(x+w*.25,y-u*.22),
          Offset(x+w,y-u*.22),Offset(x+w*1.08,y+h*.62),
          Offset(x+w*.84,y+h),Offset(x,y+h)
        ],front);
        _polygon(canvas,[
          Offset(x+w*.25,y-u*.22),Offset(x+w*.48,y-u*.42),
          Offset(x+w*1.18,y-u*.40),Offset(x+w,y-u*.22)
        ],const Color(0xFF78C95A));
        _polygon(canvas,[
          Offset(x+w,y-u*.22),Offset(x+w*1.08,y+h*.62),
          Offset(x+w*.84,y+h),Offset(x+w*.82,y-u*.02)
        ],side);
      }
      foliage(p.dx-u*.94,p.dy-u*1.05,u*1.70,u*1.18,
          const Color(0xFF368847),const Color(0xFF24683B));
      foliage(p.dx-u*.68,p.dy-u*1.52,u*1.48,u*1.02,
          const Color(0xFF4FA64A),const Color(0xFF2F7D3F));
      _polygon(canvas,[
        Offset(p.dx-u*.38,p.dy-u*1.55),Offset(p.dx-u*.12,p.dy-u*1.82),
        Offset(p.dx+u*.58,p.dy-u*1.80),Offset(p.dx+u*.88,p.dy-u*1.52)
      ],const Color(0xFF80D65B));
      _rect(canvas,p.dx-u*.45,p.dy-u*1.24,u*.34,u*.24,
          const Color(0xFF8BD969),radius:u*.06);
    }

    // Houses: warm little voxel cottages with distinct roof, walls and depth.
    final homeSpots = <Offset>[
      Offset(cx+u*.55,cy-u*.02), Offset(cx+r*.38*u,cy+r*.20*u),
      Offset(cx-r*.32*u,cy+r*.24*u), Offset(cx+u*.08,cy+r*.57*u)
    ];
    for (int i = 0; i < houses.clamp(0, homeSpots.length); i++) {
      final p = _arrange(homeSpots[i],cx,cy);
      _oval(canvas,p.dx-u*1.35,p.dy+u*.72,u*2.7,u*.62,
          const Color(0x55334F38));
      // Building front and right wall.
      _polygon(canvas,[
        Offset(p.dx-u*.92,p.dy-u*.10),Offset(p.dx+u*.55,p.dy-u*.10),
        Offset(p.dx+u*.55,p.dy+u*1.08),Offset(p.dx-u*.92,p.dy+u*1.08)
      ],const Color(0xFFF2D9A5));
      _polygon(canvas,[
        Offset(p.dx+u*.55,p.dy-u*.10),Offset(p.dx+u*1.02,p.dy-u*.36),
        Offset(p.dx+u*1.02,p.dy+u*.82),Offset(p.dx+u*.55,p.dy+u*1.08)
      ],const Color(0xFFD4AE7D));
      // Roof ridge and two sloping roof planes.
      _polygon(canvas,[
        Offset(p.dx-u*1.18,p.dy-u*.12),Offset(p.dx-u*.05,p.dy-u*1.18),
        Offset(p.dx+u*.72,p.dy-u*.36),Offset(p.dx+u*.55,p.dy-u*.12)
      ],const Color(0xFFB94D3F));
      _polygon(canvas,[
        Offset(p.dx-u*.05,p.dy-u*1.18),Offset(p.dx+u*.72,p.dy-u*.36),
        Offset(p.dx+u*1.18,p.dy-u*.58),Offset(p.dx+u*.12,p.dy-u*1.48)
      ],const Color(0xFF873B37));
      _polygon(canvas,[
        Offset(p.dx-u*1.18,p.dy-u*.12),Offset(p.dx-u*.05,p.dy-u*1.18),
        Offset(p.dx+u*.12,p.dy-u*1.48),Offset(p.dx-u*1.00,p.dy-u*.42)
      ],const Color(0xFFE06C50));
      // Door, windows and small lit details.
      _rect(canvas,p.dx-u*.23,p.dy+u*.42,u*.42,u*.66,
          const Color(0xFF895638),radius:u*.04);
      _rect(canvas,p.dx-u*.75,p.dy+u*.20,u*.36,u*.34,
          const Color(0xFF6AA6B1),radius:u*.04);
      _rect(canvas,p.dx+u*.20,p.dy+u*.20,u*.30,u*.34,
          const Color(0xFF6AA6B1),radius:u*.04);
      _rect(canvas,p.dx-u*.78,p.dy+u*.16,u*.42,u*.07,
          const Color(0xFFFFF0C5));
      _rect(canvas,p.dx+u*.18,p.dy+u*.16,u*.34,u*.07,
          const Color(0xFFFFF0C5));
      _rect(canvas,p.dx+u*.73,p.dy-u*.86,u*.25,u*.72,
          const Color(0xFF8D5A43));
      _rect(canvas,p.dx+u*.70,p.dy-u*.91,u*.34,u*.14,
          const Color(0xFFB77C5A));
    }

    // Residents are small rounded low-poly sprites, with clear heads and outfits.
    final residentSpots = <Offset>[
      Offset(cx-r*.08*u,cy+r*.22*u), Offset(cx+r*.22*u,cy+r*.30*u),
      Offset(cx-u*.18,cy+r*.48*u)
    ];
    final outfits = [const Color(0xFFE5A04F),const Color(0xFF5C9B69),
      const Color(0xFF668FCB)];
    final hair = [const Color(0xFF75452F),const Color(0xFF4D4035),
      const Color(0xFF55466B)];
    for (int i = 0; i < residentCount.clamp(0,3); i++) {
      final p = _arrange(residentSpots[i],cx,cy);
      _oval(canvas,p.dx-u*.43,p.dy+u*.48,u*.86,u*.28,
          const Color(0x55334D38));
      _rect(canvas,p.dx-u*.23,p.dy+u*.22,u*.19,u*.38,
          const Color(0xFF675044),radius:u*.04);
      _rect(canvas,p.dx+u*.04,p.dy+u*.22,u*.19,u*.38,
          const Color(0xFF675044),radius:u*.04);
      _rect(canvas,p.dx-u*.34,p.dy-u*.10,u*.68,u*.56,outfits[i],
          radius:u*.12);
      _rect(canvas,p.dx-u*.30,p.dy+u*.28,u*.60,u*.10,
          i==0?const Color(0xFFF4D16B):i==1?const Color(0xFFB5D98A):const Color(0xFFB6C8F0));
      _rect(canvas,p.dx-u*.30,p.dy-u*.76,u*.60,u*.58,
          const Color(0xFFFFC99F),radius:u*.16);
      _rect(canvas,p.dx-u*.34,p.dy-u*.82,u*.68,u*.20,hair[i],
          radius:u*.10);
      _rect(canvas,p.dx-u*.24,p.dy-u*.48,u*.10,u*.10,
          const Color(0xFF493B36),radius:u*.03);
      _rect(canvas,p.dx+u*.12,p.dy-u*.48,u*.10,u*.10,
          const Color(0xFF493B36),radius:u*.03);
      _rect(canvas,p.dx-u*.10,p.dy-u*.32,u*.20,u*.04,
          const Color(0xFFB96E63),radius:u*.02);
      if (i==0) {
        _rect(canvas,p.dx-u*.38,p.dy-u*.91,u*.76,u*.13,
            const Color(0xFFE8B65D),radius:u*.06);
      } else if (i==1) {
        _rect(canvas,p.dx-u*.34,p.dy-u*.94,u*.68,u*.15,
            const Color(0xFF6CB978),radius:u*.06);
      } else {
        _rect(canvas,p.dx-u*.36,p.dy-u*.92,u*.72,u*.14,
            const Color(0xFF688BC5),radius:u*.06);
      }
    }

    // Puffy clouds remain in motion above the island.
    for (int i = 0; i < cloudXs.length; i++) {
      final x = cloudXs[i];
      final y = u * (3.0 + i * 3.2);
      _oval(canvas,x+u*.5,y+u*.65,u*5.8,u*1.05,
          const Color(0x4477A8B4));
      _rect(canvas,x+u*.8,y+u*.45,u*4.7,u*.88,
          const Color(0xFFEAF8F7),radius:u*.38);
      _oval(canvas,x+u*1.3,y,u*2.5,u*1.65,const Color(0xFFF8FFFF));
      _oval(canvas,x+u*3.0,y+u*.25,u*2.5,u*1.35,
          const Color(0xFFF3FCFC));
      _rect(canvas,x+u*1.1,y+u*1.0,u*4.2,u*.35,
          const Color(0xFFD4ECEB),radius:u*.18);
    }
  }

  @override
  bool shouldRepaint(covariant _IslandPainter old) =>
      old.land != land || old.houses != houses || old.trees != trees ||
      old.residentCount != residentCount || old.layout != layout ||
      old.cloudPhase != cloudPhase;
}
