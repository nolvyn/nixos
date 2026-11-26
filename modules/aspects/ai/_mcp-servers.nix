# Shared launch definitions only; clients select and adapt their own servers.
let
  remote = url: {
    command = "npx";
    args = [
      "mcp-remote"
      url
    ];
  };
in
{
  cloudflare-docs = remote "https://docs.mcp.cloudflare.com/mcp";
  stripe = remote "https://mcp.stripe.com";
  supabase = remote "https://mcp.supabase.com/mcp";
}
