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
      AspectRatio(aspectRatio:1,child:ClipRRect(borderRadius:BorderRadius.circular(24),child:CustomPaint(painter:_IslandPainter(land,houses,trees,residents.length,layout),child:const SizedBox.expand()))),
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
  _IslandPainter(this.land, this.houses, this.trees, this.residentCount, this.layout);
  final int land, houses, trees, residentCount, layout;

  final Paint _paint = Paint()..isAntiAlias = false;

  void _rect(Canvas c, double x, double y, double w, double h, Color color) {
    _paint.color = color;
    c.drawRect(Rect.fromLTWH(x, y, w, h), _paint);
  }

  void _oval(Canvas c, double x, double y, double w, double h, Color color) {
    _paint.color = color;
    c.drawOval(Rect.fromLTWH(x, y, w, h), _paint);
  }

  void _polygon(Canvas c, List<Offset> points, Color color) {
    _paint.color = color;
    final path = Path()..addPolygon(points, true);
    c.drawPath(path, _paint);
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
    final u = size.shortestSide / 36;
    final cx = size.width / 2, cy = size.height / 2;
    _rect(canvas, 0, 0, size.width, size.height, const Color(0xFF72D3E5));

    // Agua: pequeñas olas escalonadas y reflejos.
    for (int i = 0; i < 28; i++) {
      final x = ((i * 71 + 19) % 97) / 97 * size.width;
      final y = ((i * 43 + 11) % 89) / 89 * size.height;
      final w = u * (1.1 + (i % 3) * .55);
      _rect(canvas, x, y, w, u * .22, const Color(0xFFB8F0E9));
      if (i % 3 == 0) {
        _rect(canvas, x + u * .35, y + u * .25, w * .55, u * .18,
            const Color(0xFF3AAFCB));
      }
    }

    final r = (11.2 + (land - 1).clamp(0, 5) * .85) * u;
    final outline = <Offset>[
      Offset(cx-r*.24,cy-r), Offset(cx+r*.24,cy-r),
      Offset(cx+r*.34,cy-r*.91), Offset(cx+r*.70,cy-r*.91),
      Offset(cx+r*.76,cy-r*.72), Offset(cx+r*.94,cy-r*.58),
      Offset(cx+r,cy-r*.24), Offset(cx+r*.94,cy+r*.36),
      Offset(cx+r*.78,cy+r*.48), Offset(cx+r*.72,cy+r*.78),
      Offset(cx+r*.40,cy+r*.88), Offset(cx+r*.20,cy+r),
      Offset(cx-r*.38,cy+r*.94), Offset(cx-r*.53,cy+r*.78),
      Offset(cx-r*.83,cy+r*.70), Offset(cx-r*.94,cy+r*.40),
      Offset(cx-r,cy-r*.28), Offset(cx-r*.82,cy-r*.55),
      Offset(cx-r*.68,cy-r*.80), Offset(cx-r*.36,cy-r*.82),
    ];

    // Sombra bajo la isla y costa rocosa en varios niveles.
    final shadow = outline.map((p)=>Offset(p.dx+u*.65,p.dy+u*1.25)).toList();
    _polygon(canvas, shadow, const Color(0xFF397FAE));
    _polygon(canvas, outline.map((p)=>Offset(p.dx,p.dy+u*.95)).toList(),
        const Color(0xFF70452F));
    _polygon(canvas, outline.map((p)=>Offset(p.dx,p.dy+u*.48)).toList(),
        const Color(0xFFB97843));
    _polygon(canvas, outline, const Color(0xFF6B9B43));

    // Facetas claras y oscuras de los acantilados.
    for (int i=0;i<outline.length;i++) {
      final a=outline[i], b=outline[(i+1)%outline.length];
      final mid=Offset((a.dx+b.dx)/2,(a.dy+b.dy)/2+u*.72);
      _polygon(canvas,[a,b,Offset(b.dx,b.dy+u*1.05),mid],
          i.isEven?const Color(0xFFD99A5B):const Color(0xFF95603D));
      _rect(canvas, mid.dx-u*.32, mid.dy-u*.10, u*.72, u*.18,
          i%3==0?const Color(0xFFF0C27B):const Color(0xFF744832));
    }

    final grass = outline.map((p)=>Offset(p.dx,p.dy-u*.25)).toList();
    _polygon(canvas, grass, const Color(0xFF83D34F));
    _polygon(canvas, [
      Offset(cx-r*.82,cy+r*.15),Offset(cx-r*.68,cy+r*.62),
      Offset(cx-r*.28,cy+r*.83),Offset(cx+r*.18,cy+r*.80),
      Offset(cx+r*.64,cy+r*.55),Offset(cx+r*.78,cy+r*.12),
      Offset(cx+r*.42,cy-r*.35),Offset(cx-r*.18,cy-r*.42)
    ], const Color(0xFF78C94A));

    // Manchas de césped, pequeñas hojas y flores.
    for(int i=0;i<58;i++){
      final x=cx+(((i*37)%31)-15)*u*.57;
      final y=cy+(((i*19)%29)-14)*u*.55;
      final col=i%4==0?const Color(0xFFA4E66B):
          i%4==1?const Color(0xFF69B94B):const Color(0xFF8BD75A);
      _rect(canvas,x,y,u*(.18+(i%3)*.10),u*.16,col);
      if (i % 5 == 0) {
        _rect(canvas, x + u * .22, y - u * .16, u * .12, u * .24,
            const Color(0xFF559F48));
      }
    }

    // Camino de tierra con piedras individuales.
    final pathPoints=[
      Offset(cx-r*.42,cy+r*.65),Offset(cx-r*.35,cy+r*.10),
      Offset(cx-r*.31,cy-r*.34),Offset(cx-r*.12,cy-r*.48),
      Offset(cx+r*.02,cy-r*.28)
    ];
    for(int i=0;i<pathPoints.length-1;i++){
      final a=pathPoints[i],b=pathPoints[i+1];
      _polygon(canvas,[
        Offset(a.dx-u*1.05,a.dy),Offset(a.dx+u*.82,a.dy),
        Offset(b.dx+u*.82,b.dy),Offset(b.dx-u*.85,b.dy)
      ],const Color(0xFFC99B63));
    }
    for(int i=0;i<13;i++){
      final x=cx-r*.37+((i%3)-1)*u*.42;
      final y=cy+r*.55-i*u*.78;
      _oval(canvas,x,y,u*.48,u*.29,const Color(0xFF8F7655));
      _oval(canvas,x+u*.07,y-u*.04,u*.32,u*.16,const Color(0xFFE0C18A));
    }

    // Arbustos y flores en pequeños grupos.
    for(int i=0;i<8;i++){
      final x=cx+(((i*23)%17)-8)*u*.95;
      final y=cy+(((i*17)%15)-7)*u*.83;
      if(i%2==0){
        _rect(canvas,x,y,u*.22,u*.38,const Color(0xFF397C43));
        _rect(canvas,x-u*.18,y-u*.12,u*.34,u*.28,const Color(0xFF4D9B4E));
        _rect(canvas,x+u*.14,y-u*.18,u*.30,u*.30,const Color(0xFF5EAD50));
      } else {
        _rect(canvas,x,y,u*.18,u*.28,const Color(0xFF3E914C));
        _rect(canvas,x-u*.18,y-u*.10,u*.18,u*.18,const Color(0xFFFFD56D));
        _rect(canvas,x+u*.12,y-u*.22,u*.18,u*.18,const Color(0xFFFF9DB2));
      }
    }

    // Árboles con tronco, raíces, copa en capas y píxeles de luz.
    final treeSpots=<Offset>[
      Offset(cx-r*.48,cy-r*.40),Offset(cx+r*.48,cy-r*.38),
      Offset(cx-r*.53,cy+r*.35),Offset(cx+r*.50,cy+r*.38),
      Offset(cx+r*.02,cy-r*.62),Offset(cx+r*.05,cy+r*.62),
    ];
    for(int i=0;i<trees.clamp(0,treeSpots.length);i++){
      final o=_arrange(treeSpots[i],cx,cy);
      _oval(canvas,o.dx-u*.80,o.dy+u*.30,u*1.7,u*.55,
          const Color(0x55365C38));
      _rect(canvas,o.dx-u*.16,o.dy-u*.05,u*.34,u*.98,
          const Color(0xFF89552F));
      _rect(canvas,o.dx-u*.48,o.dy+u*.54,u*.38,u*.16,
          const Color(0xFF89552F));
      _rect(canvas,o.dx+u*.12,o.dy+u*.58,u*.36,u*.16,
          const Color(0xFF89552F));
      _oval(canvas,o.dx-u*1.12,o.dy-u*1.22,u*2.25,u*1.85,
          const Color(0xFF285F3D));
      _oval(canvas,o.dx-u*.88,o.dy-u*1.43,u*1.82,u*1.50,
          const Color(0xFF3D8B48));
      _oval(canvas,o.dx-u*.55,o.dy-u*1.42,u*1.22,u*.95,
          const Color(0xFF65B84D));
      _oval(canvas,o.dx-u*.38,o.dy-u*1.34,u*.72,u*.48,
          const Color(0xFF8BD45A));
      _rect(canvas,o.dx-u*.72,o.dy-u*.65,u*.25,u*.20,
          const Color(0xFFB0E36A));
      _rect(canvas,o.dx+u*.48,o.dy-u*.32,u*.22,u*.20,
          const Color(0xFF75C653));
    }

    // Casas: paredes con zócalo, tejado a dos aguas, chimenea y ventanas.
    final homeSpots=<Offset>[
      Offset(cx+u*.65,cy-u*.15),Offset(cx+r*.38,cy+r*.22),
      Offset(cx-r*.30,cy+r*.24),Offset(cx+u*.10,cy+r*.58),
    ];
    for(int i=0;i<houses.clamp(0,homeSpots.length);i++){
      final o=_arrange(homeSpots[i],cx,cy);
      _oval(canvas,o.dx-u*1.25,o.dy+u*.70,u*2.6,u*.52,
          const Color(0x55345D38));
      _rect(canvas,o.dx-u*.90,o.dy-u*.05,u*1.80,u*1.18,
          const Color(0xFF684936));
      _rect(canvas,o.dx-u*.78,o.dy-u*.12,u*1.56,u*1.02,
          const Color(0xFFF0D6A0));
      _rect(canvas,o.dx-u*.88,o.dy+u*.78,u*1.76,u*.20,
          const Color(0xFF78604A));
      _polygon(canvas,[
        Offset(o.dx-u*1.18,o.dy-u*.16),Offset(o.dx,o.dy-u*1.20),
        Offset(o.dx+u*1.18,o.dy-u*.16),Offset(o.dx+u*.95,o.dy+u*.04),
        Offset(o.dx,o.dy-u*.78),Offset(o.dx-u*.96,o.dy+u*.04)
      ],const Color(0xFF783E39));
      _polygon(canvas,[
        Offset(o.dx-u*1.08,o.dy-u*.20),Offset(o.dx,o.dy-u*1.15),
        Offset(o.dx,o.dy-u*.78),Offset(o.dx-u*.92,o.dy+u*.03)
      ],const Color(0xFFD66A4E));
      _polygon(canvas,[
        Offset(o.dx,o.dy-u*1.15),Offset(o.dx+u*1.08,o.dy-u*.20),
        Offset(o.dx+u*.94,o.dy+u*.03),Offset(o.dx,o.dy-u*.78)
      ],const Color(0xFFB94F49));
      for(int k=0;k<4;k++){
        _rect(canvas,o.dx-u*.78+k*u*.42,o.dy-u*.20+k*u*.19,
            u*.28,u*.10,const Color(0xFFE58A62));
      }
      _rect(canvas,o.dx+u*.38,o.dy-u*1.50,u*.32,u*.75,
          const Color(0xFF754B3D));
      _rect(canvas,o.dx+u*.43,o.dy-u*1.43,u*.22,u*.18,
          const Color(0xFFB9A18A));
      _rect(canvas,o.dx-u*.20,o.dy+u*.35,u*.43,u*.82,
          const Color(0xFF8B5638));
      _rect(canvas,o.dx-u*.12,o.dy+u*.43,u*.27,u*.72,
          const Color(0xFFA96C43));
      _oval(canvas,o.dx+u*.12,o.dy+u*.72,u*.08,u*.08,
          const Color(0xFFFFD66E));
      _rect(canvas,o.dx-u*.68,o.dy+u*.12,u*.34,u*.32,
          const Color(0xFF6C9DA5));
      _rect(canvas,o.dx+u*.36,o.dy+u*.12,u*.34,u*.32,
          const Color(0xFF6C9DA5));
      _rect(canvas,o.dx-u*.72,o.dy+u*.08,u*.42,u*.08,
          const Color(0xFFF8E8B8));
      _rect(canvas,o.dx+u*.32,o.dy+u*.08,u*.42,u*.08,
          const Color(0xFFF8E8B8));
    }

    // Habitantes con siluetas completas y detalles propios.
    final spots=<Offset>[
      Offset(cx-r*.08,cy+r*.20),Offset(cx+r*.24,cy+r*.25),
      Offset(cx+u*.10,cy+r*.48)
    ];
    final clothes=[const Color(0xFFE5A04F),const Color(0xFF5C9B69),
      const Color(0xFF668FCB)];
    final hair=[const Color(0xFF75452F),const Color(0xFF4D4035),
      const Color(0xFF55466B)];
    for(int i=0;i<residentCount.clamp(0,3);i++){
      final o=_arrange(spots[i],cx,cy);
      final col=clothes[i];
      _oval(canvas,o.dx-u*.46,o.dy+u*.53,u*.92,u*.25,
          const Color(0x55304F37));
      // Piernas y zapatos.
      _rect(canvas,o.dx-u*.23,o.dy+u*.23,u*.18,u*.42,
          const Color(0xFF665044));
      _rect(canvas,o.dx+u*.05,o.dy+u*.23,u*.18,u*.42,
          const Color(0xFF665044));
      _rect(canvas,o.dx-u*.29,o.dy+u*.58,u*.28,u*.13,
          const Color(0xFF493D39));
      _rect(canvas,o.dx+u*.02,o.dy+u*.58,u*.28,u*.13,
          const Color(0xFF493D39));
      // Brazos, torso y cuello.
      _rect(canvas,o.dx-u*.43,o.dy-u*.02,u*.18,u*.48,col);
      _rect(canvas,o.dx+u*.25,o.dy-u*.02,u*.18,u*.48,col);
      _rect(canvas,o.dx-u*.27,o.dy-u*.10,u*.54,u*.60,col);
      _rect(canvas,o.dx-u*.12,o.dy-u*.20,u*.24,u*.16,
          const Color(0xFFFFC69A));
      // Cabeza, cabello, orejas y expresión.
      _rect(canvas,o.dx-u*.28,o.dy-u*.72,u*.56,u*.56,
          const Color(0xFFFFC99F));
      _rect(canvas,o.dx-u*.36,o.dy-u*.68,u*.12,u*.22,
          const Color(0xFFFFB98E));
      _rect(canvas,o.dx+u*.24,o.dy-u*.68,u*.12,u*.22,
          const Color(0xFFFFB98E));
      _rect(canvas,o.dx-u*.31,o.dy-u*.79,u*.62,u*.20,hair[i]);
      _rect(canvas,o.dx-u*.29,o.dy-u*.62,u*.12,u*.20,hair[i]);
      _rect(canvas,o.dx+u*.17,o.dy-u*.62,u*.12,u*.20,hair[i]);
      _rect(canvas,o.dx-u*.16,o.dy-u*.48,u*.07,u*.07,
          const Color(0xFF493B36));
      _rect(canvas,o.dx+u*.09,o.dy-u*.48,u*.07,u*.07,
          const Color(0xFF493B36));
      _rect(canvas,o.dx-u*.04,o.dy-u*.32,u*.12,u*.04,
          const Color(0xFFB96E63));
      // Detalle distintivo de cada residente.
      if(i==0){
        _rect(canvas,o.dx-u*.38,o.dy-u*.91,u*.76,u*.12,
            const Color(0xFFE8B65D)); // pañuelo
      } else if(i==1){
        _rect(canvas,o.dx-u*.34,o.dy-u*.91,u*.68,u*.12,
            const Color(0xFF6CB978)); // gorro
        _rect(canvas,o.dx+u*.22,o.dy-u*.98,u*.12,u*.18,
            const Color(0xFF4C8D53));
      } else {
        _rect(canvas,o.dx-u*.35,o.dy-u*.88,u*.70,u*.13,
            const Color(0xFF688BC5)); // gorro de inventor
        _rect(canvas,o.dx+u*.30,o.dy-u*.82,u*.16,u*.16,
            const Color(0xFFFFD36A));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IslandPainter old) =>
      old.land != land || old.houses != houses || old.trees != trees ||
      old.residentCount != residentCount || old.layout != layout;
}
