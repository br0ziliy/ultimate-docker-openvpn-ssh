#!/bin/bash

# Make OpenVPN happy:
mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

# Deal with OpenVPN configuration file.
# If DVPN_CONFIG is not defined with --env parameter, or first argument during "docker run", - try to
# use /vpn_configs/default; we die if the file cannot be found.
[ -z "$1" ] && vpn_config=/vpn_configs/${DVPN_CONFIG:="default"} || \
    vpn_config=/vpn_configs/$1
[ -f ${vpn_config} ] || { echo "Cannot find requested config file: $vpn_config"; exit 1; } 
# Make sure we see actual filename of the config that was used to build a
# tunnel - for cases when "default" symlink is used:
DVPN_CONFIG_FNAME=$(basename $(readlink -f ${vpn_config}))

# Provide shell for debugging purposes, if requested by user:
[ ! -z "${DVPN_DEBUG}" ] && {
    cat > /root/.bash_profile<<EOF
export PS1="[debugging mode] \w # "
EOF
    /bin/bash -l -i
}

# Start the OpenVPN client:
echo "OpenVPN config in use: "${DVPN_CONFIG_FNAME}
/usr/sbin/openvpn \
    --config $vpn_config \
    --daemon \
    --log /var/log/openvpn.log \
    --script-security 2 \
    --up /etc/openvpn/up.sh \
    --down /etc/openvpn/down.sh

# Wait for connection, bailing out if it fails:
i=0
echo
while :;do
    [ $i -gt 60 ] && { echo "Could not connect"; cat /var/log/openvpn.log; exit 1; }
    # Check if OpenVPN process exist; if it's not - we're done:
    ps axfuww | grep -q /usr/sbin/[o]penvpn || { echo "Could not connect"; cat /var/log/openvpn.log; exit 1; }
    # ... the process might exist, but there might be problem with creating
    # tunnel and setting it up - check it here:
    ip r get 1.2.3.4 | grep -q tun && break
    # Some eye-candy:
    echo -n .
    ((i++))
    sleep 1
done
echo

# Set up sshd and start it:
docker_ip=$(hostname -i)
sed -i -r 's/^\s*ListenAddress.*$//' /sshd_config
echo "ListenAddress ${docker_ip}" >> /sshd_config
/usr/sbin/sshd -e -f /sshd_config

# Run optional post-up hook, ignoring it's exit status
# (/vpn_configs/post-up.sh should be executable):
[ -x /vpn_configs/post-up.sh ] && /vpn_configs/post-up.sh || true

# Give shell to keep the lights on;
# Without this the container would exit immediately after this script finishes.
# See README.md, "Why shell?" section for additional details.

cat > /root/.bash_profile<<EOF
export PS1="[${DVPN_CONFIG_FNAME}] \w # "
EOF
/bin/bash -l -i
