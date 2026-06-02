# Modular Procedural Terrain Generation for Games

Final Degree Project on Procedural Terrain Generation for Games.

## Description

This project provides a customizable, user-friendly and extensible Procedural Terrain Generation System for the Godot 4 Engine.
It has been made as a Final Degree Project (TFG) for the Grado en Ingeniería Informática at Universidad de La Laguna.

## Getting Started

### Dependencies

* [Godot 4.6](https://godotengine.org/) and its requirements (See [Godot Engine Requirements](https://docs.godotengine.org/en/stable/about/system_requirements.html))
The .NET version is not needed, prefer the basic one.
* A C++ compiler (e.g. [gcc](https://gcc.gnu.org/))
* [SCons](https://scons.org/) and its requirements to compile GDExtension code. More information [here](Godot-TerrainGeneration/terrain_native/README.md).

### Usage

1. Download [Godot 4.6](https://godotengine.org/). 

2. Clone the repository.

    ```
    git clone https://github.com/fsande/TFG---Eric-Rios.git
    ```

3. Run the Godot executable and import the project from its location at the Godot-TerrainGeneration directory of this repository.

4. Compile the GDExtension code by following [the instructions](Godot-TerrainGeneration/terrain_native/README.md).

6. With the project open, open the TerrainDemo (Godot-TerrainGeneration/scenes/terrain_demo.tscn) scene, which contains an example setup. The system supports larger and more complex configurations.

7. To modify terrain generation, select the TerrainPresenter node in the scene tree and change the configuration. 
You can load predefined generation configurations with right-click -> Quick Load  or create your own.
Explore the various options. 
Note that very large heightmaps, many agents or an dense prop placements might negatively impact performance.

## Features

* **Heightmap generation pipeline**: compose multiple sources (noise, image, texture) using
  the Strategy and Decorator patterns. Stack processors such as gaussian blur, contrast  normalization, mask application, thermal erosion, and the Rune erosion filter to shape the base terrain.
* **Agent-based terrain modification**: layer sequential or conditional agent stages to  introduce specific geographic features: mountain ridges, rivers with flowing water meshes, tunnels carved via constructive solid geometry, and terrain overhangs.
* **GPU-accelerated generation**: compute shader implementations for image-processing operations achieve up to ~15× speedup over CPU for large heightmaps. 
Chunk mesh generation runs on a native C++ GDExtension (~35× faster than GDScript sequentially, ~82× in parallel).
* **Chunked LOD system**: discrete level-of-detail via chunking with asynchronous on-demand generation, LRU chunk caching, frame-budget-limited instantiation, and configurable load strategies (grid, view frustum, or combined).
* **Feature and prop placement**: rule-based prop spawning with constraints for height range, slope, spacing, sea level, volume exclusion, and agent-defined zones. 
MultiMesh support and LOD-aware density scaling for performance-friendly dense scenes.
* **Designer-friendly configuration**: all parameters exposed through Godot's native Resource system. Save, load, and share generation profiles without writing code. Full real-time preview in the editor via the `@tool` annotation.
* **Benchmarking framework**: measure per-stage execution time and cache metrics across configurations. 
Results exportable as CSV or JSON, with interactive HTML visualizations via Plotly (see [DataAnalysis](DataAnalysis/README.md)).

For a full description of the system's architecture, implementation, and evaluation results,
see the [project memoria](Memoria/Memoria_TFG_Eric_Ríos.pdf).

## Help

* If the engine briefly freezes during generation each time you change a setting, it might be because your configuration is expensive.
This might happen if you use CPU heightmap generation, I recommend using GPU, as it is much faster.
However, this is less critical during gameplay than it may seem during editing.
If it is bothering you while editing, just disable the Auto Generate checkbox under Settings in the TerrainConfiguration.

* The editor may sometimes crash if your configuration is too expensive. 
Relaunch the editor and try to reduce the requirements. 
If the problem persists, open an issue or directly contact the author.

## Authors

[Eric Ríos Hamilton](https://github.com/EricRios-commits)

## License
This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
This license applies to the project as an academic work. The code is available for non-commercial use and adaptation with attribution.