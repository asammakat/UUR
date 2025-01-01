## Overview
---
A simple REST api built with Django for fetching quotes from the inspirational work "The You You Are" by Dr Ricken Lazlo Hale, PhD.
## Docker image
---

Available in a public repo asammakia/uur-container. The most recent version is 1.1.0 .

## Provision Compute Nodes
---
[Andrew Malkov's Tutorial](https://www.youtube.com/watch?app=desktop&v=rOXkutK8ANc&ab_channel=AndrewMalkov) is a good place to start.
[Quick-Start Guide | K3s](https://docs.k3s.io/quick-start) is for setting up K3s.
[Raspberry Pi K8s Cluster ( Part 8 ) - How to Build an NFS Server on Raspberry Pi](https://www.youtube.com/watch?v=L97Z5In3KXQ&list=PLZlXrZGK4hBhh_9Z543lG6TEQp-c_E9pv&index=11&ab_channel=The_Sudo) is a very helpful guide for setting up the NFS server.
#### Hardware
- Three [Raspberry Pi 4](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/specifications/) running [Raspian Pi OS Lite 62-bit (Debian 12)](https://www.raspberrypi.com/software/operating-systems/)for the K3s control plane and worker nodes.
- One compute node (currently a 2011 MacBook Pro) with 1tb storage running [Debian 12](https://www.debian.org/releases/bookworm/) as an NFS server for persistent storage.
## Configure K3s
---
#### Activate The `cgroup` On The K3s Nodes
We need to activate the cgroup for k3s to work
- `sudo vim /boot/firmware/cmdline.txt` (on an older system this might be `sudo vim /boot/cmdline.txt`)
- This should be a file with a single line, add the following to the end of that line `cgroup_memory=1 cgroup_enable=memory`
- reboot the machine `sudo reboot`

```/boot/firmware/cmdline.txt
console=serial0,115200 console=tty1 root=PARTUUID=93b3735c-02 rootfstype=ext4 fsck.repair=yes rootwait cgroup_memory=1 cgroup_enable=memory
```
#### Install K3s On The Nodes
- On the control plane node run `curl -sfL https://get.k3s.io | sh -` 
- Grab the NODE_TOKEN from `/var/lib/rancher/k3s/server/node-token` on the control plane node
- On each worker node run `curl -sfL https://get.k3s.io | K3S_URL=https://<ip-of-k3s-controller>:6443 K3S_TOKEN=NODE_TOKEN sh -`
## Configure NFS Server
---
#### Install nfs-kernel-server
On the NFS server compute node Install software that allows the machine to act as an NFS server
`sudo apt-get install nfs-kernel-server`
#### Create Directory To Be Mounted 
On the NFS server compute node create a directory that will be mounted to client machines.
- Probably want this as a distinct directory in `mnt/`
- ex: `sudo mkdir /mnt/uur`
- If directory is owned by root change it to current admin user `sudo chown adam:adam /mnt/uur` (This will again be changed later)
#### Edit etc/exports
On the NFS server compute node the directory etc/exports is where mountable files and their permissions are defined. We need to add the directory we just created to this file by adding the line `/mnt/uur 10.0.0.4/24(rw,sync,all_squash)` to `/etc/exports`
- `<directory-to-share> <allowed-cidr-block>(permissions)`
- The `<allowed-cidr-block>` can be `*` to allow all hosts to connect.
- The [all_squash](https://linux.die.net/man/5/exports) permission maps all user requests to the anonymous uid.
- If `/etc/exports` does not exist we can create it.
```/etc/exports
# /etc/exports: the access control list for filesystems which may be exported
#               to NFS clients.  See exports(5).
#
# Example for NFSv2 and NFSv3:
# /srv/homes       hostname1(rw,sync,no_subtree_check) hostname2(ro,sync,no_subtree_check)
#
# Example for NFSv4:
# /srv/nfs4        gss/krb5i(rw,sync,fsid=0,crossmnt,no_subtree_check)
# /srv/nfs4/homes  gss/krb5i(rw,sync,no_subtree_check)
#
/mnt/uur 192.168.4.0/24(rw,sync,all_squash)
```
#### Update The Export Table
On the NFS server compute node after modifying `/etc/exports` we need to update our export table with the most recent changes.
`sudo exportfs -ra`
#### Install nfs-kernel-common
On the K3s nodes Install software that allows the machines to act as an NFS client.
`sudo apt install nfs-common`
#### Add NFS Server To /etc/fstab
On the K3s nodes in order for the machines to mount persistently across reboots we need to add the NFS mount point to the file `/etc/fstab`
	- `<ip-addr>:<mount-point-on-server> <mount-point-on-client> <file-system-type> <options> 0 1`
- ex: `10.0.0.4:/mnt/uur /mnt nfs defaults 0 1`
```/etc/fstab
proc            /proc           proc    defaults          0       0
PARTUUID=a3f161f3-01  /boot/firmware  vfat    defaults          0       2
PARTUUID=a3f161f3-02  /               ext4    defaults,noatime  0       1
# a swapfile is not a swap partition, no line here
#   use  dphys-swapfile swap[on|off]  for that
10.0.0.4:/mnt/uur /mnt nfs defaults 0 1
```
#### Mount The Directory
We need to mount the entry we just made in `etc/fstab`
`sudo mount -a`
- We should now see any test files we created on the server machine in our client mount point and vice versa
- To unmount use `umount` and specify the mount point `sudo umount /mnt`

NOTE: the `all_squash` setting on the server will prevent the client admin/root user from writing to this mount point. We set `all_squash` for the [[Self Hosted Kubernetes Web Application]] use case, but it we want to test or if we have a different use case we can change the `all_squash` setting to `no_root_squash`
#### Setup for UUR
After installs and testing, The owner for the mount point on the NFS server ie `/mnt/uur` needs to be changed to the postgres user 999. `sudo chown 999:999 /mnt/uur`
## Deploy UUR
---
#### Secrets
Before deploying two secrets files need to be added:
```deploy/application/secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: uur-secrets
type: Opaque
data:
  SECRET_KEY: <base64 encode your secret key>
  DB_USERNAME: <base64 encode your db username> # this will probably be 'postgres'
  DB_PASSWORD: <base64 encode your db password>
```

```deploy/database/secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secrets
type: Opaque
data:
  database: <base64 encode your database name> # I used UUR, this must match the name used in deploy/application/configmap.yaml
  username: <base 64 encode your db username> # this will probably be 'postgres'
  password: <base64 encode your db password>
```
#### Deploy Database
Deploy the database files
```
kubectl apply -f deploy/database/secret.yaml
kubectl apply -f deploy/database/storage.yaml
kubectl apply -f deploy/database/deployment.yaml
kubectl apply -f deploy/database/service.yaml
```
#### Update Application Config Map
Get the cluster ip of the postgres service and add it to the `DB_HOST` data field of `deploy/application/configmap`
```
kubectl get service
```
#### Deploy Application
Deploy the application files
```
kubectl apply -f deploy/application/configmap.yaml
kubectl apply -f deploy/application/secret.yaml.yaml
kubectl apply -f deploy/application/nginxconfig.yaml
kubectl apply -f deploy/application/deployment.yaml
kubectl apply -f deploy/application/service.yaml
```
#### Database Migration
If a database migration is required ssh on to one of the application containers and run:
```
python manage.py migrate auth
python manage.py makemigrations
python manage.py migrate
```
## Networking Configuration
---
- The ingress to the cluster is at `https://uurapi.com`
- A port forward is setup to send requests over port 80 and port 443 to the control plane which is also acting as a nodeport service.
## Test
---
You should now have the application up an running. To test you can run.
```
curl uurapi.com/quotes/
```
This should return a json object imbued with the wisdom of Dr Ricken Lazlo Hale, PhD.