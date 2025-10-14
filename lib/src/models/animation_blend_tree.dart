import 'dart:math' as math;
import 'animation_blend.dart';

/// Represents a node in a blend tree
abstract class BlendTreeNode {
  /// Unique identifier for this node
  final String id;

  /// Display name for this node
  final String name;

  /// Position in the blend tree (for editor visualization)
  final Map<String, double> position;

  const BlendTreeNode({
    required this.id,
    required this.name,
    this.position = const {},
  });

  /// Calculate the output of this blend tree node
  AnimationBlendSet evaluate(Map<String, dynamic> parameters);

  /// Get all animation IDs used by this node and its children
  List<String> getUsedAnimations();

  /// Convert to map representation
  Map<String, dynamic> toMap();

  /// Create from map representation
  factory BlendTreeNode.fromMap(Map<dynamic, dynamic> map) {
    final type = map['type'] as String;
    switch (type) {
      case 'animation':
        return AnimationNode.fromMap(map);
      case 'blend1D':
        return Blend1DNode.fromMap(map);
      case 'blend2D':
        return Blend2DNode.fromMap(map);
      case 'additive':
        return AdditiveNode.fromMap(map);
      case 'override':
        return OverrideNode.fromMap(map);
      case 'selector':
        return SelectorNode.fromMap(map);
      case 'conditional':
        return ConditionalNode.fromMap(map);
      default:
        throw ArgumentError('Unknown blend tree node type: $type');
    }
  }
}

/// A leaf node that represents a single animation
class AnimationNode extends BlendTreeNode {
  /// Animation ID to play
  final String animationId;

  /// Speed multiplier for this animation
  final double speed;

  /// Whether this animation should loop
  final bool loop;

  /// Time offset in seconds
  final double timeOffset;

  /// Bone mask for selective animation
  final List<String>? boneMask;

  const AnimationNode({
    required super.id,
    required super.name,
    required this.animationId,
    this.speed = 1.0,
    this.loop = true,
    this.timeOffset = 0.0,
    this.boneMask,
    super.position = const {},
  });

  factory AnimationNode.fromMap(Map<dynamic, dynamic> map) {
    return AnimationNode(
      id: map['id'] as String,
      name: map['name'] as String,
      animationId: map['animationId'] as String,
      speed: (map['speed'] as num?)?.toDouble() ?? 1.0,
      loop: map['loop'] as bool? ?? true,
      timeOffset: (map['timeOffset'] as num?)?.toDouble() ?? 0.0,
      boneMask: (map['boneMask'] as List?)?.cast<String>(),
      position: (map['position'] as Map?)?.cast<String, double>() ?? {},
    );
  }

  @override
  AnimationBlendSet evaluate(Map<String, dynamic> parameters) {
    return AnimationBlendSet(
      id: '${id}_output',
      animations: [
        AnimationBlend(
          animationId: animationId,
          weight: 1.0,
          speed: speed,
          timeOffset: timeOffset,
          loop: loop,
          boneMask: boneMask,
        ),
      ],
    );
  }

  @override
  List<String> getUsedAnimations() => [animationId];

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'animation',
      'id': id,
      'name': name,
      'animationId': animationId,
      'speed': speed,
      'loop': loop,
      'timeOffset': timeOffset,
      if (boneMask != null) 'boneMask': boneMask,
      'position': position,
    };
  }
}

/// A node that blends between animations based on a single parameter
class Blend1DNode extends BlendTreeNode {
  /// Parameter name to use for blending
  final String parameterName;

  /// List of blend points with their parameter values and child nodes
  final List<BlendPoint1D> blendPoints;

  /// How to handle values outside the blend point range
  final BlendWrapMode wrapMode;

  const Blend1DNode({
    required super.id,
    required super.name,
    required this.parameterName,
    required this.blendPoints,
    this.wrapMode = BlendWrapMode.clamp,
    super.position = const {},
  });

  factory Blend1DNode.fromMap(Map<dynamic, dynamic> map) {
    return Blend1DNode(
      id: map['id'] as String,
      name: map['name'] as String,
      parameterName: map['parameterName'] as String,
      blendPoints: (map['blendPoints'] as List)
          .map((e) => BlendPoint1D.fromMap(e as Map))
          .toList(),
      wrapMode: BlendWrapMode.values.firstWhere(
        (e) => e.name == map['wrapMode'],
        orElse: () => BlendWrapMode.clamp,
      ),
      position: (map['position'] as Map?)?.cast<String, double>() ?? {},
    );
  }

