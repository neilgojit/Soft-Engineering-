# Spot & Breathe — Godot 4 Project

## Requirements
Godot 4.2+  (GL Compatibility renderer)

## How to open
1. Extract the zip to a folder
2. Godot 4 → Import → SpotAndBreathe folder → project.godot
3. F5 to run

## How to play

### Breathing minigame (unlocks each scene)
- A cursor sweeps back and forth across a bar
- A GREEN zone sits in the middle of the bar
- Hold SPACE  (or hold left-click)  when the cursor is inside the green zone
- Hold it for at least 1.2 seconds to count as a successful breath
- Complete 3 successful breaths to unlock the scene
- Releasing outside the zone OR not holding long enough = lose 1 heart

### Explore phase
- 10 items are placed in the scene; 5 of them are the hidden targets
- Click/tap items to find them
- Correct item  → +30 score, ripple effect
- Wrong item    → lose 1 heart, red flash
- Find all 5 to complete the scene

### Hearts
- You start with 3 hearts  ♥♥♥
- Lose all 3 → Game Over
- Hearts carry across scenes

### Scenes
1. Cosy Café
2. Quiet Forest
3. Old Library

### Scoring
- Each successful breath: +15
- Each correct item found: +30
- Scene complete bonus: +200

## Project structure
    SpotAndBreathe/
    ├── project.godot
    ├── Main.tscn        (4-line scene, Node2D + script)
    ├── Main.gd          (entire game logic + draw)
    ├── icon.svg
    └── assets/
        ├── item_cup.svg
        ├── item_book.svg
        ├── item_candle.svg
        ├── item_plant.svg
        ├── item_glasses.svg
        ├── item_feather.svg
        ├── item_mushroom.svg
        ├── item_lantern.svg
        ├── item_butterfly.svg
        ├── item_watch.svg
        ├── item_teapot.svg
        ├── item_acorn.svg
        └── item_inkwell.svg
