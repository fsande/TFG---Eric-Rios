# terrain_native GDExtension
## Summary
This file explains how to compile the project's GDExtension code, which provides
native C++ implementations of noise algorithms and chunk mesh generation exposed to Godot via GDExtension.

## Supported Platforms
Windows, Linux, and macOS. Each platform must be compiled on its target machine.

## Before Building
Initialize and update the submodule:
```
    git submodule update --init --recursive
```

Requires C++ build tools and [SCons](https://scons.org/):
```
    pip install scons
```

## Building
Run from inside `terrain_native/`. Output lands in `terrain_native/bin/`.

### Debug
Use during development.
```
    scons target=template_debug
```

### Release
Required to run the project outside the editor.
```
    scons target=template_release
```