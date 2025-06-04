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

interface ConfirmRequest {
  friendship_id: string;
  user_id: string; // The user who is confirming the request
}

const isConfirmRequest = (data: unknown): data is ConfirmRequest => {
  return (
    typeof data === "object" &&
    data !== null &&
    "friendship_id" in data &&
    "user_id" in data
  );
};

const sendConfirmationNotification = async (
  friendshipId: string,
  userId: string,
) => {
  // First get the friendship details
  const { data: friendship, error: friendshipError } = await supabase
    .from("friends")
    .select("user_id, friend_id")
    .eq("id", friendshipId)
    .single();

  if (friendshipError) {
    console.error("Error fetching friendship:", friendshipError);
    throw friendshipError;
  }

  const requesterId = friendship.user_id === userId
    ? friendship.friend_id
    : friendship.user_id;

  // Get both users' data in a single query
  const { data: users, error: usersError } = await supabase
    .from("profiles")
    .select("id, username, apn_tokens!inner(token)")
    .in("id", [userId, requesterId]);

  if (usersError) {
    console.error("Error fetching users:", usersError);
    throw usersError;
  }

  const confirmingUser = users.find((u) => u.id === userId);
  const requester = users.find((u) => u.id === requesterId);

  if (!confirmingUser || !requester) {
    throw new Error("Could not find both users");
  }

  // Send notification to the original requester
  const notification = new Notification(requester.apn_tokens[0].token, {
    type: PushType.alert,
    alert: {
      title: "Friend Request Accepted",
      body: `${confirmingUser.username} accepted your friend request`,
    },
    data: {
      type: "friend_confirmation",
      friendship_id: friendshipId,
      from: userId,
      to: requesterId,
    },
    priority: Priority.low,
    sound: "default",
    expiration: new Date(Date.now() + 30 * 1000), // 30 seconds
  });

  await client.send(notification);
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  try {
    const data = await req.json();
    if (!isConfirmRequest(data)) {
      return new Response("Invalid payload", { status: 400 });
    }

    // Update the friendship to confirmed
    const { error: updateError } = await supabase
      .from("friends")
      .update({ confirmed: true })
      .eq("id", data.friendship_id)
      .eq("friend_id", data.user_id); // Ensure only the friend can confirm

    if (updateError) {
      console.error("Error confirming friendship:", updateError);
      return new Response("Error confirming friendship", { status: 500 });
    }

    // Send notification to the original requester
    try {
      await sendConfirmationNotification(data.friendship_id, data.user_id);
    } catch (notificationError) {
      console.error("Error sending notification:", notificationError);
      // Don't return error here since the friendship was confirmed successfully
    }

    return new Response("Friendship confirmed", { status: 200 });
  } catch (err) {
    console.error(err);
    return new Response("Internal Server Error", { status: 500 });
  }
});

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/confirmFriend' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