  @override
  AnimationBlendSet evaluate(Map<String, dynamic> parameters) {
    final parameterValue =
        (parameters[parameterName] as num?)?.toDouble() ?? 0.0;

    // Sort blend points by their values
    final sortedPoints = List<BlendPoint1D>.from(blendPoints)
      ..sort((a, b) => a.value.compareTo(b.value));

    if (sortedPoints.isEmpty) {
      return AnimationBlendSet(id: '${id}_output', animations: []);
    }

    if (sortedPoints.length == 1) {
      final childOutput = sortedPoints.first.child.evaluate(parameters);
      return childOutput.copyWith(id: '${id}_output');
    }

    // Handle wrapping/clamping
    double clampedValue = parameterValue;
    switch (wrapMode) {
      case BlendWrapMode.clamp:
        clampedValue = parameterValue.clamp(
          sortedPoints.first.value,
          sortedPoints.last.value,
        );
        break;
      case BlendWrapMode.repeat:
        final range = sortedPoints.last.value - sortedPoints.first.value;
        if (range > 0) {
          clampedValue = sortedPoints.first.value + (parameterValue % range);
        }
        break;
    }

    // Find the two closest blend points
    BlendPoint1D? lowerPoint;
    BlendPoint1D? upperPoint;

    for (int i = 0; i < sortedPoints.length - 1; i++) {
      if (clampedValue >= sortedPoints[i].value &&
          clampedValue <= sortedPoints[i + 1].value) {
        lowerPoint = sortedPoints[i];
        upperPoint = sortedPoints[i + 1];
        break;
      }
    }

    // Handle edge cases
    if (lowerPoint == null || upperPoint == null) {
      if (clampedValue <= sortedPoints.first.value) {
        final childOutput = sortedPoints.first.child.evaluate(parameters);
        return childOutput.copyWith(id: '${id}_output');
      } else {
        final childOutput = sortedPoints.last.child.evaluate(parameters);
        return childOutput.copyWith(id: '${id}_output');
      }
    }

    // Calculate blend weights
    final range = upperPoint.value - lowerPoint.value;
    final blend = range == 0 ? 0.0 : (clampedValue - lowerPoint.value) / range;

    final lowerWeight = 1.0 - blend;
    final upperWeight = blend;

    // Evaluate child nodes and blend their outputs
    final lowerOutput = lowerPoint.child.evaluate(parameters);
    final upperOutput = upperPoint.child.evaluate(parameters);

    final blendedAnimations = <AnimationBlend>[];

    // Add weighted animations from lower child
    for (final anim in lowerOutput.animations) {
      blendedAnimations.add(anim.copyWith(weight: anim.weight * lowerWeight));
    }

    // Add weighted animations from upper child
    for (final anim in upperOutput.animations) {
      blendedAnimations.add(anim.copyWith(weight: anim.weight * upperWeight));
    }

    return AnimationBlendSet(id: '${id}_output', animations: blendedAnimations);
  }

  @override
  List<String> getUsedAnimations() {
    return blendPoints
        .expand((point) => point.child.getUsedAnimations())
        .toSet()
        .toList();
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'blend1D',
      'id': id,
      'name': name,
      'parameterName': parameterName,
      'blendPoints': blendPoints.map((p) => p.toMap()).toList(),
      'wrapMode': wrapMode.name,
      'position': position,
    };
  }
}

/// A node that blends between animations based on two parameters (2D blending)
class Blend2DNode extends BlendTreeNode {
  /// X-axis parameter name
  final String parameterX;

  /// Y-axis parameter name
  final String parameterY;

  /// List of blend points with their 2D positions and child nodes
  final List<BlendPoint2D> blendPoints;

  /// Blending algorithm to use
  final Blend2DType blendType;

  const Blend2DNode({
    required super.id,
    required super.name,
    required this.parameterX,
    required this.parameterY,
    required this.blendPoints,
    this.blendType = Blend2DType.freeform,
    super.position = const {},
  });

  factory Blend2DNode.fromMap(Map<dynamic, dynamic> map) {
    return Blend2DNode(
      id: map['id'] as String,
      name: map['name'] as String,
      parameterX: map['parameterX'] as String,
      parameterY: map['parameterY'] as String,
      blendPoints: (map['blendPoints'] as List)
          .map((e) => BlendPoint2D.fromMap(e as Map))
          .toList(),
      blendType: Blend2DType.values.firstWhere(
        (e) => e.name == map['blendType'],
        orElse: () => Blend2DType.freeform,
      ),
      position: (map['position'] as Map?)?.cast<String, double>() ?? {},
    );
  }

