import 'package:flutter_test/flutter_test.dart';
import 'package:augen/augen.dart';

void main() {
  group('Animation Blend Tree Tests', () {
    group('AnimationNode', () {
      test('creates animation node with default values', () {
        const node = AnimationNode(
          id: 'walk_node',
          name: 'Walk Animation',
          animationId: 'walk',
        );

        expect(node.id, 'walk_node');
        expect(node.name, 'Walk Animation');
        expect(node.animationId, 'walk');
        expect(node.speed, 1.0);
        expect(node.loop, true);
        expect(node.timeOffset, 0.0);
        expect(node.boneMask, isNull);
      });

      test('evaluates to single animation blend set', () {
        const node = AnimationNode(
          id: 'idle_node',
          name: 'Idle',
          animationId: 'idle',
          speed: 0.8,
        );

        final result = node.evaluate({});

        expect(result.id, 'idle_node_output');
        expect(result.animations.length, 1);
        expect(result.animations[0].animationId, 'idle');
        expect(result.animations[0].weight, 1.0);
        expect(result.animations[0].speed, 0.8);
      });

      test('returns used animations', () {
        const node = AnimationNode(
          id: 'run_node',
          name: 'Run',
          animationId: 'run_animation',
        );

        final usedAnimations = node.getUsedAnimations();
        expect(usedAnimations, ['run_animation']);
      });

      test('converts to and from map', () {
        const node = AnimationNode(
          id: 'jump_node',
          name: 'Jump',
          animationId: 'jump',
          speed: 1.2,
          boneMask: ['spine', 'head'],
        );

        final map = node.toMap();
        final fromMap = AnimationNode.fromMap(map);

        expect(fromMap.id, node.id);
        expect(fromMap.name, node.name);
        expect(fromMap.animationId, node.animationId);
        expect(fromMap.speed, node.speed);
        expect(fromMap.boneMask, node.boneMask);
      });
    });

    group('Blend1DNode', () {
      late Blend1DNode blendNode;

      setUp(() {
        blendNode = Blend1DNode(
          id: 'speed_blend',
          name: 'Speed Blend',
          parameterName: 'speed',
          blendPoints: [
            BlendPoint1D(
              value: 0.0,
              child: AnimationNode(
                id: 'idle_node',
                name: 'Idle',
                animationId: 'idle',
              ),
            ),
            BlendPoint1D(
              value: 2.0,
              child: AnimationNode(
                id: 'walk_node',
                name: 'Walk',
                animationId: 'walk',
              ),
            ),
            BlendPoint1D(
              value: 5.0,
              child: AnimationNode(
                id: 'run_node',
                name: 'Run',
                animationId: 'run',
              ),
            ),
          ],
        );
      });

      test('blends between animations based on parameter', () {
        // At speed 0.0 - should be 100% idle
        final result0 = blendNode.evaluate({'speed': 0.0});
        expect(result0.animations.length, greaterThanOrEqualTo(1));
        final idleAnim = result0.animations.firstWhere(
          (a) => a.animationId == 'idle',
        );
        expect(idleAnim.weight, 1.0);

        // At speed 1.0 - should blend idle and walk 50/50
        final result1 = blendNode.evaluate({'speed': 1.0});
        expect(result1.animations.length, 2);
        expect(
          result1.animations.where((a) => a.animationId == 'idle').first.weight,
          0.5,
        );
        expect(
          result1.animations.where((a) => a.animationId == 'walk').first.weight,
          0.5,
        );

        // At speed 5.0 - should be 100% run
        final result5 = blendNode.evaluate({'speed': 5.0});
        expect(result5.animations.length, greaterThanOrEqualTo(1));
        final runAnim = result5.animations.firstWhere(
          (a) => a.animationId == 'run',
        );
        expect(runAnim.weight, 1.0);
      });

      test('clamps values outside range', () {
        // Below minimum
        final resultLow = blendNode.evaluate({'speed': -1.0});
        expect(resultLow.animations.length, greaterThanOrEqualTo(1));
        final idleAnim = resultLow.animations.firstWhere(
          (a) => a.animationId == 'idle',
        );
        expect(idleAnim.weight, 1.0);

        // Above maximum
        final resultHigh = blendNode.evaluate({'speed': 10.0});
        expect(resultHigh.animations.length, greaterThanOrEqualTo(1));
        final runAnim = resultHigh.animations.firstWhere(
          (a) => a.animationId == 'run',
        );
        expect(runAnim.weight, 1.0);
      });

      test('handles missing parameter', () {
        final result = blendNode.evaluate({});
        expect(
          result.animations[0].animationId,
          'idle',
        ); // Should default to first
      });

      test('returns all used animations', () {
        final usedAnimations = blendNode.getUsedAnimations();
        expect(usedAnimations, containsAll(['idle', 'walk', 'run']));
        expect(usedAnimations.length, 3);
      });

      test('converts to and from map', () {
        final map = blendNode.toMap();
        final fromMap = Blend1DNode.fromMap(map);

        expect(fromMap.id, blendNode.id);
        expect(fromMap.parameterName, blendNode.parameterName);
        expect(fromMap.blendPoints.length, blendNode.blendPoints.length);
      });
    });

    group('Blend2DNode', () {
      late Blend2DNode blend2D;

      setUp(() {
        blend2D = Blend2DNode(
          id: 'movement_blend',
          name: 'Movement Blend',
          parameterX: 'speed',
          parameterY: 'direction',
          blendPoints: [
            BlendPoint2D(
              x: 0.0,
              y: 0.0,
              child: AnimationNode(
                id: 'idle_node',
                name: 'Idle',
                animationId: 'idle',
              ),
            ),
            BlendPoint2D(
              x: 1.0,
              y: 0.0,
              child: AnimationNode(
                id: 'walk_forward_node',
                name: 'Walk Forward',
                animationId: 'walk_forward',
              ),
            ),
            BlendPoint2D(
              x: 1.0,
              y: 1.0,
              child: AnimationNode(
                id: 'walk_right_node',
                name: 'Walk Right',
                animationId: 'walk_right',
              ),
            ),
            BlendPoint2D(
              x: 0.0,
              y: 1.0,
              child: AnimationNode(
                id: 'strafe_right_node',
                name: 'Strafe Right',
                animationId: 'strafe_right',
              ),
            ),
          ],
        );
      });

      test('blends based on 2D coordinates', () {
        // At origin - should be mostly idle
        final resultOrigin = blend2D.evaluate({'speed': 0.0, 'direction': 0.0});
        expect(resultOrigin.animations.isNotEmpty, true);

        // Find idle animation in results
        final idleAnim = resultOrigin.animations.firstWhere(
          (anim) => anim.animationId == 'idle',
          orElse: () => throw StateError('Idle animation not found'),
        );
        expect(idleAnim.weight, greaterThan(0.8)); // Should be dominant

        // At center - should blend multiple animations
        final resultCenter = blend2D.evaluate({'speed': 0.5, 'direction': 0.5});
        expect(resultCenter.animations.length, greaterThan(1));
      });

      test('handles missing parameters', () {
        final result = blend2D.evaluate({});
        expect(result.animations.isNotEmpty, true);
      });

      test('returns all used animations', () {
        final usedAnimations = blend2D.getUsedAnimations();
        expect(
          usedAnimations,
          containsAll(['idle', 'walk_forward', 'walk_right', 'strafe_right']),
        );
      });

      test('converts to and from map', () {
        final map = blend2D.toMap();
        final fromMap = Blend2DNode.fromMap(map);

        expect(fromMap.id, blend2D.id);
        expect(fromMap.parameterX, blend2D.parameterX);
        expect(fromMap.parameterY, blend2D.parameterY);
        expect(fromMap.blendPoints.length, blend2D.blendPoints.length);
      });
    });

    group('AdditiveNode', () {
      late AdditiveNode additiveNode;

      setUp(() {
        additiveNode = AdditiveNode(
          id: 'additive_blend',
          name: 'Base with Gesture',
          baseLayer: AnimationNode(
            id: 'base_node',
            name: 'Base',
            animationId: 'walk',
          ),
          additiveLayer: AnimationNode(
            id: 'gesture_node',
            name: 'Gesture',
            animationId: 'wave',
          ),
          additiveWeight: 0.7,
        );
      });

      test('combines base and additive layers', () {
        final result = additiveNode.evaluate({});

        expect(result.animations.length, 2);

        final baseAnim = result.animations.firstWhere(
          (a) => a.animationId == 'walk',
        );
        final additiveAnim = result.animations.firstWhere(
          (a) => a.animationId == 'wave',
        );

        expect(baseAnim.weight, 1.0);
        expect(baseAnim.blendMode, AnimationBlendMode.weighted);
        expect(additiveAnim.weight, 0.7);
        expect(additiveAnim.blendMode, AnimationBlendMode.additive);
        expect(additiveAnim.layer, 1);
      });

      test('uses parameter for additive weight', () {
        const nodeWithParam = AdditiveNode(
          id: 'param_additive',
          name: 'Parameter Additive',
          baseLayer: AnimationNode(
            id: 'base',
            name: 'Base',
            animationId: 'run',
          ),
          additiveLayer: AnimationNode(
            id: 'additive',
            name: 'Additive',
            animationId: 'lean',
          ),
          additiveWeight: 1.0,
          weightParameterName: 'lean_weight',
        );

        final result = nodeWithParam.evaluate({'lean_weight': 0.3});
        final additiveAnim = result.animations.firstWhere(
          (a) => a.animationId == 'lean',
        );
        expect(additiveAnim.weight, 0.3);
      });

      test('returns used animations from both layers', () {
        final usedAnimations = additiveNode.getUsedAnimations();
        expect(usedAnimations, containsAll(['walk', 'wave']));
      });

      test('converts to and from map', () {
        final map = additiveNode.toMap();
        final fromMap = AdditiveNode.fromMap(map);

        expect(fromMap.id, additiveNode.id);
        expect(fromMap.additiveWeight, additiveNode.additiveWeight);
      });
    });

    group('OverrideNode', () {
      late OverrideNode overrideNode;

      setUp(() {
        overrideNode = OverrideNode(
          id: 'override_arms',
          name: 'Override Arms',
          baseLayer: AnimationNode(
            id: 'full_body',
            name: 'Full Body',
            animationId: 'walk_full',
          ),
          overrideLayer: AnimationNode(
            id: 'arm_gesture',
            name: 'Arm Gesture',
            animationId: 'point',
          ),
          boneMask: [
            'arm_left',
            'arm_right',
            'shoulder_left',
            'shoulder_right',
          ],
          overrideWeight: 0.8,
        );
      });

      test('combines base and override layers with bone masks', () {
        final result = overrideNode.evaluate({});

        expect(result.animations.length, 2);

        final overrideAnim = result.animations.firstWhere(
          (a) => a.animationId == 'point',
        );
        expect(overrideAnim.boneMask, [
          'arm_left',
          'arm_right',
          'shoulder_left',
          'shoulder_right',
        ]);
        expect(overrideAnim.blendMode, AnimationBlendMode.override);
        expect(overrideAnim.weight, 0.8);
        expect(overrideAnim.layer, 1);
      });

      test('returns used animations from both layers', () {
        final usedAnimations = overrideNode.getUsedAnimations();
        expect(usedAnimations, containsAll(['walk_full', 'point']));
      });

      test('converts to and from map', () {
        final map = overrideNode.toMap();
        final fromMap = OverrideNode.fromMap(map);

        expect(fromMap.id, overrideNode.id);
        expect(fromMap.boneMask, overrideNode.boneMask);
        expect(fromMap.overrideWeight, overrideNode.overrideWeight);
      });
    });

    group('SelectorNode', () {
      late SelectorNode selectorNode;

      setUp(() {
        selectorNode = SelectorNode(
          id: 'weapon_selector',
          name: 'Weapon Animation Selector',
          parameterName: 'weapon_type',
          children: [
            AnimationNode(
              id: 'unarmed_node',
              name: 'Unarmed',
              animationId: 'unarmed_idle',
            ),
            AnimationNode(
              id: 'sword_node',
              name: 'Sword',
              animationId: 'sword_idle',
            ),
            AnimationNode(id: 'bow_node', name: 'Bow', animationId: 'bow_idle'),
          ],
          defaultIndex: 0,
        );
      });

      test('selects correct child based on parameter', () {
        // Select first child (unarmed)
        final result0 = selectorNode.evaluate({'weapon_type': 0});
        expect(result0.animations[0].animationId, 'unarmed_idle');

        // Select second child (sword)
        final result1 = selectorNode.evaluate({'weapon_type': 1});
        expect(result1.animations[0].animationId, 'sword_idle');

        // Select third child (bow)
        final result2 = selectorNode.evaluate({'weapon_type': 2});
        expect(result2.animations[0].animationId, 'bow_idle');
      });

      test('uses default when parameter is missing or out of range', () {
        // Missing parameter
        final resultMissing = selectorNode.evaluate({});
        expect(resultMissing.animations[0].animationId, 'unarmed_idle');

        // Out of range (negative)
        final resultNeg = selectorNode.evaluate({'weapon_type': -1});
        expect(resultNeg.animations[0].animationId, 'unarmed_idle');

        // Out of range (too high)
        final resultHigh = selectorNode.evaluate({'weapon_type': 10});
        expect(resultHigh.animations[0].animationId, 'bow_idle');
      });

      test('returns all used animations', () {
        final usedAnimations = selectorNode.getUsedAnimations();
        expect(
          usedAnimations,
          containsAll(['unarmed_idle', 'sword_idle', 'bow_idle']),
        );
      });

      test('converts to and from map', () {
        final map = selectorNode.toMap();
        final fromMap = SelectorNode.fromMap(map);

        expect(fromMap.id, selectorNode.id);
        expect(fromMap.parameterName, selectorNode.parameterName);
        expect(fromMap.children.length, selectorNode.children.length);
        expect(fromMap.defaultIndex, selectorNode.defaultIndex);
      });
    });

    group('ConditionalNode', () {
      late ConditionalNode conditionalNode;

      setUp(() {
        conditionalNode = ConditionalNode(
          id: 'combat_conditional',
          name: 'Combat Conditional',
          conditionParameter: 'in_combat',
          trueChild: AnimationNode(
            id: 'combat_idle',
            name: 'Combat Idle',
            animationId: 'combat_idle',
          ),
          falseChild: AnimationNode(
            id: 'peaceful_idle',
            name: 'Peaceful Idle',
            animationId: 'peaceful_idle',
          ),
          transitionDuration: 0.5,
        );
      });

      test('selects true child when condition is true', () {
        final result = conditionalNode.evaluate({'in_combat': true});
        expect(result.animations[0].animationId, 'combat_idle');
      });

      test('selects false child when condition is false', () {
        final result = conditionalNode.evaluate({'in_combat': false});
        expect(result.animations[0].animationId, 'peaceful_idle');
      });

      test('defaults to false child when parameter is missing', () {
        final result = conditionalNode.evaluate({});
        expect(result.animations[0].animationId, 'peaceful_idle');
      });

      test('returns used animations from both children', () {
        final usedAnimations = conditionalNode.getUsedAnimations();
        expect(usedAnimations, containsAll(['combat_idle', 'peaceful_idle']));
      });

      test('converts to and from map', () {
        final map = conditionalNode.toMap();
        final fromMap = ConditionalNode.fromMap(map);

        expect(fromMap.id, conditionalNode.id);
        expect(fromMap.conditionParameter, conditionalNode.conditionParameter);
        expect(fromMap.transitionDuration, conditionalNode.transitionDuration);
      });
    });

    group('AnimationBlendTree', () {
      late AnimationBlendTree blendTree;

      setUp(() {
        blendTree = AnimationBlendTree(
          id: 'character_blend_tree',
          name: 'Character Animation Tree',
          rootNode: Blend1DNode(
            id: 'root_blend',
            name: 'Root Blend',
            parameterName: 'speed',
            blendPoints: [
              BlendPoint1D(
                value: 0.0,
                child: AnimationNode(
                  id: 'idle',
                  name: 'Idle',
                  animationId: 'idle',
                ),
              ),
              BlendPoint1D(
                value: 1.0,
                child: AnimationNode(
                  id: 'walk',
                  name: 'Walk',
                  animationId: 'walk',
                ),
              ),
            ],
          ),
          parameters: {
            'speed': BlendTreeParameter(
              name: 'speed',
              type: BlendTreeParameterType.float,
              defaultValue: 0.0,
              minValue: 0.0,
              maxValue: 10.0,
              description: 'Movement speed',
            ),
          },
          defaultValues: {'speed': 0.0},
        );
      });

      test('evaluates with given parameters', () {
        final result = blendTree.evaluate({'speed': 0.5});
        expect(result.animations.length, 2); // Should blend idle and walk
      });

      test('uses default values when parameters are missing', () {
        final result = blendTree.evaluate({});
        expect(
          result.animations[0].animationId,
          'idle',
        ); // Should use default speed 0.0
      });

      test('gets all used animations', () {
        final usedAnimations = blendTree.getUsedAnimations();
        expect(usedAnimations, containsAll(['idle', 'walk']));
      });

      test('validates correctly', () {
        expect(blendTree.validate(), true);

        // Test invalid tree (missing parameter)
        final invalidTree = AnimationBlendTree(
          id: 'invalid',
          name: 'Invalid Tree',
          rootNode: Blend1DNode(
            id: 'invalid_blend',
            name: 'Invalid',
            parameterName: 'missing_param',
            blendPoints: [
              BlendPoint1D(
                value: 0.0,
                child: AnimationNode(
                  id: 'test',
                  name: 'Test',
                  animationId: 'test',
                ),
              ),
            ],
          ),
        );
        expect(invalidTree.validate(), false);
      });

      test('converts to and from map', () {
        final map = blendTree.toMap();
        final fromMap = AnimationBlendTree.fromMap(map);

        expect(fromMap.id, blendTree.id);
        expect(fromMap.name, blendTree.name);
        expect(fromMap.parameters.length, blendTree.parameters.length);
        expect(fromMap.defaultValues, blendTree.defaultValues);
      });
    });

    group('BlendTreeParameter', () {
      test('creates parameter with all types', () {
        const floatParam = BlendTreeParameter(
          name: 'speed',
          type: BlendTreeParameterType.float,
          defaultValue: 1.0,
          minValue: 0.0,
          maxValue: 10.0,
        );

        expect(floatParam.name, 'speed');
        expect(floatParam.type, BlendTreeParameterType.float);
        expect(floatParam.defaultValue, 1.0);
        expect(floatParam.minValue, 0.0);
        expect(floatParam.maxValue, 10.0);
      });

      test('converts to and from map', () {
        const param = BlendTreeParameter(
          name: 'enabled',
          type: BlendTreeParameterType.bool,
          defaultValue: true,
          description: 'Whether feature is enabled',
        );

        final map = param.toMap();
        final fromMap = BlendTreeParameter.fromMap(map);

        expect(fromMap.name, param.name);
        expect(fromMap.type, param.type);
        expect(fromMap.defaultValue, param.defaultValue);
        expect(fromMap.description, param.description);
      });
    });

    group('BlendTreeNode Factory', () {
      test('creates correct node types from map', () {
        // Animation node
        final animMap = {
          'type': 'animation',
          'id': 'test',
          'name': 'Test',
          'animationId': 'test_anim',
        };
        final animNode = BlendTreeNode.fromMap(animMap);
        expect(animNode, isA<AnimationNode>());

        // Blend1D node
        final blend1DMap = {
          'type': 'blend1D',
          'id': 'test',
          'name': 'Test',
          'parameterName': 'speed',
          'blendPoints': [],
        };
        final blend1DNode = BlendTreeNode.fromMap(blend1DMap);
        expect(blend1DNode, isA<Blend1DNode>());

        // Selector node
        final selectorMap = {
          'type': 'selector',
          'id': 'test',
          'name': 'Test',
          'parameterName': 'index',
          'children': [],
        };
        final selectorNode = BlendTreeNode.fromMap(selectorMap);
        expect(selectorNode, isA<SelectorNode>());
      });

      test('throws on unknown node type', () {
        final invalidMap = {
          'type': 'unknown_type',
          'id': 'test',
          'name': 'Test',
        };
        expect(
          () => BlendTreeNode.fromMap(invalidMap),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Enum Tests', () {
      test('BlendWrapMode has expected values', () {
        expect(BlendWrapMode.values.length, 2);
        expect(BlendWrapMode.values, contains(BlendWrapMode.clamp));
        expect(BlendWrapMode.values, contains(BlendWrapMode.repeat));
      });

      test('Blend2DType has expected values', () {
        expect(Blend2DType.values.length, 3);
        expect(Blend2DType.values, contains(Blend2DType.freeform));
        expect(Blend2DType.values, contains(Blend2DType.directional));
        expect(Blend2DType.values, contains(Blend2DType.cartesian));
      });

      test('BlendTreeParameterType has expected values', () {
        expect(BlendTreeParameterType.values.length, 4);
        expect(
          BlendTreeParameterType.values,
          contains(BlendTreeParameterType.float),
        );
        expect(
          BlendTreeParameterType.values,
          contains(BlendTreeParameterType.int),
        );
        expect(
          BlendTreeParameterType.values,
          contains(BlendTreeParameterType.bool),
        );
        expect(
          BlendTreeParameterType.values,
          contains(BlendTreeParameterType.string),
        );
      });
    });
  });
}
