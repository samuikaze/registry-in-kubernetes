# 在 Kubernetes 中架設私有 Docker Registry

實際上將 registry 架設到 Kubernetes 中並沒有什麼好處，除非想要流量有統一的出入口 (Kubernetes ingress)，否則仍然建議直接將 registry 架設在 Docker 或 Podman 中就好

1. 建立 `registry` 資料夾

    ```console
    # mkdir /var/lib/registry
    ```

2. 建立 `certs` 與 `auth` 資料夾，分別存放 TLS 憑證與身分驗證資料

    ```console
    # cd /var/lib/registry/
    # mkdir certs auth
    ```

3. 建立 TLS 憑證，或將既有的憑證寫到 Kubernetes secrets 中

    - 沒有憑證者可以先建立自簽憑證憑證，`<REGISTRY_DOMAIN>` 請改為正確的 registry 網域名稱

    > 若是要使用於正式環境中，建議使用 Let's encrypt 的憑證，或自己去申請一張憑證

    ```console
    # openssl req -x509 -newkey rsa:4096 -days 365 -nodes -sha256 -keyout certs/tls.key -out certs/tls.crt -subj "/CN=<REGISTRY_DOMAIN>" -addext "subjectAltName = DNS:<REGISTRY_DOMAIN>"
    ```

    - `<REGISTRY_DOMAIN>` 若為自己定義的網域名稱，請透過下列指令設定到 `/etc/hosts` 檔案中

        ```console
        # echo <IP_ADDRESS> <REGISTRY_DOMAIN> > /etc/hosts
        ```

    - 將 crt 檔案內容以 Base64 編碼取代 `kubernetes/deployment.yaml` 檔案中的 `<TLS_CERT_WITH_B64_ENCODED>` 區塊，將 key 檔案內容以 Base64 編碼取代同檔案中的 `<TLS_KEY_WITH_B64_ENCODED>` 區塊

    > Linux 可以使用 `cat <TARGET_FILE_PATH> | base64` 將檔案內容轉換為 Base64 編碼，但須先安裝 base64 套件

4. 設定 registry 登入的帳號密碼

    - 建立身分驗證檔案，`<帳號>` 與 `<密碼>` 請更改為自己想要的帳號密碼

        ```console
        # podman run --rm --entrypoint htpasswd docker.io/httpd:2 -Bbn <帳號> <密碼> > auth/htpasswd
        ```

    - 將 `htpasswd` 內容以 Base64 編碼後取代 `kubernetes/deployment.yaml` 檔案中的 `<HTPASSWD_CONTENT_WITH_B64_ENCODED>` 區塊

    > Linux 可以使用 `cat <TARGET_FILE_PATH> | base64` 將檔案內容轉換為 Base64 編碼，但須先安裝 base64 套件

