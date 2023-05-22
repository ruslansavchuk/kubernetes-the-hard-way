# DNS in Kubernetes

Again, it is very interesting to access the service by ip but we know that we can access it by service name
Lets try,

```bash
kubectl exec busy-box -- wget -O - nginx-service
```

and nothing happen

the reason is DNS server which we still not configured

but dns server we can install from kubernetes directly

```bash
kubectl apply -f https://storage.googleapis.com/kubernetes-the-hard-way/coredns-1.8.yaml
```

and try to erpeat

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

great, everything works as expected