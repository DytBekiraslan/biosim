import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import '../data/ets_data.dart';
import '../models/complex_model.dart';

class EtsScreen extends StatefulWidget {
  @override
  _EtsScreenState createState() => _EtsScreenState();
}

// PROTON MODELİ
class ProtonModel {
  String id;
  double top;
  double left;
  bool isMovingToATP; 
  
  ProtonModel(this.id, this.top, this.left, {this.isMovingToATP = false});
}

class _EtsScreenState extends State<EtsScreen> with SingleTickerProviderStateMixin {
  // --- OYUN DURUMU ---
  int gameLevel = 0; 
  int lives = 3; 
  
  // --- SİMÜLASYON VERİLERİ ---
  int totalProtons = 0;
  double atpCount = 0.0;
  String feedbackMessage = "Laboratuvar hazır.";
  
  // --- LEVEL 2 (MÜHENDİS) DURUMU ---
  // ATP Sentaz parçaları için özel takip
  bool isF0Built = false; 
  bool isF1Built = false;

  // --- LEVEL 3 (SABOTAJ) ---
  List<String> sabotageQueue = [];
  String? currentSabotage;
  bool isAlarmActive = false;
  bool sabotageTriggered = false;
  
  // --- ANİMASYON ---
  late AnimationController _turbineController;

  // --- HAREKETLİ PARÇALAR ---
  bool showElectron = false;
  double electronLeft = 0;
  double electronTop = 0;
  Color electronColor = Colors.yellow;
  Duration electronSpeed = Duration(seconds: 1);

  // --- EFEKTLER ---
  List<ProtonModel> protons = []; 
  List<Widget> activeEffects = []; 
  List<Widget> subUnitEffects = []; 

  // --- BALON ---
  bool showBubble = false;
  String bubbleText = "";
  double bubbleLeft = 0;
  double bubbleTop = 0;
  Completer<void>? _bubbleCompleter; 

  // --- SU OLUŞUMU ---
  bool showWater = false;
  double waterTop = 0;
  double waterLeft = 0;

  @override
  void initState() {
    super.initState();
    _turbineController = AnimationController(vsync: this, duration: Duration(seconds: 3))..repeat(); 
  }

  @override
  void dispose() {
    _turbineController.dispose();
    super.dispose();
  }

