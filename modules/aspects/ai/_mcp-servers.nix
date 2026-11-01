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
  cloudflare-bindings = remote "https://bindings.mcp.cloudflare.com/mcp";
  cloudflare-docs = remote "https://docs.mcp.cloudflare.com/mcp";
  playwright = {
    command = "npx";
    args = [ "@playwright/mcp@latest" ];
  };
  revenuecat = remote "https://mcp.revenuecat.ai/mcp";
  stripe = remote "https://mcp.stripe.com";
  supabase = remote "https://mcp.supabase.com/mcp";
}