  @override
  AnimationBlendSet evaluate(Map<String, dynamic> parameters) {
    final x = (parameters[parameterX] as num?)?.toDouble() ?? 0.0;
    final y = (parameters[parameterY] as num?)?.toDouble() ?? 0.0;

    if (blendPoints.isEmpty) {
      return AnimationBlendSet(id: '${id}_output', animations: []);
    }

    // Calculate weights for each blend point based on distance
    final weights = <double>[];
    double totalWeight = 0.0;

    for (final point in blendPoints) {
      final distance = _calculateDistance(x, y, point.x, point.y);
      final weight = distance == 0.0
          ? 1000000.0
          : 1.0 / (distance * distance); // Inverse square falloff
      weights.add(weight);
      totalWeight += weight;
    }

    // Normalize weights
    if (totalWeight > 0.0) {
      for (int i = 0; i < weights.length; i++) {
        weights[i] /= totalWeight;
      }
    }

    // Evaluate child nodes and blend their outputs
    final blendedAnimations = <AnimationBlend>[];

    for (int i = 0; i < blendPoints.length; i++) {
      final point = blendPoints[i];
      final weight = weights[i];

      if (weight > 0.001) {
        // Skip very small weights for performance
        final childOutput = point.child.evaluate(parameters);

        for (final anim in childOutput.animations) {
          blendedAnimations.add(anim.copyWith(weight: anim.weight * weight));
        }
      }
    }

    return AnimationBlendSet(id: '${id}_output', animations: blendedAnimations);
  }

  double _calculateDistance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  List<String> getUsedAnimations() {
    return blendPoints
        .expand((point) => point.child.getUsedAnimations())
        .toSet()
        .toList();
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'blend2D',
      'id': id,
      'name': name,
      'parameterX': parameterX,
      'parameterY': parameterY,
      'blendPoints': blendPoints.map((p) => p.toMap()).toList(),
      'blendType': blendType.name,
      'position': position,
    };
  }
}

/// A node that adds animations on top of a base layer (additive blending)
class AdditiveNode extends BlendTreeNode {
  /// Base animation layer
  final BlendTreeNode baseLayer;

  /// Additive animation layer
  final BlendTreeNode additiveLayer;

  /// Weight of the additive layer
  final double additiveWeight;

  /// Parameter name to control additive weight (optional)
  final String? weightParameterName;

  const AdditiveNode({
    required super.id,
    required super.name,
    required this.baseLayer,
    required this.additiveLayer,
    this.additiveWeight = 1.0,
    this.weightParameterName,
    super.position = const {},
  });

  factory AdditiveNode.fromMap(Map<dynamic, dynamic> map) {
    return AdditiveNode(
      id: map['id'] as String,
      name: map['name'] as String,
      baseLayer: BlendTreeNode.fromMap(map['baseLayer'] as Map),
      additiveLayer: BlendTreeNode.fromMap(map['additiveLayer'] as Map),
      additiveWeight: (map['additiveWeight'] as num?)?.toDouble() ?? 1.0,
      weightParameterName: map['weightParameterName'] as String?,
      position: (map['position'] as Map?)?.cast<String, double>() ?? {},
    );
  }

  @override
  AnimationBlendSet evaluate(Map<String, dynamic> parameters) {
    final baseOutput = baseLayer.evaluate(parameters);
    final additiveOutput = additiveLayer.evaluate(parameters);

    // Get the actual additive weight from parameters if specified
    final actualWeight = weightParameterName != null
        ? (parameters[weightParameterName!] as num?)?.toDouble() ??
              additiveWeight
        : additiveWeight;

    final blendedAnimations = <AnimationBlend>[];

    // Add base layer animations
    blendedAnimations.addAll(baseOutput.animations);

    // Add additive layer animations
    for (final anim in additiveOutput.animations) {
      blendedAnimations.add(
        anim.copyWith(
          weight: anim.weight * actualWeight,
          blendMode: AnimationBlendMode.additive,
          layer: anim.layer + 1,
        ),
      );
    }

    return AnimationBlendSet(id: '${id}_output', animations: blendedAnimations);
  }

  @override
  List<String> getUsedAnimations() {
    return [
      ...baseLayer.getUsedAnimations(),
      ...additiveLayer.getUsedAnimations(),
    ];
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'additive',
      'id': id,
      'name': name,
      'baseLayer': baseLayer.toMap(),
      'additiveLayer': additiveLayer.toMap(),
      'additiveWeight': additiveWeight,
      if (weightParameterName != null)
        'weightParameterName': weightParameterName,
      'position': position,
    };
  }
}

