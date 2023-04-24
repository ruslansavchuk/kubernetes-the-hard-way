# Трохи про мережу в кубернетесі

Давайте спробуємо запустити нджінкс
Як і раніше ми просто покладемо правильний файл у правильне місце

```bash
cat <<EOF> /etc/kubernetes/manifests/static-nginx.yml
apiVersion: v1
kind: Pod
metadata:
  name: static-nginx
  labels:
    app: static-nginx
spec:
  hostNetwork: true
  containers:
  - name: nginx
    image: nginx
EOF
```

можна навіть перевірити чи контейнер хапустивсь
```bash
curl localhost
```

```
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

```bash
crictl pods
```

```
POD ID              CREATED              STATE               NAME                          NAMESPACE           ATTEMPT             RUNTIME
e8720dee2b08b       About a minute ago   Ready               static-nginx-example-server   default             0                   (default)
```

так, це ж контейнер, тут все чотко, можна щось робити і все має працювати 
давайте створимо ще 1

```bash
cat <<EOF> /etc/kubernetes/manifests/static-nginx-2.yml
apiVersion: v1
kind: Pod
metadata:
  name: static-nginx-2
  labels:
    app: static-nginx-2
spec:
  hostNetwork: true
  containers:
  - name: nginx
    image: nginx
EOF
```

але стаять, а як ми на нього потрапимо, із першим все було просто ми просто пішли на 80 порт, хоча також питання зо там взагалі відбулось

поки не особо ясно, але у нас є чотка утіліта для дебага
то давайте глянемо що там за контейнери існують

```bash
crictl ps -a
```

```
CONTAINER           IMAGE               CREATED             STATE               NAME                ATTEMPT             POD ID
9e8cb98b87aed       6efc10a0510f1       42 seconds ago      Exited              nginx               3                   b013eca0e9d33
0e47618b39c09       6efc10a0510f1       4 minutes ago       Running             nginx               0                   e8720dee2b08b
```

такс, що за неподобство, чому 1 контейнер не запущений, давайте розбиратись, і куди першим ділом потрібно лізти, звісно у логи

```bash
crictl logs $(crictl ps -q -s Exited)
```

```
...
2023/04/18 20:49:47 [emerg] 1#1: bind() to 0.0.0.0:80 failed (98: Address already in use)
nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address already in use)
...
```

такс, біда, це що виходить що ми не можемо запусти 2 нджінкса?
всьо розхожимось, докер в 100 раз лучше)))
але ні, не все так просто

справа в тому що окім всього існує ще такий собі стандарт який говорить як алаштовувати мережу для контейнера - CNI
а ми його поки ніяким чином не конфігурували, і похорошому всі ті контейнери не мали б створитись якби не 1 чіт, ми їх всіх створювали у хостівій мережі, так якби ми просто запускаємо якусь програму, тож давайте зараз налаштуємо якийсь мережевий плагін

```bash
wget -q --show-progress --https-only --timestamping \
  https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-amd64-v0.9.1.tgz
```

```bash
sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin
```

```bash
sudo tar -xvf cni-plugins-linux-amd64-v0.9.1.tgz -C /opt/cni/bin/
```

```bash
cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.4.0",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "10.240.1.0/24"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF
```

```bash
cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.4.0",
    "name": "lo",
    "type": "loopback"
}
EOF
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
  --network-plugin=cni \\
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
  sudo systemctl restart kubelet
}
```

```bash
sudo systemctl status kubelet
```

ну що, давайте щось запустимо

```bash
cat <<EOF> /etc/kubernetes/manifests/static-nginx-2.yml
apiVersion: v1
kind: Pod
metadata:
  name: static-nginx-2
  labels:
    app: static-nginx-2
spec:
  # hostNetwork: true
  containers:
  - name: nginx
    image: ubuntu/nginx
EOF
```

```bash
crictl pods
```

```bash
crictl ps
```

такс, воно то все звісно добре, але як отимати айпішнік
ну тут потрібно трохи пошаманити

```bash
PID=$(crictl pods --label app=static-nginx-2 -q)
CID=$(crictl ps -q --pod $PID)
crictl exec $CID ip a
```

...
3: cnio0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether c2:44:0d:6d:17:61 brd ff:ff:ff:ff:ff:ff
    inet 10.240.1.1/24 brd 10.240.1.255 scope global cnio0
       valid_lft forever preferred_lft forever
    inet6 fe80::c044:dff:fe6d:1761/64 scope link
       valid_lft forever preferred_lft forever
...
```

пам'ятаємо що ми створювали підмережу 10.240.1.0/24 при конфігураціїх нашого плагіну
знаючи що контейнер у нас такий поки 1 можна і підбором (із 1) вибрати айішнік

```bash
curl 10.240.1.1
```

```
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

думаю для гарантії потрібно ще 1 контейнер створити

```bash
cat <<EOF> /etc/kubernetes/manifests/static-nginx-3.yml
apiVersion: v1
kind: Pod
metadata:
  name: static-nginx-3
  labels:
    app: static-nginx-3
spec:
  # hostNetwork: true
  containers:
  - name: nginx
    image: ubuntu/nginx
EOF
```

```bash
PID=$(crictl pods --label app=static-nginx-3 -q)
CID=$(crictl ps -q --pod $PID)
crictl exec $CID ip a
```

```bash
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
3: eth0@if9: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 26:24:72:70:b7:9f brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.240.1.7/24 brd 10.240.1.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::2424:72ff:fe70:b79f/64 scope link
       valid_lft forever preferred_lft forever
```

отримуємо потрібний нам айпі

такс, тепер ми знайємо щу у 1 контейнера 1 айпішнік а у іншого інший
тепер прийшов час подивитись чи можуть вони комунікувати між собою

```bash
crictl exec -it $CID bash
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

```bash
PID=$(crictl pods --label app=static-pod -q)
CID=$(crictl ps -q --pod $PID)
crictl exec -it $CID sh

wget -O - 10.240.1.7
exit
```

ну і тепер все почистити після себе


```bash
rm /etc/kubernetes/manifests/static-*
```