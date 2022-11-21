#!/bin/ash
unbound -c /opt/unbound/unbound.conf

nohup /opt/adguardhome/AdGuardHome -c /opt/adguardhome/conf/AdGuardHome.yaml -w /opt/adguardhome/work --no-check-update &

dnscrypt-proxy -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml
