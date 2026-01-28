## @brief Simple radius-based chunk loading strategy.
##
## @details Loads all chunks within a fixed radius from the camera,
## unloads chunks beyond a larger radius. Simple and predictable behavior.
class_name GridLoadStrategy extends ChunkLoadStrategy
