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

class _EarnYourIslandViewState extends State<EarnYourIslandView> {
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

  @override
  void initState(){super.initState(); _load(); ticker=Timer.periodic(const Duration(seconds:30),(_)=>_tick());}
  @override
  void didUpdateWidget(covariant EarnYourIslandView old){super.didUpdateWidget(old);if(old.productiveSeconds!=widget.productiveSeconds)_claim();}
  @override
  void dispose(){ticker?.cancel();super.dispose();}

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
      AspectRatio(aspectRatio:1.22,child:ClipRRect(borderRadius:BorderRadius.circular(24),child:CustomPaint(painter:_IslandPainter(land,houses,trees,residents.length,layout),child:const SizedBox.expand()))),
      Center(child:Text('Zona $land · $houses casas · $trees árboles · ${residents.length} habitantes',style:t.textTheme.labelLarge?.copyWith(color:c.onSurfaceVariant))),
      const SizedBox(height:7),
      Center(child:OutlinedButton.icon(onPressed:busy?_noop:null, icon:const Icon(Icons.swap_horiz_rounded), label:const Text('Cambiar distribución'))),
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
  void _noop() => _changeLayout();
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
  _IslandPainter(this.land, this.houses, this.trees, this.residentCount, this.layout);
  final int land, houses, trees, residentCount, layout;

  Offset _arrange(Offset o, double cx, double cy) {
    final x = o.dx - cx, y = o.dy - cy;
    switch (layout) {
      case 1: return Offset(cx - y, cy + x);
      case 2: return Offset(cx - x, cy - y);
      default: return o;
    }
  }

