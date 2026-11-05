# Usage

::: warning Requirements
Kubernetes 1.36+ ([image volumes](https://v1-36.docs.kubernetes.io/docs/concepts/storage/volumes/#image)).
:::

The Helm example uses the official community chart,
[netbox-community/netbox-chart](https://github.com/netbox-community/netbox-chart). Pass the values
with `helm install netbox oci://ghcr.io/netbox-community/netbox-chart/netbox -f values.yaml`.

::: code-group

```yaml [Helm chart]
# values.yaml for the netbox-community/netbox-chart chart: the worker loads the same plugins.
plugins:
  - netbox_dns

extraVolumes:
  - &plugin-dns
    name: netbox-plugin-dns
    image:
      reference: ghcr.io/nicolasboulard/netbox-plugin-images/netbox-plugin-dns:1.7.3
      pullPolicy: IfNotPresent
extraVolumeMounts:
  - &plugin-dns-mount
    name: netbox-plugin-dns
    mountPath: /opt/netbox/plugins/netbox-plugin-dns
    readOnly: true
extraEnvs:
  - &plugins-path
    name: PYTHONPATH
    value: /opt/netbox/plugins/netbox-plugin-dns

worker:
  extraVolumes: [*plugin-dns]
  extraVolumeMounts: [*plugin-dns-mount]
  extraEnvs: [*plugins-path]
```

```yaml [Plain Kubernetes]
# Add netbox_dns to PLUGINS in the NetBox configuration.
spec:
  containers:
    - name: netbox
      image: ghcr.io/netbox-community/netbox:v4.7.4
      env:
        - name: PYTHONPATH
          value: /opt/netbox/plugins/netbox-plugin-dns
      volumeMounts:
        - name: netbox-plugin-dns
          mountPath: /opt/netbox/plugins/netbox-plugin-dns
          readOnly: true
  volumes:
    - name: netbox-plugin-dns
      image:
        reference: ghcr.io/nicolasboulard/netbox-plugin-images/netbox-plugin-dns:1.7.3
        pullPolicy: IfNotPresent
```

```dockerfile [Dockerfile]
# Without Kubernetes: copy the plugin into your own NetBox image.
FROM ghcr.io/netbox-community/netbox:v4.7.4
COPY --from=ghcr.io/nicolasboulard/netbox-plugin-images/netbox-plugin-dns:1.7.3 / /opt/netbox/plugins/netbox-plugin-dns/
ENV PYTHONPATH=/opt/netbox/plugins/netbox-plugin-dns
```

:::

## Several plugins

One volume and one mount per plugin, and every mount path in `PYTHONPATH`, separated by `:`:

```yaml
- name: PYTHONPATH
  value: /opt/netbox/plugins/netbox-plugin-dns:/opt/netbox/plugins/another-plugin
```

Each plugin's database tables are created by NetBox's own migrations when it starts.

::: tip Pick versions that match
A plugin's minor version targets one NetBox minor: the [catalog](./catalog) shows which.
Upgrade NetBox and its plugins together.
:::
