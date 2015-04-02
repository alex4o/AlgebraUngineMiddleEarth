#/bin/sh

uwsgi --stop /var/run/uwsgi.pid
uwsgi --yaml conf.yaml
