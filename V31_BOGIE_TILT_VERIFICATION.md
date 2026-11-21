# V31 aircraft bogie-tilt verification gate

## Audit result — implementation not approved yet

The target path and exact aircraft variant are still placeholders. Around the World currently offers 20 different aircraft, with single-axle, two-axle, three-axle, wing-gear, and body-gear layouts. Their airborne truck angle, direction, pivot, and retraction orientation are not interchangeable. No new aircraft-specific bogie tilt was implemented or guessed in V31.

The V31 deployment-animation repair is separate: it restores smooth extension/retraction of the existing gear and doors without claiming an aircraft-specific truck angle.

## Existing hierarchy audit

Generated aircraft use this live structure after organization:

```text
Aircraft Model
├── Root
└── Controls
    └── LandingGear
        ├── MainStrut-1 / MainStrut1
        ├── MainTruckBeam-1 / MainTruckBeam1
        ├── MainWheel...
        ├── optional BodyGearStrut...
        ├── optional BodyGearTruck...
        └── Gear doors and nose gear
```

- Struts, truck beams, wheels, hubs, brakes, and doors are separate procedural Parts; the generated bogie and strut are not one combined MeshPart.
- Every moving visual currently has a Root-connected `VisualMotor` Motor6D and cached local poses.
- Truck parts share `GearTruckId`, `TruckPivotBaseCF`, `TruckPivotRetractedCF`, `TruckMaxTiltDegrees`, and `TruckTiltDirection` attributes.
- Wheels retain independent visual spin while their shared truck transform is calculated around one pivot.
- Existing state already exposes `Gear`, `GearProgress`, `GearMoving`, `OnGround`, `LandingPhase`, `TouchdownLoad`, and `TruckTiltProgress`.
- Detailed gear visuals are massless and non-collidable; flight and ground handling remain server-authoritative.

The current generic 7–11 degree visual tilt is selected mainly from axle count. That is not enough evidence to call the angle or direction accurate for a named real-world variant, so V31 does not expand or certify it.

## Aircraft groups requiring different decisions

- Single-axle main gear (no bogie tilt should be added): A223, A19N, A20N, A21N, B38M, B39M, E290, E295, CRJ9.
- Multi-axle main gear requiring variant-specific verification: A339, A359, A35K, B752, B763, B77W, B779, B788, B789.
- Aircraft with additional body gear requiring separate wing/body truck verification: A388 and B748.

This grouping confirms only which generated layouts have a truck; it does not verify a real aircraft's tilt angle or airborne direction.

## Proposed implementation after verification and approval

1. Confirm the exact aircraft and production/gear variant from reliable side-view references in airborne, touchdown, ground, and retraction states.
2. Confirm that an imported replacement mesh keeps the strut and truck separate. If combined, stop for a Blender separation instead of rotating the whole strut.
3. Create the required non-running ServerStorage backup.
4. Add a dedicated strut-to-truck Motor6D (or bone for a skinned imported mesh) at the verified central pivot. Preserve its original C0/C1.
5. Bind the lower truck, wheels, hubs, brakes, and lower details to that pivot while keeping wheel spin independent.
6. Drive the eight requested visual states from the existing authoritative attributes. Use filtered front/rear wheel-group raycasts only if the target has no usable weight-on-wheels state.
7. Use delta-time exponential damping, cached objects, local left/right axes, and cleaned connections.
8. Validate extension, airborne angle, first-axle contact, full weight-on-wheels, taxi, liftoff, and retraction without changing collision or flight physics.

## Configuration awaiting verified values

```lua
{
    LeftAirborneTiltDegrees = "UNVERIFIED",
    RightAirborneTiltDegrees = "UNVERIFIED",
    GroundTiltDegrees = "UNVERIFIED",
    RetractionTiltDegrees = "UNVERIFIED",
    TiltResponseSpeed = "UNVERIFIED",
    TouchdownResponseSpeed = "UNVERIFIED",
    LeftTiltAxis = "UNVERIFIED_LOCAL_AXIS",
    RightTiltAxis = "UNVERIFIED_LOCAL_AXIS",
}
```

## Approval question

Which aircraft code and exact variant should be verified first, and can you provide side-view references of its main gear airborne and on the ground?
