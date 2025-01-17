# Pod networking

Now, we know how kubelet runs containers and we know how to run pod without other kubernetes cluster components.

Let's experiment with static pod a bit.

We will create a static pod, but this time we will run nginx, instead of busybox
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
    image: ubuntu/nginx
EOF
```

After the manifest is created we can check whether our nginx container is created

```bash
crictl pods
```

Output:
```
POD ID              CREATED              STATE               NAME                          NAMESPACE           ATTEMPT             RUNTIME
14662195d6829       About a minute ago   Ready               static-nginx-example-server   default             0                   (default)
```

As we can see our nginx container is up and running.
Let's check whether it works as expected.

```bash
curl localhost
```

Output:
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

Now, let's try to create 1 more Nginx container.
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
    image: ubuntu/nginx
EOF
```

Again will try to check if our pod is in a running state

```bash
crictl pods
```

Output:
```
POD ID              CREATED             STATE               NAME                            NAMESPACE           ATTEMPT             RUNTIME
a299a86893e28       40 seconds ago      Ready               static-nginx-2-example-server   default             0                   (default)
14662195d6829       4 minutes ago       Ready               static-nginx-example-server     default             0                   (default)
```

Looks like our pod is up, but if we will try to check the underlying containers we may be surprised.

```bash
crictl ps -a
```

Output:
```
CONTAINER           IMAGE               CREATED             STATE               NAME                ATTEMPT             POD ID
9e8cb98b87aed       6efc10a0510f1       42 seconds ago      Exited              nginx               3                   b013eca0e9d33
0e47618b39c09       6efc10a0510f1       4 minutes ago       Running             nginx               0                   e8720dee2b08b
```

As you can see our second container is in exit state.
To check the reason for the exit state we can review the container logs

```bash
crictl logs $(crictl ps -q -s Exited)
```

Output:
```
...
2023/04/18 20:49:47 [emerg] 1#1: bind() to 0.0.0.0:80 failed (98: Address already in use)
nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address already in use)
...
```

As we can see, the reason for the exit state - the address is already in use.
The Nginx container tries to use the port that is already in use by another (first) Nginx other container.

We received this error because we run two Nginx applications that use the same host. That was done by specifying
```
...
spec:
  hostNetwork: true
...
```

This option says kubelet that containers created should be run on the host without any network isolation (almost the same as running two nginx on the same host without containers)

Now we will try to update our pod manifests to run containers in separate network namespaces
```bash
{
cat <<EOF> /etc/kubernetes/manifests/static-nginx.yml
apiVersion: v1
kind: Pod
metadata:
  name: static-nginx
  labels:
    app: static-nginx
spec:
  containers:
  - name: nginx
    image: ubuntu/nginx
EOF

cat <<EOF> /etc/kubernetes/manifests/static-nginx-2.yml
apiVersion: v1
kind: Pod
metadata:
  name: static-nginx-2
  labels:
    app: static-nginx-2
spec:
  containers:
  - name: nginx
    image: ubuntu/nginx
EOF
}
```

As you can see we removed the "hostNetwork: true" configuration option.

So, let's check what we have
```bash
crictl pods
```

Output:
```
POD ID              CREATED             STATE               NAME                NAMESPACE           ATTEMPT             RUNTIME
```

We see nothing.
To define the reason why no pods were created let's review the logs
```bash
journalctl -u kubelet | grep NetworkNotReady
```

Output:
```
...
May 03 13:43:43 example-server kubelet[23701]: I0503 13:43:43.862719   23701 event.go:291] "Event occurred" object="default/static-nginx-example-server" kind="Pod" apiVersion="v1" type="Warning" reason="NetworkNotReady" message="network is not ready: container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized"
...
```

As we can see cni plugin is not initialized. But what is cni plugin?

> CNI stands for Container Networking Interface. It is a standard for defining how network connectivity is established and managed between containers, as well as between containers and the host system in a container runtime environment. Kubernetes uses CNI plugins to implement networking for pods.

> A CNI plugin is a binary executable that is responsible for configuring the network interfaces and routes of a container or pod. It communicates with the container runtime (such as Docker or CRI-O) to set up networking for the container or pod.

As we can see kubelet can't configure the network for a pod by himself (or with the help of containerd). Same as with containers, to configure a network kubelet uses some 'protocol' to communicate with 'someone' who can configure a network.

Now, we will configure the cni plugin.

First of all, we need to download that plugin

```bash
wget -q --show-progress --https-only --timestamping \
  https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-amd64-v0.9.1.tgz
```

Now, we will create proper folders structure
```bash
sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin
```

here:
- net.d - folder where plugin configuration files stored
- bin - folder for plugin binaries

Now, we will untar the plugin to the proper folder

```bash
sudo tar -xvf cni-plugins-linux-amd64-v0.9.1.tgz -C /opt/cni/bin/
```

