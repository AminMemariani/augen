package com.example.augen

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/** AugenPlugin */
class AugenPlugin : FlutterPlugin {
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        
        flutterPluginBinding
            .platformViewRegistry
            .registerViewFactory(
                "augen_ar_view",
                AugenViewFactory(flutterPluginBinding.binaryMessenger)
            )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Cleanup if needed
    }
}

class AugenViewFactory(
    private val messenger: io.flutter.plugin.common.BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<String, Any> ?: emptyMap()
        return AugenARView(context, viewId, messenger, creationParams)
    }
}
