CREATE OR REPLACE FUNCTION execute_notify_friend_request_edge_function()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    sb_base_functions_url TEXT := 'http://host.docker.internal:54321/functions/v1';
    sb_sr_secret TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';
BEGIN
    -- Perform the HTTP POST request
    PERFORM "net"."http_post"(
        sb_base_functions_url || '/notifyFriendRequest',
        to_jsonb(NEW),
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || sb_sr_secret
        )
    );
    RETURN NEW;
END $$;

-- Create the Trigger and Execute the Function
CREATE TRIGGER execute_notify_friend_request_edge_function
AFTER INSERT ON public.friends
FOR EACH ROW
EXECUTE FUNCTION execute_notify_friend_request_edge_function();

CREATE OR REPLACE FUNCTION execute_notify_friend_confirmation_edge_function()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    sb_base_functions_url TEXT := 'http://host.docker.internal:54321/functions/v1';
    sb_sr_secret TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';
BEGIN
    -- Perform the HTTP POST request
    PERFORM "net"."http_post"(
        sb_base_functions_url || '/notifyFriendConfirmation',
        to_jsonb(NEW),
        headers := jsonb_build_object(
            'Content-Type', 'application/json',

            'Authorization', 'Bearer ' || sb_sr_secret
        )
    );

    RETURN NEW;
END $$;

-- Create the Trigger and Execute the Function
CREATE TRIGGER execute_notify_friend_confirmation_edge_function
AFTER UPDATE ON public.friends
FOR EACH ROW
EXECUTE FUNCTION execute_notify_friend_confirmation_edge_function();