/// A node that overrides specific body parts with a different animation
class OverrideNode extends BlendTreeNode {
  /// Base animation layer
  final BlendTreeNode baseLayer;

  /// Override animation layer
  final BlendTreeNode overrideLayer;

  /// Bone mask defining which bones to override
  final List<String> boneMask;

  /// Weight of the override
  final double overrideWeight;

  const OverrideNode({
    required super.id,
    required super.name,
    required this.baseLayer,
    required this.overrideLayer,
    required this.boneMask,
    this.overrideWeight = 1.0,
    super.position = const {},
  });

  factory OverrideNode.fromMap(Map<dynamic, dynamic> map) {
    return OverrideNode(
      id: map['id'] as String,
      name: map['name'] as String,
      baseLayer: BlendTreeNode.fromMap(map['baseLayer'] as Map),
      overrideLayer: BlendTreeNode.fromMap(map['overrideLayer'] as Map),
      boneMask: (map['boneMask'] as List).cast<String>(),
      overrideWeight: (map['overrideWeight'] as num?)?.toDouble() ?? 1.0,
      position: (map['position'] as Map?)?.cast<String, double>() ?? {},
    );
  }

  @override
  AnimationBlendSet evaluate(Map<String, dynamic> parameters) {
    final baseOutput = baseLayer.evaluate(parameters);
    final overrideOutput = overrideLayer.evaluate(parameters);

    final blendedAnimations = <AnimationBlend>[];

    // Add base layer animations with inverse bone mask
    for (final anim in baseOutput.animations) {
      blendedAnimations.add(
        anim.copyWith(boneMask: _getInverseBoneMask(anim.boneMask)),
      );
    }

    // Add override layer animations with the specified bone mask
    for (final anim in overrideOutput.animations) {
      blendedAnimations.add(
        anim.copyWith(
          weight: anim.weight * overrideWeight,
          boneMask: boneMask,
          blendMode: AnimationBlendMode.override,
          layer: anim.layer + 1,
        ),
      );
    }

    return AnimationBlendSet(id: '${id}_output', animations: blendedAnimations);
  }

  List<String>? _getInverseBoneMask(List<String>? originalMask) {
    // This would need to be implemented based on the full skeleton
    // For now, return null to indicate "all bones except the override mask"
    return null;
  }

  @override
  List<String> getUsedAnimations() {
    return [
      ...baseLayer.getUsedAnimations(),
      ...overrideLayer.getUsedAnimations(),
    ];
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'override',
      'id': id,
      'name': name,
      'baseLayer': baseLayer.toMap(),
      'overrideLayer': overrideLayer.toMap(),
      'boneMask': boneMask,
      'overrideWeight': overrideWeight,
      'position': position,
    };
  }
}

/// A node that selects one child based on an integer parameter
class SelectorNode extends BlendTreeNode {
  /// Parameter name to use for selection
  final String parameterName;

  /// List of child nodes to select from
  final List<BlendTreeNode> children;

  /// Default index to use if parameter is out of range
  final int defaultIndex;

  const SelectorNode({
    required super.id,
    required super.name,
    required this.parameterName,
    required this.children,
    this.defaultIndex = 0,
    super.position = const {},
  });

  factory SelectorNode.fromMap(Map<dynamic, dynamic> map) {
    return SelectorNode(
      id: map['id'] as String,
      name: map['name'] as String,
      parameterName: map['parameterName'] as String,
      children: (map['children'] as List)
          .map((e) => BlendTreeNode.fromMap(e as Map))
          .toList(),
      defaultIndex: map['defaultIndex'] as int? ?? 0,
      position: (map['position'] as Map?)?.cast<String, double>() ?? {},
    );
  }

  @override
  AnimationBlendSet evaluate(Map<String, dynamic> parameters) {
    final index = (parameters[parameterName] as int?) ?? defaultIndex;
    final clampedIndex = index.clamp(0, children.length - 1);

    if (children.isEmpty) {
      return AnimationBlendSet(id: '${id}_output', animations: []);
    }

    final selectedChild = children[clampedIndex];
    final childOutput = selectedChild.evaluate(parameters);

    return childOutput.copyWith(id: '${id}_output');
  }

