teleport configure \
  --output=file \
  --proxy=teleport.example.com:443 \
  --token=<YOUR_TOKEN> \
  --roles=app \
  --app-name=grafana \
  --app-uri=http://localhost:3000

tctl tokens add \
    --type=app \
    --app-name=uptimekuma \
    --app-uri=http://uptime-kuma:3001

teleport configure \
   --output=file \
   --token=<YOUR_TOKEN> \
   --proxy=isekaijitaku.rip:443 \
   --roles=app \
   --app-name=uptimekuma \
   --app-uri=http://uptime-kuma:3001

teleport configure \
    --app-name=uptimekuma \
    --app-uri=http://uptime-kuma:3001 \
    --output=file \
    --roles=app \
    --token=<YOUR_TOKEN> \
    --proxy=isekaijitaku.rip:443

teleport start --config="$HOME"/.config/app_config.yaml
