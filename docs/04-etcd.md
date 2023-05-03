# ETCD

![image](./img/04_cluster_architecture_etcd.png "Kubelet")

це все звісно прикольно але потрібно всетаки почати конфігурувати нормальний кубернетес
а для цього нам потрібно мати базу данних де можуть зберігатись всі необхідні кубернетесу речі

і відповідно почати потрібно із ітісіді

потрібно встановити всі необхідні нам інструменти для генерації сертифікатів
```bash
{
    wget -q --show-progress --https-only --timestamping \
    https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssl \
    https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/1.4.1/linux/cfssljson
    chmod +x cfssl cfssljson
    sudo mv cfssl cfssljson /usr/local/bin/
}
```

тепер потрібно згенерувати сертифікат яким ми будемо підписувати всі інші сертифікати

```bash
{
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca
}
```

Результат:
```
ca-key.pem
ca.csr
ca.pem
```

такс, а тепер нам потрібно згенерувати сертифікат який уже власне буде використовуватись самим ітісіді (але якщо бути точним то не тільки, але про то ми дізнаємось трохи згодом)
```bash
{
HOST_NAME=$(hostname -a)
KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=worker,127.0.0.1,${KUBERNETES_HOSTNAMES},10.32.0.1 \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
}
```

Завантажимо etcd
```
wget -q --show-progress --https-only --timestamping \
  "https://github.com/etcd-io/etcd/releases/download/v3.4.15/etcd-v3.4.15-linux-amd64.tar.gz"
```


Розпакувати і помістити etcd у диреторію /usr/local/bin/
```
{
  tar -xvf etcd-v3.4.15-linux-amd64.tar.gz
  sudo mv etcd-v3.4.15-linux-amd64/etcd* /usr/local/bin/
}
```

```
{
  sudo mkdir -p /etc/etcd /var/lib/etcd
  sudo chmod 700 /var/lib/etcd
  sudo cp ca.pem \
    kubernetes.pem kubernetes-key.pem \
    /etc/etcd/
}
```

```
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name etcd \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --client-cert-auth \\
  --listen-client-urls https://127.0.0.1:2379 \\
  --advertise-client-urls https://127.0.0.1:2379 \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

```bash
{
  sudo systemctl daemon-reload
  sudo systemctl enable etcd
  sudo systemctl start etcd
}
```

```bash
systemctl status etcd
```

```
● etcd.service - etcd
     Loaded: loaded (/etc/systemd/system/etcd.service; enabled; vendor preset: enabled)
     Active: active (running) since Thu 2023-04-20 10:55:03 UTC; 18s ago
       Docs: https://github.com/coreos
   Main PID: 12374 (etcd)
      Tasks: 10 (limit: 2275)
     Memory: 4.2M
     CGroup: /system.slice/etcd.service
             └─12374 /usr/local/bin/etcd --name etcd --cert-file=/etc/etcd/kubernetes.pem --key-file=/etc/
...
```

```
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
```

Результат:
```bash
8e9e05c52164694d, started, etcd, http://localhost:2380, https://127.0.0.1:2379, false
```

Next: [Api Server](./docs/05-apiserver.md)