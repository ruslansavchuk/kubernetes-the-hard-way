# Kube-proxy

In this section we will configure kupe-proxy.
> kube-proxy is a network proxy that runs on each node in your cluster, implementing part of the Kubernetes Service concept.
> kube-proxy maintains network rules on nodes. These network rules allow network communication to your Pods from network sessions inside or outside of your cluster.

![image](./img/09_cluster_architecture_proxy.png "Kubelet")

Before we will start, lets clarify the reason why do we need it. To do that, we will create deployment with nginx.
```bash
{
cat <<EOF> nginx-deployment.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-conf
data:
  default.conf: |
    server {
        listen 80;
        server_name _;
        location / {
            return 200 "Hello from pod: \$hostname\n";
        }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 3
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21.3
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-conf
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: nginx-conf
        configMap:
          name: nginx-conf
EOF

kubectl apply -f nginx-deployment.yml
}
```

```bash
kubectl get pod -o wide
```

Output:
```
NAME                               READY   STATUS    RESTARTS   AGE   IP            NODE             NOMINATED NODE   READINESS GATES
nginx-deployment-db9778f94-2zv7x   1/1     Running   0          63s   10.240.1.12   example-server   <none>           <none>
nginx-deployment-db9778f94-q5jx4   1/1     Running   0          63s   10.240.1.10   example-server   <none>           <none>
nginx-deployment-db9778f94-twx78   1/1     Running   0          63s   10.240.1.11   example-server   <none>           <none>
```

As you an see, we created 3 pods (each has its own ip address). Now, we will run busybox container and will try to access our pods from other container
```bash
{
cat <<EOF> pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: busy-box
spec:
  containers:
    - name: busy-box
      image: busybox
      command: ['sh', '-c', 'while true; do echo "Busy"; sleep 1; done']
EOF

kubectl apply -f pod.yaml
}
```

And execute command from our container
```bash
kubectl exec busy-box -- wget -O - $(kubectl get pod -o wide | grep nginx | awk '{print $6}' | head -n 1)
```

Output:
```
error: unable to upgrade connection: Forbidden (user=kubernetes, verb=create, resource=nodes, subresource=proxy)
```

This error occured, because api server has no access to execute commands. We will fix this issue, by creating cluster role and assigning it role to kubernetes user. 
```bash
{
cat <<EOF> rbac-create.yml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kubernetes-user-clusterrole
rules:
- apiGroups: [""]
  resources: ["nodes/proxy"]
  verbs: ["create"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kubernetes-user-clusterrolebinding
subjects:
- kind: User
  name: kubernetes
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: kubernetes-user-clusterrole
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f rbac-create.yml
}
```

Now, we can execute command
```bash
kubectl exec busy-box -- wget -O - $(kubectl get pod -o wide | grep nginx | awk '{print $6}' | head -n 1)
```

Output:
```
Hello from pod: nginx-deployment-68b9c94586-qkwjc
Connecting to 10.32.0.230 (10.32.0.230:80)
writing to stdout
-                    100% |********************************|    50  0:00:00 ETA
written to stdout
```

Note: usually, it takes some time to apply all RBAC policies

Note: it take some time to apply user permission. During this you can steel see permission error.

As you can see, we successfully received the response from the nginx. But to do that we used the IP address of the pod. To solve service discovery issue, kubernetes has special component - service. Now we will create it.
```bash
{
cat <<EOF> nginx-service.yml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
EOF

kubectl apply -f nginx-service.yml
}
```

Get service created
```bash
kubectl get service
```

Now, we will try to access our pods by using the IP of the service created.
```bash
kubectl exec busy-box -- wget -O - $(kubectl get service -o wide | grep nginx | awk '{print $3}')
```

Output:
```
Connecting to 10.32.0.230 (10.32.0.230:80)
```

As you can see, we received an error. This error occured because kubernetes know nothing about the IP creted for the service. As already mentioned, kube-proxy is the component responsible to handle requests to ip of the service and redirect that requests to the pods. So, lets configure kube-proxy.

## certificates

We will start with certificates.

As you remeber we configured our API server to use client certificate to authenticate user.
So, lets create proper certificate for the kube-proxy
```bash
{
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
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
  kube-proxy-csr.json | cfssljson -bare kube-proxy
}
```

The most interesting configuration options:
- cn(common name) - value, api server will use as a client name during authorization
- o(organozation) - user group system:node-proxier will use during authorization

We specified "system:node-proxier" in the organization. It says api server that the client who uses which certificate belongs to the system:node-proxier group.

## configuration

After the certificate files created we can create configuration files for the kube proxy.
```bash
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=kube-proxy.pem \
    --client-key=kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
}
```

We created kubernetes configuration file, which says kube-proxy where api server is configured and which certificates to use communicating with it

Now, we can distribute created configuration file.

```bash
{
  sudo mkdir -p /var/lib/kube-proxy
  sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
}
```

After all required configuration file created, we need to download kube-proxy binaries.

```bash
wget -q --show-progress --https-only --timestamping \
  https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kube-proxy
```

And install it
```bash
{    
  chmod +x kube-proxy 
  sudo mv kube-proxy /usr/local/bin/
}
```

Now, we can create configuration file for kube-proxy
```bash
cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF
```

Service configuration file
```bash
cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

Start service
```bash
{
  sudo systemctl daemon-reload
  sudo systemctl enable kube-proxy
  sudo systemctl start kube-proxy
}
```

And check its status
```bash
sudo systemctl status kube-proxy
```

Output:
```
● kube-proxy.service - Kubernetes Kube Proxy
     Loaded: loaded (/etc/systemd/system/kube-proxy.service; enabled; vendor preset: enabled)
     Active: active (running) since Thu 2023-04-20 13:37:27 UTC; 23s ago
       Docs: https://github.com/kubernetes/kubernetes
   Main PID: 19873 (kube-proxy)
      Tasks: 5 (limit: 2275)
     Memory: 10.0M
     CGroup: /system.slice/kube-proxy.service
             └─19873 /usr/local/bin/kube-proxy --config=/var/lib/kube-proxy/kube-proxy-config.yaml
...
```

## verification

After we configured kube-proxy, we can check how or service works once again.
```bash
kubectl exec busy-box -- wget -O - $(kubectl get service -o wide | grep nginx | awk '{print $3}')
```

Output:
```
Hello from pod: nginx-deployment-68b9c94586-qkwjc
Connecting to 10.32.0.230 (10.32.0.230:80)
writing to stdout
-                    100% |********************************|    50  0:00:00 ETA
written to stdout
```

If you try to repeat the command once again you will see that requests are handled by different pods.

Next: [DNS in Kubernetes](./10-dns.md)