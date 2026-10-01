## ATMOS Vehicle Mocap Odom

A ROS 2 package that bridges motion capture (mocap) Odometry messages to PX4 `VehicleVisualOdometry` messages.

* Assumes the mocap system uses the **East-North-Up (ENU)** frame.
* PX4 expects data in the **North-East-Down (NED)** frame.

---

## Usage Examples

### On ATMOS Robots

To run with the default configuration (using the machine’s hostname as the namespace):

```bash
ros2 run vehicle_mocap_odom vehicle_mocap_odom_node
```

This will subscribe to:

```
/<hostname>/odom
```

And publish to:

```
/<hostname>/fmu/in/vehicle_visual_odometry
```

### Specifying a Namespace

When running in simulation (e.g. SITL), you can explicitly set the namespace:

```bash
ros2 run vehicle_mocap_odom vehicle_mocap_odom_node --ros-args -p namespace:=your_namespace
```

This will subscribe to:

```
/your_namespace/odom
```

And publish to:

```
/your_namespace/fmu/in/vehicle_visual_odometry
```
