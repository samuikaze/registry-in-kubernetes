# 在 Kubernetes 中架設私有 Docker Registry

1. 建立 `registry` 資料夾

    ```console
    $ sudo mkdir /var/lib/registry
    ```

2. 建立 `certs` 與 `auth` 資料夾，分別存放 TLS 憑證與身分驗證資料

    ```console
    $ cd /var/lib/registry
    $ sudo mkdir certs auth`
    ```

3. 建立 TLS 憑證，或將既有的憑證複製到此資料夾中

    > ※ 如欲建立自簽憑證，`DNS:docker-registry` 請改為自己想要的 DNS 名稱，稍後會直接設定到 `/etc/hosts` 檔案中

    ```console
    # openssl req -x509 -newkey rsa:4096 -days 365 -nodes -sha256 -keyout certs/tls.key -out certs/tls.crt -subj "/CN=docker-registry" -addext "subjectAltName = DNS:docker-registry"
    ```

4. 建立身分驗證檔案，`<帳號>` 與 `<密碼>` 請更改為自己想要的帳號密碼

    ```console
    # podman run --rm --entrypoint htpasswd docker.io/httpd:2 -Bbn <帳號> <密碼> > auth/htpasswd
    ```

5. 開始部署私有 Docker Registry

    - 使用 Terraform

        1. 重新命名 `terraform.tfvars.example` 為 `terraform.tfvars` 並修改 `terraform.tfvars` 檔案中變數的值修改為正確的值
        2. 打開終端機並切換到 `terraform` 資料夾下
        3. 執行指令 `terraform init`
        4. 執行指令 `terraform apply --auto-approve`
        5. 完成

    - 使用 kubectl

        1. 修改 `kubernetes` 資料夾下的 `deployment.yaml` 檔，將檔案中變數的值修改為正確的值
        2. 打開終端機並切換到 `kubernetes` 資料夾下
        3. 執行指令 `kubectl apply -f deployment.yaml`
        4. 完成

6. 將私有儲存庫暴露到網際網路上

    1. 修改 `kubernetes` 資料夾下的 `ingress-nginx-tcp.yaml` 檔，將命名空間與應用程式名稱填入
    2. 執行指令 `kubectl apply -f ingress-nginx-tcp.yaml`
    3. 修改 nginx ingress 的 deployment，將 `'--tcp-services-configmap=$(POD_NAMESPACE)/ingress-nginx-tcp'` 加到 `args` 下
    4. 重新佈署 nginx ingress 的 Pod
    5. 完成，可利用 `curl -u <帳號>:<密碼> -X GET http://<K8s 存取網址>:5000/v2/_catalog` 測試服務是否正常

7. 若有安裝 SELinux，需對其設定允許策略

    > 如欲關閉 SELinux，請跳至步驟 5.

    1. 切換使用者為 `root`

        ```console
        $ su -
        ```

    2. 使用指令匯出需要允許的策略

        ```console
        # audit2allow -a -M allowpolicy < /var/log/audit/audit.log
        ```

    3. 使用指令套用允許策略

        ```console
        # semodule -i allowpolicy.pp
        ```

    4. 使用 `podman image push <DOMAIN>/<IMAGE_NAME>:<VERSION>` 測試映像是否可以正確被推到儲存庫中，若仍無法，重複 1. ~ 3. 步驟直到可以正常推送為止
    5. 若要直接關閉 SELinux (極不推薦)，則使用指令 `sudo setenforce 0` 就可以關閉 SELinux 了
        > **極不推薦** 關閉 SELinux，這會讓伺服器暴露於危險之中。

## 參考資料

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