5. 若有安裝 SELinux，需對其設定允許策略

    > 如欲關閉 SELinux，請跳至步驟 8.

    1. 打開終端機並切換到 `SELinux` 資料夾
    2. 使用下面指令套用 SELinux 策略

        > 若 `sudo` 無作用, 請切換登入的使用者為 root ，切換到正確的資料夾路徑後再執行下面的指令

        ```console
        # checkmodule -M -m -o allowregistrypolicy.mod allowregistrypolicy.te
        # semodule_package -o allowregistrypolicy.pp -m allowregistrypolicy.mod
        # semodule -i allowregistrypolicy.pp
        ```

    3. 使用 `podman image push <DOMAIN>/<IMAGE_NAME>:<VERSION>` 測試映像是否可以正確被推到儲存庫中，若仍無法推送或拉取映像，請繼續進行 4. ~ 6. 步驟
    4. 切換使用者為 `root`

        ```console
        $ su -
        ```

    5. 使用指令匯出需要允許的策略

        ```console
        # audit2allow -a -M allowpolicy < /var/log/audit/audit.log
        ```

    6. 打開 `allowpolicy.te` 與 `allowregistrypolicy.te` 做比較，看 `container_var_lib_t` 在 `allowpolicy.te` 檔中是什麼名稱，把它取代成該名稱後，進行步驟 2. 重新套用策略。
    7. 使用 `podman image push <DOMAIN>/<IMAGE_NAME>:<VERSION>` 測試映像是否可以正確被推到儲存庫中，若仍無法，重複 4. ~ 6. 步驟直到可以正常推送為止
    8. 若要直接關閉 SELinux (極不推薦)，則使用指令 `sudo setenforce 0` 並修改 `/etc/selinux/config` 中的 `SELINUX=disabled` 就可以關閉 SELinux 了
        > **極不推薦** 關閉 SELinux，這會讓伺服器暴露於危險之中，且[會讓 Dan Walsh 傷心](https://stopdisablingselinux.com/)。

6. 開始部署私有 Docker Registry
    > 如果是以 Helm 安裝 ingress-nginx，請直接編輯 Helm 的 yaml 檔

    - 使用 Terraform

        1. 重新命名 `terraform.tfvars.example` 為 `terraform.tfvars` 並修改 `terraform.tfvars` 檔案中變數的值修改為正確的值
        2. 打開終端機並切換到 `terraform` 資料夾下
        3. 執行指令 `terraform init`
        4. 執行指令 `terraform apply --auto-approve`
        5. 完成

    - 使用 kubectl

        1. 修改 `kubernetes` 資料夾下的 `deployment.yaml` 檔，將檔案中變數的值修改為正確的值
            > 可以將 `deployment.yaml` 更名為 `deployment.real.yaml`，這份檔案就不會再進版控
        2. 打開終端機並切換到 `kubernetes` 資料夾下
        3. 執行指令 `kubectl apply -f deployment.yaml`
        4. 完成

7. 將私有儲存庫暴露到網際網路上

    1. 修改 `kubernetes` 資料夾下的 `ingress-config.yaml` 檔，將命名空間與應用程式名稱填入

        > 可以將 `ingress-config.yaml` 更名為 `ingress-config.real.yaml`，這份檔案就不會再進版控

    2. 執行指令 `kubectl apply -f ingress-config.real.yaml`

        > 執行前請先調整 yaml 檔中埠號的設定，這個設定值須與 `kubernetes` 資料夾下所有 yaml 檔中的 `<PROXIED_PORT_NUMBER>` 值相同

    3. 修改 nginx ingress 的 deployment，將 `'--tcp-services-configmap=$(POD_NAMESPACE)/ingress-nginx-tcp'` 加到 `args` 下

    4. 完成，可利用 `curl -u <帳號>:<密碼> -X GET http://<REGISTRY_DOMAIN>:<PROXIED_PORT_NUMBER>/v2/_catalog` 或 `podman login -u <帳號> -p <密碼> <REGISTRY_DOMAIN>:<PROXIED_PORT_NUMBER>` 測試服務是否正常
        > 若 registry 沒有 TLS 憑證或僅有自簽的 TLS 憑證，則將 `--tls-verify=false` 當作參數傳入到 podman 的相關指令可以使 podman 忽略 TLS 憑證驗證
        > 同理 curl 在沒有 TLS 憑證或僅有自簽的 TLS 憑證的情況下，參數多帶 `-k` 即可讓 curl 忽略 TLS 憑證的驗證
        > Image push 一定要測試，由於是 Container 要直接寫資料到實體硬碟路徑上，SELinux 會阻擋此類狀況發生，這會導致 image 無法正常上傳到 registry 中

        ```console
        $ curl -u <帳號>:<密碼> -X GET http://<REGISTRY_DOMAIN>:<PROXIED_PORT_NUMBER>/v2/_catalog
        $ podman login <REGISTRY_DOMAIN>:<PROXIED_PORT_NUMBER>
        $ podman image push <REGISTRY_DOMAIN>:<PROXIED_PORT_NUMBER>/<映像名稱>:<版本>
        ```

    5. 若私有映像儲存庫未使用 TLS 憑證，則須做下列的設定，使 Kubernetes 可以透過 HTTP 協定登入儲存庫或拉取映像

        > 若私有儲存庫需要暴露到網際網路上，仍然建議使用 TLS 憑證以保護儲存庫與客戶端間的連線安全

        > 下面的說明僅適用於 Kubernetes 安裝於 Rocky Linux 9 且以 crio 當作容器的 runtime

        - 打開終端機並輸入 `service status crio` 以找出 `crio.service` 檔案位置
        - 使用文字編輯器打開 `crio.service` 檔案，並將下列的文字加到 `ExecStart` 區塊中

            > 請將 `<YOUR_PRIVATE_REGISTRY>` 取代為正確的值

            ```txt
            --insecure-registry=<YOUR_PRIVATE_REGISTRY> \
            --registry=<YOUR_PRIVATE_REGISTRY> \
            ```

        - 儲存並關閉檔案
        - 在終端機中依序執行 `systemctl daemon-reload` 與 `service crio restart` 指令重啟 crio 服務
        - 現在可以正常使用 HTTP 通訊協定從私有儲存庫中拉取映像了

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
- [Stop Disabling SELinux](https://stopdisablingselinux.com/)
- [Mounting a Kubernetes Secret as a single file inside a Pod](https://www.jeffgeerling.com/blog/2019/mounting-kubernetes-secret-single-file-inside-pod)
- [建立一個可以通過卷存取 Secret 資料的 Pod](https://kubernetes.io/zh-cn/docs/tasks/inject-data-application/distribute-credentials-secure/#create-a-pod-that-has-access-to-the-secret-data-through-a-volume)
- [How do I mount a single file from a secret in Kubernetes?](https://stackoverflow.com/a/53296198)
- [Distribution Registry - Configuring a registry - debug](https://distribution.github.io/distribution#debug)
- [設定存活、就緒和啟動探針](https://kubernetes.io/zh-cn/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Kubernetes: Issues with liveness / readiness probe on S3 storage hosted Docker Registry](https://stackoverflow.com/q/61103591)
