class_name Chronicle
extends RefCounted
## Facts worth retelling, recorded as the campaign goes. Feeds the end-of-campaign recap.

## One entry per character death: {"name": String, "night": int, "killer": String}.
## An empty killer means poison.
var deaths: Array[Dictionary] = []
var encounters := 0
var flees := 0
var timeouts := 0
var fudges := 0
var narrations := 0
var monologues := 0
var skipped := 0
## Player name -> encounters started on the phone.
var phone_encounters: Dictionary[String, int] = {}
## Player name -> items received.
var loot_received: Dictionary[String, int] = {}


func count(tally: Dictionary[String, int], player_name: String) -> void:
	tally[player_name] = tally.get(player_name, 0) + 1


## Name with the highest count, or "" when the tally is empty. First one wins ties.
func top(tally: Dictionary[String, int]) -> String:
	var best := ""
	for player_name in tally:
		if best == "" or tally[player_name] > tally[best]:
			best = player_name
	return best
