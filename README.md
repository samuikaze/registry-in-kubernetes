# Host private Docker registry in self-hosted Kubernetes cluster

- [中文文檔](/docs/zh-TW.md)

## Steps

1. Create folder for registry.

    ```console
    $ sudo mkdir /var/lib/registry
    ```

2. Create `certs` and `auth` folder in order to serve tls certificates and authentication information.

    ```console
    $ cd /var/lib/registry
    $ sudo mkdir certs auth`
    ```

3. Create self-signed TLS certificates or copy exists certificate files to this folder

    > Note: To create self-signed certificates, change `DNS:docker-registry` into what domain name you want, and set the domain name into `/etc/hosts`.

    ```console
    # openssl req -x509 -newkey rsa:4096 -days 365 -nodes -sha256 -keyout certs/tls.key -out certs/tls.crt -subj "/CN=docker-registry" -addext "subjectAltName = DNS:docker-registry"
    ```

4. Create authentication information files. Change `<ACCOUNT>` and `<PASSWORD>` into what you want.

    ```console
    # podman run --rm --entrypoint htpasswd docker.io/httpd:2 -Bbn <ACCOUNT> <PASSWORD> > auth/htpasswd
    ```

5. Start to deploy private Docker registry

    - Using Terraform:

        1. Rename `terraform.tfvars.example` to `terraform.tfvars` and modify value in `terraform.tfvars` file.
        2. Open terminal and change current directory to `terraform`.
        3. Perform `terraform init`.
        4. Perform `terraform apply --auto-approve`.
        5. Done.

    - Using kubectl:

        1. Modify `deployment.yaml` file under `kubernetes`.
        2. Open terminal and change current directory to `kubernetes`.
        3. Perform `kubectl apply -f deployment.yaml`.
        4. Done.

6. Expose private Docker registry service to internet

    1. Modify `ingress-nginx-tcp.yaml` under `kubernetes`
    2. Perform `kubectl apply -f ingress-nginx-tcp.yaml`
    3. Modify nginx ingress deployment, add `'--tcp-services-configmap=$(POD_NAMESPACE)/ingress-nginx-tcp'` to `args`.
    4. Restart nginx ingress deployment.
    5. Add `ingress-nginx-controller` service configuration below to `spec.ports`

        ```yaml
        - name: registry
          protocol: TCP
          port: 5000
          targetPort: 5000
        ```

    6. Done.
    7. To test if the service is working correctly, issue the command below:

        > If registry only have self-signed certificate or have no TLS certificates, add `--tls-verify=false` as argument to podman command will ignore TLS certificate verify.

        ```console
        $ curl -u <ACCOUNT>:<PASSWORD> -X GET http://<K8S_DOMAIN>:5000/v2/_catalog
        $ podman login <K8S_DOMAIN>:5000
        $ podman image push <K8S_DOMAIN>:5000/<IMAGE_NAME>:<VERSION>
        ```

7. If had SELinux installed in server, you need to add allow polocy to SELinux or push/pull will always fail.

    > To disable SELinux, see step 8.

    1. Open terminal and switch to `SELinux` directory
    2. Issue commands below to apply SELinux policy

        > If `sudo` not work, copy `allowregistrypolicy.te` to `/root` folder and login as root to perform there commands.

        ```console
        $ sudo checkmodule -M -m -o allowregistrypolicy.mod allowregistrypolicy.te
        $ sudo semodule_package -o allowregistrypolicy.pp -m allowregistrypolicy.mod
        $ sudo semodule -i allowregistrypolicy.pp
        ```

    3. Perform `podman image push <DOMAIN>/<IMAGE_NAME>:<VERSION>` to test if image can push to registry. If can't, continue to step 4. to 6.
    4. Login as `root`

        ```console
        $ su -
        ```

    5. Export allow policy from SELinux audit log

        ```console
        # audit2allow -a -M allowpolicy < /var/log/audit/audit.log
        ```

    6. Apply policy to SELinux

        ```console
        # semodule -i allowpolicy.pp
        ```

    7. Perform `podman image push <DOMAIN>/<IMAGE_NAME>:<VERSION>` to test if image can push to registry. If can't, do step 4. to 6. until it work.
    8. To disable SELinux (not recommand)，perform `sudo setenforce 0` and set `SELINUX=disabled` in `/etc/selinux/config` file
        > Not recommand to disable SELinux, this will insecure your server.

## References

- [Deploy Your Private Docker Registry as a Pod in Kubernetes](https://medium.com/swlh/deploy-your-private-docker-registry-as-a-pod-in-kubernetes-f6a489bf0180)
- [How To Install A Private Docker Container Registry In Kubernetes](https://towardsdatascience.com/how-to-install-a-private-docker-container-registry-in-kubernetes-eadcfd6e0f27)
- [Deploying Docker Registry on Kubernetes](https://medium.com/geekculture/deploying-docker-registry-on-kubernetes-3319622b8f32)
- [How to run a Public Docker Registry in Kubernetes](https://www.nearform.com/blog/how-to-run-a-public-docker-registry-in-kubernetes/)
- [How to Setup Private Docker Registry in Kubernetes (k8s)](https://www.linuxtechi.com/setup-private-docker-registry-kubernetes/)
- [Deploy a registry server](https://docs.docker.com/registry/deploying/)
- [Configuring a registry](https://docs.docker.com/registry/configuration/)
- [Docker registry deployment](https://kubernetes.github.io/ingress-nginx/examples/docker-registry/)
- [does kubernetes pv recognize namespace when created/queried with kubectl?](https://stackoverflow.com/a/32324374)
- [[Terraform] Input Variables](https://godleon.github.io/blog/DevOps/terraform-input-variables/)
- [[Kubernetes] Persistent Volume (Claim) Overview](https://godleon.github.io/blog/Kubernetes/k8s-PersistentVolume-Overview/)
- [kubernetes_persistent_volume_v1](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/persistent_volume_v1)
- [Exposing TCP and UDP services](https://kubernetes.github.io/ingress-nginx/user-guide/exposing-tcp-udp-services/)
- [How to expose port 22 via NGINX Ingress Controller?](https://stackoverflow.com/a/66371932)
- [How to use private Docker registry?](https://github.com/orgs/community/discussions/26534#discussioncomment-3252253)
- [GitHub Actions: Private registry support for job and service containers](https://github.blog/changelog/2020-09-24-github-actions-private-registry-support-for-job-and-service-containers/)
- [Docker - Restrictions regarding naming image](https://stackoverflow.com/questions/43091075/docker-restrictions-regarding-naming-image)
- [SELinux Policy for OpenShift Containers](https://zhimin-wen.medium.com/selinux-policy-for-openshift-containers-40baa1c86aa5)
- [SELinux, Kubernetes RBAC, and Shipping Security Policies for On-prem Applications](https://platform9.com/blog/selinux-kubernetes-rbac-and-shipping-security-policies-for-on-prem-applications/)
- [為 Container 賦予 SELinux 標籤](https://kubernetes.io/zh-cn/docs/tasks/configure-pod-container/security-context/#%E4%B8%BA-container-%E8%B5%8B%E4%BA%88-selinux-%E6%A0%87%E7%AD%BE)
- [K8s mount PV with SELinux](https://storage-chaos.io/k8s-selinux-mount-pv.html)
- [vxflexos-cni.if - Gist](https://gist.github.com/coulof/9df7c9f3178ecf6706b0c5316ab9de7e)
