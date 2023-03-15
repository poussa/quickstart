export NS=intel-system
export CA_SIGNER_NAME=sgx-signer
export CA_SIGNER=tcsclusterissuer.tcs.intel.com/sgx-signer
cat << EOF > istio-custom-ca.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  components:
    pilot:
      k8s:
        env:
          - name: CERT_SIGNER_DOMAIN
            value: tcsclusterissuer.tcs.intel.com
          - name: EXTERNAL_CA
            value: ISTIOD_RA_KUBERNETES_API
          - name: PILOT_CERT_PROVIDER
            value: k8s.io/$CA_SIGNER
        overlays:
          - kind: ClusterRole
            name: istiod-clusterrole-istio-system
            patches:
              - path: rules[-1]
                value: |
                  apiGroups:
                  - certificates.k8s.io
                  resourceNames:
                  - tcsclusterissuer.tcs.intel.com/*
                  resources:
                  - signers
                  verbs:
                  - approve
  meshConfig:
    defaultConfig:
      proxyMetadata:
        PROXY_CONFIG_XDS_AGENT: "true"
        ISTIO_META_CERT_SIGNER: sgx-signer
    caCertificates:
    - pem: |
$(kubectl get secret -n ${NS} ${CA_SIGNER_NAME}-secret -o jsonpath='{.data.tls\.crt}' |base64 -d | sed -e 's;\(.*\);        \1;g')
      certSigners:
      - $CA_SIGNER
EOF

