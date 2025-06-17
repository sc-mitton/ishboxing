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

const privilegedSupabaseClient = createClient(supabaseUrl, supabaseKey);

// Initialize APNS client
const client = new ApnsClient({
  team: teamId,
  keyId: keyId,
  signingKey: apnSecret,
  host: apnServer,
  defaultTopic: apnTopic,
});

interface MatchUser {
  profile_id: string;
  match_topic: string;
  is_challenger: boolean;
  is_challenged: boolean;
}

const sendMatchNotification = async (
  from: { username: string; id: string },
  to: { username: string; id: string },
  match: { id: string },
  apnToken: string,
): Promise<void> => {
  const notification = new Notification(apnToken, {
    type: PushType.alert,
    alert: {
      title: "New Match Challenge",
      body: `${from.username} has started a match`,
    },
    category: "MATCH_NOTIFICATION",
    data: {
      id: match.id,
      from: {
        id: from.id,
        username: from.username,
      },
      to: {
        id: to.id,
        username: to.username,
      },
    },
    priority: Priority.low,
    sound: "default",
    expiration: new Date(Date.now() + 30 * 1000), // 30 seconds
    topic: apnTopic,
  });
  await client.send(notification);
};

Deno.serve(async (req) => {
  try {
    const { data } = await req.json() as { data: MatchUser };

    if (!data.is_challenged) {
      return new Response(JSON.stringify({ error: "User is not challenged" }), {
        status: 200,
      });
    }

    // Query for owner of match
    const { data: match } = await privilegedSupabaseClient.from(
      "match_users",
    ).select("profile_id")
      .eq("match_topic", data.match_topic)
      .eq("is_challenger", true)
      .single()
      .throwOnError();

    if (!match) {
      return new Response(JSON.stringify({ error: "Match not found" }), {
        status: 404,
      });
    }

    // Query for the challenger and challenged to get their user name and the apn token of the challenged user
    const { data: users } = await privilegedSupabaseClient.from("profiles")
      .select("id, username, apn_tokens(token)")
      .in("id", [match.profile_id, data.profile_id])
      .throwOnError();

    if (!users || users.length !== 2) {
      return new Response(JSON.stringify({ error: "Users not found" }), {
        status: 404,
      });
    }

    const [challenger, challenged] = users;

    // Notify the challenged user
    await sendMatchNotification(
      challenger,
      challenged,
      { id: data.match_topic },
      (challenged.apn_tokens as any).token,
    );

    return new Response(
      JSON.stringify(data),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (error: unknown) {
    console.error("Error: ", error);
    const errorMessage = error instanceof Error
      ? error.message
      : "An unknown error occurred";
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 500,
    });
  }
});
