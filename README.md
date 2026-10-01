# Project Astro

ROS 2 packages for ATMOS/PX4 offboard control, MPC, simulation, visualization,
and motion-capture odometry.

## Prerequisites

The commands below target Ubuntu 22.04 with ROS 2 Humble. ROS, Gazebo, PX4,
acados, and Micro XRCE-DDS are external dependencies. They are installed on
the computer running the project and are not copied into this repository.

### Install ROS 2 and build tools

Follow the official ROS 2 Humble installation instructions if ROS is not
already installed. Then install the workspace tools and Python dependencies:

```bash
sudo apt update
sudo apt install -y \
	ros-humble-desktop \
	python3-colcon-common-extensions \
	python3-rosdep \
	python3-vcstool \
	python3-pip \
	python3-pyquaternion

source /opt/ros/humble/setup.bash
sudo rosdep init 2>/dev/null || true
rosdep update
```

### Install PX4 and Gazebo

PX4 provides the SITL simulator and the Gazebo vehicle models. Clone the PX4
version or ATMOS-compatible fork required by your simulation:

```bash
cd ~
git clone --recursive https://github.com/PX4/PX4-Autopilot.git
cd PX4-Autopilot
bash Tools/setup/ubuntu.sh
```

Log out and back in if the PX4 setup script requests it. Build a standard
quadrotor simulation with:

```bash
cd ~/PX4-Autopilot
make px4_sitl gz_x500
```

The spacecraft simulation command `gz_atmos` requires the PX4/ATMOS source
tree that contains that model. The standard PX4 repository may not contain it.
Use the ATMOS guide or the project-specific PX4 fork when running:

```bash
make px4_sitl_spacecraft gz_atmos
```

### Install Micro XRCE-DDS Agent

The agent bridges PX4's uXRCE-DDS client to ROS 2:

```bash
cd ~
git clone https://github.com/eProsima/Micro-XRCE-DDS-Agent.git
cd Micro-XRCE-DDS-Agent
git checkout master
mkdir -p build && cd build
cmake ..
make -j"$(nproc)"
sudo make install
sudo ldconfig
```

Start it in a separate terminal before launching a ROS 2 controller:

```bash
micro-xrce-dds-agent udp4 --port 8888
```

### Install acados

The MPC controllers use acados and CasADi. Build acados outside this
repository, then install its Python interface:

```bash
cd ~
git clone https://github.com/acados/acados.git
cd acados
git submodule update --init --recursive
mkdir -p build && cd build
cmake .. -DACADOS_WITH_QPOASES=ON
make -j"$(nproc)"
sudo make install

python3 -m pip install --user casadi
python3 -m pip install --user -e ~/acados/interfaces/acados_template
```

If this project uses generated acados solver code, generate it after acados is
installed and keep the generated output out of Git unless the project
explicitly requires it.

## Build Project Astro

```bash
source /opt/ros/humble/setup.bash
cd ~/project-astro
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install
source install/setup.bash
```

For future terminals, source both environments:

```bash
source /opt/ros/humble/setup.bash
source ~/project-astro/install/setup.bash
```

## Run the spacecraft simulation

Use three terminals:

Terminal 1, PX4 SITL:

```bash
cd ~/PX4-Autopilot
make px4_sitl_spacecraft gz_atmos
```

Terminal 2, DDS bridge:

```bash
source /opt/ros/humble/setup.bash
micro-xrce-dds-agent udp4 --port 8888
```

Terminal 3, MPC:

```bash
source /opt/ros/humble/setup.bash
source ~/project-astro/install/setup.bash
ros2 launch px4_mpc mpc_spacecraft_launch.py mode:=wrench setpoint_from_rviz:=False
```

For the quadrotor example, start PX4 with `make px4_sitl gz_x500` and launch:

```bash
ros2 launch px4_mpc mpc_quadrotor_launch.py
```

See the package documentation under `src/` for controller modes, namespaces,
RViz options, and hardware-specific instructions.

## Control ATMOS

### Remote control and QGroundControl

For manual control, connect the RC transmitter to PX4 or use the virtual
joystick in QGroundControl. Keep the throttle at its lowest position before
arming. Start the PX4 SITL, Micro XRCE-DDS Agent, and the MPC launch command
from the simulation instructions above. Then, from the PX4 shell or QGroundControl:

```text
commander arm
commander mode offboard
```

Use the transmitter mode switch to leave Offboard mode and return to a manual
or stabilized mode before stopping ROS 2 nodes. Test all control changes in
SITL before using a real vehicle.

### Run a control node from a script

The mocap package includes nodes for direct control and predefined open-loop
sequences. Source the ROS environments first, then run the node that matches
the desired behavior:

```bash
source /opt/ros/humble/setup.bash
source ~/project-astro/install/setup.bash

# Forward direct-control input to PX4
ros2 run vehicle_mocap_odom rc_direct_control_node

# Run a predefined sequence
ros2 run vehicle_mocap_odom open_loop_sequence_node

# Run the second predefined sequence
ros2 run vehicle_mocap_odom open_loop_sequence_2_node
```

For a repeatable startup, save the following as `run_atmos.sh` outside the
repository or in a local scripts directory:

```bash
#!/usr/bin/env bash
set -euo pipefail

source /opt/ros/humble/setup.bash
source "$HOME/project-astro/install/setup.bash"

ros2 run vehicle_mocap_odom open_loop_sequence_node
```

Make it executable and run it with:

```bash
chmod +x run_atmos.sh
./run_atmos.sh
```

The script starts the ROS 2 control node; it does not remove PX4 safety
checks. PX4 must already be running, the DDS agent must be connected, and the
vehicle must receive valid offboard messages before Offboard mode can be
selected. Keep an RC or other emergency stop available during testing.
