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

const sendFriendConfirmationNotification = async (
  from: { username: string; user_id: string },
  to: { username: string; user_id: string },
  apnToken: string,
): Promise<void> => {
  const notification = new Notification(apnToken, {
    type: PushType.alert,
    alert: {
      title: "Friend Request Accepted",
      body: `${from.username} accepted your friend request`,
    },
    category: "FRIEND_CONFIRMATION",
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
};

// Main handler
Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  try {
    const { data: requestData } = await req.json();

    // Get the friend's profile information and APN tokens
    const { data: users, error } = await privilegedSupabaseClient
      .from("profiles")
      .select(
        "id, username, apn_tokens(token)",
      )
      .in("id", [requestData.user_id, requestData.friend_id]);

    if (error || !users || users.length === 0) {
      console.error("Error fetching users:", error);
      return new Response("Error fetching users", { status: 404 });
    }

    const fromUser = users.find((user) => user.id === requestData.user_id);
    const toUser = users.find((user) => user.id === requestData.friend_id);

    if (!fromUser || !toUser) {
      return new Response(JSON.stringify({ error: "Users not found" }), {
        status: 404,
      });
    }

    await sendFriendConfirmationNotification(
      {
        username: toUser.username,
        user_id: toUser.id,
      },
      {
        username: fromUser.username,
        user_id: fromUser.id,
      },
      (toUser.apn_tokens as any).token,
    );

    return new Response("User notified", { status: 200 });
  } catch (err) {
    console.error("Unexpected error:", err);
    return new Response(
      JSON.stringify({
        error: err instanceof Error ? err.message : "Unknown error",
      }),
      {
        headers: { "Content-Type": "application/json" },
        status: 400,
      },
    );
  }
});
