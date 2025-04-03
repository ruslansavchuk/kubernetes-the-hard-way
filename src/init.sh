#!/bin/bash

stage=""

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --stage) 
            stage="$2"
            shift # Remove --last-stage
            shift # Remove the value
            ;;
        *) 
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# init container runtime
if [ "$stage" = "configure-runtime" ]; then
echo '======================  download runc ========================='
wget -q --show-progress --https-only --timestamping \
  https://github.com/opencontainers/runc/releases/download/v1.2.6/runc.amd64

echo '======================  make runc executable ========================='
mv runc.amd64 runc \
  && chmod +x runc \
  && mv runc /usr/local/bin/

echo '======================  download containerd ========================='
wget https://github.com/containerd/containerd/releases/download/v2.0.4/containerd-2.0.4-linux-amd64.tar.gz

echo '======================  make containerd executable ========================='
mkdir containerd \
  && tar -xvf containerd-2.0.4-linux-amd64.tar.gz -C containerd \
  && mv containerd/bin/* /bin/

echo '======================  int containerd service ========================='
mkdir -p /etc/containerd/
cat << EOF | tee /etc/containerd/config.toml
[debug]
  level = "debug"
  
[plugins]
  [plugins.'io.containerd.cri.v1.images']
    snapshotter = "native"
  [plugins."io.containerd.cri.v1.runtime"]
    [plugins."io.containerd.cri.v1.runtime".containerd]
      default_runtime_name = "runc"
      [plugins."io.containerd.cri.v1.runtime".containerd.runtimes]
        [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          snapshotter = "native"

          [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.runc.options]
            BinaryName = "/usr/local/bin/runc"
EOF

cat <<EOF | tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
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

systemctl daemon-reload \
  && systemctl enable containerd \
  && systemctl start containerd

systemctl status containerd
exit 0
elif [ "$stage" = "configure-kubelet" ]; then
echo '======================  download kubelet ========================='
wget -q --show-progress --https-only --timestamping \
  https://dl.k8s.io/v1.32.3/kubernetes-node-linux-amd64.tar.gz
tar -xvzf kubernetes-node-linux-amd64.tar.gz

echo '======================  make kubelet executable ========================='
chmod +x kubernetes/node/bin/kubelet \
  && mv kubernetes/node/bin/kubelet /usr/local/bin/

echo '======================  disable swap ========================='
swapoff -a

echo '======================  int kubelet service ========================='
cat <<EOF | tee /etc/systemd/system/kubelet.service
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/home/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --file-check-frequency=10s \\
  --pod-manifest-path='/etc/kubernetes/manifests/' \\
  --v=10
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload \
  && systemctl enable kubelet \
  && systemctl start kubelet

systemctl status kubelet

echo '======================  download crictl ========================='
wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.32.0/crictl-v1.32.0-linux-amd64.tar.gz
tar -xvf crictl-v1.32.0-linux-amd64.tar.gz \
  && chmod +x crictl \
  && mv crictl /usr/local/bin/

echo '======================  configure crictl ========================='
tar -xvf crictl-v1.32.0-linux-amd64.tar.gz \
  && chmod +x crictl \
  && mv crictl /usr/local/bin/

cat <<EOF | tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

exit 0
# configure networking
elif [ "$stage" = "configure-networking" ]; then
echo '======================  download cni-plugins ========================='
wget -q --show-progress --https-only --timestamping \
  https://github.com/containernetworking/plugins/releases/download/v1.6.2/cni-plugins-linux-amd64-v1.6.2.tgz

echo '======================  configure cni-plugins ========================='
mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin

tar -xvf cni-plugins-linux-amd64-v1.6.2.tgz -C /opt/cni/bin/

cat <<EOF | tee /etc/cni/net.d/10-bridge.conf
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

cat <<EOF | tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.4.0",
    "name": "lo",
    "type": "loopback"
}
EOF

echo '======================  reconfigure cni-plugins ========================='
cat <<EOF | tee /var/lib/kubelet/kubelet-config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  anonymous:
    enabled: true
  webhook:
    enabled: false
authorization:
  mode: AlwaysAllow
networkPlugin: "cni"
cniConfDir: "/etc/cni/net.d"
cniBinDir: "/opt/cni/bin"
EOF

cat <<EOF | tee /etc/systemd/system/kubelet.service
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/home/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --file-check-frequency=10s \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --pod-manifest-path='/etc/kubernetes/manifests/' \\
  --v=10
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload \
  && systemctl restart kubelet

systemctl status kubelet

exit 0

# configure etcd
elif [ "$stage" = "configure-etcd" ]; then
echo '======================  download cert tools ========================='
wget -q --show-progress --https-only --timestamping \
  https://github.com/cloudflare/cfssl/releases/download/v1.4.1/cfssl_1.4.1_linux_amd64 \
  https://github.com/cloudflare/cfssl/releases/download/v1.4.1/cfssljson_1.4.1_linux_amd64

mv cfssl_1.4.1_linux_amd64 cfssl \
  && mv cfssljson_1.4.1_linux_amd64 cfssljson \
  && chmod +x cfssl cfssljson \
  && mv cfssl cfssljson /usr/local/bin/

echo '======================  generate etcd certs ========================='
cat <<EOF | tee ca-config.json 
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

cat <<EOF | tee ca-csr.json
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

HOST_NAME=$(hostname -a)
KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat <<EOF | tee kubernetes-csr.json 
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

echo '======================  download etcd ========================='
wget -q --show-progress --https-only --timestamping \
  "https://github.com/etcd-io/etcd/releases/download/v3.4.15/etcd-v3.4.15-linux-amd64.tar.gz"

echo '======================  configure etcd ========================='
tar -xvf etcd-v3.4.15-linux-amd64.tar.gz \
  && mv etcd-v3.4.15-linux-amd64/etcd* /usr/local/bin/

mkdir -p /etc/etcd /var/lib/etcd \
  && chmod 700 /var/lib/etcd \
  && cp ca.pem kubernetes.pem kubernetes-key.pem /etc/etcd/

cat <<EOF | tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --client-cert-auth \\
  --name etcd \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --listen-client-urls https://127.0.0.1:2379 \\
  --advertise-client-urls https://127.0.0.1:2379 \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload \
  && systemctl enable etcd \
  && systemctl start etcd

systemctl status etcd

exit 0

# configure api server
elif [ "$stage" = "configure-etcd" ]; then

fi
