# Kubelet

![image](./img/02_cluster_architecture_kubelet.png "Kubelet")

In this part of tutorial we will configure (let's say partially) configure kubelet on our server.

As mentioned in the official kubernetes documentation:
> An agent that runs on each node in the cluster. It makes sure that containers are running in a Pod.
> The kubelet takes a set of PodSpecs that are provided through various mechanisms and ensures that the containers described in those PodSpecs are running and healthy.

So, lets set up kubelet and run some pod.

First of all we need to download kubelet binary

```bash
wget -q --show-progress --https-only --timestamping \
  https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubelet
```

Make file exacutable and move to the bin folder

```bash
{
  chmod +x kubelet 
  sudo mv kubelet /usr/local/bin/
}
```

And the last part when configuring kubelet - create service to run kubelet.

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

The main configuration parameters here:
- --container-runtime-endpoint - linux soket on which containerd listed for the requests
- --file-check-frequency - how often kubelet will check for the updates of static pods
- --pod-manifest-path - directory where we will place our pod manifest files

Now, let's start our service
```bash
{
  sudo systemctl daemon-reload
  sudo systemctl enable kubelet
  sudo systemctl start kubelet
}
```

And check service status
```bash
sudo systemctl status kubelet
```

Output:
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

After kubelet service up and running, we can start creating our pods.
To do that we will use static pods feature of kubelet.
> Static Pods are managed directly by the kubelet daemon on a specific node, without the API server observing them. 

Before we will create static pod manifests, we need to create folders where we will place our pods (as we can see from kibelet configuration, it sould be /etc/kubernetes/manifests)

```bash
{
mkdir /etc/kubernetes
mkdir /etc/kubernetes/manifests
}
```

After directory created, we can create static with busybox inside 

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

We can check if containerd runned new container
```bash
ctr tasks ls
```

Output:
```bash
TASK    PID    STATUS
```

Looks like containerd didn't created any containrs yet? 
Of course it may be true, but baed on the output of ctr command we can't answer that question. It is not true (of course it may be true, but based on the output of the ctr command we can't confirm that ////more about that here)

To see containers managed by kubelet lets install [crictl](http://google.com/crictl).
Download binaries
```bash
wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.21.0/crictl-v1.21.0-linux-amd64.tar.gz
```

Install (move to bin folder)
```bash
{
  tar -xvf crictl-v1.21.0-linux-amd64.tar.gz
  chmod +x crictl 
  sudo mv crictl /usr/local/bin/
}
```
And configure a bit
```bash
cat <<EOF> /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
```

And we can finaly get the list of pods running on our server
```bash
crictl pods
```

Outout:
```
POD ID              CREATED             STATE               NAME                        NAMESPACE           ATTEMPT             RUNTIME
16595e954ab3e       8 minutes ago       Ready               static-pod-example-server   default             0                   (default)
```

As we can see our pod is up and running.

Also, we can check the containers running inside our pod
```bash
crictl ps
```

Output:
```
CONTAINER           IMAGE               CREATED             STATE               NAME                ATTEMPT             POD ID
912487fb63f9e       7cfbbec8963d8       10 minutes ago      Running             busybox             0                   16595e954ab3e
```

Looks like our container is in running state.
Lets check its logs.
```bash
crictl logs $(crictl ps -q)
```

Output:
```
Hello from static pod
Hello from static pod
Hello from static pod
...
```

Great, now we can run pods on our server.

Before we will continue, remove our pods running
```bash
rm /etc/kubernetes/manifests/static-pod.yml
```

It takes some time to remove the pods, we can ensure that pod are deleted by running 
```bash
{
crictl pods
crictl ps
}
```

The output shuld be empty.

Next: [Pod networking](./03-pod-networking.md)