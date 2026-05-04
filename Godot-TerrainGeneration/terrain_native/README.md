# terrain_native GDExtension

## Building

Needs c++ build tools and SCons installed. Install SCons with pip:

```
pip install scons
```

From inside `terrain_native/`:

### Debug (use during development)
```
scons target=template_debug
```

### Release
```
scons target=template_release
```

### All platforms from the same machine (cross-compile not supported)

Output lands in `terrain_native/bin/`.
