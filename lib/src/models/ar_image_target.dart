/// Physical size of the image target
class ImageTargetSize {
  final double width;
  final double height;

  const ImageTargetSize(this.width, this.height);

  factory ImageTargetSize.fromMap(Map<dynamic, dynamic> map) {
    return ImageTargetSize(
      (map['width'] as num).toDouble(),
      (map['height'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'width': width, 'height': height};
  }

  @override
  String toString() => 'ImageTargetSize($width x $height)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageTargetSize &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(width, height);
}

/// Represents an image target for AR tracking
class ARImageTarget {
  final String id;
  final String name;
  final String imagePath;
  final ImageTargetSize physicalSize;
  final bool isActive;

  ARImageTarget({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.physicalSize,
    this.isActive = true,
  });

  factory ARImageTarget.fromMap(Map<dynamic, dynamic> map) {
    return ARImageTarget(
      id: map['id'] as String,
      name: map['name'] as String,
      imagePath: map['imagePath'] as String,
      physicalSize: ImageTargetSize.fromMap(map['physicalSize'] as Map),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'physicalSize': physicalSize.toMap(),
      'isActive': isActive,
    };
  }

  @override
  String toString() =>
      'ARImageTarget(id: $id, name: $name, size: $physicalSize)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ARImageTarget &&
          id == other.id &&
          name == other.name &&
          imagePath == other.imagePath &&
          physicalSize == other.physicalSize &&
          isActive == other.isActive;

  @override
  int get hashCode => Object.hash(id, name, imagePath, physicalSize, isActive);
}
