# DNS in Kubernetes

As we saw in previous section, kubernetes has special component to solve service discovery issues. But we solved it only partially. 

In this section we will figure out with the next part of the service discovery.

If you remember, in previous section we accessed service by using its IP address. But it solves the issue only partially, as we still need to know the service IP address. To solve second part of it - we will configure DNS server in kubernetes.

> In Kubernetes, DNS (Domain Name System) is a crucial component that enables service discovery and communication between various resources within a cluster. DNS allows you to refer to services, pods, and other Kubernetes objects by their domain names instead of IP addresses, making it easier to manage and communicate between them.

Befire we will configure it, we can check if we can access our service (created in previuos section) by its name.

```bash
kubectl exec busy-box -- wget -O - nginx-service
```

And nothing happen. The reason of this befaviour - pod can't resolve IP address of the domain name requested as DNS server is not configured in our cluster. 

Also, would like to mention, that kubernetes automatically configure DNS system in pod to use "special" DNS server configured for our cluster, this DNS server was configured using during setting up kubelet
```
...
clusterDNS:
  - "10.32.0.10"
...
```

We will configure DNS server with the usage of the coredns, and will install it using out kubernetes cluster
```bash
kubectl apply -f https://raw.githubusercontent.com/ruslansavchuk/kubernetes-the-hard-way/master/manifests/coredns.yml -n kube-system
```

After our DNS server is up and running, we can try to repeat the call once again
```bash
kubectl exec busy-box -- wget -O - nginx-service
```

Output:
```
Hello from pod: nginx-deployment-68b9c94586-zh9vn
Connecting to nginx-service (10.32.0.230:80)
writing to stdout
-                    100% |********************************|    50  0:00:00 ETA
written to stdout
```

As you can see everything works as expected.
