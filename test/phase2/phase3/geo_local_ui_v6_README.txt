Geo Local UI v6
================

Adds projector groups and scene assignment profiles on top of the working v5 controller.

Files:
- geo_local_ui_v6.lua        main controller/scanner UI
- geo_projector_node_v1.lua  remote projector node (unchanged from v1)

New persistent files created by the controller:
- /home/geo_projector_groups.cfg
- /home/geo_scene_profiles.cfg

New top-level keys:
- G  Manage projector groups
- J  Manage scene assignment profiles
- K  Apply one scene assignment profile
- Y  Apply all enabled profiles

Projector groups:
- A projector group is a named list of discovered projector addresses.
- Use G to create, edit, rename, inspect, or delete groups.
- Groups use your saved projector aliases, so discover/rename projectors first if needed.

Scene assignment profiles:
- A profile connects a scene source to a target destination.
- Scene source can be:
  1) active scene
  2) one loaded in-memory scene
  3) one snapshot file from disk
- Target can be:
  1) one projector
  2) one projector group
  3) all known projectors
- Profiles can be enabled or disabled.
- Use J to create/edit/delete/info/apply.
- Use Y to apply every enabled profile in order.

Recommended workflow:
1) Discover projectors with D.
2) Rename any projector aliases with M.
3) Create projector groups with G.
4) Scan or load scenes.
5) Create scene assignment profiles with J.
6) Apply one with K or all enabled with Y.

Notes:
- Profiles that point at a loaded in-memory scene require that scene to be loaded right now.
- Profiles that point at a snapshot file can survive restarts, because the scene is loaded from disk when applied.
- This is still a single-controller design. The remote projector node remains a simple display endpoint.
