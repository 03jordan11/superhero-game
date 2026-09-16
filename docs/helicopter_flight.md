# Helicopter city patrol

One rescue-red helicopter now circles central SuperCity automatically. The patrol
is a child of SuperCity, so it appears both in normal Play and when running the
city scene directly. No encounter, combat or player-control behavior was added.

## Test and tune

Restart Play. The helicopter starts south of the player spawn at approximately
**(0, 280, 400)**, initially heading west. Fly up toward 280 m to inspect it close
up, or watch from the taller rooftops. A lap takes **90.9 seconds**.

During play select **Remote > Main > SuperCity > HelicopterPatrol**:

| Control | Default | Purpose |
| --- | ---: | --- |
| Patrol Enabled | On | Hide/stop the single patrol without removing its scene |
| Orbit Radius | 550 m | Size of the circle |
| Altitude | 280 m | Height above the patrol node's origin |
| Cruise Speed | 38 m/s (137 km/h, about 74 knots) | Requested forward speed |
| Clockwise | On | Turn direction |
| Livery | Rescue red | Uses the four existing helicopter materials |
| Path Correction | 0.5 | Strength of gradual return toward the route |

Move the patrol node to relocate the orbit center (default **0, 0, -150**).
Starting Angle applies on startup. Runtime radius/altitude changes steer toward
the new route without teleporting. Tighter circles automatically reduce requested
speed to respect the configured acceleration and bank limits. Changing direction
is a new flight command, not an instant reversal.

On its **Aircraft** child, tune maximum acceleration, climb speed, heading rate,
attitude response, maximum bank and pitch, and cruise pitch drag. On
**Aircraft > Helicopter**, the existing main/tail RPM settings remain available.
Inspector changes during play are temporary; edit scene/script defaults to persist them.

Check that the nose follows the path, the cabin banks toward the circle's center,
the skids stay at a slight nose-down attitude, altitude stays steady and rotors
continue spinning. Pause the game and confirm both translation and rotors pause.

## Research and implementation

The [FAA Helicopter Flying Handbook, Chapter 9: Basic Flight Maneuvers](https://www.faa.gov/sites/faa.gov/files/regulations_policies/handbooks_manuals/aviation/helicopter_flying_handbook/hfh_ch09.pdf)
describes coordinated forward-flight turns: bank supplies the horizontal component
of lift, heading follows the curved path, and power must support altitude in a turn.
Its [flight-controls chapter](https://www.faa.gov/sites/faa.gov/files/regulations_policies/handbooks_manuals/aviation/helicopter_flying_handbook/hfh_ch03.pdf)
describes cyclic control of rotor-disc tilt and governed rotor RPM. These inform
the visual cues here; settings are game tuning, not a type-certified aircraft model.

- The guidance node computes circular position, tangential velocity and inward
  acceleration (`v²/r`). Position error adds a gentle correction to the velocity command.
- The reusable flight node limits acceleration and climb response, then integrates
  velocity. Heading follows horizontal velocity with a limited yaw rate.
- Bank comes from lateral acceleration: `atan(a_lateral / 9.81)`. The default orbit
  produces about **15 degrees inward bank**. Pitch uses forward acceleration plus
  an approximate speed-dependent drag term, giving about **4 degrees nose down**.
- Attitude and acceleration changes are smoothed. There is no random wobble or
  artificial repeated altitude bobbing. The default steady orbit starts established
  in forward flight rather than accelerating from a parked pose overhead.
- Rotor RPM stays at the authored settings, independent of travel speed. Movement
  and rotor processing inherit normal game pause behavior.

This is a lightweight kinematic visual controller. It does not simulate individual
rotor blades, aerodynamic stalls, engine torque, wind, collision response or
obstacle avoidance. The parked collider is disabled while flying. The default route
was checked against the current city; lowering it or moving it into buildings needs
another clearance check. Navigation lights and helicopter audio remain future work.

## Reusing it in encounters

Instance `assets/aircraft/helicopter/helicopter_flying.tscn` and drive
`set_flight_command(world_velocity, feed_forward_acceleration)` from encounter
guidance. A zero velocity command brakes toward hover. `initialize_flight()` is
only for initial placement; it sets position and initial flight state immediately.
The orbit logic is entirely in `helicopter_patrol.gd`, so an encounter can replace
the route without replacing the helicopter or flight-response code.

## Verification and files

`tests/test_helicopter_flight.gd` passed more than three laps in each direction at
30, 60 and 120 Hz. Maximum radial drift was 0.043 m; bank was approximately 14.98°.
Checks include heading alignment, altitude, direction of bank, pitch, route changes,
speed reduction on tight turns, acceleration limits, braking to hover, disabling
the patrol and exactly one city instance. The route has **87.38 m** clearance above
the highest nearby placed geometry, using a 10 m horizontal aircraft allowance.
Terrain was checked per triangle to exclude distant mountains from its large bounds.

The actual city and aircraft were run through Godot's renderer with active flight
physics. Follow-camera and banked-turn images were inspected under
`artifacts/helicopter_flight/`. Player-controlled pursuit still needs your playtest.
Existing sandbox certificate/settings and road-resource UID warnings remain.

Changed/added files:

- `scenes/super_city.tscn`: one reusable patrol instance; existing node order retained.
- `assets/aircraft/helicopter/helicopter_flight.gd` and `helicopter_flying.tscn`.
- `assets/aircraft/helicopter/helicopter_patrol.gd` and `helicopter_patrol.tscn`.
- `tests/test_helicopter_flight.gd`, `tests/render_helicopter_flight.gd`, this guide,
  and the helicopter README link.

The existing helicopter mesh, liveries and static preview are unchanged.
