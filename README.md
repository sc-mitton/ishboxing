
# Ish Boxing App

## Local Development

Make sure to have supabase installed.

`supabase init`

Start supabase (make sure docker is running).

`supabase start`

Open a webhook tunnel so supabase can be reached from devices.

```
ngrok http 127.0.0.1:54321 --host-header='localhost' --log=stdout > ngrok.log &
sleep 1
export NGROK_TUNNEL=$(grep "url=" ngrok.log | awk -F 'url=' '{print $2}')
sed -i '' -e 's|https.*ngrok.*|'$NGROK_TUNNEL'|g' DebugConfig.xcconfig
sed -i '' -e 's|https://|'https:##'|g' DebugConfig.xcconfig

```

Open xcode, build for a device, now you're good to go!
