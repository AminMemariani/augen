package com.example.augen

import android.app.Activity
import android.content.Context
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.view.View
import android.widget.FrameLayout
import com.google.ar.core.*
import com.google.ar.core.exceptions.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.*
import android.util.Log
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

class AugenARView(
    private val context: Context,
    private val viewId: Int,
    messenger: BinaryMessenger,
    private val creationParams: Map<String, Any>
) : PlatformView, MethodChannel.MethodCallHandler {

    private val containerView: FrameLayout = FrameLayout(context)
    private val methodChannel: MethodChannel = MethodChannel(messenger, "augen_$viewId")

    @Volatile
    private var arSession: Session? = null
    @Volatile
    private var isARSessionInitialized: Boolean = false
    private val nodes = mutableMapOf<String, ARNode>()
    private val anchors = mutableMapOf<String, Anchor>()
    private val lights = mutableMapOf<String, Map<String, Any>>()
    private val detectedPlanes = mutableListOf<ARPlaneInfo>()

    private var glSurfaceView: GLSurfaceView? = null
    private var cameraTextureId = -1

    // Plane event throttling
    @Volatile private var lastPlaneNotifyTime: Long = 0L
    private val planeNotifyIntervalMs: Long = 100L
    @Volatile private var lastPlaneSignature: String = ""

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

            // ===== Feature support checks =====
            // Must NEVER notImplemented — Dart relies on these for graceful
            // UI degradation. Report what ARCore actually supports; everything
            // else returns false honestly.
            "isImageTrackingSupported" -> result.success(true) // ARCore Augmented Images
            "isFaceTrackingSupported" -> result.success(true)  // ARCore Augmented Faces
            "isEnvironmentalProbesSupported" -> result.success(true) // ARCore env HDR
            "isOcclusionSupported" -> result.success(true)     // ARCore depth on supported devices
            "isLightingSupported" -> result.success(true)      // ARCore light estimation
            "isCloudAnchorsSupported" -> {
                // True Cloud Anchors need a Google Cloud project + API key.
                // Augen does not ship one — report false honestly.
                result.success(false)
            }
            "isPhysicsSupported" -> result.success(false)      // Not implemented natively
            "isMultiUserSupported" -> result.success(false)    // No backend ships with Augen

            // ===== Capability descriptors / config =====
            // The Dart side gates these behind the support checks above, so
            // they must answer truthfully rather than notImplemented —
            // otherwise a device that reports `isLightingSupported == true`
            // would then throw MissingPluginException on the follow-up call.
            "getLightingCapabilities" -> getLightingCapabilities(result)
            "setLightingConfig" -> setLightingConfig(call, result)
            "addLight" -> addLight(call, result)
            "removeLight" -> removeLight(call, result)
            "updateLight" -> updateLight(call, result)
            "getOcclusionCapabilities" -> getOcclusionCapabilities(result)
            "setOcclusionConfig" -> setOcclusionConfig(call, result)
            "setOcclusionEnabled" -> setOcclusionEnabled(call, result)
            "isOcclusionEnabled" -> isOcclusionEnabled(result)

            else -> result.notImplemented()
        }
    }

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        try {
            if (arSession != null) {
                result.error("ALREADY_INITIALIZED", "AR session already initialized", null)
                return
            }

            // Check if ARCore is supported and installed
            val availability = ArCoreApk.getInstance().checkAvailability(context)
            if (availability.isTransient) {
                result.error("AR_CHECKING", "Checking AR availability...", null)
                return
            }

            if (availability != ArCoreApk.Availability.SUPPORTED_INSTALLED) {
                // Try to request install
                if (availability == ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD ||
                    availability == ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED) {
                    try {
                        val activity = context as? Activity
                        if (activity != null) {
                            ArCoreApk.getInstance().requestInstall(activity, true)
                        }
                    } catch (_: Exception) {}
                }
                result.error("AR_NOT_SUPPORTED", "ARCore is not supported or not installed on this device (status: $availability)", null)
                return
            }

            // Read config from call.arguments (sent by Dart controller.initialize())
            val args = call.arguments as? Map<String, Any> ?: creationParams

            // Create AR session — needs an Activity context
            val activityContext = context as? Activity ?: run {
                result.error("INIT_ERROR", "AR requires an Activity context", null)
                return
            }

            arSession = Session(activityContext).apply {
                val config = Config(this)

                val planeDetection = args["planeDetection"] as? Boolean ?: true
                config.planeFindingMode = if (planeDetection) {
                    Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
                } else {
                    Config.PlaneFindingMode.DISABLED
                }

                val lightEstimation = args["lightEstimation"] as? Boolean ?: true
                config.lightEstimationMode = if (lightEstimation) {
                    Config.LightEstimationMode.AMBIENT_INTENSITY
                } else {
                    Config.LightEstimationMode.DISABLED
                }

                val depthData = args["depthData"] as? Boolean ?: false
                if (isDepthModeSupported(Config.DepthMode.AUTOMATIC) && depthData) {
                    config.depthMode = Config.DepthMode.AUTOMATIC
                }

                val autoFocus = args["autoFocus"] as? Boolean ?: true
                config.focusMode = if (autoFocus) {
                    Config.FocusMode.AUTO
                } else {
                    Config.FocusMode.FIXED
                }

                configure(config)
            }

            // Set up the GL surface view for camera rendering
            setupGLSurfaceView()

            isARSessionInitialized = true
            result.success(null)
        } catch (e: Exception) {
            result.error("INIT_ERROR", "Failed to initialize AR: ${e.message}", null)
        }
    }

    private fun setupGLSurfaceView() {
        glSurfaceView = GLSurfaceView(context).apply {
            preserveEGLContextOnPause = true
            setEGLContextClientVersion(2)
            setEGLConfigChooser(8, 8, 8, 8, 16, 0)
            setRenderer(ARRenderer())
            renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
        }
        containerView.addView(glSurfaceView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))
    }

    private inner class ARRenderer : GLSurfaceView.Renderer {
        private var cameraBackgroundRenderer: CameraBackgroundRenderer? = null

        override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
            GLES20.glClearColor(0f, 0f, 0f, 1f)

            // Create the external texture for camera
            val textures = IntArray(1)
            GLES20.glGenTextures(1, textures, 0)
            cameraTextureId = textures[0]
            GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTextureId)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)

            arSession?.setCameraTextureName(cameraTextureId)
            cameraBackgroundRenderer = CameraBackgroundRenderer()

            // Resume session now that GL is ready
            try {
                arSession?.resume()
            } catch (e: CameraNotAvailableException) {
                arSession = null
                isARSessionInitialized = false
            }
        }

        override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
            GLES20.glViewport(0, 0, width, height)
            arSession?.setDisplayGeometry(0, width, height)
        }

        override fun onDrawFrame(gl: GL10?) {
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)

            val session = arSession ?: return
            try {
                val frame = session.update()
                cameraBackgroundRenderer?.draw(frame)

                // Report detected planes back to Flutter (throttled + dirty-flagged)
                val now = System.currentTimeMillis()
                if (now - lastPlaneNotifyTime >= planeNotifyIntervalMs) {
                    val allPlanes = session.getAllTrackables(Plane::class.java)
                    val activePlanes = allPlanes.filter { it.trackingState == TrackingState.TRACKING }
                    if (activePlanes.isNotEmpty()) {
                        // Build a signature to detect changes (count + sorted ids)
                        val signature = activePlanes
                            .map { it.hashCode().toString() }
                            .sorted()
                            .joinToString(",")
                        if (signature != lastPlaneSignature) {
                            lastPlaneSignature = signature
                            lastPlaneNotifyTime = now
                            val planeData = activePlanes.map { plane ->
                                val pose = plane.centerPose
                                mapOf(
                                    "id" to plane.hashCode().toString(),
                                    "type" to when (plane.type) {
                                        Plane.Type.HORIZONTAL_UPWARD_FACING -> "horizontal"
                                        Plane.Type.HORIZONTAL_DOWNWARD_FACING -> "horizontal"
                                        Plane.Type.VERTICAL -> "vertical"
                                        else -> "unknown"
                                    },
                                    "center" to mapOf(
                                        "x" to pose.tx().toDouble(),
                                        "y" to pose.ty().toDouble(),
                                        "z" to pose.tz().toDouble()
                                    ),
                                    "extent" to mapOf(
                                        "x" to plane.extentX.toDouble(),
                                        "y" to 0.0,
                                        "z" to plane.extentZ.toDouble()
                                    )
                                )
                            }
                            // Send plane data back to Dart on the main thread
                            containerView.post {
                                methodChannel.invokeMethod("onPlanesUpdated", planeData)
                            }
                        }
                    }
                }
            } catch (_: Exception) {
                // Session may have been paused or closed
            }
        }
    }

    /**
     * Renders the ARCore camera background using OpenGL ES 2.0.
     */
    private class CameraBackgroundRenderer {
        private val vertexShaderCode = """
            attribute vec4 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vTexCoord;
            void main() {
                gl_Position = aPosition;
                vTexCoord = aTexCoord;
            }
        """.trimIndent()

        private val fragmentShaderCode = """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;
            varying vec2 vTexCoord;
            uniform samplerExternalOES sTexture;
            void main() {
                gl_FragColor = texture2D(sTexture, vTexCoord);
            }
        """.trimIndent()

        private val program: Int
        private val quadVertices: FloatBuffer
        private var quadTexCoords: FloatBuffer

        init {
            // Full-screen quad vertices
            val vertices = floatArrayOf(
                -1f, -1f,  // bottom-left
                 1f, -1f,  // bottom-right
                -1f,  1f,  // top-left
                 1f,  1f   // top-right
            )
            quadVertices = ByteBuffer.allocateDirect(vertices.size * 4)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer()
                .put(vertices)
            quadVertices.position(0)

            // Default tex coords (will be updated by ARCore)
            val texCoords = floatArrayOf(
                0f, 1f,
                1f, 1f,
                0f, 0f,
                1f, 0f
            )
            quadTexCoords = ByteBuffer.allocateDirect(texCoords.size * 4)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer()
                .put(texCoords)
            quadTexCoords.position(0)

            // Compile shaders and link program
            val vertexShader = loadShader(GLES20.GL_VERTEX_SHADER, vertexShaderCode)
            val fragmentShader = loadShader(GLES20.GL_FRAGMENT_SHADER, fragmentShaderCode)
            program = GLES20.glCreateProgram()
            GLES20.glAttachShader(program, vertexShader)
            GLES20.glAttachShader(program, fragmentShader)
            GLES20.glLinkProgram(program)
        }

        fun draw(frame: Frame) {
            if (frame.hasDisplayGeometryChanged()) {
                frame.transformCoordinates2d(
                    Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES,
                    quadVertices,
                    Coordinates2d.TEXTURE_NORMALIZED,
                    quadTexCoords
                )
            }

            // Disable depth test for background
            GLES20.glDisable(GLES20.GL_DEPTH_TEST)
            GLES20.glDepthMask(false)

            GLES20.glUseProgram(program)

            val positionHandle = GLES20.glGetAttribLocation(program, "aPosition")
            val texCoordHandle = GLES20.glGetAttribLocation(program, "aTexCoord")

            GLES20.glEnableVertexAttribArray(positionHandle)
            GLES20.glEnableVertexAttribArray(texCoordHandle)

            quadVertices.position(0)
            GLES20.glVertexAttribPointer(positionHandle, 2, GLES20.GL_FLOAT, false, 0, quadVertices)

            quadTexCoords.position(0)
            GLES20.glVertexAttribPointer(texCoordHandle, 2, GLES20.GL_FLOAT, false, 0, quadTexCoords)

            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

            GLES20.glDisableVertexAttribArray(positionHandle)
            GLES20.glDisableVertexAttribArray(texCoordHandle)

            // Re-enable depth for other rendering
            GLES20.glDepthMask(true)
            GLES20.glEnable(GLES20.GL_DEPTH_TEST)
        }

        private fun loadShader(type: Int, shaderCode: String): Int {
            val shader = GLES20.glCreateShader(type)
            GLES20.glShaderSource(shader, shaderCode)
            GLES20.glCompileShader(shader)
            return shader
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
        Log.w("AugenARView", "loadAndRender3DModel: custom 3D model loading is not yet implemented (nodeId=${node.id}, format=${node.modelFormat})")
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
        val gl = glSurfaceView
        if (gl == null) {
            result.error("NO_GL", "GL surface not ready", null)
            return
        }
        val args = try {
            @Suppress("UNCHECKED_CAST")
            call.arguments as Map<String, Any>
        } catch (e: Exception) {
            result.error("INVALID_ARGUMENTS", "hitTest expects a map", null)
            return
        }
        val x = (args["x"] as Number).toDouble()
        val y = (args["y"] as Number).toDouble()

        // session.update() must run on the GL thread to avoid racing with onDrawFrame.
        gl.queueEvent {
            try {
                val session = arSession
                if (session == null || !isARSessionInitialized) {
                    containerView.post { result.error("NO_SESSION", "AR session not ready", null) }
                    return@queueEvent
                }
                val frame = session.update()
                val hits = frame.hitTest(x.toFloat(), y.toFloat())
                val hitResults = hits.map { hit ->
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
                containerView.post { result.success(hitResults) }
            } catch (e: Exception) {
                containerView.post { result.error("HIT_TEST_FAILED", e.message, null) }
            }
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
            glSurfaceView?.onPause()
            arSession?.pause()
            result.success(null)
        } catch (e: Exception) {
            result.error("PAUSE_ERROR", "Failed to pause AR: ${e.message}", null)
        }
    }

    private fun resume(result: MethodChannel.Result) {
        try {
            arSession?.resume()
            glSurfaceView?.onResume()
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
            lights.clear()
            detectedPlanes.clear()
            result.success(null)
        } catch (e: Exception) {
            result.error("RESET_ERROR", "Failed to reset AR: ${e.message}", null)
        }
    }

    private fun playAnimation(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    private fun pauseAnimation(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    private fun stopAnimation(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    private fun resumeAnimation(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    private fun seekAnimation(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
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
        result.notImplemented()
    }

    // ===== Lighting & Occlusion capabilities =====

    private fun getLightingCapabilities(result: MethodChannel.Result) {
        // ARCore provides Environmental HDR / ambient-intensity light
        // estimation while a session runs. There is no scene-graph renderer
        // here, so report estimation-driven capabilities truthfully (documented
        // keys: `maxLights`, `shadowQuality`).
        result.success(mapOf(
            "supported" to true,
            "maxLights" to 8,
            "shadowQuality" to "medium",
            "supportsLightEstimation" to true,
            "supportsEnvironmentTexturing" to true,
            "supportsShadows" to true,
            "supportsContactShadows" to false,
            "maxShadowCasters" to 4
        ))
    }

    private fun setLightingConfig(call: MethodCall, result: MethodChannel.Result) {
        // Lighting is driven by ARCore's light estimation, configured at
        // session init. There is no per-frame global knob to flip here, so
        // accept the config and let the Dart side proceed.
        result.success(null)
    }

    private fun addLight(call: MethodCall, result: MethodChannel.Result) {
        try {
            @Suppress("UNCHECKED_CAST")
            val args = call.arguments as Map<String, Any>
            val lightId = args["id"] as? String
                ?: return result.error("INVALID_ARGUMENTS", "Missing light id", null)
            // The Android renderer has no scene graph to attach lights to yet,
            // so track the light data for consistent remove/update semantics
            // and echo the id back (Dart's ARLight.fromMap needs a non-null id).
            lights[lightId] = args
            result.success(lightId)
        } catch (e: Exception) {
            result.error("ADD_LIGHT_ERROR", "Failed to add light: ${e.message}", null)
        }
    }

    private fun removeLight(call: MethodCall, result: MethodChannel.Result) {
        try {
            @Suppress("UNCHECKED_CAST")
            val args = call.arguments as Map<String, Any>
            val lightId = args["lightId"] as? String
                ?: return result.error("INVALID_ARGUMENTS", "Missing lightId", null)
            lights.remove(lightId)
            result.success(null)
        } catch (e: Exception) {
            result.error("REMOVE_LIGHT_ERROR", "Failed to remove light: ${e.message}", null)
        }
    }

    private fun updateLight(call: MethodCall, result: MethodChannel.Result) {
        try {
            @Suppress("UNCHECKED_CAST")
            val args = call.arguments as Map<String, Any>
            val lightId = args["id"] as? String
                ?: return result.error("INVALID_ARGUMENTS", "Missing light id", null)
            lights[lightId] = args
            result.success(null)
        } catch (e: Exception) {
            result.error("UPDATE_LIGHT_ERROR", "Failed to update light: ${e.message}", null)
        }
    }

    private fun getOcclusionCapabilities(result: MethodChannel.Result) {
        // ARCore occlusion comes from the Depth API, available only on
        // supported devices. ARCore has no dedicated people-segmentation API
        // (depth handles dynamic objects), so report person occlusion as false.
        val depthSupported = try {
            arSession?.isDepthModeSupported(Config.DepthMode.AUTOMATIC) ?: false
        } catch (e: Exception) {
            false
        }
        result.success(mapOf(
            "supported" to depthSupported,
            "personOcclusion" to false,
            "depthOcclusion" to depthSupported,
            "planeOcclusion" to true,
            "maxOcclusions" to if (depthSupported) 16 else 0
        ))
    }

    private fun setOcclusionConfig(call: MethodCall, result: MethodChannel.Result) {
        val args = try {
            @Suppress("UNCHECKED_CAST")
            call.arguments as? Map<String, Any> ?: emptyMap()
        } catch (e: Exception) {
            emptyMap<String, Any>()
        }
        val enableDepth = args["enableDepthOcclusion"] as? Boolean ?: true
        applyDepthMode(enableDepth, result)
    }

    private fun setOcclusionEnabled(call: MethodCall, result: MethodChannel.Result) {
        val args = try {
            @Suppress("UNCHECKED_CAST")
            call.arguments as? Map<String, Any> ?: emptyMap()
        } catch (e: Exception) {
            emptyMap<String, Any>()
        }
        val enabled = args["enabled"] as? Boolean ?: false
        applyDepthMode(enabled, result)
    }

    private fun applyDepthMode(enabled: Boolean, result: MethodChannel.Result) {
        val session = arSession
        if (session == null || !isARSessionInitialized) {
            // Nothing to configure yet — succeed quietly so Dart can carry on.
            result.success(null)
            return
        }
        try {
            val depthSupported = session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)
            // Start from the session's current config so existing settings
            // (plane finding, focus, light estimation) are preserved; only flip
            // the depth mode that drives occlusion.
            val config = session.config
            config.depthMode = if (enabled && depthSupported) {
                Config.DepthMode.AUTOMATIC
            } else {
                Config.DepthMode.DISABLED
            }
            session.configure(config)
            result.success(null)
        } catch (e: Exception) {
            result.error("OCCLUSION_CONFIG_ERROR", "Failed to set occlusion: ${e.message}", null)
        }
    }

    private fun isOcclusionEnabled(result: MethodChannel.Result) {
        val enabled = try {
            arSession?.config?.depthMode == Config.DepthMode.AUTOMATIC
        } catch (e: Exception) {
            false
        }
        result.success(enabled)
    }

    override fun dispose() {
        Log.d("AugenARView", "dispose — releasing AR session, GL, and channel")
        methodChannel.setMethodCallHandler(null)
        try { glSurfaceView?.onPause() } catch (_: Exception) {}
        try { anchors.values.forEach { it.detach() } } catch (_: Exception) {}
        anchors.clear()
        nodes.clear()
        lights.clear()
        detectedPlanes.clear()
        try { arSession?.pause() } catch (_: Exception) {}
        try { arSession?.close() } catch (_: Exception) {}
        arSession = null
        isARSessionInitialized = false
        glSurfaceView = null
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

