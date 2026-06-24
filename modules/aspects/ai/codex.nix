{ inputs, ... }:
{
  flake-file.inputs.openai-plugins = {
    url = "github:openai/plugins";
    flake = false;
  };

  den.aspects.ai.provides.codex = {
    nixos =
      { host, ... }:
      {
        environment.persistence."/persistent".users.${host.userName} = {
          directories = [ ".codex" ];
        };
      };

    homeManager =
      { pkgs, ... }:
      let
        mkPlugin =
          name:
          builtins.path {
            inherit name;
            path = "${inputs.openai-plugins}/plugins/${name}";
          };
      in
      {
        home.packages = [ pkgs.llm-agents.oh-my-codex ];

        programs.codex = {
          enable = true;
          package = pkgs.llm-agents.codex;
          enableMcpIntegration = true;

          skills = "${pkgs.llm-agents.oh-my-codex}/share/oh-my-codex/skills";

          plugins = map mkPlugin [
            "cloudflare"
            "codex-security"
            "github"
            "stripe"
            "supabase"
          ];

          rules.default = ''
            prefix_rule(pattern = ["rm", "-rf", "/"], decision = "deny")
            prefix_rule(pattern = ["rm", "-rf", "~"], decision = "deny")
            prefix_rule(pattern = ["dd", "if=/dev/"], decision = "deny")
            prefix_rule(pattern = ["mkfs"], decision = "deny")
          '';

          settings = {
            theme = "dark";
            approval_policy = "on-request";
            sandbox_mode = "danger-full-access";

            projects."/home/weeb/nixos".trust_level = "trusted";
            projects."/home/weeb/projects/folirei".trust_level = "trusted";
          };
        };
      };
  };
}
