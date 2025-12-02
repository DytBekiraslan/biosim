class MitoComplex {
  final int id;
  final String name;
  final int protonPumpOutput;
  final List<String> compatibleInputs;
  final String? inhibitor;
  // Yeni Eklenen: Kompleksin içindeki yapılar (PDF Verisi)
  final List<String> requiredComponents; 
  // Level 2'de bu parçalar yerleştirildi mi kontrolü
  bool isBuilt; 

  MitoComplex({
    required this.id,
    required this.name,
    required this.protonPumpOutput,
    required this.compatibleInputs,
    this.inhibitor,
    this.requiredComponents = const [],
    this.isBuilt = false, // Başlangıçta inşa edilmemiş (Level 2 için)
  });
}

// Level 2 için Parça Modeli
class CellComponent {
  final String name;
  final int targetComplexId; // Hangi komplekse ait?
  
  CellComponent(this.name, this.targetComplexId);
}