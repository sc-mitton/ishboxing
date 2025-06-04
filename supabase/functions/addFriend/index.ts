// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import {
  ApnsClient,
  Notification,
  Priority,
  PushType,
} from "@fivesheepco/cloudflare-apns2";

const apnSecret = Deno.env.get("APN_SECRET");
const teamId = Deno.env.get("APPLE_TEAM_ID");
const keyId = Deno.env.get("APPLE_KEY_ID");
const apnServer = Deno.env.get("APN_SERVER");
const apnTopic = Deno.env.get("APN_TOPIC");
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (
  !apnSecret ||
  !teamId ||
  !keyId ||
  !apnServer ||
  !apnTopic ||
  !supabaseUrl ||
  !supabaseKey
) {
  throw new Error(
    "Missing one or more required environment variables: APN_SECRET, APPLE_TEAM_ID, APPLE_KEY_ID, APN_SERVER, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY",
  );
}

const supabase = createClient(supabaseUrl, supabaseKey);

const client = new ApnsClient({
  team: teamId,
  keyId: keyId,
  signingKey: apnSecret,
  host: apnServer,
  defaultTopic: apnTopic,
});

interface FriendRequest {
  friend_id: string;
  from: string;
}

const isFriendRequest = (data: unknown): data is FriendRequest => {
  return (
    typeof data === "object" &&
    data !== null &&
    "friend_id" in data &&
    "from" in data
  );
};

const sendFriendRequestNotification = async (request: FriendRequest) => {
  // Fetch both users' data in a single query
  const { data: users, error } = await supabase
    .from("profiles")
    .select("id, username, apn_tokens!inner(token)")
    .in("id", [request.from, request.friend_id]);

  if (error) {
    console.error("Error fetching users:", error);
    throw error;
  }

  const fromUser = users.find((u) => u.id === request.from);
  const toUser = users.find((u) => u.id === request.friend_id);

  if (!fromUser || !toUser) {
    throw new Error("Could not find both users");
  }

  const notification = new Notification(toUser.apn_tokens[0].token, {
    type: PushType.alert,
    alert: {
      title: "New Friend Request",
      body: `${fromUser.username} wants to be your friend`,
    },
    data: {
      type: "friend_request",
      from: request.from,
      to: request.friend_id,
    },
    priority: Priority.low,
    sound: "default",
    expiration: new Date(Date.now() + 30 * 1000), // 30 seconds
  });

  await client.send(notification);
};

console.log("Hello from Functions!");

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  try {
    const data = await req.json();
    if (!isFriendRequest(data)) {
      return new Response("Invalid payload", { status: 400 });
    }

    // Create the friendship relationship
    const { error: friendshipError } = await supabase
      .from("friends")
      .insert({
        user_id: data.from,
        friend_id: data.friend_id,
        confirmed: false,
      });

    if (friendshipError) {
      console.error("Error creating friendship:", friendshipError);
      return new Response("Error creating friendship", { status: 500 });
    }

    // Send push notification
    try {
      await sendFriendRequestNotification(data);
    } catch (notificationError) {
      console.error("Error sending notification:", notificationError);
      // Don't return error here since the friendship was created successfully
    }

    return new Response("Friend request sent", { status: 200 });
  } catch (err) {
    console.error(err);
    return new Response("Internal Server Error", { status: 500 });
  }
});

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/addFriend' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
