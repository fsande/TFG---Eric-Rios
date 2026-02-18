## River agent responsible for carving riverbeds and placing water tiles. 
## It may also handle other river-related features in the future, such as river vegetation.
## Carving part will be based on Doran and Parberry's https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=5454273
## Their pseudo-code:
## RIVER-GENERATE ()
##  #1 coast random point on coastline
##  #2 mountain random point at the base of a mountain
##  #3 point coast
##  #4 while point not at mountain
##  #5 do
##  #6 add point to path
##  #7 point next point closer to mountain
##  #8 while point not at coast
##  #9 do
##  #10 flatten wedge perpendicular to downhill direction
##  #11 smooth area around point
##  #12 point next point in path

@tool
class_name RiverAgent extends TerrainModifierAgent

func _init() -> void:
	agent_name = "River"
	tokens = 25

func get_modifier_type() -> ModifierType:
	return ModifierType.COMPOSITE   # Will carve riverbed and place water. 
									# Might also extend to other river-related features in the future.

func get_agent_type() -> String:
	return "River"
