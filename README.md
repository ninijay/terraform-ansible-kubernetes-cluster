# Terraform+Ansible+LIBVIRT Kubernetes Cluster

## Makefile does not work

Run terraform,
create hosts file manually
run ansible

## dependencies
- libvirt-provider for terraform
- terraform
- ansible
- changed access rights for libvirt
- libvirt + qemo + kvm

## libvirt settings

edit `/etc/libvirt/qemu.conf`:

find the corresponding properties and change their value (also uncomment)

```bash
security_driver = "none"
user = "$YOURUSERNAME"
group = "users"
```

restart:

```bash
sudo systemctl restart libvirtd.service
sudo systemctl restart libvirt-guests.service
#if exists:
sudo systemctl restart libvirt-bin
```

## resolve hostname

to resolve the hostname locally add this to `/etc/systemd/resolved.conf`

```bash
[Resolve]
DNS=172.16.1.1
Domains=~k8s.local # or the specified domain name
```
