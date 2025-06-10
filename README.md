
# Ish Boxing App

## Local Development

Make sure to have supabase installed

`supabase init`

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
