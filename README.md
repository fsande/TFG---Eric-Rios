# Modular Procedural Terrain Generation for Games

Final Degree Project on Procedural Terrain Generation for Games.

## Description

This project seeks to provide a customizable, user-friendly and extensible Procedural Terrain Generation System for the Godot Engine. 
It has been made as a Final Degree Project (TFG) for the Grado en Ingeniería Informática at Universidad de La Laguna.

## Getting Started

### Dependencies

* [Godot](https://godotengine.org/) and its requirements (See [Godot Engine Requirements](https://docs.godotengine.org/en/stable/about/system_requirements.html))
* A C++ compiler (e.g. [gcc](https://gcc.gnu.org/))
* [SCons](https://scons.org/) and its requirements to compile GDExtension code. More information [here](Godot-TerrainGeneration\terrain_native\README.md).

### Usage

1. Download [Godot](https://godotengine.org/).

2. Clone the repository.

    ```
    git  clone git@github.com:fsande/TFG---Eric-Rios.git
    ```

3. Run the Godot executable and import the project from its location.

4. Compile the GDExtension code by following [the instructions](Godot-TerrainGeneration\terrain_native\README.md).

5. Open the project. 
Open the TerrainDemo (Godot-TerrainGeneration\scenes\terrain_demo.tscn) scene, which contains an example setup for the system.
The system supports considerably larger and more complex configurations. 
This one aims to serve as a simple introduction.

6. To modify terrain generation, select the TerrainPresenter node in the scene tree and change the configuration. 
You can load predefined generation configurations with right click -> quick load or create your own.
Explore the various options. 
Keep in mind that extremely large heightmaps, too many agents or an excessive density of props might impact performance.

## Help

* If the engine briefly freezes during generation each time you change a setting, it might be because your configuration is expensive.
This might happen if you use CPU heightmap generation, I recommend using GPU, as it is much faster.
However, don't worry too much, the base generation time is not as important for gameplay. 
If it is bothering you while editing, just disable the Auto Generate checkbox under Settings in the TerrainConfiguration.

* The editor may sometimes crash if your configuration is too expensive. 
Just relaunch and try to reduce the requirements. 
If the problem persists, open an issue or directly contact the author.

## Authors

[Eric Ríos Hamilton](https://github.com/EricRios-commits)

## License

This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
