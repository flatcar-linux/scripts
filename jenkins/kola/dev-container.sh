#!/bin/bash
set -ex

sudo rm -f flatcar_developer_container.bin*
trap 'sudo rm -f flatcar_developer_container.bin*' EXIT

[ -s verify.asc ] && verify_key=--verify-key=verify.asc || verify_key=

bin/gangue get \
    --json-key="${GOOGLE_APPLICATION_CREDENTIALS}" \
    --verify=true $verify_key \
    "${DOWNLOAD_ROOT}/boards/${BOARD}/${VERSION}/flatcar_production_image_kernel_config.txt"

bin/gangue get \
    --json-key="${GOOGLE_APPLICATION_CREDENTIALS}" \
    --verify=true $verify_key \
    "${DOWNLOAD_ROOT}/boards/${BOARD}/${VERSION}/flatcar_developer_container.bin.bz2"
bunzip2 flatcar_developer_container.bin.bz2

if [[ "$(systemd-nspawn --version | grep 'systemd 241')" = "" ]]
then
    PIPEARG="--pipe"
else
    # TODO: Remove this case once Flatcar >=2592 is used on all nodes
    PIPEARG=""
fi

sudo systemd-nspawn $PIPEARG \
    --bind-ro=/lib/modules \
    --bind-ro="$PWD/flatcar_production_image_kernel_config.txt:/boot/config" \
    --image=flatcar_developer_container.bin \
    --machine=flatcar-developer-container-$(uuidgen) \
    --tmpfs=/usr/src \
    --tmpfs=/var/tmp \
    /bin/bash -eux << 'EOF'
emerge-gitclone
. /usr/share/coreos/release
if [[ $FLATCAR_RELEASE_VERSION =~ master ]]
then
        git -C /var/lib/portage/portage-stable checkout master
        git -C /var/lib/portage/coreos-overlay checkout master
fi
emerge -gv coreos-sources
ln -fns /boot/config /usr/src/linux/.config
exec make -C /usr/src/linux -j"$(nproc)" modules_prepare V=1
EOF
