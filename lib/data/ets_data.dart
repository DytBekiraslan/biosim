import '../models/complex_model.dart';

// OYUNDAKİ KOMPLEKSLER
final List<MitoComplex> etsComplexes = [
  MitoComplex(
    id: 1,
    name: "Kompleks I",
    protonPumpOutput: 4,
    compatibleInputs: ["NADH"],
    inhibitor: "Rotenon",
    // PDF Sayfa 43: "NADH dehidrogenaz, FMN, Fe-S içerir"
    requiredComponents: ["FMN", "Fe-S"],
  ),
  MitoComplex(
    id: 2,
    name: "Kompleks II",
    protonPumpOutput: 0,
    compatibleInputs: ["FADH2"],
    inhibitor: "Malonat",
    // PDF Sayfa 43: "Süksinat DH, FAD, Fe-S, Hem"
    requiredComponents: ["FAD", "Fe-S"],
  ),
  MitoComplex(
    id: 3,
    name: "Kompleks III",
    protonPumpOutput: 4,
    compatibleInputs: ["Ubikinon"],
    inhibitor: "Antimisin A",
    // PDF Sayfa 43: "Sitokrom bc1, hem, Fe-S"
    requiredComponents: ["Cyt b", "Cyt c1", "Fe-S"], 
  ),
  MitoComplex(
    id: 4,
    name: "Kompleks IV",
    protonPumpOutput: 2,
    compatibleInputs: ["Sitokrom C"],
    inhibitor: "Siyanür",
    // PDF Sayfa 43: "Sitokrom aa3, hem, Cu iyonu"
    requiredComponents: ["Cyt a", "Cyt a3", "Cu (Bakır)"],
  ),
  MitoComplex(
    id: 5,
    name: "ATP Sentaz",
    protonPumpOutput: 0,
    compatibleInputs: ["H_Gradient"],
    inhibitor: "Oligomisin",
    // PDF Sayfa 52: "F0 (Kanal) ve F1 (Baş)"
    requiredComponents: ["F0 (Kanal)", "F1 (Baş)"],
  ),
];

// LEVEL 2 İÇİN SÜRÜKLENECEK PARÇALAR LİSTESİ (KARIŞIK)
final List<CellComponent> buildingBlocks = [
  CellComponent("FMN", 1),
  CellComponent("Fe-S", 1), // Genel Fe-S (I için kabul edelim)
  CellComponent("FAD", 2),
  CellComponent("Cyt b", 3),
  CellComponent("Cyt c1", 3),
  CellComponent("Cyt a", 4),
  CellComponent("Cyt a3", 4),
  CellComponent("Cu (Bakır)", 4),
  CellComponent("F0 (Kanal)", 5),
  CellComponent("F1 (Baş)", 5),
  // Şaşırtmaca parçalar (İsteğe bağlı eklenebilir)
];