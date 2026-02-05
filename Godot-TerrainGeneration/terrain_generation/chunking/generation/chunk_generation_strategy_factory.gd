## @brief Factory for creating chunk generation strategies.
##
## @details Encapsulates strategy creation logic and provides a clean API
## for configuring terrain generation processing mode. Follows the Factory
## pattern for strategy instantiation.
@tool
class_name ChunkGenerationStrategyFactory extends RefCounted

enum StrategyType {
	CPU,
	GPU,
	HYBRID,
	AUTO
}

static func create(strategy_type: StrategyType = StrategyType.AUTO) -> ChunkGenerationStrategy:
	match strategy_type:
		StrategyType.CPU:
			return CpuChunkGenerationStrategy.new()
		StrategyType.GPU:
			return GpuChunkGenerationStrategy.new()
		StrategyType.HYBRID:
			return HybridChunkGenerationStrategy.new()
		StrategyType.AUTO:
			return _create_auto_strategy()
	return CpuChunkGenerationStrategy.new()

static func _create_auto_strategy() -> ChunkGenerationStrategy:
	var gpu_manager := GpuResourceManager.get_singleton()
	if gpu_manager and gpu_manager.is_gpu_available():
		var work_queue := GpuWorkQueue.get_singleton()
		if work_queue:
			return HybridChunkGenerationStrategy.new()
	return CpuChunkGenerationStrategy.new()

static func get_recommended_strategy_type() -> StrategyType:
	var gpu_manager := GpuResourceManager.get_singleton()
	if not gpu_manager or not gpu_manager.is_gpu_available():
		return StrategyType.CPU
	var work_queue := GpuWorkQueue.get_singleton()
	if not work_queue:
		return StrategyType.CPU
	return StrategyType.HYBRID

static func get_strategy_description(strategy_type: StrategyType) -> String:
	match strategy_type:
		StrategyType.CPU:
			return "CPU-only processing. Best for debugging or systems without GPU compute support."
		StrategyType.GPU:
			return "GPU-accelerated processing. Best for high-resolution chunks on capable hardware."
		StrategyType.HYBRID:
			return "Automatic CPU/GPU selection. Balances workload based on context and complexity."
		StrategyType.AUTO:
			return "Automatically selects the best available strategy based on hardware capabilities."
	return "Unknown strategy type"
