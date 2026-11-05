---
layout: home

hero:
  name: NetBox Plugin Images
  text: Plugins mounted, not built in.
  tagline: One OCI image per plugin, mounted into official NetBox as a Kubernetes image volume.
  image:
    src: /favicon.svg
    alt: ""
  actions:
    - theme: brand
      text: Get started
      link: /usage
    - theme: alt
      text: Browse plugins
      link: /catalog

features:
  - title: Official NetBox, untouched
    details: Upgrade NetBox by changing one tag. Plugins stay separate images with their own versions.
  - title: Nothing to install at startup
    details: The kubelet pulls plugin images like any other. No PyPI access from the cluster, no init container.
  - title: Tested before publishing
    details: Every image boots the NetBox release it targets, with PostgreSQL and Valkey, and must load and migrate.
  - title: Kubernetes native
    details: Plugins are plain image volumes declared in the pod spec. No custom operator, no sidecar, no extra tooling.
---
