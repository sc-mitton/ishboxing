import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import {
  ApnsClient,
  Notification,
  Priority,
  PushType,
} from '@fivesheepco/cloudflare-apns2';
import { createClient } from '@supabase/supabase-js';

const apnSecret = Deno.env.get('APN_SECRET');
const teamId = Deno.env.get('APPLE_TEAM_ID');
const keyId = Deno.env.get('APPLE_KEY_ID');
const apnServer = Deno.env.get('APN_SERVER');
const apnTopic = Deno.env.get('APN_TOPIC');
const supabaseUrl = Deno.env.get('SUPABASE_URL');
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

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
    'Missing one or more required environment variables: APN_SECRET, APPLE_TEAM_ID, APPLE_KEY_ID, APN_SERVER, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY'
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

interface Meeting {
  from: string;
  to: string;
  id: string;
}

const isMeeting = (data: unknown): data is Meeting => {
  return (
    typeof data === 'object' &&
    data !== null &&
    'from' in data &&
    'to' in data &&
    'id' in data
  );
};

const alertUser = async (meeting: Meeting) => {
  // Fetch the user record from Supabase
  const { data, error } = await supabase
    .from('auth.users')
    .select('username, apn_token')
    .eq('id', meeting.to)
    .single();

  if (error) {
    console.error('Error fetching user:', error);
    throw error;
  }

  const bn = new Notification(data.apn_token, {
    type: PushType.alert,
    alert: {
      title: `${data.username} wants to fight`,
      body: `Tap to open the fight`,
    },
    data: {
      meeting: {
        from: meeting.from,
        to: meeting.to,
        id: meeting.id,
      },
    },
    priority: Priority.low,
    sound: 'default',
    expiration: new Date(Date.now() + 30 * 1000), // 30 seconds
  });

  await client.send(bn);
};

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  try {
    const data = await req.json();
    if (!isMeeting(data)) {
      return new Response('Invalid payload', { status: 400 });
    }

    await alertUser(data);
    return new Response('Notification sent', { status: 200 });
  } catch (err) {
    console.error(err);
    return new Response('Error sending notification', { status: 500 });
  }
});
