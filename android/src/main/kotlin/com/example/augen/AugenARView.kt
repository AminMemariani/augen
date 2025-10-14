package com.example.augen

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import com.google.ar.core.*
import com.google.ar.core.exceptions.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.util.*

class AugenARView(
    private val context: Context,
    private val viewId: Int,
    messenger: BinaryMessenger,
    private val creationParams: Map<String, Any>
) : PlatformView, MethodChannel.MethodCallHandler {

    private val containerView: FrameLayout = FrameLayout(context)
    private val methodChannel: MethodChannel = MethodChannel(messenger, "augen_$viewId")
    
    private var arSession: Session? = null
    private var isARSessionInitialized = false
    private val nodes = mutableMapOf<String, ARNode>()
    private val anchors = mutableMapOf<String, Anchor>()
    private val detectedPlanes = mutableListOf<ARPlaneInfo>()

    init {
        methodChannel.setMethodCallHandler(this)
    }

    override fun getView(): View = containerView

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "isARSupported" -> isARSupported(result)
            "addNode" -> addNode(call, result)
            "removeNode" -> removeNode(call, result)
            "updateNode" -> updateNode(call, result)
            "hitTest" -> hitTest(call, result)
            "addAnchor" -> addAnchor(call, result)
            "removeAnchor" -> removeAnchor(call, result)
            "pause" -> pause(result)
            "resume" -> resume(result)
            "reset" -> reset(result)
            "playAnimation" -> playAnimation(call, result)
            "pauseAnimation" -> pauseAnimation(call, result)
            "stopAnimation" -> stopAnimation(call, result)
            "resumeAnimation" -> resumeAnimation(call, result)
            "seekAnimation" -> seekAnimation(call, result)
            "getAvailableAnimations" -> getAvailableAnimations(call, result)
            "setAnimationSpeed" -> setAnimationSpeed(call, result)
            else -> result.notImplemented()
        }
    }

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        try {
            if (arSession != null) {
                result.error("ALREADY_INITIALIZED", "AR session already initialized", null)
                return
            }

            // Check if ARCore is supported
            val availability = ArCoreApk.getInstance().checkAvailability(context)
            if (availability.isTransient) {
                // Wait and check again
                result.error("AR_CHECKING", "Checking AR availability...", null)
                return
            }

            if (availability != ArCoreApk.Availability.SUPPORTED_INSTALLED) {
                result.error("AR_NOT_SUPPORTED", "ARCore is not supported on this device", null)
                return
            }

            // Create AR session
            arSession = Session(context).apply {
                val config = Config(this)
                
                // Apply configuration from params
                val planeDetection = creationParams["planeDetection"] as? Boolean ?: true
                config.planeFindingMode = if (planeDetection) {
                    Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
                } else {
                    Config.PlaneFindingMode.DISABLED
                }

                val lightEstimation = creationParams["lightEstimation"] as? Boolean ?: true
                config.lightEstimationMode = if (lightEstimation) {
                    Config.LightEstimationMode.AMBIENT_INTENSITY
                } else {
                    Config.LightEstimationMode.DISABLED
                }

                val depthData = creationParams["depthData"] as? Boolean ?: false
                if (isDepthModeSupported(Config.DepthMode.AUTOMATIC) && depthData) {
                    config.depthMode = Config.DepthMode.AUTOMATIC
                }

                val autoFocus = creationParams["autoFocus"] as? Boolean ?: true
                config.focusMode = if (autoFocus) {
                    Config.FocusMode.AUTO
                } else {
                    Config.FocusMode.FIXED
                }

                configure(config)
            }

            isARSessionInitialized = true
            result.success(null)
        } catch (e: Exception) {
            result.error("INIT_ERROR", "Failed to initialize AR: ${e.message}", null)
        }
    }

    private fun isARSupported(result: MethodChannel.Result) {
        try {
            val availability = ArCoreApk.getInstance().checkAvailability(context)
            result.success(availability == ArCoreApk.Availability.SUPPORTED_INSTALLED)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun addNode(call: MethodCall, result: MethodChannel.Result) {
        try {
            val nodeData = call.arguments as Map<String, Any>
            val nodeId = nodeData["id"] as String
            val type = nodeData["type"] as String
            val position = nodeData["position"] as Map<String, Any>
            val rotation = nodeData["rotation"] as Map<String, Any>
            val scale = nodeData["scale"] as Map<String, Any>
            val properties = nodeData["properties"] as? Map<String, Any>
            val modelPath = nodeData["modelPath"] as? String
            val modelFormat = nodeData["modelFormat"] as? String
            val modelData = nodeData["modelData"] as? ByteArray

            val node = ARNode(
                id = nodeId,
                type = type,
                position = Vector3(
                    (position["x"] as Number).toFloat(),
                    (position["y"] as Number).toFloat(),
                    (position["z"] as Number).toFloat()
                ),
                rotation = Quaternion(
                    (rotation["x"] as Number).toFloat(),
                    (rotation["y"] as Number).toFloat(),
                    (rotation["z"] as Number).toFloat(),
                    (rotation["w"] as Number).toFloat()
                ),
                scale = Vector3(
                    (scale["x"] as Number).toFloat(),
                    (scale["y"] as Number).toFloat(),
                    (scale["z"] as Number).toFloat()
                ),
                properties = properties,
                modelPath = modelPath,
                modelFormat = modelFormat,
                modelData = modelData
            )

            // Handle custom 3D model loading
            if (type == "model" && (modelData != null || modelPath != null)) {
                loadAndRender3DModel(node)
            }

            nodes[nodeId] = node
            result.success(null)
        } catch (e: Exception) {
            result.error("ADD_NODE_ERROR", "Failed to add node: ${e.message}", null)
        }
    }

    private fun loadAndRender3DModel(node: ARNode) {
        // Implementation for loading 3D models (GLB, GLTF, OBJ)
        // This would integrate with Filament or Sceneform for rendering
        // 
        // Example implementation:
        // 1. Parse model data based on format (glb, gltf, obj, etc.)
        // 2. Create renderable from model data
        // 3. Attach renderable to AR anchor at specified position
        //
        // For production use, you would use:
        // - Filament (Google's rendering engine)
        // - Or Sceneform (deprecated but still functional)
        //
        // Sample code structure:
        // when (node.modelFormat) {
        //     "glb", "gltf" -> loadGLTFModel(node)
        //     "obj" -> loadOBJModel(node)
        //     else -> throw IllegalArgumentException("Unsupported format")
        // }
    }

    private fun removeNode(call: MethodCall, result: MethodChannel.Result) {
        try {
            val args = call.arguments as Map<String, Any>
            val nodeId = args["nodeId"] as String
            nodes.remove(nodeId)
            result.success(null)
        } catch (e: Exception) {
            result.error("REMOVE_NODE_ERROR", "Failed to remove node: ${e.message}", null)
        }
    }

    private fun updateNode(call: MethodCall, result: MethodChannel.Result) {
        try {
            val nodeData = call.arguments as Map<String, Any>
            val nodeId = nodeData["id"] as String
            
            if (nodes.containsKey(nodeId)) {
                addNode(call, result) // Reuse addNode logic for update
            } else {
                result.error("NODE_NOT_FOUND", "Node with id $nodeId not found", null)
            }
        } catch (e: Exception) {
            result.error("UPDATE_NODE_ERROR", "Failed to update node: ${e.message}", null)
        }
    }

    private fun hitTest(call: MethodCall, result: MethodChannel.Result) {
        try {
            val session = arSession
            if (session == null || !isARSessionInitialized) {
                result.success(emptyList<Map<String, Any>>())
                return
            }

            val args = call.arguments as Map<String, Any>
            val x = (args["x"] as Number).toFloat()
            val y = (args["y"] as Number).toFloat()

            val frame = session.update()
            val hits = frame.hitTest(x, y)

            val results = hits.map { hit ->
                val pose = hit.hitPose
                mapOf(
                    "position" to mapOf(
                        "x" to pose.tx(),
                        "y" to pose.ty(),
                        "z" to pose.tz()
                    ),
                    "rotation" to mapOf(
                        "x" to pose.qx(),
                        "y" to pose.qy(),
                        "z" to pose.qz(),
                        "w" to pose.qw()
                    ),
                    "distance" to hit.distance,
                    "planeId" to (hit.trackable as? Plane)?.hashCode()?.toString()
                )
            }

            result.success(results)
        } catch (e: Exception) {
            result.error("HIT_TEST_ERROR", "Failed to perform hit test: ${e.message}", null)
        }
    }

    private fun addAnchor(call: MethodCall, result: MethodChannel.Result) {
        try {
            val session = arSession
            if (session == null || !isARSessionInitialized) {
                result.error("SESSION_NOT_READY", "AR session not initialized", null)
                return
            }

            val positionData = call.arguments as Map<String, Any>
            val x = (positionData["x"] as Number).toFloat()
            val y = (positionData["y"] as Number).toFloat()
            val z = (positionData["z"] as Number).toFloat()

            val pose = Pose.makeTranslation(x, y, z)
            val anchor = session.createAnchor(pose)
            val anchorId = UUID.randomUUID().toString()
            anchors[anchorId] = anchor

            val anchorData = mapOf(
                "id" to anchorId,
                "position" to mapOf(
                    "x" to pose.tx(),
                    "y" to pose.ty(),
                    "z" to pose.tz()
                ),
                "rotation" to mapOf(
                    "x" to pose.qx(),
                    "y" to pose.qy(),
                    "z" to pose.qz(),
                    "w" to pose.qw()
                ),
                "timestamp" to System.currentTimeMillis()
            )

            result.success(anchorData)
        } catch (e: Exception) {
            result.error("ADD_ANCHOR_ERROR", "Failed to add anchor: ${e.message}", null)
        }
    }

    private fun removeAnchor(call: MethodCall, result: MethodChannel.Result) {
        try {
            val args = call.arguments as Map<String, Any>
            val anchorId = args["anchorId"] as String
            anchors[anchorId]?.detach()
            anchors.remove(anchorId)
            result.success(null)
        } catch (e: Exception) {
            result.error("REMOVE_ANCHOR_ERROR", "Failed to remove anchor: ${e.message}", null)
        }
    }

    private fun pause(result: MethodChannel.Result) {
        try {
            arSession?.pause()
            result.success(null)
        } catch (e: Exception) {
            result.error("PAUSE_ERROR", "Failed to pause AR: ${e.message}", null)
        }
    }

    private fun resume(result: MethodChannel.Result) {
        try {
            arSession?.resume()
            result.success(null)
        } catch (e: Exception) {
            result.error("RESUME_ERROR", "Failed to resume AR: ${e.message}", null)
        }
    }

    private fun reset(result: MethodChannel.Result) {
        try {
            nodes.clear()
            anchors.values.forEach { it.detach() }
            anchors.clear()
            detectedPlanes.clear()
            result.success(null)
        } catch (e: Exception) {
            result.error("RESET_ERROR", "Failed to reset AR: ${e.message}", null)
        }
    }

    private fun playAnimation(call: MethodCall, result: MethodChannel.Result) {
        try {
            val args = call.arguments as Map<String, Any>
            val nodeId = args["nodeId"] as String
            val animationId = args["animationId"] as String
            val speed = (args["speed"] as? Number)?.toFloat() ?: 1.0f
            val loopMode = args["loopMode"] as? String ?: "loop"

            // Implementation for playing animations on 3D models
            // This would control the animation playback using Filament's Animator
            // Example:
            // val node = nodes[nodeId]
            // if (node?.type == "model") {
            //     val animator = modelAnimators[nodeId]
            //     animator?.let {
            //         it.applyAnimation(animationIndex)
            //         it.updateBoneMatrices()
            //     }
            // }

            result.success(null)
        } catch (e: Exception) {
            result.error("PLAY_ANIMATION_ERROR", "Failed to play animation: ${e.message}", null)
        }
    }

    private fun pauseAnimation(call: MethodCall, result: MethodChannel.Result) {
        try {
            val args = call.arguments as Map<String, Any>
            val nodeId = args["nodeId"] as String
            val animationId = args["animationId"] as String

            // Pause animation playback
            result.success(null)
        } catch (e: Exception) {
            result.error("PAUSE_ANIMATION_ERROR", "Failed to pause animation: ${e.message}", null)
        }
    }

    private fun stopAnimation(call: MethodCall, result: MethodChannel.Result) {
        try {
            val args = call.arguments as Map<String, Any>
            val nodeId = args["nodeId"] as String
            val animationId = args["animationId"] as String

            // Stop animation and reset to first frame
            result.success(null)
        } catch (e: Exception) {
            result.error("STOP_ANIMATION_ERROR", "Failed to stop animation: ${e.message}", null)
        }
    }

    private fun resumeAnimation(call: MethodCall, result: MethodChannel.Result) {
        try {
            val args = call.arguments as Map<String, Any>
            val nodeId = args["nodeId"] as String
            val animationId = args["animationId"] as String

            // Resume paused animation
            result.success(null)
        } catch (e: Exception) {
            result.error("RESUME_ANIMATION_ERROR", "Failed to resume animation: ${e.message}", null)
        }
    }

    private fun seekAnimation(call: MethodCall, result: MethodChannel.Result) {
        try {
            val args = call.arguments as Map<String, Any>
            val nodeId = args["nodeId"] as String
            val animationId = args["animationId"] as String
            val time = (args["time"] as Number).toFloat()

            // Seek to specific time in animation
            result.success(null)
        } catch (e: Exception) {
            result.error("SEEK_ANIMATION_ERROR", "Failed to seek animation: ${e.message}", null)
        }
    }

    private fun getAvailableAnimations(call: MethodCall, result: MethodChannel.Result) {
        try {
            val args = call.arguments as Map<String, Any>
            val nodeId = args["nodeId"] as String

            // Get list of animation names from the model
            // Example:
            // val node = nodes[nodeId]
            // val animator = modelAnimators[nodeId]
            // val animationNames = animator?.getAnimationNames() ?: emptyList()

            result.success(emptyList<String>())
        } catch (e: Exception) {
            result.error("GET_ANIMATIONS_ERROR", "Failed to get animations: ${e.message}", null)
        }
    }

    private fun setAnimationSpeed(call: MethodCall, result: MethodChannel.Result) {
        try {
            val args = call.arguments as Map<String, Any>
            val nodeId = args["nodeId"] as String
            val animationId = args["animationId"] as String
            val speed = (args["speed"] as Number).toFloat()

            // Set playback speed for animation
            result.success(null)
        } catch (e: Exception) {
            result.error("SET_SPEED_ERROR", "Failed to set animation speed: ${e.message}", null)
        }
    }

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        arSession?.close()
        arSession = null
    }

    // Helper classes
    private data class ARNode(
        val id: String,
        val type: String,
        val position: Vector3,
        val rotation: Quaternion,
        val scale: Vector3,
        val properties: Map<String, Any>?,
        val modelPath: String? = null,
        val modelFormat: String? = null,
        val modelData: ByteArray? = null,
        val animations: List<Map<String, Any>>? = null
    )

    private data class Vector3(val x: Float, val y: Float, val z: Float)
    private data class Quaternion(val x: Float, val y: Float, val z: Float, val w: Float)
    private data class ARPlaneInfo(val id: String, val plane: Plane)
}