  void _playSound(String type) {
    if (type == "ding") {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✨ ATP SENTEZLENDİ!"), duration: Duration(milliseconds: 800), backgroundColor: Colors.green));
    } else if (type == "alarm") {
      setState(() => isAlarmActive = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (gameLevel == 0) return _buildMainMenu();
    
    return Scaffold(
      backgroundColor: isAlarmActive ? Colors.red[50] : Colors.white,
      appBar: AppBar(
        title: Text("Seviye $gameLevel: ${_getLevelTitle()}"),
        backgroundColor: isAlarmActive ? Colors.red : Colors.indigo,
        actions: [IconButton(icon: Icon(Icons.home), onPressed: () => setState(() => gameLevel = 0))],
      ),
      body: Column(
        children: [
          _buildTopHud(),
          Expanded(
            child: Stack(
              children: [
                _buildBackground(), 
                
                // KOMPLEKSLER (1-4)
                ...etsComplexes.map((c) => _buildComplexWidget(c)).toList(),
                
                _buildMobileCarriers(), 

                if (currentSabotage == "İyonofor" && sabotageTriggered) _buildSmokeEffect(),

                _buildSpinningTurbine(), // ATP SENTAZ (F0 ve F1)

                if (gameLevel == 2) _buildComponentInventory(),
                if (gameLevel != 2) _buildFuels(),

                ...protons.map((p) => _buildProtonWidget(p)).toList(),
                ...subUnitEffects,
                ...activeEffects,

                if (showElectron) _buildElectronWidget(),
                if (showWater) _buildWaterWidget(),

                if (isAlarmActive) Center(child: Icon(Icons.warning_amber_rounded, size: 100, color: Colors.red.withOpacity(0.5))),

                if (showBubble) _buildSpeechBubble(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- MENÜ ---
  Widget _buildMainMenu() {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hub, size: 80, color: Colors.cyanAccent),
            SizedBox(height: 20),
            Text("ETS MASTER", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
            SizedBox(height: 40),
            _buildLevelButton(1, "🎓 Seviye 1: Öğrenme Modu", Colors.green),
            _buildLevelButton(2, "🔧 Seviye 2: Mühendis Modu", Colors.orange),
            _buildLevelButton(3, "🕵️ Seviye 3: Teşhis Modu", Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelButton(int level, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color, fixedSize: Size(300, 60)),
        onPressed: () {
          setState(() {
            gameLevel = level;
            _resetGameForLevel();
          });
        },
        child: Text(title, style: TextStyle(fontSize: 18, color: Colors.white)),
      ),
    );
  }

  // --- ANİMASYON MOTORU ---
  
  Future<void> _animateElectron(String type) async {
    Duration speed = (gameLevel == 1) ? Duration(seconds: 2) : Duration(seconds: 1);
    
    setState(() {
      showElectron = true;
      sabotageTriggered = false;
      isAlarmActive = false;
      electronSpeed = speed;
      electronColor = (type == "NADH") ? Colors.yellow : Colors.orange;
      electronLeft = (type == "NADH") ? _getComplexX(1) + 25 : _getComplexX(2) + 25;
      electronTop = _getMembraneY() + 100; 
      feedbackMessage = "$type sisteme giriyor...";
    });

    if (gameLevel == 3 && currentSabotage == null && sabotageQueue.isNotEmpty) {
      currentSabotage = sabotageQueue.first;
    }

    // --- ADIM 1: KOMPLEKSE GİRİŞ ---
    await Future.delayed(Duration(milliseconds: 500)); 
    setState(() => electronTop = _getMembraneY() + 20); 

    if (type == "NADH") {
      _spawnMoleculeTransformation("NADH", "NAD+", Colors.yellow, Colors.grey, _getComplexX(1), _getMembraneY() + 60, true);
      _flashSubUnit(1, "FMN", -20);
      await Future.delayed(Duration(milliseconds: 800));
      _flashSubUnit(1, "Fe-S", 10);

      if (gameLevel == 1) await _showBubbleAndWait(1, "Merhaba! Ben Kompleks I (NADH Dehidrogenaz).\n\nNADH elektronlarını FMN'ye, oradan Fe-S merkezlerime aktardı.\nBu enerjiyle 4 Protonu (\$H⁺) zarlar arasına postaladım!");
      _triggerProtonPump(1, 4); 
    } else {
       _spawnMoleculeTransformation("FADH2", "FAD", Colors.orange, Colors.grey, _getComplexX(2), _getMembraneY() + 60, true);
       _flashSubUnit(2, "FAD", -10);
       await Future.delayed(Duration(milliseconds: 800));
       _flashSubUnit(2, "Fe-S", 15);

       if (gameLevel == 1) await _showBubbleAndWait(2, "Selam! Ben Kompleks II (Süksinat Dehidrogenaz).\n\nFADH2'den elektronları FAD ve Fe-S kümelerimle aldım.\nBen proton pompalamam, sadece kuryeyim.");
    }

    // --- ADIM 2: UBIKINON ---
    double qPos = _getComplexX(3) - 40; 
    setState(() { electronLeft = qPos; feedbackMessage = "Ubikinon (Q) yükü devralıyor..."; });
    await Future.delayed(speed); 

    if (gameLevel == 1) await _showBubbleAndWait(3, "Ben Ubikinon (Q).\n\nLipid tabakasında yüzen bir kuryeyim.\nElektronları güvenle Kompleks III'e götürüyorum.");

    // --- ADIM 3: KOMPLEKS III ---
    setState(() { electronLeft = _getComplexX(3) + 25; feedbackMessage = "Kompleks III'e aktarım..."; });
    await Future.delayed(speed);

    _flashSubUnit(3, "Cyt b", -20);
    await Future.delayed(Duration(milliseconds: 600));
    _flashSubUnit(3, "Fe-S", 0);
    await Future.delayed(Duration(milliseconds: 600));
    _flashSubUnit(3, "Cyt c1", 20);

    if (gameLevel == 1) await _showBubbleAndWait(3, "Teşekkürler Q! Ben Kompleks III (Sitokrom bc1).\n\nQ döngüsü sayesinde elektronları aktarırken 4 Proton (\$H⁺) daha pompalıyorum!");
    _triggerProtonPump(3, 4);

    // --- ADIM 4: SITOKROM C ---
    double cytCPos = _getComplexX(4) - 40;
    setState(() { electronLeft = cytCPos; electronTop = _getMembraneY() - 25; feedbackMessage = "Sitokrom c taşıyor..."; });
    await Future.delayed(speed);

    if (gameLevel == 1) await _showBubbleAndWait(4, "Ben Sitokrom c.\n\nZarın dış yüzeyine tutunmuş bir proteinim.\nSon aşama için elektronları IV'e taşıyorum.");

    // --- ADIM 5: KOMPLEKS IV ---
    setState(() { electronLeft = _getComplexX(4) + 25; electronTop = _getMembraneY() + 20; feedbackMessage = "Kompleks IV çalışıyor..."; });
    await Future.delayed(speed);

    // SABOTAJ: SİYANÜR (GİZLİ UYARI)
    if (gameLevel == 3 && currentSabotage == "Siyanür") {
      setState(() { 
        sabotageTriggered = true; 
        electronColor = Colors.black; 
        feedbackMessage = "⚠️ HATA! Akış aniden durdu! Elektronlar ilerlemiyor."; // Açık isim yok
        _playSound("alarm"); 
      });
      return; 
    }

    _flashSubUnit(4, "Cyt a", -20);
    await Future.delayed(Duration(milliseconds: 600));
    _flashSubUnit(4, "Cyt a3", 0);
    await Future.delayed(Duration(milliseconds: 600));
    _flashSubUnit(4, "Cu", 20);

    if (gameLevel == 1) await _showBubbleAndWait(4, "Ben Kompleks IV (Sitokrom Oksidaz).\n\nBakır (Cu) ve Sitokrom a+a3 merkezlerimle Oksijene (O₂) elektron verip SU (H₂O) ürettim.\nSon 2 Protonu da depoya gönderiyorum.");
    _triggerProtonPump(4, 2);

    setState(() { showElectron = false; showWater = true; waterLeft = _getComplexX(4) + 20; waterTop = _getMembraneY() + 20; });
    await Future.delayed(Duration(milliseconds: 100));
    setState(() => waterTop = _getMembraneY() + 120); 
    await Future.delayed(Duration(milliseconds: 800));
    setState(() => showWater = false);

    // SABOTAJ: İYONOFOR (GİZLİ UYARI)
    if (gameLevel == 3 && currentSabotage == "İyonofor") {
      setState(() { 
        sabotageTriggered = true; 
        protons.clear(); 
        totalProtons = 0; 
        feedbackMessage = "⚠️ UYARI: Pompalar çalışıyor ama basınç (H+) oluşmuyor!"; // İsim yok
        _playSound("alarm"); 
      });
      return; 
    }

    // --- ADIM 6: ATP ÜRETİMİ ---
    await Future.delayed(Duration(milliseconds: 500));
    if (protons.isNotEmpty) {
      await _automateATPProduction();
    } else {
       feedbackMessage = "Havuzda yeterli H+ yok. Daha fazla yakıt lazım.";
    }
  }

  Future<void> _automateATPProduction() async {
    // SABOTAJ: OLİGOMİSİN (GİZLİ UYARI)
    if (gameLevel == 3 && currentSabotage == "Oligomisin") {
       _turbineController.stop(); 
       setState(() { 
         isAlarmActive = true; 
         feedbackMessage = "⚠️ HATA! Türbin dönmüyor, sanki bir şey sıkışmış!"; // İsim yok
       });
       _playSound("alarm");
       return;
    }

    if (gameLevel == 1) {
      await _showBubbleAndWait(5, "Ve büyük final! Ben ATP Sentaz (Motor).\n\nSlayt 48'deki gibi protonlar (\$H⁺) \$F₀ kanalımdan girip \$F₁'den çıkacak.\nBu dönüş hareketi ATP sentezleyecek!");
    }

    int consumed = protons.length; // Mevcut tüm protonları kullan
    
    if (consumed > 0) {
      // 1. ADIM: F0'a Toplan
      double f0X = MediaQuery.of(context).size.width - 45; 
      double f0Y = _getMembraneY() - 40; 

      for(int i=0; i<consumed; i++) {
         setState(() {
           protons[i].top = f0Y; 
           protons[i].left = f0X + (math.Random().nextDouble() * 20 - 10);
           protons[i].isMovingToATP = true;
         });
      }
      
      await Future.delayed(Duration(seconds: 1)); 

      // 2. ADIM: Kanaldan Aşağı (Matriks)
      double f1Y = _getMembraneY() + 80;

      for(int i=0; i<consumed; i++) {
         setState(() {
           protons[i].top = f1Y; 
         });
      }
      
      _turbineController.duration = Duration(milliseconds: 300); 
      _turbineController.repeat();

      await Future.delayed(Duration(seconds: 1)); 

      // 3. ADIM: Temizlik ve Ödül
      setState(() {
        protons.clear(); // HEPSİNİ SİL
        totalProtons = 0;
        
        _spawnMoleculeTransformation("ADP+Pi", "ATP ✨", Colors.orangeAccent, Colors.yellowAccent, f0X, f1Y, false);
        
        // HESAPLAMA (PDF: 4 H+ = 1 ATP)
        double gained = consumed / 4.0;
        atpCount += gained;
        
        feedbackMessage = "Harika! $gained ATP sentezlendi.";
        _playSound("ding");
      });
      
      _turbineController.duration = Duration(seconds: 3); 
    }
  }

  // --- YARDIMCILAR ---
  
  void _triggerProtonPump(int complexId, int amount) async {
    if (gameLevel == 3 && currentSabotage == "İyonofor") return;

    double startX = _getComplexX(complexId) + 15;
    double startY = _getMembraneY() + 10;
    
    for(int i=0; i<amount; i++) {
       await Future.delayed(Duration(milliseconds: 150));
       _addProtonToPool(startX, startY);
    }
  }

  void _addProtonToPool(double startX, double startY) {
    double targetY = 10 + math.Random().nextDouble() * (_getMembraneY() - 30);
    double targetX = 20 + math.Random().nextDouble() * (MediaQuery.of(context).size.width - 40);
    var p = ProtonModel(UniqueKey().toString(), startY, startX);
    setState(() { 
      protons.add(p);
      totalProtons = protons.length;
    });
    Future.delayed(Duration(milliseconds: 50), () { setState(() { p.top = targetY; p.left = targetX; }); });
  }

  void _flashSubUnit(int complexId, String text, double offsetY) {
    Key sKey = UniqueKey();
    double x = _getComplexX(complexId) + 15;
    double y = _getMembraneY() + offsetY + 20;
    setState(() {
      subUnitEffects.add(
        _SubUnitFlash(
          key: sKey, x: x, y: y, text: text,
          onComplete: () => setState(() => subUnitEffects.removeWhere((w) => w.key == sKey))
        )
      );
    });
  }

  Widget _buildProtonWidget(ProtonModel p) {
    return AnimatedPositioned(
      duration: p.isMovingToATP ? Duration(milliseconds: 800) : Duration(seconds: 2), curve: Curves.easeInOut, top: p.top, left: p.left,
      child: Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.yellowAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.yellow, blurRadius: 2)]), child: Center(child: Text("H+", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)))),
    );
  }

  void _spawnMoleculeTransformation(String start, String end, Color c1, Color c2, double x, double y, bool returnKrebs) {
    double targetKrebsX = _getComplexX(2) + 20; 
    double targetKrebsY = MediaQuery.of(context).size.height * 0.8;
    Key tKey = UniqueKey();
    setState(() {
      activeEffects.add(_MoleculeTransformer(
        key: tKey, startX: x, startY: y, targetX: targetKrebsX, targetY: targetKrebsY,
        startText: start, endText: end, startColor: c1, endColor: c2, returnToKrebs: returnKrebs,
        onComplete: () => setState(() => activeEffects.removeWhere((w) => w.key == tKey))
      ));
    });
  }

  Future<void> _showBubbleAndWait(int complexId, String text) {
    _bubbleCompleter = Completer<void>();
    setState(() {
      showBubble = true;
      bubbleText = text;
      
      double screenW = MediaQuery.of(context).size.width;
      double bubbleW = 220;
      double targetX = _getComplexX(complexId) - 60;
      if (complexId == 5) targetX = screenW - bubbleW - 20;
      if (targetX < 10) targetX = 10;
      if (targetX + bubbleW > screenW) targetX = screenW - bubbleW - 10;

      bubbleLeft = targetX;
      bubbleTop = _getMembraneY() - 170; 
    });
    return _bubbleCompleter!.future; 
  }

  void _onBubbleOkClicked() {
    setState(() => showBubble = false);
    _bubbleCompleter?.complete(); 
  }

  // --- UI BİLEŞENLERİ ---
  Widget _buildSpeechBubble() {
    return Positioned(
      left: bubbleLeft, top: bubbleTop,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 220, padding: EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.indigo, width: 2), boxShadow: [BoxShadow(color:Colors.black26, blurRadius:10)]),
          child: Column(children: [Text(bubbleText, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), SizedBox(height: 5), ElevatedButton(onPressed: _onBubbleOkClicked, child: Text("Tamam"), style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact, backgroundColor: Colors.indigo, foregroundColor: Colors.white))]),
        ),
      ),
    );
  }

  Widget _buildElectronWidget() {
    return AnimatedPositioned(duration: electronSpeed, curve: Curves.easeInOut, left: electronLeft, top: electronTop, child: Container(width: 20, height: 20, decoration: BoxDecoration(color: electronColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: electronColor, blurRadius: 10)]), child: Icon(Icons.bolt, size: 15)));
  }
  
  // MÜHENDİS MODU İÇİN ÖZEL TÜRBİN (Sürükle-Bırak)
  Widget _buildSpinningTurbine() {
    return Positioned(right: 20, top: _getMembraneY() - 40, child: Column(children: [
       // F0 KISMI (Zarın İçinde)
       DragTarget<String>(
         onAccept: (val) { if(val=="F0") setState(() { isF0Built=true; _checkLevel2Completion(); }); },
         builder: (ctx, cand, rej) {
           bool built = (gameLevel != 2) || isF0Built;
           return Container(
             width: 50, height: 40, 
             decoration: BoxDecoration(color: built ? Colors.red[800] : Colors.grey[300], borderRadius: BorderRadius.vertical(top: Radius.circular(5)), border: Border.all(color: cand.isNotEmpty ? Colors.green : Colors.transparent)),
             child: Center(child: Text("F0", style:TextStyle(color: built ? Colors.white70 : Colors.black45, fontSize:10, fontWeight:FontWeight.bold)))
           );
         }
       ),
       
       Container(width: 10, height: 20, color: Colors.grey[400]),
       
       // F1 KISMI (Matrikste)
       DragTarget<String>(
         onAccept: (val) { if(val=="F1") setState(() { isF1Built=true; _checkLevel2Completion(); }); },
         builder: (ctx, cand, rej) {
           bool built = (gameLevel != 2) || isF1Built;
           return built 
             ? RotationTransition(turns: _turbineController, child: Container(width: 70, height: 70, decoration: BoxDecoration(color: Colors.red[600], shape: BoxShape.circle, border: Border.all(color:Colors.white, width: 2)), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.settings, color: Colors.white, size: 30), Text("F1", style:TextStyle(color:Colors.white, fontSize:10, fontWeight:FontWeight.bold))]))))
             : Container(width: 70, height: 70, decoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle, border: Border.all(color: cand.isNotEmpty ? Colors.green : Colors.grey)), child: Center(child: Text("F1 Yeri", style:TextStyle(fontSize:10))));
         }
       ),

       if (gameLevel == 3) Padding(padding: EdgeInsets.only(top:5), child: ElevatedButton(onPressed: _showDiagnosisDialog, child: Text("TEŞHİS"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red)))
    ]));
  }

  void _checkLevel2Completion() {
    // Tüm kompleksler + F0 + F1 yapıldı mı?
    bool allComplexesOk = etsComplexes.every((c) => c.isBuilt);
    if (allComplexesOk && isF0Built && isF1Built) {
      _showDialogInfo("TEBRİKLER!", "Mühendislik Harikası!\nFabrikayı başarıyla kurdun.\nArtık 'Teşhis Modu' açıldı.");
      // Burada level 3'e geçiş butonu veya menüye dönüş yapılabilir
    }
  }

  // MÜHENDİS MODU ENVANTERİ
  Widget _buildComponentInventory() {
    List<dynamic> items = [...buildingBlocks]; // Standart parçalar
    // F0 ve F1 ekle (eğer daha yapılmadıysa)
    if (!isF0Built) items.add("F0");
    if (!isF1Built) items.add("F1");

    return Positioned(bottom: 10, left: 0, right: 0, child: Container(height: 60, color: Colors.black54, child: ListView(scrollDirection: Axis.horizontal, children: items.map((comp) { 
       String label = (comp is CellComponent) ? comp.name : comp.toString();
       return Draggable<Object>(
         data: (comp is CellComponent) ? comp : label, // String olarak F0/F1
         feedback: Material(color:Colors.transparent, child: Chip(label:Text(label), backgroundColor: Colors.orangeAccent)), 
         child: Padding(padding:EdgeInsets.all(4), child: Chip(label:Text(label)))
       );
    }).toList())));
  }

  // --- DİĞER FONKSİYONLAR AYNI ---
  void _checkDiagnosis(String answer) {
    Navigator.pop(context);
    if (answer == currentSabotage) {
      _showDialogInfo("TEBRİKLER!", "Doğru teşhis!").then((_) {
        setState(() { sabotageQueue.removeAt(0); currentSabotage = null; isAlarmActive = false; if (sabotageQueue.isEmpty) { _showDialogInfo("BİTTİ", "Doktor unvanını hak ettin!"); gameLevel = 0; } });
      });
    } else { _showDialogInfo("YANLIŞ", "Tekrar dene."); }
  }

  void _resetGameForLevel() {
    protons.clear(); totalProtons = 0; atpCount = 0; currentSabotage = null; isAlarmActive = false;
    // Level 2 sıfırlama
    isF0Built = false; isF1Built = false;
    for(var c in etsComplexes) c.isBuilt = false;

    if (gameLevel == 3) { sabotageQueue = ["Oligomisin", "Siyanür", "İyonofor"]; sabotageQueue.shuffle(); }
    if (gameLevel == 1) { isF0Built = true; isF1Built = true; for(var c in etsComplexes) c.isBuilt = true; }
  }

  Future<void> _showDialogInfo(String title, String body) async {
    return showDialog<void>(context: context, builder: (c) => AlertDialog(title: Text(title), content: Text(body), actions: [TextButton(child: Text('Tamam'), onPressed: () => Navigator.pop(c))]));
  }
  
  void _showDiagnosisDialog() {
    showDialog(context: context, builder: (c) => SimpleDialog(title: Text("Teşhis?"), children: [SimpleDialogOption(child: Text("Oligomisin"), onPressed: () => _checkDiagnosis("Oligomisin")), SimpleDialogOption(child: Text("Siyanür"), onPressed: () => _checkDiagnosis("Siyanür")), SimpleDialogOption(child: Text("İyonofor"), onPressed: () => _checkDiagnosis("İyonofor"))]));
  }

  Widget _buildTopHud() {
    return Padding(padding: EdgeInsets.all(8), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        Text("Havuzdaki H+: ${protons.length}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
        Text("ATP: ${atpCount.toStringAsFixed(1)}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
        if (gameLevel == 2) Text("Can: $lives ❤️", style: TextStyle(color: Colors.red))
      ]),
      Container(color: Colors.yellow[100], width: double.infinity, padding: EdgeInsets.all(4), child: Text(feedbackMessage, textAlign: TextAlign.center))
    ]));
  }

  Widget _buildBackground() {
    double krebX = _getComplexX(2);
    return Column(children: [
      Expanded(flex: 4, child: Container(color: Colors.cyan[50], child: Align(alignment:Alignment.topLeft, child:Text(" ZARLAR ARASI BOŞLUK\n (Yüksek H+)", style: TextStyle(color:Colors.cyan[800], fontWeight: FontWeight.bold))))),
      Container(height: 60, color: Colors.brown[300], child: Center(child: Text("İÇ ZAR (Krista)", style: TextStyle(color:Colors.white30, letterSpacing: 5)))),
      Expanded(flex: 6, child: Container(color: Colors.orange[50], child: Stack(children: [
          Align(alignment:Alignment.bottomLeft, child: Padding(padding: EdgeInsets.all(8.0), child: Text(" MATRİKS\n (Krebs Döngüsü Buradadır)", style: TextStyle(color:Colors.orange[900], fontWeight: FontWeight.bold)))),
          Positioned(bottom: 20, left: krebX - 15, child: Opacity(opacity: 0.3, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.orange, width: 5)), child: Center(child: Text("KREBS\nDÖNGÜSÜ", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[900]))))))
      ]))),
    ]);
  }

  Widget _buildComplexWidget(MitoComplex c) {
    if (c.id == 5) return SizedBox.shrink(); 

    double left = _getComplexX(c.id); double top = _getMembraneY() - 20; bool isVisible = (gameLevel != 2) || c.isBuilt; 
    String romanId = ""; if (c.id == 1) romanId = "I"; if (c.id == 2) romanId = "II"; if (c.id == 3) romanId = "III"; if (c.id == 4) romanId = "IV";
    
    Widget innerContent = SizedBox.shrink();
    if (c.id == 1) innerContent = Column(mainAxisAlignment:MainAxisAlignment.spaceEvenly, children: [Text("FMN", style:TextStyle(fontSize:9, color:Colors.white70)), Text("Fe-S", style:TextStyle(fontSize:9, color:Colors.white70))]);
    if (c.id == 2) innerContent = Column(mainAxisAlignment:MainAxisAlignment.spaceEvenly, children: [Text("FAD", style:TextStyle(fontSize:9, color:Colors.white70)), Text("Fe-S", style:TextStyle(fontSize:9, color:Colors.white70)), Text("Hem", style:TextStyle(fontSize:9, color:Colors.white70))]);
    if (c.id == 3) innerContent = Column(mainAxisAlignment:MainAxisAlignment.spaceEvenly, children: [Text("Cyt b", style:TextStyle(fontSize:9, color:Colors.white70)), Text("Fe-S", style:TextStyle(fontSize:9, color:Colors.white70)), Text("Cyt c1", style:TextStyle(fontSize:9, color:Colors.white70))]);
    if (c.id == 4) innerContent = Column(mainAxisAlignment:MainAxisAlignment.spaceEvenly, children: [Text("Cyt a", style:TextStyle(fontSize:9, color:Colors.white70)), Text("Cyt a3", style:TextStyle(fontSize:9, color:Colors.white70)), Text("Cu", style:TextStyle(fontSize:9, color:Colors.white70))]);

    return Positioned(left: left, top: top, child: DragTarget<CellComponent>(
      onAccept: (component) { 
        if (component.targetComplexId == c.id) {
           setState(() { c.isBuilt = true; _checkLevel2Completion(); });
        } else { setState(() { lives--; if(lives<=0) { gameLevel=0; _showDialogInfo("Bitti", "Yanlış parça! Laboratuvar patladı."); } }); }
      },
      builder: (context, candidate, rejected) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(width: 70, height: 100, decoration: BoxDecoration(color: isVisible ? _getComplexColor(c.id) : Colors.grey.withOpacity(0.3), border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(10)),
              child: isVisible ? innerContent : Center(child: Icon(Icons.build, color:Colors.white54))),
            Positioned(top: -20, left: 0, right: 0, child: Center(child: Text("Kompleks $romanId", style: TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold))))
          ],
        );
      },
    ));
  }
  
  Widget _buildMobileCarriers() {
    return Stack(children: [
      Positioned(left: _getComplexX(3) - 30, top: _getMembraneY() + 15, child: CircleAvatar(radius: 12, backgroundColor: Colors.green, child: Text("Q", style: TextStyle(fontSize: 10, color:Colors.white)))),
      Positioned(left: _getComplexX(4) - 30, top: _getMembraneY() - 25, child: CircleAvatar(radius: 10, backgroundColor: Colors.pink, child: Text("C", style: TextStyle(fontSize: 8, color:Colors.white)))),
    ]);
  }

  Widget _buildFuels() {
    return Positioned(bottom: 30, left: 130, child: Row(children: [_buildDraggableFuel("NADH", Colors.blue[900]!), SizedBox(width: 20), _buildDraggableFuel("FADH2", Colors.orange[900]!)]));
  }

  Widget _buildDraggableFuel(String name, Color color) {
    return Draggable<String>(
      data: name, feedback: CircleAvatar(radius: 25, backgroundColor: color.withOpacity(0.7), child: Text(name)), childWhenDragging: CircleAvatar(radius: 25, backgroundColor: Colors.grey),
      onDragEnd: (details) { if(gameLevel!=2) _animateElectron(name); },
      child: CircleAvatar(radius: 25, backgroundColor: color, child: Text(name, style: TextStyle(color:Colors.white, fontWeight: FontWeight.bold))),
    );
  }
  
  Widget _buildWaterWidget() {
    return AnimatedPositioned(duration: Duration(milliseconds: 500), curve: Curves.bounceOut, left: waterLeft, top: waterTop, child: Column(children: [Icon(Icons.water_drop, color: Colors.blue), Text("H2O", style:TextStyle(fontSize:10, fontWeight:FontWeight.bold, color:Colors.blue))]));
  }
  
  Widget _buildSmokeEffect() {
    return Positioned.fill(child: IgnorePointer(child: Container(color: Colors.orange.withOpacity(0.2), child: Center(child: Text("🔥 ISI ARTIŞI 🔥", style: TextStyle(color: Colors.red, fontSize: 40))))));
  }

  double _getMembraneY() => MediaQuery.of(context).size.height * 0.35;
  double _getComplexX(int id) { double w = MediaQuery.of(context).size.width; if (id == 1) return w * 0.05; if (id == 2) return w * 0.25; if (id == 3) return w * 0.45; if (id == 4) return w * 0.65; if (id == 5) return w * 0.85; return 0; }
  Color _getComplexColor(int id) { if (id == 1) return Colors.purple; if (id == 2) return Colors.orange; if (id == 3) return Colors.teal; if (id == 4) return Colors.indigo; return Colors.grey; }
  String _getLevelTitle() { if (gameLevel == 1) return "Öğrenme"; if (gameLevel == 2) return "Mühendislik"; if (gameLevel == 3) return "Teşhis"; return ""; }
}