  @override
  List<String> getUsedAnimations() {
    return children
        .expand((child) => child.getUsedAnimations())
        .toSet()
        .toList();
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'selector',
      'id': id,
      'name': name,
      'parameterName': parameterName,
      'children': children.map((c) => c.toMap()).toList(),
      'defaultIndex': defaultIndex,
      'position': position,
    };
  }
}

/// A node that conditionally plays one of two children based on a boolean parameter
class ConditionalNode extends BlendTreeNode {
  /// Parameter name to use for the condition
  final String conditionParameter;

  /// Child to play when condition is true
  final BlendTreeNode trueChild;

  /// Child to play when condition is false
  final BlendTreeNode falseChild;

  /// Transition duration when switching between children
  final double transitionDuration;

  const ConditionalNode({
    required super.id,
    required super.name,
    required this.conditionParameter,
    required this.trueChild,
    required this.falseChild,
    this.transitionDuration = 0.3,
    super.position = const {},
  });

  factory ConditionalNode.fromMap(Map<dynamic, dynamic> map) {
    return ConditionalNode(
      id: map['id'] as String,
      name: map['name'] as String,
      conditionParameter: map['conditionParameter'] as String,
      trueChild: BlendTreeNode.fromMap(map['trueChild'] as Map),
      falseChild: BlendTreeNode.fromMap(map['falseChild'] as Map),
      transitionDuration:
          (map['transitionDuration'] as num?)?.toDouble() ?? 0.3,
      position: (map['position'] as Map?)?.cast<String, double>() ?? {},
    );
  }

  @override
  AnimationBlendSet evaluate(Map<String, dynamic> parameters) {
    final condition = parameters[conditionParameter] as bool? ?? false;
    final selectedChild = condition ? trueChild : falseChild;
    final childOutput = selectedChild.evaluate(parameters);

    return childOutput.copyWith(id: '${id}_output');
  }

  @override
  List<String> getUsedAnimations() {
    return [
      ...trueChild.getUsedAnimations(),
      ...falseChild.getUsedAnimations(),
    ];
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'conditional',
      'id': id,
      'name': name,
      'conditionParameter': conditionParameter,
      'trueChild': trueChild.toMap(),
      'falseChild': falseChild.toMap(),
      'transitionDuration': transitionDuration,
      'position': position,
    };
  }
}

/// Represents a blend point in 1D space
class BlendPoint1D {
  /// Parameter value for this blend point
  final double value;

  /// Child node to blend at this point
  final BlendTreeNode child;

  const BlendPoint1D({required this.value, required this.child});

  factory BlendPoint1D.fromMap(Map<dynamic, dynamic> map) {
    return BlendPoint1D(
      value: (map['value'] as num).toDouble(),
      child: BlendTreeNode.fromMap(map['child'] as Map),
    );
  }

  Map<String, dynamic> toMap() {
    return {'value': value, 'child': child.toMap()};
  }
}

/// Represents a blend point in 2D space
class BlendPoint2D {
  /// X coordinate for this blend point
  final double x;

  /// Y coordinate for this blend point
  final double y;

  /// Child node to blend at this point
  final BlendTreeNode child;

  const BlendPoint2D({required this.x, required this.y, required this.child});

  factory BlendPoint2D.fromMap(Map<dynamic, dynamic> map) {
    return BlendPoint2D(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      child: BlendTreeNode.fromMap(map['child'] as Map),
    );
  }

  Map<String, dynamic> toMap() {
    return {'x': x, 'y': y, 'child': child.toMap()};
  }
}

/// Wrap modes for 1D blending
enum BlendWrapMode {
  /// Clamp values to the range
  clamp,

  /// Repeat values within the range
  repeat,
}

/// Blending algorithms for 2D blending
enum Blend2DType {
  /// Freeform blending based on distance
  freeform,

  /// Directional blending (good for movement)
  directional,

  /// Cartesian blending (grid-based)
  cartesian,
}

/// Complete blend tree with parameters and root node
class AnimationBlendTree {
  /// Unique identifier for this blend tree
  final String id;

  /// Display name for this blend tree
  final String name;

  /// Root node of the blend tree
  final BlendTreeNode rootNode;

  /// Parameter definitions for this blend tree
  final Map<String, BlendTreeParameter> parameters;

  /// Default parameter values
  final Map<String, dynamic> defaultValues;

  const AnimationBlendTree({
    required this.id,
    required this.name,
    required this.rootNode,
    this.parameters = const {},
    this.defaultValues = const {},
  });

