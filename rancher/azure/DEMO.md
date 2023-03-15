# SUSE Rancher with Intel Security

In this demo we will demonstrate Intel(R) SGX TEchnology in action in SuSe Rancher. 

We will install Intel's Kubernetes Device Plugins for SGX and Trusted Certificate Service (TCS).

Then, we will Install Istio service mesh and configure TCS as an external CA to Istio control plane. 

With this setup, the external CA private keys are never exposed in clear in the Kubernetes cluster. The keys are protected via SGX enclave and remanins encrypted during rest, transit and use.

## Prerequisites

### Hardware

- Kubernetes cluster with at least one node with Intel SGX (Intel Xeon 3rd generation, or later). 
- On Azure, you can use Azure DCsv3 VM SKUs or confidential computing nodes.

### SGX Device permissions

On the SGX node ensure that the SGX device has the proper permissions.

```bash
sudo chmod 666 /dev/sgx_enclave
```

### Cert manager

```bash
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.11.0 \
  --set installCRDs=true
```

### Node Feature Discovery (NFD)

```bash
helm install nfd nfd/node-feature-discovery \
  --namespace node-feature-discovery --create-namespace --version 0.12.1 \
  --set 'master.extraLabelNs={gpu.intel.com,sgx.intel.com}' \
  --set 'master.resourceLabels={gpu.intel.com/millicores,gpu.intel.com/memory.max,gpu.intel.com/tiles,sgx.intel.com/epc}'
```

## Demo Install

From the rancher UI: select a workload cluster you want to use

Install the following applications.

### Device Plugin Operator

1. Apps > Charts > Filter > Intel > Select: Intel Device Plugin Operator
2. Press `Install`
3. Namespace > Create a New Namespace > `intel-system`
4. Press `Next`
5. Press `Install`

### SGX device Plugin

1. Apps > Charts > Filter > Intel > Select: Intel SGX Device Plugin
2. Press `Install`
3. Namespace > `intel-system`
4. Press `Next`
5. In the YAML file, change line 10 from "nodeFeatureRule: `false`" to "nodeFeatureRule: `true`"
6. Press `Install`

### Trusted Certificate Issuer (TCS)

1. Apps > Charts > Filter > Intel > Select: Intel Trusted Certificate Issuer
2. Press `Install`
3. Namespace > `intel-system`
4. Press `Next`
5. Press `Install`

### Istio

For Istio, we need to generate confuguration which uses the TCS as an external CA.

To generate config file `istio-custom-ca.yaml`, run the below script.

```bash
./generate-istio-config.sh
```

1. Press `Cluster Tools` on bottom left corner.
2. Select `Istio` and press `Install`
3. Press `Next`
4. Uncheck `Enabled Kiali` and `Enabled Telemetry`
5. Select `Custom Overlay File` 
6. Select `Read from File` and select the generated `istio-custom-ca.yaml` file
7. Press `Install`

## Verification

Monitor the Kubernetes Certificate Signing Requests (CSR) from istiod to TCS.

```bash
kubectl get csr -A -w
```

1. Check the CA signer's private key and very that is empty (hidden inside the SGX enclave)

Storage > Secrets > namespace: intel-system > `sgx-signer-secret` > Private Key <Empty>

You can also use the CLI to check the empty key:

```bash
kubectl get tcsclusterissuers.tcs.intel.com sgx-signer -o jsonpath='{.spec.secretName}' | xargs kubectl get secret -n intel-system -o jsonpath='{.spec.data.tls\.key}'
```

Check the CA signer's certificate

1. Storage > Secrets > namespace: intel-system > `sgx-signer-secret` > Certificate > Copy
2. Save the certificate to a file ca.pem
3. Decode the ca.pem: `openssl x509 -in ca.pem -noout -text`
3. Check the issuer: `Issuer: O=Intel(R) Corporation, CN=SGX self-signed root certificate authority`

Deploy sample application (sleep/default)

```bash
kubectl label namespace default istio-injection=enabled
kubectl apply -f https://raw.githubusercontent.com/istio/istio/master/samples/sleep/sleep.yaml
```

Check the CSRs are being sent to TCS from istiod, and are signed:

```bash
NAME                              AGE   SIGNERNAME                                  REQUESTOR                                   REQUESTEDDURATION   CONDITION
csr-workload-nlqn6f6xxp5jr5xvfb   0s    tcsclusterissuer.tcs.intel.com/sgx-signer   system:serviceaccount:istio-system:istiod   <none>              Pending
csr-workload-nlqn6f6xxp5jr5xvfb   0s    tcsclusterissuer.tcs.intel.com/sgx-signer   system:serviceaccount:istio-system:istiod   <none>              Approved
csr-workload-nlqn6f6xxp5jr5xvfb   0s    tcsclusterissuer.tcs.intel.com/sgx-signer   system:serviceaccount:istio-system:istiod   <none>              Approved,Issued
csr-workload-nlqn6f6xxp5jr5xvfb   0s    tcsclusterissuer.tcs.intel.com/sgx-signer   system:serviceaccount:istio-system:istiod   <none>              Approved,Issued
```

## Demo Uninstall

From the Rancher UI, delete the above.