// EFEKTLER (Particle, Flash, Transform) - Aynen Korundu
class _FlyingParticle extends StatefulWidget {
  final double startX; final double startY; final String label; final Color color; final VoidCallback onComplete;
  const _FlyingParticle({Key? key, required this.startX, required this.startY, required this.label, required this.color, required this.onComplete}) : super(key: key);
  @override __FlyingParticleState createState() => __FlyingParticleState();
}
class __FlyingParticleState extends State<_FlyingParticle> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl; late Animation<double> _yAnim;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: Duration(seconds: 1)); _yAnim = Tween<double>(begin: widget.startY, end: widget.startY - 100).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)); _ctrl.forward().then((_) => widget.onComplete()); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { return AnimatedBuilder(animation: _ctrl, builder: (context, child) { return Positioned(left: widget.startX, top: _yAnim.value, child: Opacity(opacity: 1.0 - _ctrl.value, child: Container(padding: EdgeInsets.all(4), decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(5)), child: Text(widget.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))))); }); }
}

class _SubUnitFlash extends StatefulWidget {
  final double x, y; final String text; final VoidCallback onComplete;
  const _SubUnitFlash({Key? key, required this.x, required this.y, required this.text, required this.onComplete}) : super(key: key);
  @override __SubUnitFlashState createState() => __SubUnitFlashState();
}
class __SubUnitFlashState extends State<_SubUnitFlash> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: Duration(milliseconds: 800)); _ctrl.forward().then((_) => widget.onComplete()); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { return AnimatedBuilder(animation: _ctrl, builder: (ctx, child) { return Positioned(left: widget.x, top: widget.y, child: Opacity(opacity: 1 - _ctrl.value, child: Container(padding: EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.yellow.withOpacity(0.7), borderRadius: BorderRadius.circular(4)), child: Text(widget.text, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10))))); }); }
}

