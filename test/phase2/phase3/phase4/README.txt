
Geo V7 package
==============

Files
-----
geo_console_v7.lua
geo_scanner_node_v7.lua
geo_projector_node_v2.lua

What V7 does
------------
- One console computer controls the system.
- Geo scanner nodes can manage multiple attached geolyzers.
- Projector nodes can manage multiple attached holograms.
- Scenes store placements that reference named scan slots instead of copying layout rules.
- "Get Live Snapshot" refreshes current scan-slot data on the console without changing scene layout rules.
- Loading a scene reuses the current cached snapshots.

Recommended setup order
-----------------------
1. On each geo scanner computer:
   lua /home/geo_scanner_node_v7.lua setup

2. On each projector computer:
   lua /home/geo_projector_node_v2.lua setup

3. On the console computer:
   lua /home/geo_console_v7.lua

Suggested workflow
------------------
Scanner node:
- Set nodeId/group name.
- Name each attached geolyzer.
- Create scan slots like VillageScan_1, VillageScan_2, etc.
- Use "Test capture one slot" to verify each slot.

Projector node:
- Set nodeId/group name.
- Name each attached projector.
- Set per-projector colors/scale if wanted.

Console:
- System -> Discover nodes
- Geo Nodes -> pick a node -> Get Live Snapshot
- Scenes -> Create scene
- Add placements mapping scan slots to projector aliases
- Scenes -> Load scene

Scene placement notes
---------------------
- Rotation supports 0, 90, 180, 270.
- Center=true centers the scan on the projector, then applies offsets.
- Center=false uses offsetX/offsetY/offsetZ as direct start coordinates.

Important current limits
------------------------
- A scene placement targets a specific projector alias, not a projector subgroup yet.
- Scene editing is text-menu based and intentionally paged to avoid running off screen.
- The console caches snapshots after "Get Live Snapshot". Loading a scene uses the cache. If a referenced slot is missing, the console will try to fetch it.
- This build focuses on the architecture you asked for. It is not the final polished UI.

Suggested next step after V7
----------------------------
- add projector sub-groups inside a projector node
- add node-side per-group defaults
- add a more visual scene editor / quick nudge mode
