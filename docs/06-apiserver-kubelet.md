# Kubelet

![image](./img/06_cluster_architecture_apiserver_kubelet.png "Kubelet")

```bash
{
HOST_NAME=$(hostname -a)
cat > kubelet-csr.json <<EOF
{
  "CN": "system:node:${HOST_NAME}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
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
  -hostname=127.0.0.1,${HOST_NAME} \
  -profile=kubernetes \
  kubelet-csr.json | cfssljson -bare kubelet
}
```

це конфігураційний файл кублєта - розказує кублєту як ходити на апі сервер
```bash
{
HOST_NAME=$(hostname -a)
kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kubelet.kubeconfig

kubectl config set-credentials system:node:${HOST_NAME} \
    --client-certificate=kubelet.pem \
    --client-key=kubelet-key.pem \
    --embed-certs=true \
    --kubeconfig=kubelet.kubeconfig

kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${HOST_NAME} \
    --kubeconfig=kubelet.kubeconfig

kubectl config use-context default --kubeconfig=kubelet.kubeconfig
}
```

```bash
{
  sudo cp kubelet-key.pem kubelet.pem /var/lib/kubelet/
  sudo cp kubelet.kubeconfig /var/lib/kubelet/kubeconfig
  sudo cp ca.pem /var/lib/kubernetes/
}
```

```bash
cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "10.240.1.0/24"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/kubelet.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/kubelet-key.pem"
EOF
```

```bash
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

```bash
{
  sudo systemctl daemon-reload
  sudo systemctl enable kubelet
  sudo systemctl restart kubelet
}
```

```bash
sudo systemctl status kubelet
```

такс, ну і тепер момент істини, потрібно розібратись чи з'явились у нас ноди у кластері

```bash
kubectl get nodes
```

```
NAME             STATUS     ROLES    AGE   VERSION
example-server   NotReady   <none>   6s    v1.21.0
```

ох ти, раз є ноди, маж бути і контейнер
```bash
kubectl get pod
```

```
NAME          READY   STATUS    RESTARTS   AGE
hello-world   1/1     Running   0          8m1s
```

пише що запущений, а що в дійсності?

```bash
crictl pods
```

```
POD ID              CREATED             STATE               NAME                NAMESPACE           ATTEMPT             RUNTIME
1719d0202a5ef       8 minutes ago       Ready               hello-world         default             0                   (default)
```


```bash
crictl ps
```

```
CONTAINER           IMAGE               CREATED             STATE               NAME                    ATTEMPT             POD ID
3f2b0a0d70377       7cfbbec8963d8       8 minutes ago       Running             hello-world-container   0                   1719d0202a5ef
```

навіть логи можна глянути
```bash
crictl logs $(crictl ps -q)
```

```
Hello, World!
Hello, World!
Hello, World!
Hello, World!
...
```

але так не діло логи дивитись
тепер коли ми зрозуміли що сервер наш працює і показує правду - можна користуватись тільки куб сітіель

```bash
kubectl logs hello-world
```

```
Error from server (Forbidden): Forbidden (user=kubernetes, verb=get, resource=nodes, subresource=proxy) ( pods/log hello-world)
```

причина помилки відсутність всяких приколів
давайте їх створимо


```bash
{
cat <<EOF> rbac.yml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-proxy-access
rules:
- apiGroups: [""]
  resources: ["nodes/proxy"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: node-proxy-access-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: node-proxy-access
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: kubernetes
EOF

kubectl apply -f rbac.yml
}
```

```bash
kubectl logs hello-world
```

```
Hello, World!
Hello, World!
Hello, World!
Hello, World!
...
```

ух ти тепер точно все працює, можна користуватись кубернетесом, але стоп у нас все ще є речі які на нашому графіку сірі давайте розбиратись

Next: [Controller manager](./07-controller-manager.md)