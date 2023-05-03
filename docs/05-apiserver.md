# апі сервер

![image](./img/05_cluster_architecture_apiserver.png "Kubelet")

так як ми уже налаштували бд - можна починати налаштовувати і сам куб апі сервер, будемо пробувати щось четапити

```bash
{
cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
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
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account
}
```

```bash
{
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
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
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin
}
```

```
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
```

```bash
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
```

```
sudo mkdir -p /etc/kubernetes/config
```

```
wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kube-apiserver"
```

```
{
  chmod +x kube-apiserver
  sudo mv kube-apiserver /usr/local/bin/
}
```

```
{
  sudo mkdir -p /var/lib/kubernetes/

  sudo cp \
    ca.pem \
    kubernetes.pem kubernetes-key.pem \
    encryption-config.yaml \
    service-account-key.pem service-account.pem \
    /var/lib/kubernetes/
}
```

```
sudo mkdir -p /etc/kubernetes/config
```


```bash
ADVERTISE_IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -f1 -d'/')

cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address='${ADVERTISE_IP}' \\
  --allow-privileged='true' \\
  --audit-log-maxage='30' \\
  --audit-log-maxbackup='3' \\
  --audit-log-maxsize='100' \\
  --audit-log-path='/var/log/audit.log' \\
  --authorization-mode='Node,RBAC' \\
  --bind-address='0.0.0.0' \\
  --client-ca-file='/var/lib/kubernetes/ca.pem' \\
  --enable-admission-plugins='NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota' \\
  --etcd-cafile='/var/lib/kubernetes/ca.pem' \\
  --etcd-certfile='/var/lib/kubernetes/kubernetes.pem' \\
  --etcd-keyfile='/var/lib/kubernetes/kubernetes-key.pem' \\
  --etcd-servers='https://127.0.0.1:2379' \\
  --event-ttl='1h' \\
  --encryption-provider-config='/var/lib/kubernetes/encryption-config.yaml' \\
  --kubelet-certificate-authority='/var/lib/kubernetes/ca.pem' \\
  --kubelet-client-certificate='/var/lib/kubernetes/kubernetes.pem' \\
  --kubelet-client-key='/var/lib/kubernetes/kubernetes-key.pem' \\
  --runtime-config='api/all=true' \\
  --service-account-key-file='/var/lib/kubernetes/service-account.pem' \\
  --service-cluster-ip-range='10.32.0.0/24' \\
  --service-node-port-range='30000-32767' \\
  --tls-cert-file='/var/lib/kubernetes/kubernetes.pem' \\
  --tls-private-key-file='/var/lib/kubernetes/kubernetes-key.pem' \\
  --service-account-signing-key-file='/var/lib/kubernetes/service-account-key.pem' \\
  --service-account-issuer='https://kubernetes.default.svc.cluster.local' \\
  --api-audiences='https://kubernetes.default.svc.cluster.local' \\
  --v='2'
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

```bash
{
  sudo systemctl daemon-reload
  sudo systemctl enable kube-apiserver
  sudo systemctl restart kube-apiserver
}
```

```bash
sudo systemctl status kube-apiserver
```

```
● kube-apiserver.service - Kubernetes API Server
     Loaded: loaded (/etc/systemd/system/kube-apiserver.service; enabled; vendor preset: enabled)
     Active: active (running) since Thu 2023-04-20 11:04:29 UTC; 22s ago
       Docs: https://github.com/kubernetes/kubernetes
   Main PID: 12566 (kube-apiserver)
      Tasks: 8 (limit: 2275)
     Memory: 291.6M
     CGroup: /system.slice/kube-apiserver.service
             └─12566 /usr/local/bin/kube-apiserver --advertise-address=91.107.220.4 --allow-privileged=true --apiserver-count=3 --audit-log-maxage=30 --audit-log-maxbackup=3 --audit-log-m>
...
```

```bash
wget -q --show-progress --https-only --timestamping \
  https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubectl \
  && chmod +x kubectl \
  && sudo mv kubectl /usr/local/bin/
```

```
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem \
    --embed-certs=true

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=admin

  kubectl config use-context default
}
```

```bash
kubectl version --kubeconfig=admin.kubeconfig
```

тепер можна починати створбвати поди і все має чотко працювати

```bash
{
HOST_NAME=$(hostname -a)

cat <<EOF> pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello-world
spec:
  serviceAccountName: hello-world
  containers:
    - name: hello-world-container
      image: busybox
      command: ['sh', '-c', 'while true; do echo "Hello, World!"; sleep 1; done']
  nodeName: ${HOST_NAME}
EOF

cat <<EOF> sa.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hello-world
automountServiceAccountToken: false
EOF

kubectl apply -f sa.yaml --kubeconfig=admin.kubeconfig
kubectl apply -f pod.yaml --kubeconfig=admin.kubeconfig
}
```

```bash
kubectl get pod --kubeconfig=admin.kubeconfig
```

```
NAME          READY   STATUS    RESTARTS   AGE
hello-world   0/1     Pending   0          29s
```

такс под є але він у статусі пендінг, якесь неподобство
в дійсності, зоч у нас кублєт і є але він про сервер нічого незнає а сервер про нього
потрібно цю проблємку вирішити

Next: [Apiserver - Kubelet integration](./docs/06-apiserver-kubelet.md)