Ultimate Docker OpenVPN client with SSH
==================

Inspired by https://github.com/freeboson/openvpn-ssh-tunnel

Setup an OpenVPN connection to any VPN endpoint within a
docker container, with an SSH daemon (OpenSSH) running. You can then create an
SSH tunnel into your container that will route your traffic via the VPN, or set
up your local SSH client to use container as a jump host to get to SSH services
inside the VPN network  (see **Usage** below). This is
useful for having **some** but not **all** of your traffic to go through VPN.

The setup here will be like this:
```
┏━━━━━━━━━━━┓  (chacha20)  ┏━━━━━━━━━━━━━┓  (AES-128 CBC)  ┏━━━━━━━━━━━┓
┃           ┃──────────────┃    Docker   ┃─────────────────┃           ┃
┃    You    ┃      SSH     ┠─────┐ ┌─────┨     OpenVPN     ┃    VPN    ┃
┃           ┃──────────────┃ SSH │ │ VPN ┃─────────────────┃           ┃
┗━━━━━━━━━━━┛              ┗━━━━━┷━┷━━━━━┛                 ┗━━━━━━━━━━━┛
```

Features
--------

- Connect to any OpenVPN server out there - just supply the `*.ovpn` configuration file
- Utilize OpenSSH port forwarding features to proxy your web traffic through VPN
- Perform additional action after VPN connection established using provided
    post-up hook feature

Usage
-----

1. Clone this repo
1. Create `authorized_keys` file with your public key to authorize to SSH daemon inside the container 
1. Create `vpn_configs` directory and put your OpenVPN client configuration file(s) there.
1. Build the container, labeling it as `docker-vpn`: `docker build -t docker-vpn .`
1. Run the container you just built, provding the directory name with your
   OpenVPN configurations, and the configuration filename you'd like to use: `docker run -v $(pwd)/vpn_configs/:/vpn_configs -it
   --cap-add NET_ADMIN -p 22222:22 --env DVPN_CONFIG=my-vpn-config.ovpn docker-vpn` - this will grab your current
   terminal session, make sure you use `screen(1)` or `tmux(1)`. Alternatively,
   you can create a symlink named `default` in the `vpn_configs` directory and
   point it to the config file you'd like to use - in this case you don't need
   the `--env DVPN_CONFIG=my-vpn-config.ovpn` parameter.
1. Tunnel in: `ssh -N -D 9000 tunnel@localhost -p 22222` (or use autossh)
1. Now you can set whatever client that supports SOCKS e.g. Firefox,
   qBittorrent, etc. to connect via SOCKS5 at `localhost:9000`
    - You can also try `tsocks` or similar for clients that do not support it
1. If you want to route just some of the SSH connections through your container - put this in your `~/.ssh/config` file:

```
Host docker-vpn
    Hostname 127.0.0.1
    Port 22222
    User tunnel
    ServerAliveInterval 60
    IdentityFile ~/.ssh/id_rsa # this should correspond to what you put in the authorized_keys file above
    ForwardAgent yes # Useful if you authenticate to your SSH boxes inside VPN using SSH keys - see ssh-agent(1) for details
    StrictHostKeyChecking no # It's container - key fingerprint changes after each rebuild, no point of dealing with it
    UserKnownHostsFile /dev/null # Same as above option

Host *.secret-domain-behind-vpn.com
    ProxyJump                    docker-vpn
    ForwardAgent yes

```

Now all the ssh connections to `*.secret-domain-behind-vpn.com` will be going through container.

If you have to authenticate against an SSH jumphost when connected to VPN - just
append it's name to `ProxyJump` directive, like this:
`ProxyJump docker-vpn,user@some.jumphost.secret-domain-behind-vpn.com` - SSH
will first authenticate to your container SSH, then to the jumphost SSH and then
finally - against your target SSH server you're trying to reach. This feature
might not work wit holder SSH clients, see
[this link](https://en.wikibooks.org/wiki/OpenSSH/Cookbook/Proxies_and_Jump_Hosts#Jump_Hosts_--_Passing_Through_a_Gateway_or_Two) for details.

If you'd like to debug the container - supply `--env DVPN_DEBUG=true` parameter
to `docker run` - this will give you shell inside the container without
connecting to the VPN or starting the SSH daemon.

Post-run hook
-------------

If you'd like to perform additional actions **inside** the container - create
`post-run.sh` file in the `vpn_configs` directory, make it executable and put
any commands you'd like to run there. The file can be a bash or Python script,
or even a compiled binary.

Why shell?
----------

Containers were designed with a concept "one process - one container" in mind;
as soon as what they call "the root process" dies - containers' life ends.  In
this particular case, without shell a user would end up with "grabbed" terminal
anyway - with OpenVPN or SSH daemon running in foreground.  "Detached" option
to `docker run` cannot be used either - OpenVPN needs user input (to ask for
username and password). Supplying a file with credentials, or use some other
non-interactive way like env variables is not flexible, and might cause
inconveniences (especially in 2FA environments).  I spawn a shell after OpenVPN
connection is made and SSH daemon started to keep the container running, and to
provide a user ability to, for example, ssh from inside container somewhere
else (though my personal preference is to use `ProxyJump` ssh option, as
described above).

Having split containers (one for SSH, one for OpenVPN) makes no sense in this
case - OpenVPN container will still grab the terminal due to the reasons
described above.
