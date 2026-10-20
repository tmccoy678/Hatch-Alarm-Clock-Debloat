#!/bin/sh

set -eu

bundle_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)

for command_name in shairport-sync lame uhttpd uci nginx; do
    command -v "$command_name" >/dev/null 2>&1 || {
        echo "Missing required command: $command_name" >&2
        exit 1
    }
done

backup_once() {
    source_path=$1
    backup_path="${source_path}.before-rose"
    if [ -e "$source_path" ] && [ ! -e "$backup_path" ]; then
        cp -p "$source_path" "$backup_path"
    fi
}

backup_once /etc/asound.conf
backup_once /etc/shairport-sync.conf
backup_once /etc/nginx/gl-conf.d/rose-relay.conf

cp "$bundle_dir/etc/asound.conf" /etc/asound.conf
cp "$bundle_dir/etc/shairport-sync.conf" /etc/shairport-sync.conf
mkdir -p /www/rose-relay/cgi-bin
mkdir -p /etc/nginx/gl-conf.d
cp "$bundle_dir/www/health.txt" /www/rose-relay/health.txt
cp "$bundle_dir/www/cgi-bin/stream.mp3" /www/rose-relay/cgi-bin/stream.mp3
cp "$bundle_dir/etc/init.d/rose-relay-http" /etc/init.d/rose-relay-http
cp "$bundle_dir/etc/nginx/gl-conf.d/rose-relay.conf" /etc/nginx/gl-conf.d/rose-relay.conf
chmod 755 /www/rose-relay/cgi-bin/stream.mp3 /etc/init.d/rose-relay-http

uci set shairport-sync.shairport_sync_file.enabled='1'
uci set shairport-sync.shairport_sync.enabled='0'
uci commit shairport-sync

/etc/init.d/rose-relay-http enable
/etc/init.d/rose-relay-http restart
nginx -t
nginx -s reload
/etc/init.d/shairport-sync enable
/etc/init.d/shairport-sync restart
