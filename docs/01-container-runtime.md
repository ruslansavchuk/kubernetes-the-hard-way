# Container runtime

In this part of our tutorial we will focus of the container runtime.

![image](./img/01_cluster_architecture_container_runtime.png "Container runtime")

Firt of all, container runtime is a tool which can be used by other kubernetes components (kubelet) to manage containers. In case if we have two parts of the system which communicate - we need to have some specification. Nad tehre is the cpecification - CRI.

> The CRI is a plugin interface which enables the kubelet to use a wide variety of container runtimes, without having a need to recompile the cluster components.

In this tutorial we will use [containerd](https://github.com/containerd/containerd) as tool for managing the containers on the node.

On other hand there is a project under the Linux Foundation - OCI. 
> The OCI is a project under the Linux Foundation is aims to develop open industry standards for container formats and runtimes. The primary goal of OCI is to ensure container portability and interoperability across different platforms and container runtime implementations. The OCI has two main specifications, Runtime Specification (runtime-spec) and Image Specification (image-spec).

In this tutorial we will use [runc](https://github.com/opencontainers/runc) as tool for running containers.

Now, we can start with the configuration.

## runc

Lets download runc binaries

```bash
wget -q --show-progress --https-only --timestamping \
  https://github.com/opencontainers/runc/releases/download/v1.0.0-rc93/runc.amd64
```

As download process complete, we need to move runc binaries to bin folder

```bash
{
    sudo mv runc.amd64 runc
    chmod +x runc 
    sudo mv runc /usr/local/bin/
}
```

Now, as we have runc installed, we can run busybox container

```bash
{
mkdir -p ~/busybox-container/rootfs/bin
cd ~/busybox-container/rootfs/bin
wget https://www.busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-x86_64
chmod +x busybox-x86_64
./busybox-x86_64 --install .
cd ~/busybox-container
runc spec
sed -i 's/"sh"/"echo","Hello from container runned by runc!"/' config.json
}
```

Now, we created all proper files, required by runc to run the container (including container confguration and files which will be accesible from container).

```bash
runc run busybox
```

Output:
```
Hello from container runned by runc!
```

Great, everything works, now we need to clean up our workspace
```bash
{
cd ~
rm -r busybox-container
}
```

## containerd

As already mentioned, Container Runtime: The software responsible for running and managing containers on the worker nodes. The container runtime is responsible for pulling images, creating containers, and managing container lifecycles

Now, let's download containerd.

```bash
wget -q --show-progress --https-only --timestamping \
  https://github.com/containerd/containerd/releases/download/v1.4.4/containerd-1.4.4-linux-amd64.tar.gz
```

Unzip containerd binaries to the bin directory

```bash
{
    mkdir containerd
    tar -xvf containerd-1.4.4-linux-amd64.tar.gz -C containerd
    sudo mv containerd/bin/* /bin/
}
```

In comparison to the runc, containerd is a service which can be called by someone to run container.

Before we will run containerd service, we need to configure it.
```bash
{
sudo mkdir -p /etc/containerd/

cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
EOF
}
```

As we can see, we configured containerd to use runc (we installed before) to run containers.

Now we can configure contanerd service
```bash
cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
```

Run service
```bash
{
  sudo systemctl daemon-reload
  sudo systemctl enable containerd
  sudo systemctl start containerd
}
```

Ensure if service is in running state
```bash
sudo systemctl status containerd
```

We should see the output like this
```
● containerd.service - containerd container runtime
     Loaded: loaded (/etc/systemd/system/containerd.service; enabled; vendor preset: enabled)
     Active: active (running) since Sat 2023-04-15 21:04:43 UTC; 59s ago
       Docs: https://containerd.io
    Process: 1018 ExecStartPre=/sbin/modprobe overlay (code=exited, status=0/SUCCESS)
   Main PID: 1031 (containerd)
      Tasks: 9 (limit: 2275)
     Memory: 22.0M
     CGroup: /system.slice/containerd.service
             └─1031 /bin/containerd
...
```

As we have running containerd service, we can run some containers.

To do that, we need the tool called [ctr](//todo), it is distributed as part of containerd. 

Lets pull busbox image
```bash
sudo ctr images pull docker.io/library/busybox:latest
```

And check if it is presented on our server
```bash
ctr images ls
```

Output:
```
REF                              TYPE                                                      DIGEST                                                                  SIZE    PLATFORMS                                                                                                                          LABELS
docker.io/library/busybox:latest application/vnd.docker.distribution.manifest.list.v2+json sha256:b5d6fe0712636ceb7430189de28819e195e8966372edfc2d9409d79402a0dc16 2.5 MiB linux/386,linux/amd64,linux/arm/v5,linux/arm/v6,linux/arm/v7,linux/arm64/v8,linux/mips64le,linux/ppc64le,linux/riscv64,linux/s390x -
```

Now, lets start our container.
```bash
ctr run --rm --detach docker.io/library/busybox:latest busybox-container sh -c 'echo "Hello from container runned by containerd!"'
```

Output:
```bash
Hello from container runned by containerd!
```

Now, lets clean-up.
```bash
ctr task rm busybox-container
```

Next: [Kubelet](./docs/02-kubelet.md)




















Ну раз так то доавайте його втановимо

Потрібо виключити свап і переконатись що він виключений

```bash
sudo swapon --show
```

```bash
sudo swapoff -a
```

Тепер давайте завантажимо всі необхідні бінарні файли для того щоб встановити наш кублєт
```bash
wget -q --show-progress --https-only --timestamping \
  https://github.com/opencontainers/runc/releases/download/v1.0.0-rc93/runc.amd64 \
  https://github.com/containerd/containerd/releases/download/v1.4.4/containerd-1.4.4-linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubelet
```

Тепер починаємо робиратись із тим що і для чього ми тільки що завантажували
1. runc - штука яка власне і запускаю контейнери, так давайте її перенесемо куда потрібно
```bash
{
    sudo mv runc.amd64 runc
    chmod +x runc 
    sudo mv runc /usr/local/bin/
}
```


2. containerd - штука яка використовується кублетом для запуску контейнерів, він рансі відрізняється тим що контейнерді уже вміє окрім запуску самих контейнерів отримувати образи, і робити ще всяких багато різних і цікавих речей, так давайте її відконфігуруємо
```bash
{
    mkdir containerd
    tar -xvf containerd-1.4.4-linux-amd64.tar.gz -C containerd
    sudo mv containerd/bin/* /bin/
}
```

створимо директорію в якій буде лежати конфіг контейнерді
```bash
sudo mkdir -p /etc/containerd/
```

ну і сам конфіг, а у конфігу сказано що використовувати ми будемо рансі
```bash
cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
EOF
```

такс, контейнер ді уже готовий, можна створюватиюніт файл для запуску
```bash
cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
```

ну тепер залишилось тільки запустити сам демон
```bash
{
  sudo systemctl daemon-reload
  sudo systemctl enable containerd
  sudo systemctl start containerd
}
```

щоб переконатись що все запустилось і працює успішно, давайте перевіримо що наш сервіс працює
```bash
sudo systemctl status containerd
```

маємо отримати щось наприкладі
```
● containerd.service - containerd container runtime
     Loaded: loaded (/etc/systemd/system/containerd.service; enabled; vendor preset: enabled)
     Active: active (running) since Sat 2023-04-15 21:04:43 UTC; 59s ago
       Docs: https://containerd.io
    Process: 1018 ExecStartPre=/sbin/modprobe overlay (code=exited, status=0/SUCCESS)
   Main PID: 1031 (containerd)
      Tasks: 9 (limit: 2275)
     Memory: 22.0M
     CGroup: /system.slice/containerd.service
             └─1031 /bin/containerd
...
```

що цікаво, так це то що у нас уже є енджін який вміє запускати контейнери, і мо мощемо щось запустити
так давайте не втрачати час і запустимо бізівокс (штука яка нас буде ще довго супроводжувати)


```bash
wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.21.0/crictl-v1.21.0-linux-amd64.tar.gz
```

для початку спулимо імедж
```bash
sudo ctr images pull docker.io/library/busybox:latest
```

ця команда має показати щось цікаве
```bash
ctr images ls
```

ну і тепер запустимо наш контейнер
```bash
sudo ctr run --rm --detach docker.io/library/busybox:latest busybox-container sh -c 'echo "Hello, World!"'
```

мали побачити що у консоль виелось хело волд

такс ну тереп давайте почистимо з собою
```bash
ctr task rm busybox-container
```