  void _pixel(Canvas canvas, double x, double y, double w, double h, Color color) {
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 32;
    final cx = size.width / 2, cy = size.height / 2;

    // Agua en pequeños bloques, en lugar de líneas suaves.
    _pixel(canvas, 0, 0, size.width, size.height, const Color(0xFF65C5CF));
    for (int row = 0; row < (size.height / (u * 3)).ceil(); row++) {
      for (int col = 0; col < (size.width / (u * 5)).ceil(); col++) {
        if ((row * 7 + col * 3) % 4 == 0) {
          _pixel(canvas, col * u * 5 + u, row * u * 3 + u,
              u * 1.35, u * .35, const Color(0xFF9AE0D9));
        }
      }
    }
    // Sombra y arena con contorno escalonado.
    final r = (10.2 + (land - 1).clamp(0, 5) * 1.05) * u;
    final points = <Offset>[
      Offset(cx - r * .25, cy - r), Offset(cx + r * .25, cy - r),
      Offset(cx + r * .25, cy - r * .88), Offset(cx + r * .72, cy - r * .88),
      Offset(cx + r * .72, cy - r * .62), Offset(cx + r, cy - r * .62),
      Offset(cx + r, cy + r * .28), Offset(cx + r * .75, cy + r * .28),
      Offset(cx + r * .75, cy + r * .72), Offset(cx + r * .25, cy + r * .72),
      Offset(cx + r * .25, cy + r), Offset(cx - r * .38, cy + r),
      Offset(cx - r * .38, cy + r * .82), Offset(cx - r * .78, cy + r * .82),
      Offset(cx - r * .78, cy + r * .48), Offset(cx - r, cy + r * .48),
      Offset(cx - r, cy - r * .48), Offset(cx - r * .72, cy - r * .48),
      Offset(cx - r * .72, cy - r * .82), Offset(cx - r * .25, cy - r * .82),
    ];
    final sandPath = Path()..addPolygon(
      points.map((p) => Offset((p.dx / u).round() * u, (p.dy / u).round() * u + u * .7)).toList(), true);
    final grassPath = Path()..addPolygon(
      points.map((p) => Offset((p.dx / u).round() * u, (p.dy / u).round() * u)).toList(), true);
    canvas.drawPath(sandPath, Paint()..color = const Color(0xFFB98550));
    canvas.drawPath(grassPath, Paint()..color = const Color(0xFF79C85F));

    // Pequeños parches de hierba y tierra: cada detalle ocupa píxeles enteros.
    final grassColors = [const Color(0xFF8BD46A), const Color(0xFF68B957), const Color(0xFFA0D978)];
    for (int i = 0; i < 24; i++) {
      final x = cx + ((i * 17) % 17 - 8) * u * .72;
      final y = cy + ((i * 11) % 15 - 7) * u * .62;
      _pixel(canvas, x, y, u * .65, u * .45, grassColors[i % grassColors.length]);
    }

    final treeSpots = <Offset>[
      Offset(cx-r*.48,cy-r*.38), Offset(cx+r*.52,cy-r*.35),
      Offset(cx-r*.55,cy+r*.35), Offset(cx+r*.5,cy+r*.35),
      Offset(cx,cy-r*.58), Offset(cx,cy+r*.58),
    ];
    for (int i = 0; i < trees.clamp(0, treeSpots.length); i++) {
      final o = _arrange(treeSpots[i], cx, cy);
      _pixel(canvas, o.dx-u*.18, o.dy+u*.25, u*.38, u*.65, const Color(0xFF95603A));
      _pixel(canvas, o.dx-u*.78, o.dy-u*.58, u*1.55, u*.82, const Color(0xFF347F49));
      _pixel(canvas, o.dx-u*.58, o.dy-u*.9, u*1.15, u*.48, const Color(0xFF4B9D50));
      _pixel(canvas, o.dx-u*.35, o.dy-u*.72, u*.38, u*.3, const Color(0xFF75BF58));
      _pixel(canvas, o.dx+u*.42, o.dy-u*.28, u*.28, u*.25, const Color(0xFF65AE51));
    }

    final homes = <Offset>[
      Offset(cx,cy-u*.35), Offset(cx+r*.32,cy+r*.2),
      Offset(cx-r*.32,cy+r*.2), Offset(cx,cy+r*.55),
    ];
    for (int i = 0; i < houses.clamp(0, homes.length); i++) {
      final o = _arrange(homes[i], cx, cy);
      _pixel(canvas, o.dx-u*.68, o.dy-u*.05, u*1.36, u*.95, const Color(0xFFF4D79A));
      _pixel(canvas, o.dx-u*.78, o.dy-u*.35, u*1.56, u*.42, const Color(0xFFB94F49));
      _pixel(canvas, o.dx-u*.58, o.dy-u*.62, u*1.16, u*.3, const Color(0xFFD66A55));
      _pixel(canvas, o.dx-u*.18, o.dy+u*.35, u*.36, u*.55, const Color(0xFF98613F));
      _pixel(canvas, o.dx-u*.5, o.dy+u*.05, u*.28, u*.28, const Color(0xFF79B9C4));
      _pixel(canvas, o.dx+u*.22, o.dy+u*.05, u*.28, u*.28, const Color(0xFF79B9C4));
    }

    final residentSpots = <Offset>[
      Offset(cx-u*1.35,cy-u*.1), Offset(cx+u*1.35,cy-u*.05),
      Offset(cx,cy+u*1.15),
    ];
    final residentColors = <Color>[
      const Color(0xFFE8A85B), const Color(0xFF65AD72), const Color(0xFF719ED8),
    ];
    for (int i = 0; i < residentCount.clamp(0, residentSpots.length); i++) {
      final o = _arrange(residentSpots[i], cx, cy);
      final color = residentColors[i];
      _pixel(canvas, o.dx-u*.25, o.dy+u*.05, u*.5, u*.52, color);
      _pixel(canvas, o.dx-u*.19, o.dy-u*.35, u*.38, u*.38, const Color(0xFFFFD4AD));
      _pixel(canvas, o.dx-u*.22, o.dy-u*.42, u*.44, u*.13, const Color(0xFF594B45));
      _pixel(canvas, o.dx-u*.1, o.dy-u*.22, u*.07, u*.07, const Color(0xFF493B36));
      _pixel(canvas, o.dx+u*.07, o.dy-u*.22, u*.07, u*.07, const Color(0xFF493B36));
    }

    // Flores y pequeñas piedras decorativas.
    for (int i = 0; i < 12; i++) {
      final x = cx + ((i * 13) % 13 - 6) * u * .72;
      final y = cy + ((i * 7) % 11 - 5) * u * .62;
      final color = i.isEven ? const Color(0xFFFFE78A) : const Color(0xFFFFA6B7);
      _pixel(canvas, x, y, u*.22, u*.22, color);
      if (i % 3 == 0) _pixel(canvas, x+u*.22, y+u*.12, u*.16, u*.16, const Color(0xFFFFF1C2));
    }
  }

  @override
  bool shouldRepaint(covariant _IslandPainter old) =>
      old.land != land || old.houses != houses || old.trees != trees ||
      old.residentCount != residentCount || old.layout != layout;
}
