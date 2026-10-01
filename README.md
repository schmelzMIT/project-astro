# Project Astro

ROS 2 packages for ATMOS/PX4 offboard control, MPC, simulation, visualization,
and motion-capture odometry.

## New-computer installation

The commands below target a fresh Ubuntu 22.04 computer and ROS 2 Humble.
ROS, Gazebo, PX4, acados, and Micro XRCE-DDS are external dependencies. They
are installed on the computer running the project and are not copied into this
repository.

### Manual installation

Follow the manual installation commands below if you want to see and control
each setup step individually. The automatic installation section appears
after these commands; it is called automatic because the same steps are
already implemented in `setup_new_computer.sh`.

#### 1. Install base tools

```bash
sudo apt update
sudo apt install -y \
	git curl wget ca-certificates gnupg lsb-release \
	build-essential cmake ninja-build pkg-config \
	python3-dev python3-pip python3-venv
```

#### 2. Install ROS 2 Humble

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

#### 3. Download Project Astro

```bash
cd ~
git clone https://github.com/schmelzMIT/project-astro.git
cd ~/project-astro
```

#### 4. Install PX4 and Gazebo

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

#### ATMOS PX4 configuration

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

#### ATMOS Ethernet or serial DDS configuration

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

#### 5. Install Micro XRCE-DDS Agent

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

#### 6. Install acados and CasADi

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

#### 7. Install project dependencies and build

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

#### 8. Install QGroundControl (optional)

QGroundControl is optional for headless SITL. Download the current AppImage
from <https://docs.qgroundcontrol.com/master/en/getting_started/download_and_install.html>,
then run:

```bash
chmod +x ~/Downloads/QGroundControl*.AppImage
~/Downloads/QGroundControl*.AppImage
```

The AppImage filename may differ. For real hardware, use QGroundControl or a
physical RC transmitter to keep a manual override available.

### Automatic installation (`setup_new_computer.sh`)

This section is called **automatic installation** because every software setup
step listed above is already implemented in `setup_new_computer.sh`. Choose
this section instead of repeating the manual commands above:

```bash
cd ~/project-astro
chmod +x setup_new_computer.sh
./setup_new_computer.sh
```

The setup file performs these steps automatically, in this order:

1. Checks that the computer is Ubuntu 22.04 and that the script is run by a
	normal user with `sudo` access.
2. Installs Git, compilers, CMake, Python, and other Ubuntu build tools.
3. Adds the ROS 2 apt repository and installs ROS 2 Humble, `colcon`, `rosdep`,
	NumPy, and `pyquaternion`.
4. Initializes and updates `rosdep`.
5. Clones PX4-Autopilot recursively, or updates its existing submodules, then
	runs PX4's `Tools/setup/ubuntu.sh` to install PX4 and Gazebo dependencies.
6. Optionally copies `config/dds_topics.yaml` into the PX4 checkout when
	`INSTALL_ATMOS_DDS_TOPICS=1` is set.
7. Clones, compiles, and installs the Micro XRCE-DDS Agent.
8. Clones, compiles, and installs acados, CasADi, and the acados Python
	interface.
9. Configures the acados environment and runs `rosdep install` and
	`colcon build` for Project Astro.
10. Adds ROS 2, Project Astro, and acados environment settings to `~/.bashrc`.

For an ATMOS PX4 fork, set the repository URL before running the setup file:

```bash
PX4_REPO_URL=https://github.com/YOUR_ORGANIZATION/YOUR_ATMOS_PX4_FORK.git \
	./setup_new_computer.sh
```

To copy the tracked ATMOS DDS topic configuration into PX4 during setup:

```bash
INSTALL_ATMOS_DDS_TOPICS=1 ./setup_new_computer.sh
```

The setup file does not install QGroundControl or configure physical Pixhawk
hardware. Open a new terminal, or run `source ~/.bashrc`, after it finishes.

## Physical ATMOS hardware setup

