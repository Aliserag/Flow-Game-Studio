extends Node
## Autoload that holds the active CampaignController instance for the current run.
## All UI scenes access the controller via CampaignHolder.controller.
## Usage: CampaignHolder.controller.hire(orc)

var controller: CampaignController = null
var last_battle_result: Dictionary = {}


func create_controller() -> CampaignController:
	## Instantiate a fresh CampaignController wired to the project autoloads.
	controller = CampaignController.new(ItemRegistry, Rng, RunState)
	last_battle_result = {}
	return controller


func clear() -> void:
	## Call when returning to main menu to release the old run.
	controller = null
	last_battle_result = {}
