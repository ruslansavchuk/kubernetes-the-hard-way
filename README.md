# Kubernetes The Hard Way

This tutorial is partially based on [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way).

The main focus of this tutorial is to explain the necessity of Kubernetes components. That is why there is no need to configure multiple instances of each component and allow us to set up a single-node Kubernetes cluster. Of course, the cluster created can't be used as a production-ready Kubernetes cluster.

To configure the cluster mentioned, we will use Ubuntu server 20.04 (author uses the VM in Hetzner).

## Copyright

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a> (whatever it means).

# Labs

* [Cluster architecture](./docs/00-kubernetes-architecture.md)
* [Container runtime](./docs/01-container-runtime.md)
* [Kubelet](./docs/02-kubelet.md)
* [Pod networking](./docs/03-pod-networking.md)
* [ETCD](./docs/04-etcd.md)
* [Api Server](./docs/05-apiserver.md)
* [Apiserver - Kubelet integration](./docs/06-apiserver-kubelet.md)
* [Controller manager](./docs/07-controller-manager.md)
* [Scheduler](./docs/08-scheduler.md)
* [Kube proxy](./docs/09-kubeproxy.md)
* [DNS in Kubernetes](./docs/10-dns.md)
