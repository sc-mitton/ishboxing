// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, SupabaseClient } from "@supabase/supabase-js";
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

// Helper functions
const createSupabaseClient = (req: Request): SupabaseClient => {
  const authHeader = req.headers.get("Authorization");
  const token = authHeader?.split(" ")[1];
  return createClient(supabaseUrl, token ?? "", {
    global: {
      headers: { Authorization: req.headers.get("Authorization") ?? "" },
    },
  });
};

const privilegedSupabaseClient = createClient(supabaseUrl, supabaseKey);

const sendFriendRequestNotification = async (
  from: { username: string; id: string },
  to: { username: string; id: string },
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
      from: from.id,
      to: to.id,
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
    const data = await req.json();
    if (!data.username) {
      return new Response("Invalid payload", { status: 400 });
    }
    const supabaseClient = createSupabaseClient(req);

    // Fetch sender data and the recipient data in a single query
    const [
      { data: sender, error: senderError },
      { data: recipiant, error: recipiantError },
    ] = await Promise.all([
      supabaseClient.auth.getUser(),
      privilegedSupabaseClient
        .from("profiles")
        .select("id, username, apn_tokens(token)")
        .eq("username", data.username)
        .single(),
    ]);

    if (senderError || recipiantError || !sender || !recipiant) {
      console.error("Error fetching users:", senderError, recipiantError);
      return new Response("Error fetching users", { status: 500 });
    }

    // Create the friendship relationship
    const { error: friendshipError } = await supabaseClient
      .from("friends")
      .insert({
        user_id: sender.user.id,
        friend_id: recipiant.id,
        confirmed: false,
      });

    if (friendshipError) {
      console.error("Error creating friendship:", friendshipError);
      return new Response("Error creating friendship", { status: 500 });
    }

    // Send push notification - if this fails, we still return success since friendship was created
    await sendFriendRequestNotification(
      {
        username: sender.user.user_metadata.username,
        id: sender.user.id,
      },
      {
        username: recipiant.username,
        id: recipiant.id,
      },
      recipiant.apn_tokens[0].token,
    );

    return new Response("Friend request sent", { status: 200 });
  } catch (err) {
    console.error("Unexpected error:", err);
    return new Response("Internal Server Error", { status: 400 });
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
