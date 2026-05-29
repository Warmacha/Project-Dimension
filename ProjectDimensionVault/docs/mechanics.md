# Game Mechanics

## Core Systems

### Train Bell
Each world has a bell that fast-travels the player to that world. Interacting with it registers the world on the player's map. The "entrance" to the train can be anything: a door in a hallway, a hole in the ground, etc.

### Train Whistle
A usable item that immediately returns the player to the train from anywhere. No elaborate animation — a short whistle sound effect and an animated transition.

### Keypad
The keypad on the train is used to enter world codes and travel between dimensions.

**Standard keypad quirks:**
- Certain buttons are missing and must be found.
- Extra esoteric options exist behind secret codes or items (e.g., a key unlocking a second button set labeled with symbols rather than numbers).
- Blacklight-hidden ink on the keypad (possible).
- **The 9→6 flip puzzle:** A 9 is missing early on. The player discovers they can flip themselves (or the numpad) upside-down and press the 6 (which becomes a 9) to access a new world. A proper 9 can be recovered from that world so the trick doesn't need repeating.

**Hidden Keypad — Astrology Symbols (custom symbols):**
- 1 = Neptune, 2 = Uranus, 3 = Saturn, 4 = Jupiter, 5 = Mars
- 6 = Sun, 7 = Venus, 8 = Mercury, 9 = Moon, 0 = Earth
- Hidden keypad columns are out of order: 897 / 564 / 312 / 0

### World Map
A map on the train displays discovered worlds in a tower-like structure. As each world code is found, it fills in automatically. Selecting a point of interest sets the code in the keypad; pressing enter confirms travel.

The map functions as a usable item in-world too, showing world connections. Players can still use the keypad manually (required for secret/easter egg worlds not on the map).

---

## Player Movement

- **Run button** so the player always feels in control of their speed.
- Speed-up items: bicycle, skating shoes, skateboard (possible).

---

## No Game Over

No traditional Game Over. Instead, a **punishment mechanic** sends the player back to the train (or to Prison World). Prison World is traversable with the right Effects or problem-solving.

---

## Progression Flags

Flags prevent players from reaching the final world immediately at the start of a new game:
- Missing keypad numbers.
- Required key items (similar to Effects from Yume Nikki).
- Omniscient narration blocking certain paths.

---

## Items

### TICKET STUB
Required to board the train. Multiple ways to obtain in Platform World (see `worlds.md`).

**DAMAGED TICKET STUB** — obtained by walking into the Platform World water. Leads to an alternate train version.

### SOGGY BOOTS
Obtained via the **Water Walker** radiant event in Platform World. Allows walking on water surfaces. Footsteps become squeaky; water ripples underfoot. Required to reach the Wrecked Car.

### CONDENSATION CHARM
Found in a suitcase outside the Wrecked Car (requires interacting with DROWNED first).
- Adds a mist trail to the player.
- Reflective surfaces show alternate imagery: the old man, twisted player versions, monster NPCs.
- Near The Clerk's booth: fogs the glass and displays "1101" (backwards = **1011**, a valid hidden world code).
- Near The Orphan (stand still 15–20 sec): The Orphan nods at the player and walks into the water.

### Train Whistle
See Core Systems above.

### Fishing Rod
Cannot be used for actual fishing (no fishing license). Has alternate fish-related uses TBD.

### Miriam Effect
An Effect item. Entering a specific wall hole while equipped leads to a mouse smoking a Newport in Addiction World who says "Man, Addiction World is great!"

---

## Effects System
Similar to Yume Nikki's effects — equippable items that change the player's appearance and/or unlock interactions. Some are required for progression; others are purely cosmetic or lead to secrets.