  factory AnimationBlendTree.fromMap(Map<dynamic, dynamic> map) {
    return AnimationBlendTree(
      id: map['id'] as String,
      name: map['name'] as String,
      rootNode: BlendTreeNode.fromMap(map['rootNode'] as Map),
      parameters:
          (map['parameters'] as Map?)?.map(
            (k, v) =>
                MapEntry(k as String, BlendTreeParameter.fromMap(v as Map)),
          ) ??
          {},
      defaultValues:
          (map['defaultValues'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rootNode': rootNode.toMap(),
      'parameters': parameters.map((k, v) => MapEntry(k, v.toMap())),
      'defaultValues': defaultValues,
    };
  }

  /// Evaluate the blend tree with the given parameters
  AnimationBlendSet evaluate(Map<String, dynamic> parameterValues) {
    // Merge with default values
    final mergedValues = Map<String, dynamic>.from(defaultValues);
    mergedValues.addAll(parameterValues);

    return rootNode.evaluate(mergedValues);
  }

  /// Get all animation IDs used in this blend tree
  List<String> getUsedAnimations() => rootNode.getUsedAnimations();

  /// Validate the blend tree for consistency
  bool validate() {
    // Check if all required parameters are defined
    final usedParameters = _getUsedParameterNames(rootNode);
    for (final paramName in usedParameters) {
      if (!parameters.containsKey(paramName) &&
          !defaultValues.containsKey(paramName)) {
        return false;
      }
    }

    return true;
  }

  Set<String> _getUsedParameterNames(BlendTreeNode node) {
    final usedParams = <String>{};

    if (node is Blend1DNode) {
      usedParams.add(node.parameterName);
    } else if (node is Blend2DNode) {
      usedParams.add(node.parameterX);
      usedParams.add(node.parameterY);
    } else if (node is AdditiveNode) {
      if (node.weightParameterName != null) {
        usedParams.add(node.weightParameterName!);
      }
    } else if (node is SelectorNode) {
      usedParams.add(node.parameterName);
    } else if (node is ConditionalNode) {
      usedParams.add(node.conditionParameter);
    }

    // Recursively check child nodes
    if (node is Blend1DNode) {
      for (final point in node.blendPoints) {
        usedParams.addAll(_getUsedParameterNames(point.child));
      }
    } else if (node is Blend2DNode) {
      for (final point in node.blendPoints) {
        usedParams.addAll(_getUsedParameterNames(point.child));
      }
    } else if (node is AdditiveNode) {
      usedParams.addAll(_getUsedParameterNames(node.baseLayer));
      usedParams.addAll(_getUsedParameterNames(node.additiveLayer));
    } else if (node is OverrideNode) {
      usedParams.addAll(_getUsedParameterNames(node.baseLayer));
      usedParams.addAll(_getUsedParameterNames(node.overrideLayer));
    } else if (node is SelectorNode) {
      for (final child in node.children) {
        usedParams.addAll(_getUsedParameterNames(child));
      }
    } else if (node is ConditionalNode) {
      usedParams.addAll(_getUsedParameterNames(node.trueChild));
      usedParams.addAll(_getUsedParameterNames(node.falseChild));
    }

    return usedParams;
  }
}

/// Parameter definition for blend trees
class BlendTreeParameter {
  /// Parameter name
  final String name;

  /// Parameter type
  final BlendTreeParameterType type;

  /// Default value
  final dynamic defaultValue;

  /// Minimum value (for numeric types)
  final double? minValue;

  /// Maximum value (for numeric types)
  final double? maxValue;

  /// Description of this parameter
  final String? description;

  const BlendTreeParameter({
    required this.name,
    required this.type,
    required this.defaultValue,
    this.minValue,
    this.maxValue,
    this.description,
  });

  factory BlendTreeParameter.fromMap(Map<dynamic, dynamic> map) {
    return BlendTreeParameter(
      name: map['name'] as String,
      type: BlendTreeParameterType.values.firstWhere(
        (e) => e.name == map['type'],
      ),
      defaultValue: map['defaultValue'],
      minValue: (map['minValue'] as num?)?.toDouble(),
      maxValue: (map['maxValue'] as num?)?.toDouble(),
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.name,
      'defaultValue': defaultValue,
      if (minValue != null) 'minValue': minValue,
      if (maxValue != null) 'maxValue': maxValue,
      if (description != null) 'description': description,
    };
  }
}

/// Types of parameters in blend trees
enum BlendTreeParameterType {
  /// Floating point number
  float,

  /// Integer number
  int,

  /// Boolean value
  bool,

  /// String value
  string,
}
