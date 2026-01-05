class CompostMaterial {
  final int id;
  final String name;
  final String materialType; // 'green' or 'brown'
  final double carbonNitrogenRatio;
  final double? densityKgPerLiter;
  final String? description;

  CompostMaterial({
    required this.id,
    required this.name,
    required this.materialType,
    required this.carbonNitrogenRatio,
    this.densityKgPerLiter,
    this.description,
  });

  factory CompostMaterial.fromJson(Map<String, dynamic> json) {
    return CompostMaterial(
      id: json['id'] as int,
      name: json['name'] as String,
      materialType: json['material_type'] as String,
      carbonNitrogenRatio: (json['carbon_nitrogen_ratio'] as num).toDouble(),
      densityKgPerLiter: json['density_kg_per_liter'] != null
          ? (json['density_kg_per_liter'] as num).toDouble()
          : null,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'material_type': materialType,
      'carbon_nitrogen_ratio': carbonNitrogenRatio,
      'density_kg_per_liter': densityKgPerLiter,
      'description': description,
    };
  }
}

