#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

LUANTI_VERSION="5.16.1"
LUANTI_ROOT="/opt/luanti"
WORLD_DATA_ROOT="/srv/trivium-office-data"
WORLD_DIR="${WORLD_DATA_ROOT}/world"
WORLDMODS_DIR="${WORLD_DIR}/worldmods"
WORLD_DISK_DEVICE="__WORLD_DISK_DEVICE__"
LUANTI_SERVER_BUNDLE_URL="__LUANTI_SERVER_BUNDLE_URL__"
VOXELIBRE_REPO_URL="https://codeberg.org/tacotexmex/voxelibre.git"

download_bundle_archive() {
  local source="$1"
  local destination="$2"

  if [[ "${source}" == gs://* ]]; then
    local gcs_path bucket object access_token

    gcs_path="${source#gs://}"
    bucket="${gcs_path%%/*}"
    object="${gcs_path#${bucket}/}"

    if [ -z "${bucket}" ] || [ -z "${object}" ] || [ "${object}" = "${gcs_path}" ]; then
      echo "Invalid GCS bundle source: ${source}" >&2
      exit 1
    fi

    access_token="$(curl -fsSL -H 'Metadata-Flavor: Google' 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token' | sed -n 's/.*"access_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
    if [ -z "${access_token}" ]; then
      echo "Could not obtain an access token from the instance metadata server." >&2
      exit 1
    fi

    curl -fsSL -H "Authorization: Bearer ${access_token}" "https://storage.googleapis.com/${bucket}/${object}" -o "${destination}"
    return
  fi

  curl -fsSL "${source}" -o "${destination}"
}

apt-get update
apt-get install -y \
  ca-certificates \
  curl \
  git \
  libcurl3-gnutls \
  libgmp10 \
  libjsoncpp25 \
  libluajit-5.1-2 \
  libsqlite3-0 \
  libzstd1 \
  zlib1g

if ! id -u luanti >/dev/null 2>&1; then
  useradd --system --create-home --home-dir /var/lib/luanti --user-group --shell /usr/sbin/nologin luanti
fi

install -d -m 0755 "${WORLD_DATA_ROOT}"

if [ -b "${WORLD_DISK_DEVICE}" ]; then
  if ! blkid "${WORLD_DISK_DEVICE}" >/dev/null 2>&1; then
    mkfs.ext4 -F "${WORLD_DISK_DEVICE}"
  fi

  WORLD_DISK_UUID="$(blkid -s UUID -o value "${WORLD_DISK_DEVICE}")"
  if ! grep -q "${WORLD_DISK_UUID}" /etc/fstab; then
    echo "UUID=${WORLD_DISK_UUID} ${WORLD_DATA_ROOT} ext4 defaults,nofail,discard 0 2" >> /etc/fstab
  fi

  if ! mountpoint -q "${WORLD_DATA_ROOT}"; then
    mount "${WORLD_DATA_ROOT}"
  fi
fi

install -d -o luanti -g luanti "${LUANTI_ROOT}"
install -d -o luanti -g luanti "${LUANTI_ROOT}/games"

install_luanti_from_bundle() {
  local archive_path="/tmp/luanti-server-${LUANTI_VERSION}.tar.gz"

  echo "Installing Luanti ${LUANTI_VERSION} from prebuilt bundle"
  rm -rf "${LUANTI_ROOT}"
  install -d -o luanti -g luanti "${LUANTI_ROOT}"
  download_bundle_archive "${LUANTI_SERVER_BUNDLE_URL}" "${archive_path}"
  tar -xzf "${archive_path}" -C "${LUANTI_ROOT}"
  rm -rf "${LUANTI_ROOT}/games/VoxeLibre"
  rm -f "${archive_path}"
}

install_luanti_from_source() {
  echo "Installing Luanti ${LUANTI_VERSION} from source"

  apt-get install -y \
    cmake \
    g++ \
    gcc \
    gettext \
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
    make

  if [ ! -d "${LUANTI_ROOT}/.git" ]; then
    rm -rf "${LUANTI_ROOT}"
    git clone --branch "${LUANTI_VERSION}" --depth 1 https://github.com/luanti-org/luanti.git "${LUANTI_ROOT}"
  else
    git -C "${LUANTI_ROOT}" fetch --depth 1 origin "refs/tags/${LUANTI_VERSION}:refs/tags/${LUANTI_VERSION}"
    git -C "${LUANTI_ROOT}" checkout --force "${LUANTI_VERSION}"
  fi

  cmake -S "${LUANTI_ROOT}" -B "${LUANTI_ROOT}/build" -DRUN_IN_PLACE=TRUE -DBUILD_SERVER=TRUE -DBUILD_CLIENT=FALSE -DBUILD_UNITTESTS=FALSE -DBUILD_DOCUMENTATION=FALSE -DCMAKE_BUILD_TYPE=Release
  cmake --build "${LUANTI_ROOT}/build" -j"$(nproc)"
}

if [ -n "${LUANTI_SERVER_BUNDLE_URL}" ]; then
  install_luanti_from_bundle
else
  install_luanti_from_source
fi

install -d -o luanti -g luanti "${LUANTI_ROOT}/games"

if [ ! -d "${LUANTI_ROOT}/games/VoxeLibre/.git" ]; then
  rm -rf "${LUANTI_ROOT}/games/VoxeLibre"
  git clone --depth 1 "${VOXELIBRE_REPO_URL}" "${LUANTI_ROOT}/games/VoxeLibre"
else
  git -C "${LUANTI_ROOT}/games/VoxeLibre" fetch --depth 1 origin
  git -C "${LUANTI_ROOT}/games/VoxeLibre" reset --hard origin/master
fi

chown -R luanti:luanti "${LUANTI_ROOT}"

install -d -o luanti -g luanti "${WORLD_DIR}"
install -d -o luanti -g luanti "${WORLDMODS_DIR}"

cat > "${WORLD_DIR}/world.mt" <<'EOF'
gameid = VoxeLibre
backend = sqlite3
player_backend = files
auth_backend = files
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