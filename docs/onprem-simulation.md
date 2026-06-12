# On-prem simulation (VM + Docker + Ansible)

## Why

Azure Container Apps is the preferred cloud runtime. The VM path exists to show
that the **same container image** also runs on a generic Docker host — i.e. the
app is portable to an on-prem or VM-based environment with no code changes. It
is intentionally simple: one VM, one public IP, Docker, one container.

## What Terraform creates

`infra/modules/vm-onprem-sim` provisions a minimal Ubuntu 22.04 VM:

- Resource group `rg-weather-<env>-onprem` (separate from the ACA RG)
- VNet + subnet, public IP, NIC
- NSG allowing SSH (22) and the app port (8000)
- A small burstable VM (`Standard_B1s` by default), SSH-key auth only

Outputs: `vm_public_ip`, `admin_username`, `ssh_command`, `app_url`.

## What Ansible does

`ansible/playbooks/deploy-weather-app.yml` (run as a normal SSH user with
`become`):

1. Installs Docker and the Python Docker SDK.
2. Ensures Docker is running and enabled on boot.
3. (Optional) logs in to ACR if registry credentials are supplied.
4. Runs the weather container with `restart_policy: always`, publishing
   `<app_port>:8000`, and sets the non-secret env vars.
5. Polls `/api/health` until it returns 200.

## Step by step

```bash
# 1. Provision the VM
export WEATHER_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)"
export WEATHER_SSH_CIDR="$(curl -s ifconfig.me)/32"
cd infra/live/dev/vm-onprem-sim
terragrunt apply
VM_IP=$(terragrunt output -raw vm_public_ip)

# 2. Point the inventory at the VM
#    Edit ansible/inventories/dev.ini -> replace REPLACE_WITH_VM_IP with $VM_IP
#    and REPLACE_WITH_ACR_LOGIN_SERVER with your ACR login server.

# 3. Deploy the image
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook -i ansible/inventories/dev.ini \
  ansible/playbooks/deploy-weather-app.yml \
  -e app_image="<acr-login-server>/weather-api:<tag>"

# 4. Verify
curl "http://$VM_IP:8000/api/health"
```

## Inventory

`ansible/inventories/{dev,staging,prod}.ini` are templates. Each must be edited
to contain the real VM IP, the SSH user (`azureuser`), and the private key path.
The `app_image` and `app_port` are set as `[weather:vars]`.

## Notes

- The inventory IP is a manual step (or scripted from `terragrunt output`); the
  pipeline's VM path expects the inventory to already hold the IP.
- The private key never lives in the repo: locally it's your `~/.ssh` key; in
  the pipeline it's an Azure DevOps **secure file**.
- This is a *simulation* — no load balancer, no autoscaling, no
  high-availability. For real production, prefer the Container Apps path.
