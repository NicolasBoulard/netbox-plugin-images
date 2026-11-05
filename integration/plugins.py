# Replaces the NetBox image's /etc/netbox/config/plugins.py.
import os

PLUGINS = [os.environ["PLUGIN_MODULE"]]
