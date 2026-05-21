/// Type of AR marker
enum ARMarkerType { pattern, barcode, aruco }

/// ArUco dictionary type
enum ARArucoDictionary {
  dict4x4_50,
  dict4x4_100,
  dict5x5_100,
  dict6x6_250,
  dict7x7_1000,
}

/// Represents a marker target for AR tracking
class ARMarkerTarget {
  final String id;
  final String name;
  final ARMarkerType type;
  final double physicalWidth;
  final double? physicalHeight;

  /// Path to a `.patt` ARToolKit pattern file (classic pattern markers).
  final String? patternPath;

  /// Path to an image file (PNG/JPG) used as a visual template for marker
  /// detection. Suitable for the JS bridge's image-template detector.
  final String? imagePath;

  final int? barcodeId;
  final int? arucoId;
  final ARArucoDictionary? arucoDictionary;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  const ARMarkerTarget({
    required this.id,
    required this.name,
    required this.type,
    required this.physicalWidth,
    this.physicalHeight,
    this.patternPath,
    this.imagePath,
    this.barcodeId,
    this.arucoId,
    this.arucoDictionary,
    this.isActive = true,
    this.metadata,
  });

  factory ARMarkerTarget.fromMap(Map<dynamic, dynamic> map) {
    return ARMarkerTarget(
      id: map['id'] as String,
      name: map['name'] as String,
      type: _parseMarkerType(map['type'] as String),
      physicalWidth: (map['physicalWidth'] as num).toDouble(),
      physicalHeight: map['physicalHeight'] != null
          ? (map['physicalHeight'] as num).toDouble()
          : null,
      patternPath: map['patternPath'] as String?,
      imagePath: map['imagePath'] as String?,
      barcodeId: map['barcodeId'] as int?,
      arucoId: map['arucoId'] as int?,
      arucoDictionary: map['arucoDictionary'] != null
          ? _parseArucoDictionary(map['arucoDictionary'] as String)
          : null,
      isActive: map['isActive'] as bool? ?? true,
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : null,
    );
  }

  static ARMarkerType _parseMarkerType(String type) {
    switch (type.toLowerCase()) {
      case 'pattern':
        return ARMarkerType.pattern;
      case 'barcode':
        return ARMarkerType.barcode;
      case 'aruco':
        return ARMarkerType.aruco;
      default:
        return ARMarkerType.pattern;
    }
  }

  static ARArucoDictionary _parseArucoDictionary(String dict) {
    switch (dict) {
      case 'dict4x4_50':
        return ARArucoDictionary.dict4x4_50;
      case 'dict4x4_100':
        return ARArucoDictionary.dict4x4_100;
      case 'dict5x5_100':
        return ARArucoDictionary.dict5x5_100;
      case 'dict6x6_250':
        return ARArucoDictionary.dict6x6_250;
      case 'dict7x7_1000':
        return ARArucoDictionary.dict7x7_1000;
      default:
        return ARArucoDictionary.dict4x4_50;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'physicalWidth': physicalWidth,
      if (physicalHeight != null) 'physicalHeight': physicalHeight,
      if (patternPath != null) 'patternPath': patternPath,
      if (imagePath != null) 'imagePath': imagePath,
      if (barcodeId != null) 'barcodeId': barcodeId,
      if (arucoId != null) 'arucoId': arucoId,
      if (arucoDictionary != null) 'arucoDictionary': arucoDictionary!.name,
      'isActive': isActive,
      if (metadata != null) 'metadata': metadata,
    };
  }

  ARMarkerTarget copyWith({
    String? id,
    String? name,
    ARMarkerType? type,
    double? physicalWidth,
    double? physicalHeight,
    String? patternPath,
    String? imagePath,
    int? barcodeId,
    int? arucoId,
    ARArucoDictionary? arucoDictionary,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return ARMarkerTarget(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      physicalWidth: physicalWidth ?? this.physicalWidth,
      physicalHeight: physicalHeight ?? this.physicalHeight,
      patternPath: patternPath ?? this.patternPath,
      imagePath: imagePath ?? this.imagePath,
      barcodeId: barcodeId ?? this.barcodeId,
      arucoId: arucoId ?? this.arucoId,
      arucoDictionary: arucoDictionary ?? this.arucoDictionary,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() =>
      'ARMarkerTarget(id: $id, name: $name, type: $type)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ARMarkerTarget &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          physicalWidth == other.physicalWidth &&
          physicalHeight == other.physicalHeight &&
          patternPath == other.patternPath &&
          imagePath == other.imagePath &&
          barcodeId == other.barcodeId &&
          arucoId == other.arucoId &&
          arucoDictionary == other.arucoDictionary &&
          isActive == other.isActive;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    physicalWidth,
    physicalHeight,
    patternPath,
    imagePath,
    barcodeId,
    arucoId,
    arucoDictionary,
    isActive,
  );
}
