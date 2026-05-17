#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

LUANTI_VERSION="5.16.1"
LUANTI_ROOT="/opt/luanti"
WORLD_DIR="${LUANTI_ROOT}/worlds/office"
ACCESS_MOD_DIR="${WORLD_DIR}/worldmods/trivium_access"
VOXELIBRE_REPO_URL="https://codeberg.org/tacotexmex/voxelibre.git"

apt-get update
apt-get install -y \
  ca-certificates \
  cmake \
  curl \
  g++ \
  gcc \
  gettext \
  git \
  libc6-dev \
  libcurl4-gnutls-dev \
  libfreetype6-dev \
  libgmp-dev \
  libgl1-mesa-dev \
  libjpeg-dev \
  libjsoncpp-dev \
  libluajit-5.1-dev \
  libogg-dev \
  libopenal-dev \
  libpng-dev \
  libsqlite3-dev \
  libsdl2-dev \
  libvorbis-dev \
  libzstd-dev \
  make \
  zlib1g-dev

if ! id -u luanti >/dev/null 2>&1; then
  useradd --system --create-home --home-dir /var/lib/luanti --user-group --shell /usr/sbin/nologin luanti
fi

install -d -o luanti -g luanti "${LUANTI_ROOT}"
install -d -o luanti -g luanti "${LUANTI_ROOT}/games"
install -d -o luanti -g luanti "${LUANTI_ROOT}/worlds"

if [ ! -d "${LUANTI_ROOT}/.git" ]; then
  rm -rf "${LUANTI_ROOT}"
  git clone --branch "${LUANTI_VERSION}" --depth 1 https://github.com/luanti-org/luanti.git "${LUANTI_ROOT}"
else
  git -C "${LUANTI_ROOT}" fetch --depth 1 origin "refs/tags/${LUANTI_VERSION}:refs/tags/${LUANTI_VERSION}"
  git -C "${LUANTI_ROOT}" checkout --force "${LUANTI_VERSION}"
fi

cmake -S "${LUANTI_ROOT}" -B "${LUANTI_ROOT}/build" -DRUN_IN_PLACE=TRUE -DBUILD_SERVER=TRUE -DBUILD_CLIENT=FALSE -DBUILD_UNITTESTS=FALSE -DBUILD_DOCUMENTATION=FALSE -DCMAKE_BUILD_TYPE=Release
cmake --build "${LUANTI_ROOT}/build" -j"$(nproc)"

if [ ! -d "${LUANTI_ROOT}/games/VoxeLibre/.git" ]; then
  rm -rf "${LUANTI_ROOT}/games/VoxeLibre"
  git clone --depth 1 "${VOXELIBRE_REPO_URL}" "${LUANTI_ROOT}/games/VoxeLibre"
else
  git -C "${LUANTI_ROOT}/games/VoxeLibre" fetch --depth 1 origin
  git -C "${LUANTI_ROOT}/games/VoxeLibre" reset --hard origin/master
fi

chown -R luanti:luanti "${LUANTI_ROOT}"

install -d -o luanti -g luanti "${WORLD_DIR}"
install -d -o luanti -g luanti "${WORLD_DIR}/worldmods"
install -d -o luanti -g luanti "${ACCESS_MOD_DIR}"

cat > "${ACCESS_MOD_DIR}/mod.conf" <<'EOF'
__TRIVIUM_ACCESS_MOD_CONF__
EOF

cat > "${ACCESS_MOD_DIR}/bootstrap.lua" <<'EOF'
__TRIVIUM_ACCESS_BOOTSTRAP__
EOF

cat > "${ACCESS_MOD_DIR}/init.lua" <<'EOF'
__TRIVIUM_ACCESS_INIT__
EOF

cat > "${WORLD_DIR}/world.mt" <<'EOF'
gameid = VoxeLibre
backend = sqlite3
EOF

chown -R luanti:luanti "${WORLD_DIR}"

cat > /etc/trivium-minetest.conf <<'EOF'
server_name = Cacsi Virtual Office
server_description = Internal office test world for Trivium
bind_address = 0.0.0.0
port = 30000
max_users = 10
creative_mode = false
enable_damage = true
default_privs = interact, shout
enable_bed_respawn = true
mcl_return_spawn = true
mob_difficulty = 3.0
motd = Welcome to the Cacsi office world.
EOF

SERVER_BIN=""
for candidate in \
  "${LUANTI_ROOT}/bin/luantiserver" \
  "${LUANTI_ROOT}/build/bin/luantiserver" \
  "${LUANTI_ROOT}/bin/minetestserver" \
  "${LUANTI_ROOT}/build/bin/minetestserver"; do
  if [ -x "$candidate" ]; then
    SERVER_BIN="$candidate"
    break
  fi
done

if [ -z "$SERVER_BIN" ]; then
  echo "Could not find a Luanti server binary after installation." >&2
  exit 1
fi

cat > /etc/systemd/system/trivium-office.service <<EOF
[Unit]
Description=Trivium Office Luanti Server
After=network-online.target
Wants=network-online.target

[Service]
User=luanti
Group=luanti
WorkingDirectory=${LUANTI_ROOT}
ExecStart=${SERVER_BIN} --config /etc/trivium-minetest.conf --world ${WORLD_DIR}
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now trivium-office.service