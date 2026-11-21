# Around the World V31

## Smooth landing-gear deployment

- Removed the server/client Motor6D ownership conflict that could overwrite the client-smoothed landing gear every Heartbeat.
- The server remains authoritative for gear state, timing, landing checks, physics, and engine audio; clients now have sole ownership of cosmetic gear poses at render cadence.
- Restored the ordered door-open, gear-travel, door-close sequence for extension and retraction.
- Added frame-rate-independent quintic easing to the gear travel, reducing sudden starts, drops, and downlock/uplock snaps.
- Preserved existing gear timing, wheel spin, nose steering, compression, control inputs, mass, collision, lift, drag, and ground handling.

## Varied terminals

- Added airport-specific terminal styles while retaining the shared gate-facing concourse, apron seal, and jetbridge locations.
- Sunport and Skyline use dual-pier rooflines; Ember uses a stepped terminal; Green Grass uses a T-pier; Coral Bay uses a crescent form; Northpoint and Island Hop use rotundas; Alpine uses a ridge roof; Spark and Skyline Regional use compact halls.
- All silhouette additions remain above the existing terminal foundation and clear of apron pavement and the landside access road.

## Livery system

- Added `AircraftLiveryConfig.lua` with explicit target meshes, material-class filtering, per-mesh map overrides, dry-run inspection, safe SurfaceAppearance reuse, server-only backup creation, and complete change reports.
- No livery was applied because the supplied model path and asset IDs are placeholders and the left/right UV layout is unverified.
- See `V31_LIVERY_READINESS_REPORT.md` for the exact required inputs.

## Bogie tilt verification

- Completed the required non-destructive hierarchy and state audit.
- No aircraft-specific tilt was implemented because the exact aircraft and variant were not supplied.
- See `V31_BOGIE_TILT_VERIFICATION.md` for the inspected hierarchy, proposed state machine, and one required approval question.

## Test checklist

1. Spawn a plane, take off, press `G`, and confirm the doors open before the gear begins retracting.
2. Confirm gear travel accelerates and settles smoothly, then the doors close.
3. Press `G` again in flight and confirm the reverse sequence completes without popping or fighting another animation.
4. Watch a second player's aircraft and confirm the same smooth visual motion is visible.
5. Visit several airports and compare terminal silhouettes from the air while confirming gates and jet bridges remain aligned.
6. Confirm takeoff, landing, braking, steering, wheel contact, and aircraft handling are unchanged.