And create plugin configuration
```bash
{
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

cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.4.0",
    "name": "lo",
    "type": "loopback"
}
EOF
}
```

Of course, all configuration options here are important, but I want to highlight 2 of them:
- ranges - information about subnets from which IP addresses will be assigned for pods
- routes - information on how to route traffic between nodes. As we have single node kubernetes cluster the configuration is very easy

Update the kubelet config (add network-plugin configuration option)
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

After the kubelet is reconfigured, we can restart it
```bash
{
  sudo systemctl daemon-reload
  sudo systemctl restart kubelet
}
```

And check kubelet status
```bash
sudo systemctl status kubelet
```

Output:
```
● kubelet.service - kubelet: The Kubernetes Node Agent
     Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; vendor preset: enabled)
     Active: active (running) since Wed 2023-05-03 13:53:03 UTC; 15s ago
       Docs: https://kubernetes.io/docs/home/
   Main PID: 86730 (kubelet)
      Tasks: 13 (limit: 2275)
     Memory: 46.8M
     CGroup: /system.slice/kubelet.service
             └─86730 /usr/local/bin/kubelet --container-runtime=remote --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock --image-pull-progress-deadline=2m --file-che>
```

Now, after all fixes applied and we have a working kubelet, we can check whether the pods created
```bash
crictl pods
```

Outout:
```
POD ID              CREATED             STATE               NAME                            NAMESPACE           ATTEMPT             RUNTIME
45feb5b5be77c       2 minutes ago       Ready               static-nginx-2-example-server   default             0                   (default)
b9c684fa20082       2 minutes ago       Ready               static-nginx-example-server     default             0                   (default)
```

Pods are ok, but what about containers
```bash
crictl ps
```

Output:
```
CONTAINER           IMAGE               CREATED             STATE               NAME                ATTEMPT             POD ID
6b1f7855bfdb1       6efc10a0510f1       3 minutes ago       Running             nginx               0                   45feb5b5be77c
1dde689e499bb       6efc10a0510f1       3 minutes ago       Running             nginx               0                   b9c684fa20082
```

They are also in running state

In this step, if we will try to curl localhost, nothing will happen.
Our pods are run in separate network namespaces, and each pod has its own IP address.
We need to define it.

```bash
{
  PID=$(crictl pods --label app=static-nginx-2 -q)
  CID=$(crictl ps -q --pod $PID)
  crictl exec $CID ip a
}
```

Output:
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

During plugin configuration, we remember that we configure the pod's subnet to 10.240.1.0/24. So, the container received its IP from the range specified, in my case, it was 10.240.1.1.

So, let's try to curl the container.
```bash
{
  PID=$(crictl pods --label app=static-nginx-2 -q)
  CID=$(crictl ps -q --pod $PID)
  IP=$(crictl exec $CID ip a | grep 240 | awk '{print $2}' | cut -f1 -d'/')
  curl $IP
}
```

Output:
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

As we can see we successfully reached out container from the host.

But we remember that cni plugin is also responsible to configure communication between containers.
Let's check

To do that we will run 1 more pod with busybox inside
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

Now, let's check and ensure that the pod created

```bash
crictl pods
```

Output:
```
POD ID              CREATED             STATE               NAME                            NAMESPACE           ATTEMPT             RUNTIME
80047283230cc       21 seconds ago      Ready               static-pod-example-server       default             0                   (default)
a6881b7bba036       18 minutes ago      Ready               static-nginx-example-server     default             0                   (default)
4dd70fb8f5f53       18 minutes ago      Ready               static-nginx-2-example-server   default             0                   (default)
```

As the pod is in a running state, we can check whether the other nginx pod are available

```bash
{
  PID=$(crictl pods --label app=static-nginx-2 -q)
  CID=$(crictl ps -q --pod $PID)
  IP=$(crictl exec $CID ip a | grep 240 | awk '{print $2}' | cut -f1 -d'/')
  PID_0=$(crictl pods --label app=static-pod -q)
  CID_0=$(crictl ps -q --pod $PID_0)
  crictl exec $CID_0 wget -O - $IP
}
```

Output: 
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
Connecting to 10.240.1.4 (10.240.1.4:80)
writing to stdout
-                    100% |********************************|   615  0:00:00 ETA
written to stdout
```

As we can see we successfully reached our container from busybox.

In this section, we configured the cni plugin. Now we can run pods that can communicate with each other over the network.

Now we clean up the workspace
```bash
rm /etc/kubernetes/manifests/static-*
```

And check if app pods are removed
```bash
crictl pods
```

Output:
```
POD ID              CREATED             STATE               NAME                        NAMESPACE           ATTEMPT             RUNTIME
```

Note: it takes some time to remove all created resources.

Next: [ETCD](./04-etcd.md)