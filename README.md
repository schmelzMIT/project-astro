# Project Astro

ROS 2 packages for ATMOS/PX4 offboard control, MPC, simulation, visualization,
and motion-capture odometry.

## New-computer installation

The commands below target a fresh Ubuntu 22.04 computer and ROS 2 Humble.
ROS, Gazebo, PX4, acados, and Micro XRCE-DDS are external dependencies. They
are installed on the computer running the project and are not copied into this
repository.

### Automatic installation

After downloading or cloning this repository, run the installer from its root:

```bash
cd ~/project-astro
chmod +x setup_new_computer.sh
./setup_new_computer.sh
```

The script installs ROS 2, build tools, PX4 dependencies/Gazebo, Micro
XRCE-DDS Agent, acados, CasADi, and this workspace's ROS dependencies. It may
ask for your `sudo` password and may ask you to log out and back in after the
PX4 setup step.

For an ATMOS PX4 fork, set the repository URL before running it:

```bash
PX4_REPO_URL=https://github.com/YOUR_ORGANIZATION/YOUR_ATMOS_PX4_FORK.git \
	./setup_new_computer.sh
```

The repository includes ATMOS's custom `dds_topics.yaml` at
`config/dds_topics.yaml`. To copy this tracked file into the PX4 checkout,
enable the optional installer step:

```bash
INSTALL_ATMOS_DDS_TOPICS=1 ./setup_new_computer.sh
```

The script adds ROS 2 and the Project Astro workspace to `~/.bashrc`. Open a
new terminal, or run `source ~/.bashrc`, after it finishes.

The installer does not install QGroundControl automatically. It also cannot
create the `gz_atmos` model if the selected PX4 repository does not contain it.

### 1. Install base tools

```bash
sudo apt update
sudo apt install -y \
	git curl wget ca-certificates gnupg lsb-release \
	build-essential cmake ninja-build pkg-config \
	python3-dev python3-pip python3-venv
```

### 2. Install ROS 2 Humble

Configure the ROS 2 apt repository, then install ROS and workspace tools:

```bash
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
	-o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
	| sudo tee /etc/apt/sources.list.d/ros2.list >/dev/null

sudo apt update
sudo apt install -y \
	ros-humble-desktop \
	python3-colcon-common-extensions \
	python3-rosdep \
	python3-vcstool \
	python3-pyquaternion \
	python3-numpy

source /opt/ros/humble/setup.bash
sudo rosdep init 2>/dev/null || true
rosdep update
```

Make ROS available in every new Bash terminal:

```bash
echo 'source /opt/ros/humble/setup.bash' >> ~/.bashrc
source ~/.bashrc
```

### 3. Download Project Astro

```bash
cd ~
git clone https://github.com/schmelzMIT/project-astro.git
cd ~/project-astro
```

### 4. Install PX4 and Gazebo

PX4 provides the SITL simulator and the Gazebo vehicle models. Clone the PX4
version or ATMOS-compatible fork required by your simulation:

```bash
cd ~
git clone --recursive https://github.com/PX4/PX4-Autopilot.git
cd PX4-Autopilot
bash Tools/setup/ubuntu.sh
```

The PX4 setup script installs additional Gazebo and simulator dependencies.
Log out and back in if the script requests it. Verify the standard quadrotor
simulation with:

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

### ATMOS PX4 configuration

For the ATMOS spacecraft, configure the PX4 checkout after the installer has
finished. ATMOS uses the tracked PX4 DDS topic list. Copy it into the PX4
source tree before building firmware:

```bash
cd ~/PX4-Autopilot
cp ~/project-astro/config/dds_topics.yaml \
	src/modules/uxrce_dds_client/dds_topics.yaml
```

For a namespaced vehicle, set the namespace when building or uploading
firmware. The ROS launch command must use the same namespace:

```bash
cd ~/PX4-Autopilot
PX4_UXRCE_DDS_NS=pop make px4_sitl_spacecraft gz_atmos

source /opt/ros/humble/setup.bash
source ~/project-astro/install/setup.bash
ros2 launch px4_mpc mpc_spacecraft_launch.py \
	namespace:=pop mode:=wrench setpoint_from_rviz:=False
```

