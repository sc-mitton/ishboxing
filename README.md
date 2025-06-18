
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

## Docs

### Sending Offer and Receiving Answer

The issue that needs to be delt with during this step is when the user that is trying to be reached is offline. In that case we can alert the user via a push notification, which after tapping it, will
take them to the app.

Steps:
1. Initiator taps a button to start a match, or they enter a "room" where a match has been scheduled
2. Simulatenous to step 1, open a supabase broadcast channel with a generated match id
3. Send a message to the server for who you're trying to connect to (user id) along with a match id
4. Send a push notification to the user (include the match id in the push notification)
5. If the user doesn't acknowledge the push notification within a certain amount of time, it times out
6. If the user does acknowledge the notification then their app is opened
7. Once the app is opened, it connects to the supabse broadcast channel and notifies the other user that they're connected
8. Initiator and sender exchange necessary information over the broadcast channel


### TODO

This app is meant to be a demo of the concept and also a way to feature certain technologies and platforms (Roboflow, etc)

1. Different modes for throwing punches, default would be swiping on the screen, other method
would be closer to the real life game (detecting hand gestures in the camera)
2. Rock paper scissorrs to start match (traditional way), also would require object / gesture detection in the app
3. Onboarding instructions for how to play (could be single page)
    - Rock paper scissors to see who goes first for each round
    - Point, wave, or gesture in whatever direction
    - Try to "dodge" the punch by looking in any direction other than the one your opponent threw the punch
    - The winner of each round is whoever had the longest streak of dodging their opponent's punches
    - The overall winner is the best of 12 rounds
4. Implement TURN server for certain network conditions
5. Allow different sensativities for the match (how fast the user must react)
