# Host private Docker registry in self-hosted Kubernetes cluster

Host private Docker registry in self-hosted Kubernetes cluster has no any benefit.

Unless you want manage all traffic in one place, it is recommanded to host Docker registry in Docker or Podman and expose registry to internet directly.

- [中文文檔](/docs/zh-TW.md)

## Steps

1. Create folder for registry.

    ```console
    # mkdir /var/lib/registry
    ```

2. Create `certs` and `auth` folder in order to serve tls certificates and authentication information.

    ```console
    # cd /var/lib/registry
    # mkdir certs auth
    ```

3. Create self-signed TLS certificates or copy exists certificate files to this folder

    - you can create self-signed TLS certificates if you don't have. Change `<REGISTRY_DOMAIN>` into what domain you want below.

    > It is recommanded using Let's encrypt TLS certificates or to apply one TLS certificate by yourself when using registry in production environment.

    ```console
    # openssl req -x509 -newkey rsa:4096 -days 365 -nodes -sha256 -keyout certs/tls.key -out certs/tls.crt -subj "/CN=<REGISTRY_DOMAIN>" -addext "subjectAltName = DNS:<REGISTRY_DOMAIN>"
    ```

    - Set it to `/etc/hosts` using command below if `<REGISTRY_DOMAIN>` is not a real domain on internet.

        ```console
        # echo <IP_ADDRESS> <REGISTRY_DOMAIN> > /etc/hosts
        ```

    - Replace `<TLS_CERT_WITH_B64_ENCODED>` in `kubernetes/deployment.yaml` with crt file contents with base64 encoded, and replace `<TLS_KEY_WITH_B64_ENCODED>` in the same file with key file contents with base64 encoded.

    > You can use `cat <TARGET_FILE_PATH> | base64` command to converting file content into base64 encoded string. Package base64 needs to be installed first.

4. Configurate authenticate credentials
    - Create authentication information files. Change `<ACCOUNT>` and `<PASSWORD>` into what you want.

        ```console
        # podman run --rm --entrypoint htpasswd docker.io/httpd:2 -Bbn <ACCOUNT> <PASSWORD> > auth/htpasswd
        ```

    - Replace `<HTPASSWD_CONTENT_WITH_B64_ENCODED>` in `kubernetes/deployment.yaml` file with htpasswd file content with base64 encoded

    > You can use `cat <TARGET_FILE_PATH> | base64` command to converting file content into base64 encoded string. Package base64 needs to be installed first.

5. If had SELinux installed in server, you need to add allow polocy to SELinux or push/pull will always fail.

    > To disable SELinux, see step 8.

    1. Open terminal and switch to `SELinux` directory
    2. Issue commands below to apply SELinux policy

        > If `sudo` not work, login as root then perform these commands again.

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

    6. Open `allowpolicy.te` and compare to `allowregistrypolicy.te` file. Replaces `container_var_lib_t` into what names in `allowpolicy.te` file and do step 2. to re-apply policy.
    7. Perform `podman image push <DOMAIN>/<IMAGE_NAME>:<VERSION>` to test if image can push to registry. If can't, do step 4. to 6. until it work.
    8. To disable SELinux (not recommand)，perform `sudo setenforce 0` and set `SELINUX=disabled` in `/etc/selinux/config` file
        > Not recommand to disable SELinux, this will insecure your server, and [make Dan Walsh weep](https://stopdisablingselinux.com/).

6. Start to deploy private Docker registry

    > Edit the configuration in Helm yaml if you install your ingress-nginx using Helm.

    - Using Terraform:

        1. Rename `terraform.tfvars.example` to `terraform.tfvars` and modify value in `terraform.tfvars` file.
        2. Open terminal and change current directory to `terraform`.
        3. Perform `terraform init`.
        4. Perform `terraform apply --auto-approve`.
        5. Done.

    - Using kubectl:

        1. Modify `deployment.yaml` file under `kubernetes`.
            > To prevent the edited file be commited to repository, you can copy and rename the file `deployment.yaml` into `deployment.real.yaml`.
        2. Open terminal and change current directory to `kubernetes`.
        3. Perform `kubectl apply -f deployment.yaml`.
        4. Done.

7. Expose private Docker registry service to internet

    1. Modify `ingress-config.yaml` under `kubernetes`
        > To prevent the edited file be commited to repository, you can copy and rename the file `ingress-config.yaml` into `ingress-config.real.yaml`.
    2. Perform `kubectl apply -f ingress-config.yaml`
        > Before apply the command, edit the yaml file with correct expose port number. The port number needs to be same as `<PROXIED_PORT_NUMBER>` in all yaml files in `kubernetes` directory.
    3. Modify nginx ingress deployment, add `'--tcp-services-configmap=$(POD_NAMESPACE)/ingress-nginx-tcp'` to `args`.
    4. Restart nginx ingress deployment.
    5. Done.
    6. To test if the service is working correctly, issue the command below:

        > If registry only have self-signed certificate or have no TLS certificates, add `--tls-verify=false` as argument to podman or add `-k` as argument to curl command will ignore TLS certificate verify.

        > It is recommaned to test image push and pull due to registry container needs to write to physical hard disk. Some security tool like SELinux does not allow this.

        ```console
        $ curl -u <ACCOUNT>:<PASSWORD> -X GET http://<REGISTRY_DOMAIN>:<PROXIED_PORT_NUMBER>/v2/_catalog
        $ podman login <REGISTRY_DOMAIN>:<PROXIED_PORT_NUMBER>
        $ podman image push <REGISTRY_DOMAIN>:<PROXIED_PORT_NUMBER>/<IMAGE_NAME>:<VERSION>
        ```

    7. If you don't have any TLS certificates on your registry, you need to configure your cluster to use http protocol when authenticating or pulling images from your private registry

        > If your registry needs to expose to internet, using TLS certificates to secure your connection between registry and client is recommanded.

        > This only for Kubernetes is installed on Rocky Linux 9 and using crio as its container runtime.

        - Open terminal and issue `service status crio` command to find out where `crio.service` file is located.
        - Using text editor to open `crio.service` file and insert lines below into `ExecStart` block.

            > Replace `<YOUR_PRIVATE_REGISTRY>` with the correct text.

            ```txt
            --insecure-registry=<YOUR_PRIVATE_REGISTRY> \
            --registry=<YOUR_PRIVATE_REGISTRY> \
            ```

        - Save and close the file.
        - Issue `systemctl daemon-reload` and `service crio restart` to restart crio service.
        - Here you go! Images can be pulled from your private registry without tls certificates.

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
- [Stop Disabling SELinux](https://stopdisablingselinux.com/)
- [Mounting a Kubernetes Secret as a single file inside a Pod](https://www.jeffgeerling.com/blog/2019/mounting-kubernetes-secret-single-file-inside-pod)
- [建立一個可以通過卷存取 Secret 資料的 Pod](https://kubernetes.io/zh-cn/docs/tasks/inject-data-application/distribute-credentials-secure/#create-a-pod-that-has-access-to-the-secret-data-through-a-volume)
- [How do I mount a single file from a secret in Kubernetes?](https://stackoverflow.com/a/53296198)
- [Distribution Registry - Configuring a registry - debug](https://distribution.github.io/distribution#debug)
- [設定存活、就緒和啟動探針](https://kubernetes.io/zh-cn/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Kubernetes: Issues with liveness / readiness probe on S3 storage hosted Docker Registry](https://stackoverflow.com/q/61103591)
