# Data analysis

Generates interactive HTML plots from benchmarking data for the terrain generation system.

## Dependencies
* Python 3.13+
* Packages listed in requirements.txt

## Installation and use

Run all commands from the DataAnalysis directory.

1. Create a virtual environment
```
python -m venv .venv
```

2. Install requirements

```
pip install -r requirements.txt
```

3. Run the tool

```
python -m benchmark_visualizer [path_to_json_1] [path_to_json_2] ... [path_to_json_n]
```

e.g.
```
python -m benchmark_visualizer data/cpu_chunk_256_desktop.json data/cpu_chunk_256_mac.json
```

Output: DataAnalysis/benchmark_report.html

Note: only JSON benchmark exports are supported. CSV output from the benchmarking system cannot be used here. 