For a physical Pixhawk 6X Mini, upload the spacecraft firmware with:

```bash
cd ~/PX4-Autopilot
make px4_fmu-v6x_spacecraft upload
```

To upload with a default namespace:

```bash
PX4_UXRCE_DDS_NS=pop make px4_fmu-v6x_spacecraft upload
```

The board must be connected by USB and visible to the user running the
command. For multiple vehicles, give each vehicle a unique PX4 namespace and
`MAV_SYS_ID`.

### ATMOS Ethernet or serial DDS configuration

For physical hardware, complete the optional QGroundControl installation in
step 8 before applying the parameters below. This section is not required for
headless SITL.

For an Ethernet-connected Pixhawk, configure these PX4 parameters in
QGroundControl and reboot the vehicle:

```text
UXRCE_DDS_CFG = Ethernet
UXRCE_DDS_AG_IP = <agent IP encoded as an integer>
```

The ATMOS guide uses agent IP `192.168.0.1`, encoded as `-1062731775`. For a
different address, run PX4's converter:

```bash
cd ~/PX4-Autopilot
python3 Tools/convert_ip.py "192.168.0.1"
```

For serial transport, set `UXRCE_DDS_CFG` to the board's serial option and set
the matching `SER_<port>_BAUD` parameter to `921600` or higher when the cable
supports it. Do not configure MAVLink and uXRCE-DDS on the same serial port.
For USB MAVLink/QGroundControl, keep `SYS_USB_AUTO` set to `Auto-detect` or
`MAVLink`.

### 5. Install Micro XRCE-DDS Agent

The agent bridges PX4's uXRCE-DDS client to ROS 2:

```bash
cd ~
git clone https://github.com/eProsima/Micro-XRCE-DDS-Agent.git
cd Micro-XRCE-DDS-Agent
git checkout master
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j"$(nproc)"
sudo make install
sudo ldconfig
```

Start it in a separate terminal before launching a ROS 2 controller:

```bash
micro-xrce-dds-agent udp4 --port 8888
```

### 6. Install acados and CasADi

The MPC controllers use acados and CasADi. Build acados outside this
repository, then install its Python interface:

```bash
cd ~
git clone https://github.com/acados/acados.git
cd acados
git submodule update --init --recursive
sudo apt install -y libblas-dev liblapack-dev liblapacke-dev
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DACADOS_WITH_QPOASES=ON
make -j"$(nproc)"
sudo make install

python3 -m pip install --user --upgrade pip
python3 -m pip install --user casadi
python3 -m pip install --user -e "$HOME/acados/interfaces/acados_template"
```

Configure the acados environment for the current and future terminals:

```bash
sudo ldconfig
echo 'export ACADOS_SOURCE_DIR=$HOME/acados' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=$HOME/acados/lib:${LD_LIBRARY_PATH:-}' >> ~/.bashrc
source ~/.bashrc
```

The automatic installer applies these settings without adding duplicate lines.

If this project uses generated acados solver code, generate it after acados is
installed and keep the generated output out of Git unless the project
explicitly requires it.

### 7. Install project dependencies and build

```bash
source /opt/ros/humble/setup.bash
cd ~/project-astro
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install
source install/setup.bash
```

Make the built workspace available in future terminals:

```bash
echo 'source ~/project-astro/install/setup.bash' >> ~/.bashrc
source ~/.bashrc
```

### 8. Install QGroundControl (optional)

QGroundControl is optional for headless SITL. Download the current AppImage
from <https://docs.qgroundcontrol.com/master/en/getting_started/download_and_install.html>,
then run:

```bash
chmod +x ~/Downloads/QGroundControl*.AppImage
~/Downloads/QGroundControl*.AppImage
```

The AppImage filename may differ. For real hardware, use QGroundControl or a
physical RC transmitter to keep a manual override available.

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
