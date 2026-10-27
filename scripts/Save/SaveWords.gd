extends RefCounted
## Every word the player reads about saving: the HUD's notes, the Load and
## Save pages, the death page. All are stand-ins for the user to write; each
## says above it what it must say.

# The HUD's notes

## A save was written.
const SAVED := "Saved."
## A save was asked for while saving must wait (a talk, the loading cover):
## it will happen when that ends.
const HELD := "Saving when this ends."
## Quickload with no quicksave in this run.
const NOTHING_TO_LOAD := "No quicksave yet."
## A save could not be written (the disk refused it); the old one is safe.
const FAILED := "The save could not be written."
## A save could not be read (damaged, or from a newer build).
const UNREADABLE := "This save cannot be read."

# The main menu

## Continue with no save at all.
const NO_SAVE := "No saved game yet. Choose New Game to begin."
## Continue or Load could not open the save's game.
const LOAD_FAILED := "That save could not be opened."

# The Load and Save pages

## The row that makes a new save on the Save page.
const NEW_SAVE := "New save"
## Asked before a save is overwritten, and before one is deleted.
const OVERWRITE := "Save over this?"
const DELETE_SAVE := "Delete this save?"
const DELETE_RUN := "Delete this game and all its saves?"
## The kinds of save, as a save's row names them.
const KINDS := {&"quick": "Quicksave", &"auto": "Autosave", &"named": "Save"}
## The archetypes, as a run's row names them.
const ARCHETYPES := {&"derive": "Derivé", &"thaumaturge": "Thaumaturge", &"factotum": "Factotum", &"": "Unchosen"}
## The places a save can be made in, by map.
const PLACES := {"res://maps/metro.tscn": "The Metro", "res://maps/zocalo.tscn": "The Zócalo"}
## A place with no name of its own yet.
const SOMEWHERE := "Somewhere in the city"

# The death page

const LOAD_LATEST := "Load latest"
const LOAD := "Load"
const MAIN_MENU := "Main menu"
