# Capatin Shuffle

## Overview
This Mod uses similar logic to the vanilla crew table, but for the purpose of identifying crew with reasonable captain skills and allows you to auto assign anyone more skilled from this pool to your fleet. 

Adds a new Dialogue to fleet commanders that will optimise a fleet with 'avalable' captains (service, marine and unassigned) that are more skilled than the current fleet pilots.

## Credits
SirNukes and the community that have maintained UI loading features - While this mod doesn't require the mod support APIs module, the underlying logic was key in figuring out how to load UI scripts. 
Egosoft - without the existing UI examples I would not have managed to figure this all out.

## Current status
First release (0.2)

## Known issues
* A ship that is full with unassigned crew may fail to correctly assign a captain as expected. As this is not a breaking issue I'm hoping to resolve this in a later release.
* Translations from english are machine driven and probably not great. 

## Mod Overview

### Usage
1. Talk to your fleet captain.
2. Select the crew assignment menu item.
3. The mod will loop through all your employees, and out of the pool of marines and service crews, if anyone is a better captain than those in your fleet's top level of subordinates, they will be transferred as captain. 
4. A summary of changes will be displayed in the general log. 

### Performance
Minimal while not actively shuffling captains. The mod adds an MD listener to fleet captains for the dialog.
When shuffling the impact is relative to your number of employees. If you have a lot, expect a small framerate stutter while the shuffle occurs.

### Compatibility
The mod adds a top-left dialog option to the default fleet captain chat menu and may clash with any other mod doing the same.
Apart from that this should not impact other mods/logic. The Shuffle code itself draws from standard UI functionality and should not cause any impact to other mods.