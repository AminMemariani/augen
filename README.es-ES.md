

# Augen - Plugin AR para Flutter

[![pub package](https://img.shields.io/pub/v/augen.svg)](https://pub.dev/packages/augen)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Un plugin Flutter multiplataforma para desarrollar aplicaciones de RA (Realidad Aumentada) utilizando **ARCore** en Android y **RealityKit** en iOS. Escribe toda tu lógica de RA en Dart, sin necesidad de código nativo.

## Características

- **Detección de planos** — detecta superficies horizontales y verticales
- **Objetos 3D** — coloca primitivas (esfera, cubo, cilindro) o carga modelos personalizados (GLTF, GLB, OBJ, USDZ)
- **Prueba de impacto (Hit Testing)** — coloca objetos al tocar superficies detectadas
- **Seguimiento de imágenes** — rastrea imágenes del mundo real y ancla contenido a ellas
- **Seguimiento facial** — detecta rostros con puntos faciales (landmarks) y expresiones
- **Anclajes en la nube** — persiste y comparte anclajes de RA entre sesiones y dispositivos
- **Oclusión** — oclusión por profundidad, persona y planos para un renderizado realista
- **Física** — cuerpos dinámicos, estáticos y cinemáticos con fuerzas, impulsos y restricciones
- **RA multiusuario** — sesiones compartidas con sincronización de objetos en tiempo real
- **Iluminación y sombras** — luces direccionales, puntuales, de foco y ambientales con sombras configurables
- **Sondas ambientales** — reflejos realistas e iluminación ambiental
- **Animaciones** — animaciones esqueléticas con fusión, transiciones y máquinas de estados

> **La iluminación y la oclusión cuentan con soporte nativo en ambas plataformas.** Las consultas de capacidades (`getLightingCapabilities`, `getOcclusionCapabilities`) y la configuración (`setLightingConfig`, `setOcclusionConfig`, `setOcclusionEnabled`) informan las capacidades reales del dispositivo: luces de RealityKit y oclusión de personas de ARKit en iOS, y la API de profundidad de ARCore en Android, degradándose de manera elegante cuando no están disponibles.

Para documentación detallada de la API y uso avanzado, consulta [Documentation.md](Documentation.md).

## Requisitos de la plataforma

| Plataforma | Versión Mínima        | Marco de AR            |
| -------- | ---------------------- | -------------------- |
| Android  | API 24 (Android 7.0)  | ARCore               |
| iOS      | iOS 13.0              | RealityKit & ARKit   |

**SDK:** Flutter >= 3.3.0, Dart >= 3.9.2

## Instalación

```yaml
dependencies:
  augen: ^1.4.2
```

```bash
flutter pub get
```

### Configuración para Android

Añade lo siguiente a tu `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera.ar" android:required="true" />
<uses-feature android:glEsVersion="0x00030000" android:required="true" />

<application>
    <meta-data android:name="com.google.ar.core" android:value="required" />
</application>
```

Establece `minSdkVersion` en al menos **24** en `android/app/build.gradle`.

### Configuración para iOS

Añade lo siguiente a tu `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access for AR features</string>

<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>arkit</string>
</array>
```

Establece el destino de despliegue en al menos **iOS 13.0**.

**Gestor de Paquetes Swift (SPM):** Augen incluye soporte tanto para Swift Package Manager como para CocoaPods, por lo que funciona independientemente de que tu aplicación haya migrado a SPM o no. No se requieren pasos adicionales: la herramienta de Flutter configura la integración correcta automáticamente. Si tienes habilitado SPM (`flutter config --enable-swift-package-manager`), `augen` se resuelve como un paquete Swift; de lo contrario, se instala mediante CocoaPods.

## Inicio Rápido

### 1. Mostrar la vista AR

`AugenView` es el widget que renderiza la transmisión de la cámara y la escena AR. Cuando la vista está lista, recibirás un `AugenController` para controlar todo.

```dart
import 'package:flutter/material.dart';
import 'package:augen/augen.dart';

class ARScreen extends StatefulWidget {
  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> {
  AugenController? _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AugenView(
        onViewCreated: (controller) {
          _controller = controller;
          _initAR();
        },
        config: ARSessionConfig(
          planeDetection: true,
          lightEstimation: true,
        ),
      ),
    );
  }

  Future<void> _initAR() async {
    final supported = await _controller!.isARSupported();
    if (!supported) return;

    await _controller!.initialize(
      ARSessionConfig(planeDetection: true, lightEstimation: true),
    );

    // React to detected planes
    _controller!.planesStream.listen((planes) {
      debugPrint('Detected ${planes.length} planes');
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
```

### 2. Colocar objetos mediante prueba de impacto (Hit Test)

Toca una superficie detectada para colocar un objeto 3D:

```dart
final results = await _controller!.hitTest(screenX, screenY);
if (results.isNotEmpty) {
  await _controller!.addNode(
    ARNode(
      id: 'sphere_1',
      type: NodeType.sphere,
      position: results.first.position,
      scale: Vector3(0.1, 0.1, 0.1),
    ),
  );
}
```

### 3. Cargar modelos 3D personalizados

```dart
// From Flutter assets
await _controller!.addModelFromAsset(
  id: 'ship',
  assetPath: 'assets/models/spaceship.glb',
  position: Vector3(0, 0, -1),
  scale: Vector3(0.1, 0.1, 0.1),
);

// From a URL
await _controller!.addModelFromUrl(
  id: 'building',
  url: 'https://example.com/models/building.glb',
  position: Vector3(1, 0, -2),
  modelFormat: ModelFormat.glb,
);
```

**Formatos recomendados:** GLB para Android, USDZ para iOS. También se admiten GLTF y OBJ.

## RA basada en marcadores para Web

Augen se ejecuta en el navegador mediante Flutter Web (Wasm o JS) y detecta marcadores visuales cuadrados en la transmisión en vivo de la cámara utilizando un **detector basado en coincidencia de plantillas de imágenes** implementado en JavaScript con enlaces `dart:js_interop`.

> **Estado:** El detector hace coincidir plantillas de marcadores PNG/JPG mediante correlación cruzada normalizada multiescala (NCC). La traducción de la postura se calcula a partir del tamaño aparente del marcador y el ancho físico configurado; la rotación es actualmente identidad. Para una postura completa de 6 grados de libertad (6-DoF), una futura versión incluirá ARToolKit Wasm o OpenCV.js POSIT. También está planificada la integración con el renderizado de Three.js: el renderizador ya mantiene el estado de la escena y las transformaciones de los marcadores, pero aún no dibuja geometría. Agradecemos contribuciones.

### Compatibilidad con navegadores

| Navegador | Compatibilidad |
| --- | --- |
| Chrome (escritorio y Android) | ✅ Completa |
| Edge | ✅ Completa |
| Safari | ⚠️ Parcial (limitaciones de WebRTC) |
| Firefox | ⚠️ Parcial (WebAssembly SIMD varía) |

### Requisitos

- **Flutter Wasm:** `flutter run -d chrome --wasm`
- **HTTPS** obligatorio para el acceso a la cámara con `getUserMedia` (localhost es una excepción)
- El usuario debe conceder el permiso de cámara
- El servidor debe servir archivos `.wasm` con `Content-Type: application/wasm`
- Para `SharedArrayBuffer` (mejora de rendimiento opcional): establece los encabezados `Cross-Origin-Opener-Policy: same-origin` y `Cross-Origin-Embedder-Policy: require-corp`

### Tipos de objetivos de marcador

| Tipo | Descripción | Estado |
| --- | --- | --- |
| `ARMarkerType.pattern` (con `imagePath`) | Plantilla de imagen PNG/JPG coincidente vía NCC | ✅ Implementado |
| `ARMarkerType.pattern` (con `patternPath`) | Archivo clásico `.patt` de ARToolKit | ⚠️ Planificado (ARToolKit Wasm) |
| `ARMarkerType.barcode` | Marcadores numéricos de código de barras | ⚠️ Planificado |
| `ARMarkerType.aruco` | Marcadores del diccionario ArUco | ⚠️ Planificado |

### Inicio Rápido

```dart
AugenView(
  config: const ARSessionConfig(
    markerTracking: true,
    planeDetection: false,
  ),
  onViewCreated: (controller) async {
    await controller.initialize(
      const ARSessionConfig(
        markerTracking: true,
        markerDetectionOptions: ARMarkerDetectionOptions(
          maxDetectionFps: 20,
          debug: true,
        ),
      ),
    );

    // Use a PNG/JPG image as the marker template.
    await controller.addMarkerTarget(
      const ARMarkerTarget(
        id: 'hiro',
        name: 'Hiro marker',
        type: ARMarkerType.pattern,
        imagePath: 'assets/markers/Hiro_marker.png',
        physicalWidth: 0.08, // 8 cm
      ),
    );

    await controller.setMarkerTrackingEnabled(true);

    controller.trackedMarkersStream.listen((markers) {
      for (final marker in markers) {
        if (marker.isTracked && marker.isReliable) {
          // Anchor content to the marker
        }
      }
    });
  },
);
```

Un ejemplo independiente y ejecutable se encuentra en `example/web_marker_ar/`:

```bash
cd example/web_marker_ar
flutter run -d chrome --wasm
```

### Características compatibles vs no compatibles en Web

| Característica | Soporte Web |
| --- | --- |
| Seguimiento de marcadores (plantillas de imagen PNG/JPG) | ✅ |
| Renderizado de transmisión de cámara | ✅ |
| `trackedMarkersStream` y actualizaciones de postura del marcador | ✅ |
| Anclaje de nodos 3D a marcadores (estado del grafo de escena) | ✅ |
| Renderizado de geometría con Three.js | ⚠️ Planificado |
| Postura completa de 6-DoF (rotación) | ⚠️ Planificado (ARToolKit Wasm) |
| Tipos de marcadores `.patt` / código de barras / ArUco | ⚠️ Planificado |
| Detección de planos | ❌ Solo móvil |
| Seguimiento de imágenes (estilo ARCore/ARKit) | ❌ Solo móvil |
| Seguimiento facial | ❌ Solo móvil |
| Anclajes en la nube | ❌ Solo móvil |
| Oclusión / Física / LiDAR | ❌ Solo móvil |

### Consejos de rendimiento

- Establece `maxDetectionFps` entre 15 y 20 para equilibrar precisión y uso de CPU
- Usa archivos de patrón de marcador pequeños (< 10 KB)
- Imprime los marcadores con el `physicalWidth` configurado para una escala correcta
- Prefiere Chrome/Edge para el mejor rendimiento de WebAssembly
- Usa `debug: false` en producción para desactivar las superposiciones visuales

### Solución de problemas

- **La cámara no se inicia:** Asegúrate de usar HTTPS (o localhost) y de que el usuario haya concedido el permiso de cámara.
- **Marcador no detectado:** Verifica que la `imagePath` (PNG/JPG) esté declarada en los activos de `pubspec.yaml` y que el marcador impreso coincida con `physicalWidth`. Asegúrate de que haya iluminación adecuada y que el marcador ocupe una porción razonable del encuadre de la cámara.
- **La cámara se queda en "Inicializando…":** En portátiles sin cámara trasera, `facingMode: 'environment'` se devuelve automáticamente a cualquier cámara disponible. Si sigue congelado, cierra otras aplicaciones/pestañas que estén usando la webcam.
- **Wasm no se carga:** Confirma que el servidor sirve `.wasm` con `Content-Type: application/wasm`.
- **Errores de `SharedArrayBuffer`:** Añade los encabezados COOP/COEP a tu servidor web.
- **FPS bajos:** Reduce `maxDetectionFps`, cierra otras pestañas o usa un dispositivo con mejor GPU.

## Resumen de la arquitectura

```
augen/
  lib/
    augen.dart                  # Public barrel export
    src/
      augen_controller.dart     # AugenController — all AR operations
      augen_view.dart           # AugenView widget
      models/                   # Data classes (ARNode, ARPlane, Vector3, etc.)
  android/                      # Kotlin — ARCore integration
  ios/                          # Swift — RealityKit / ARKit integration
  example/                      # Full-featured demo app
  test/                         # Unit and integration tests
```

**Cómo funciona:** `AugenView` crea una vista de plataforma (Android: `PlatformViewLink`, iOS: `UiKitView`) que aloja el renderizador AR nativo. Toda la comunicación entre Dart y el código nativo ocurre a través de canales de métodos de Flutter, abstraídos detrás de `AugenController`.

### Clases principales

| Clase | Propósito |
| ----- | ------- |
| `AugenView` | Widget que muestra la cámara AR + escena |
| `AugenController` | Controla la sesión AR: agregar/eliminar nodos, prueba de impacto, gestionar anclajes, animaciones, física, etc. |
| `ARSessionConfig` | Opciones de sesión: detección de planos, estimación de luz, datos de profundidad, enfoque automático |
| `ARNode` | Un objeto 3D en la escena (primitivas o modelos personalizados) |
| `ARPlane` | Una superficie detectada (horizontal/vertical) |
| `ARAnchor` | Un punto fijo en el espacio mundial |
| `ARHitResult` | Resultado de un raycast contra geometría detectada |
| `Vector3` / `Quaternion` | Tipos de posición y rotación 3D |

### Flujos reactivos (Streams)

`AugenController` expone flujos para todas las actualizaciones de estado AR. Suscríbete para mantener la sincronización:

```dart
_controller.planesStream          // detected planes
_controller.anchorsStream         // anchors
_controller.trackedImagesStream   // image tracking results
_controller.facesStream           // face tracking results
_controller.errorStream           // errors
_controller.physicsBodiesStream   // physics body updates
_controller.lightsStream          // light changes
// ... and more — see Documentation.md for the full list
```

## Aplicaciones de ejemplo

El directorio `example/` contiene una aplicación de demostración completa con pestañas para cada característica (planos, nodos, imágenes, rostros, anclajes en la nube, oclusión, física, multiusuario, iluminación, sondas, animaciones).

```bash
cd example
flutter run
```

### Ejemplo de RA basada en marcadores para Web

Un ejemplo web independiente que demuestra RA basada en marcadores está disponible en [`example/web_marker_ar/`](example/web_marker_ar/):

```bash
cd example/web_marker_ar
flutter run -d chrome --wasm
```

Consulta el [README de RA basada en marcadores para Web](example/web_marker_ar/README.md) para obtener detalles sobre la configuración y el uso.

## Pruebas

```bash
# Run all tests
flutter test

# Run specific test suites
flutter test test/augen_controller_test.dart
flutter test test/augen_animation_test.dart

# Integration tests (requires a device or simulator)
cd example
flutter test integration_test/plugin_integration_test.dart
```

## Solución de problemas

**Android — ARCore no funciona:**
- Verifica que el dispositivo [sea compatible con ARCore](https://developers.google.com/ar/devices)
- Asegúrate de tener instalados los Servicios de Google Play para AR
- Confirma que `minSdkVersion >= 24`

**iOS — ARKit no disponible:**
- Requiere chip A9 o posterior (iPhone 6s+)
- Confirma que el destino de despliegue es iOS 13.0+
- Asegúrate de que la capacidad `arkit` esté declarada en Info.plist

**Permiso de cámara denegado (ambas plataformas):**
- Añade las entradas de permiso requeridas listadas en las secciones de configuración anteriores
- Solicita el permiso en tiempo de ejecución antes de mostrar la vista AR

## Contribuir

1. Haz un fork del repositorio
2. Crea una rama de características (`git checkout -b feature/mi-caracteristica`)
3. Confirma tus cambios
4. Envía y abre un Pull Request

## Licencia

MIT — consulta [LICENSE](LICENSE) para más detalles.

## Enlaces

- [Paquete en pub.dev](https://pub.dev/packages/augen)
- [Repositorio en GitHub](https://github.com/AminMemariani/augen)
- [Documentación completa](Documentation.md)
- [Rastreador de problemas](https://github.com/AminMemariani/augen/issues)

## Soporte

Si Augen ha ayudado a tu proyecto, puedes apoyar el desarrollo continuo con una propina en Solana:

[![Solana](https://img.shields.io/badge/Solana-Donate-9945FF?style=for-the-badge&logo=solana&logoColor=white)](https://solscan.io/account/ApeGNaqfRM3HJocYHfdZ88GmFj2wqVCxUzm5MGvGNrWy)

**Dirección de billetera Solana:**

```
ApeGNaqfRM3HJocYHfdZ88GmFj2wqVCxUzm5MGvGNrWy
```

Se agradecen SOL y tokens SPL (USDC, etc.) en la mainnet de Solana. ¡Gracias por tu apoyo! 🙏
