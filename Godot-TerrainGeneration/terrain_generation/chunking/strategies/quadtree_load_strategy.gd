## @brief Hierarchical quadtree-based chunk loading strategy.
##
## @details Loads chunks in a hierarchical pattern, prioritizing
## closer chunks and enabling progressive detail refinement.
## Supports parent-child relationships for efficient culling.
class_name QuadTreeLoadStrategy extends ChunkLoadStrategy