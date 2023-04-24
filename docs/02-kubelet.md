# Static pods

![image](./img/02_cluster_architecture_kubelet.png "Kubelet")

як бачимо контейнери запускаються все працює
прийшла пора розбиратись із kubectl

для початку його потрібно завантажити
```bash
wget -q --show-progress --https-only --timestamping \
  https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubelet
```

```bash
{
  chmod +x kubelet 
  sudo mv kubelet /usr/local/bin/
}
```

```bash
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/home/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --file-check-frequency=10s \\
  --pod-manifest-path='/etc/kubernetes/manifests/' \\
  --v=10
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
```

```bash
{
  sudo systemctl daemon-reload
  sudo systemctl enable kubelet
  sudo systemctl start kubelet
}
```

```bash
sudo systemctl status kubelet
```

```
● kubelet.service - kubelet: The Kubernetes Node Agent
     Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; vendor preset: enabled)
     Active: active (running) since Sat 2023-04-15 22:01:06 UTC; 2s ago
       Docs: https://kubernetes.io/docs/home/
   Main PID: 16701 (kubelet)
      Tasks: 7 (limit: 2275)
     Memory: 14.8M
     CGroup: /system.slice/kubelet.service
             └─16701 /usr/local/bin/kubelet --container-runtime=remote --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock --image-pull-progress-deadline=2m --v=2
...
```

# run static pod
знач нам потрбіно створити директорію для маніфестів
```bash
mkdir /etc/kubernetes
mkdir /etc/kubernetes/manifests
```


```bash
cat <<EOF> /etc/kubernetes/manifests/static-pod.yml
apiVersion: v1
kind: Pod
metadata:
  name: static-pod
  labels:
    app: static-pod
spec:
  hostNetwork: true
  containers:
  - name: busybox
    image: busybox
    command: ["sh", "-c", "while true; do echo 'Hello from static pod'; sleep 5; done"]
EOF
```

а тепепр поки він його знайде і запустить, ми встановимо crictl
```bash
wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.21.0/crictl-v1.21.0-linux-amd64.tar.gz
```

```bash
{
  tar -xvf crictl-v1.21.0-linux-amd64.tar.gz
  chmod +x crictl 
  sudo mv crictl /usr/local/bin/
}
```

трохи відконфігуруємо
```bash
cat <<EOF> /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
```

ну і тепер поки все встановлювалось то наш под мав піднятись
спробуємо подивитись
```bash
crictl pods
```

тут є жжназва сервера
```
POD ID              CREATED             STATE               NAME                                    NAMESPACE           ATTEMPT             RUNTIME
884c50605b546       9 minutes ago       Ready               static-pod-example-server   default             0                   (default)
```

і контейнери
```bash
crictl ps
```

```
CONTAINER           IMAGE               CREATED             STATE               NAME                ATTEMPT             POD ID
4cc95ba71e9d6       7cfbbec8963d8       10 minutes ago      Running             busybox             0                   884c50605b546
```

ну і також можна глянути логи
```bash
crictl logs $(crictl ps -q)
```

```
Hello from static hostNetwork pod
Hello from static hostNetwork pod
Hello from static hostNetwork pod
Hello from static hostNetwork pod
Hello from static hostNetwork pod
Hello from static hostNetwork pod
Hello from static hostNetwork pod
Hello from static hostNetwork pod
Hello from static hostNetwork pod
Hello from static hostNetwork pod
```

такс, ну на цьому нам потрібно почитити все після себе

```bash
rm /etc/kubernetes/manifests/static-pod.yml
```

тепер має видалитись контейнер, але потрібно трохи почекати
```bash
crictl ps
```

тут пусто

```bash
crictl pods
```

і тут з часом також має стати пусто

ну всьо, на цьому на сьогодні все поки
далі будемо розбиратись із іншими компонентами кудетнетесу