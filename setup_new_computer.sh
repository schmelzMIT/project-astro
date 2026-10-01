#!/usr/bin/env bash
set -euo pipefail

# Override these when using an ATMOS-specific PX4 fork or a different install location.
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PX4_DIR="${PX4_DIR:-$HOME/PX4-Autopilot}"
PX4_REPO_URL="${PX4_REPO_URL:-https://github.com/PX4/PX4-Autopilot.git}"
XRCE_DIR="${XRCE_DIR:-$HOME/Micro-XRCE-DDS-Agent}"
ACADOS_DIR="${ACADOS_DIR:-$HOME/acados}"
INSTALL_ATMOS_DDS_TOPICS="${INSTALL_ATMOS_DDS_TOPICS:-0}"

if [[ "$(uname -s)" != "Linux" || ! -f /etc/os-release ]]; then
  echo "This installer supports Ubuntu Linux only." >&2
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "22.04" ]]; then
  echo "This installer targets Ubuntu 22.04; detected ${PRETTY_NAME:-unknown}." >&2
  exit 1
fi

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as a normal user with sudo access, not as root." >&2
  exit 1
fi

sudo -v

sudo apt update
sudo apt install -y \
  git curl wget ca-certificates gnupg lsb-release \
  software-properties-common \
  build-essential cmake ninja-build pkg-config \
  python3-dev python3-pip python3-venv

sudo add-apt-repository -y universe
sudo apt update

sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

sudo curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
  -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu ${UBUNTU_CODENAME} main" \
  | sudo tee /etc/apt/sources.list.d/ros2.list >/dev/null

sudo apt update
sudo apt install -y \
  ros-humble-desktop \
  python3-colcon-common-extensions \
  python3-rosdep \
  python3-vcstool \
  python3-numpy \
  libblas-dev liblapack-dev liblapacke-dev

python3 -m pip install --user pyquaternion

# shellcheck disable=SC1091
source /opt/ros/humble/setup.bash
sudo rosdep init 2>/dev/null || true
rosdep update

if [[ ! -d "${PX4_DIR}/.git" ]]; then
  git clone --recursive "${PX4_REPO_URL}" "${PX4_DIR}"
else
  git -C "${PX4_DIR}" submodule update --init --recursive
fi
bash "${PX4_DIR}/Tools/setup/ubuntu.sh"

if [[ "${INSTALL_ATMOS_DDS_TOPICS}" == "1" ]]; then
  DDS_TOPICS_FILE="${PX4_DIR}/src/modules/uxrce_dds_client/dds_topics.yaml"
  cp "${PROJECT_DIR}/config/dds_topics.yaml" "${DDS_TOPICS_FILE}"
  echo "Installed ATMOS DDS topics at ${DDS_TOPICS_FILE}"
fi

if [[ ! -d "${XRCE_DIR}/.git" ]]; then
  git clone https://github.com/eProsima/Micro-XRCE-DDS-Agent.git "${XRCE_DIR}"
fi
if [[ ! -x "${XRCE_DIR}/build/MicroXRCEAgent" ]]; then
  cmake -S "${XRCE_DIR}" -B "${XRCE_DIR}/build" -DCMAKE_BUILD_TYPE=Release
  cmake --build "${XRCE_DIR}/build" --parallel
  sudo cmake --install "${XRCE_DIR}/build"
  sudo ldconfig
fi

if [[ ! -d "${ACADOS_DIR}/.git" ]]; then
  git clone https://github.com/acados/acados.git "${ACADOS_DIR}"
fi
git -C "${ACADOS_DIR}" submodule update --init --recursive
cmake -S "${ACADOS_DIR}" -B "${ACADOS_DIR}/build" \
  -DCMAKE_BUILD_TYPE=Release -DACADOS_WITH_QPOASES=ON
cmake --build "${ACADOS_DIR}/build" --parallel
sudo cmake --install "${ACADOS_DIR}/build"
sudo ldconfig
python3 -m pip install --user --upgrade pip casadi
python3 -m pip install --user -e "${ACADOS_DIR}/interfaces/acados_template"

export ACADOS_SOURCE_DIR="${ACADOS_DIR}"
export LD_LIBRARY_PATH="${ACADOS_DIR}/lib:${LD_LIBRARY_PATH:-}"

cd "${PROJECT_DIR}"
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install

ROS_SOURCE="source /opt/ros/humble/setup.bash"
PROJECT_SOURCE="source ${PROJECT_DIR}/install/setup.bash"
ACADOS_SOURCE="export ACADOS_SOURCE_DIR=${ACADOS_DIR}"
ACADOS_LIBRARY_SOURCE="export LD_LIBRARY_PATH=${ACADOS_DIR}/lib:\${LD_LIBRARY_PATH:-}"
grep -qxF "${ROS_SOURCE}" "${HOME}/.bashrc" || echo "${ROS_SOURCE}" >> "${HOME}/.bashrc"
grep -qxF "${PROJECT_SOURCE}" "${HOME}/.bashrc" || echo "${PROJECT_SOURCE}" >> "${HOME}/.bashrc"
grep -qxF "${ACADOS_SOURCE}" "${HOME}/.bashrc" || echo "${ACADOS_SOURCE}" >> "${HOME}/.bashrc"
grep -qxF "${ACADOS_LIBRARY_SOURCE}" "${HOME}/.bashrc" || echo "${ACADOS_LIBRARY_SOURCE}" >> "${HOME}/.bashrc"

cat <<EOF

Installation finished.

Project: ${PROJECT_DIR}
PX4:     ${PX4_DIR}

To install ATMOS' custom DDS topic list, rerun with:
  INSTALL_ATMOS_DDS_TOPICS=1 ${PROJECT_DIR}/setup_new_computer.sh

For each new terminal, run:
  source /opt/ros/humble/setup.bash
  source ${PROJECT_DIR}/install/setup.bash

Start the DDS bridge with:
  micro-xrce-dds-agent udp4 --port 8888

Note: gz_atmos requires an ATMOS-compatible PX4 repository. The default PX4
repository may only provide gz_x500. QGroundControl is optional and must be
installed separately.
EOF
