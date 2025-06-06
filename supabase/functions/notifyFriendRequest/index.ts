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

// Environment variables
const apnSecret = Deno.env.get("APN_SECRET");
const teamId = Deno.env.get("APPLE_TEAM_ID");
const keyId = Deno.env.get("APPLE_KEY_ID");
const apnServer = Deno.env.get("APN_SERVER");
const apnTopic = Deno.env.get("APN_TOPIC");
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

// Validate environment variables
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

// Initialize APNS client
const client = new ApnsClient({
  team: teamId,
  keyId: keyId,
  signingKey: apnSecret,
  host: apnServer,
  defaultTopic: apnTopic,
});

const privilegedSupabaseClient = createClient(supabaseUrl, supabaseKey);

const sendFriendRequestNotification = async (
  from: { username: string; user_id: string },
  to: { username: string; user_id: string },
  apnToken: string,
): Promise<void> => {
  const notification = new Notification(apnToken, {
    type: PushType.alert,
    alert: {
      title: "New Friend Request",
      body: `${from.username} wants to be your friend`,
    },
    category: "FRIEND_REQUEST",
    data: {
      from: from.user_id,
      to: to.user_id,
    },
    priority: Priority.low,
    sound: "default",
    expiration: new Date(Date.now() + 30 * 1000), // 30 seconds
    topic: apnTopic,
  });
  await client.send(notification);
  console.log("Sent notification");
};

// Main handler
Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  try {
    const { data: { user_id: from, friend_id: to } } = await req.json();

    const { data: users, error } = await privilegedSupabaseClient
      .from("friends")
      .select(
        "user_id, friend_id, profiles:user_id(username), apn_tokens(token)",
      )
      .eq("user_id", from)
      .eq("friend_id", to);

    if (!users) {
      console.error("Error fetching users:", error);
      return new Response("Error fetching users", { status: 500 });
    }

    sendFriendRequestNotification(
      {
        username: users[0].profiles[0].username,
        user_id: users[0].user_id,
      },
      {
        username: users[1].profiles[0].username,
        user_id: users[1].user_id,
      },
      users[1].apn_tokens[0].token,
    );

    if (error) {
      console.error("Error fetching users:", error);
      return new Response("Error fetching users", { status: 500 });
    }

    return new Response("User notified", { status: 200 });
  } catch (err) {
    console.error("Unexpected error:", err);
    return new Response("Internal Server Error", { status: 400 });
  }
});
