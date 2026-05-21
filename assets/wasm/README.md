# ARToolKit Wasm

This directory is reserved for the ARToolKit5 WebAssembly binary.

## How to obtain

1. Clone [artoolkitX/jsartoolkit5](https://github.com/nicolo-ribaudo/jsartoolkit5)
2. Build the Wasm target following the repository instructions
3. Place the resulting `artoolkit.wasm` file in this directory

The current Augen web implementation uses a pure-JS fallback marker detector.
When the Wasm binary is available, the bridge will automatically use it for
higher-performance detection.