The following steps are adapted from the official [ATMOS Pixhawk
guide](https://atmos.discower.io/pages/PX4/) and [onboard computer
guide](https://atmos.discower.io/pages/Jetson/). They apply to a Pixhawk 6X
Mini and an Ubuntu 22.04 onboard computer such as the NVIDIA Jetson Orin NX.
Do not apply the example IP addresses blindly to a different network.

### Configure the Pixhawk in QGroundControl

Connect the Pixhawk by USB, open QGroundControl, and configure the vehicle:

1. Select the `Spacecraft` airframe and `KTH ATMOS Freeflyer`, then reboot
	when QGroundControl requests it.
2. Calibrate the RC transmitter under **Vehicle Setup > Radio**.
3. Assign switches for arming/disarming, manual or stabilized control, and
	Offboard mode under **Flight Modes**.
4. Keep `SYS_USB_AUTO` set to `Auto-detect` or `MAVLink` for USB
	QGroundControl access.
5. Give each vehicle a unique `MAV_SYS_ID` when operating multiple vehicles.

### Configure the Pixhawk Ethernet connection

In QGroundControl, open **Analyze Tools > MAVLink Console** and configure the
Pixhawk Ethernet interface. The ATMOS example uses `192.168.0.10` for the
Pixhawk and `192.168.0.1` for the onboard computer:

```text
echo DEVICE=eth0 > /fs/microsd/net.cfg
echo BOOTPROTO=fallback >> /fs/microsd/net.cfg
echo IPADDR=192.168.0.10 >> /fs/microsd/net.cfg
echo NETMASK=255.255.255.0 >> /fs/microsd/net.cfg
echo ROUTER=192.168.0.254 >> /fs/microsd/net.cfg
echo DNS=192.168.0.254 >> /fs/microsd/net.cfg
```

Reboot the Pixhawk, then verify the network configuration:

```text
netman showw
```

For Ethernet DDS, set these parameters in QGroundControl and reboot again:

```text
UXRCE_DDS_CFG = Ethernet
UXRCE_DDS_AG_IP = -1062731775
```

The value `-1062731775` represents agent IP `192.168.0.1`. For another agent
address, calculate the value with:

```bash
cd ~/PX4-Autopilot
python3 Tools/convert_ip.py "<onboard-computer-ip>"
```

For serial DDS instead, select the appropriate `UXRCE_DDS_CFG` value and set
the matching `SER_<port>_BAUD` parameter. Use `921600` or higher only when the
connection supports it, and do not assign MAVLink and uXRCE-DDS to the same
serial port.

### Configure the onboard computer network

On the onboard computer, identify the wired connection:

```bash
nmcli connection show
```

Set a static address of `192.168.0.1/24` on the connection used for PX4. Edit
the matching NetworkManager file, replacing the placeholder with its actual
name:

```bash
sudo nano "/etc/NetworkManager/system-connections/<your-wired-connection>.nmconnection"
sudo systemctl restart NetworkManager
```

The IPv4 section should use `method=manual` and an address such as:

```text
address1=192.168.0.1/24,192.168.0.254
```

### Run the DDS Agent as a service

The setup script builds a local DDS Agent for development. For an onboard
computer that should start it automatically, the ATMOS guide instead uses the
Snap package. Choose one installation method; do not run both agents on port
`8888`:

```bash
sudo snap install micro-xrce-dds-agent --edge
sudo snap set micro-xrce-dds-agent daemon=true
sudo snap set micro-xrce-dds-agent transport=udp4
sudo snap set micro-xrce-dds-agent port=8888
sudo systemctl enable --now snap.micro-xrce-dds-agent.daemon.service
```

For serial transport, replace the transport settings with:

```bash
sudo snap set micro-xrce-dds-agent transport=serial
sudo snap set micro-xrce-dds-agent device=<obc-serial-port>
sudo snap set micro-xrce-dds-agent baudrate=<px4-baudrate>
sudo systemctl enable --now snap.micro-xrce-dds-agent.daemon.service
```

### Verify the hardware connection

After sourcing ROS and the workspace, verify that PX4 topics are visible:

```bash
ros2 topic list
ros2 topic echo /fmu/out/vehicle_attitude
```

For an Ethernet vehicle, connect QGroundControl from the ground-control
computer using a TCP link to the vehicle's configured address and default
port.

The ATMOS guide also describes USB udev rules, MAVLink Router, and systemd
startup services from its separate `FF_OBC_Setup` repository. Those files are
not part of `project-astro` because they contain machine- and deployment-
specific service configuration.

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