class _MoleculeTransformer extends StatefulWidget {
  final double startX, startY, targetX, targetY; final String startText, endText; final Color startColor, endColor; final bool returnToKrebs; final VoidCallback onComplete;
  const _MoleculeTransformer({Key? key, required this.startX, required this.startY, required this.targetX, required this.targetY, required this.startText, required this.endText, required this.startColor, required this.endColor, required this.returnToKrebs, required this.onComplete}) : super(key: key);
  @override __MoleculeTransformerState createState() => __MoleculeTransformerState();
}
class __MoleculeTransformerState extends State<_MoleculeTransformer> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl; late Animation<double> _moveX, _moveY, _rotate, _scale; late Animation<Color?> _color;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: Duration(seconds: 2));
    _rotate = Tween<double>(begin: 0, end: 2 * math.pi).animate(CurvedAnimation(parent: _ctrl, curve: Interval(0.0, 0.3)));
    _color = ColorTween(begin: widget.startColor, end: widget.endColor).animate(CurvedAnimation(parent: _ctrl, curve: Interval(0.0, 0.3)));
    double endY = widget.returnToKrebs ? widget.targetY : widget.startY - 50;
    _moveX = Tween<double>(begin: widget.startX, end: widget.returnToKrebs ? widget.targetX : widget.startX).animate(CurvedAnimation(parent: _ctrl, curve: Interval(0.3, 1.0, curve: Curves.easeInOut)));
    _moveY = Tween<double>(begin: widget.startY, end: endY).animate(CurvedAnimation(parent: _ctrl, curve: Interval(0.3, 1.0, curve: Curves.easeInOut)));
    _scale = Tween<double>(begin: 1.0, end: widget.returnToKrebs ? 0.5 : 1.2).animate(CurvedAnimation(parent: _ctrl, curve: Interval(0.3, 1.0)));
    _ctrl.forward().then((_) => widget.onComplete()); 
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { return AnimatedBuilder(animation: _ctrl, builder: (context, child) { String text = _ctrl.value < 0.3 ? widget.startText : widget.endText; return Positioned(left: _moveX.value, top: _moveY.value, child: Transform.rotate(angle: _rotate.value, child: Transform.scale(scale: _scale.value, child: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: _color.value, shape: BoxShape.circle), child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))))); }); }
}