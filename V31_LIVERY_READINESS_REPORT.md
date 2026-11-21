# V31 livery readiness report

## Result

No livery texture was applied in V31. The request still contains placeholders for the aircraft path and every texture ID, so applying anything would require inventing IDs or guessing which aircraft should receive the artwork. No live aircraft instance was modified and no backup was needed because validation stops before mutation.

`AircraftLiveryConfig.lua` is now included as an inactive, data-driven livery system. It requires all safety checks to pass before it creates the mandatory non-running `ServerStorage/AroundTheWorldAircraftBackups/<aircraft>_BeforeLivery_<name>_<timestamp>` copy.

## Current inspection findings

- The standard Around the World aircraft are generated from Roblox Parts rather than imported, UV-unwrapped exterior MeshParts.
- The project contains no approved livery entry and no uploaded ColorMap ID.
- Unique left/right fuselage UV space has not been verified. Branding could therefore be mirrored on an unknown replacement mesh.
- Runtime inspection is available through `AircraftLiveryConfig.Inspect(model)` and reports every MeshPart, TextureID, SurfaceAppearance, material class, and UV-verification attribute.
- The existing `AircraftMaterialConfig` continues to preserve every current TextureID and PBR map assignment.

## Required inputs before application

1. Exact generated aircraft code or imported model path, such as `B763` or a complete Explorer path.
2. A valid owner-uploaded `ColorMap` ID in `rbxassetid://123...` form.
3. Optional owner-uploaded NormalMap, RoughnessMap, MetalnessMap, and EmissiveMap IDs, or `NONE` for each omitted map.
4. The exact intended exterior MeshPart names.
5. Confirmation from the Blender UV layout that the left and right branded areas use unique, non-mirrored UV space.

## Safeguards in `AircraftLiveryConfig`

- Rejects missing, bracketed, or malformed asset IDs.
- Rejects the wrong aircraft code.
- Rejects unverified left/right UV layouts.
- Targets MeshParts only by explicit names or approved material classes.
- Excludes `Controls`, `Collision`, `Effects`, and `Interior` containers.
- Reuses an existing SurfaceAppearance when present and creates at most one managed instance per intended mesh.
- Preserves the prior maps in the returned change report and in the ServerStorage backup.
- Supports per-mesh overrides for fuselage sections, engines, wings, and winglets.
- Stores an optional EmissiveMap as `PBREmissiveMap` because SurfaceAppearance has no native emissive-map property.
- Supports a dry run that reports eligible meshes without creating a backup or changing anything.

## Missing map guidance

- **ColorMap:** livery paint, logos, registrations, doors, windows, and markings without baked reflections.
- **NormalMap:** restrained panel seams, fasteners, and exterior relief.
- **RoughnessMap:** glossy paint/windows separated from rough tires and moderately rough wing surfaces.
- **MetalnessMap:** white only for genuinely exposed metal; painted aircraft skin stays nonmetallic.
- **EmissiveMap:** only pixels that should glow, normally instrument or sign lighting rather than the exterior paint.

## Changed live instances

None. The livery application correctly stopped before backup or editing.
