# searxng.nix
{ config, pkgs, lib, ... }:

{
  services.searx = {
    enable = true;
    # redisCreateLocally = true;
    # valkeyCreateLocally = true;
    configureUwsgi = false;
    environmentFile = "/etc/searxng.env";

    settings = {
      general = {
        debug = true;
        instance_name = "Moe Search";
        donation_url = false;
        contact_url = false;
        privacypolicy_url = false;
        enable_metrics = false;
      };

      ui = {
        static_use_hash = true;
        default_locale = "en";
        query_in_title = true;
        infinite_scroll = true;
        center_alignment = false;
        default_theme = "simple";
        theme_args.simple = "dark";
        search_on_category_select = true;
        hotkeys = "vim";
      };

      search = {
        safe_search = 0;
        autocomplete_min = 2;
        autocomplete = "brave";
        favicon_resolver = "google";
        ban_time_on_fail = 5;
        max_ban_time_on_fail = 120;
      };

      server = {
        bind_address = "127.0.0.1";
        port = 8080;
      };

      engines = lib.mapAttrsToList (name: value: { inherit name; } // value) {
        # GENERAL
        # translate
        "dictzone".disabled = true;
        "libretranslate".disabled = true;
        "lingva".disabled = true;
        "mozhi".disabled = true;
        "mymemory translated".disabled = true;

        # web
        "brave".disabled = false;
        "duckduckgo".disabled = true;
        "google".disabled = true;
        "qwant".disabled = true;
        "startpage".disabled = false;

        # wikimedia
        "wikibooks".disabled = true;
        "wikiquote".disabled = true;
        "wikisource".disabled = true;
        "wikispecies".disabled = true;
        "wikiversity".disabled = true;
        "wikivoyage".disabled = true;

        # without furhter subgrouping
        "wikidata".disabled = true;


        # IMAGES
        # icons
        "material icons".disabled = true;
        "svgrepo".disabled = true;
        "uxwing".disabled = true;

        # web
        "bing images".disabled = true;
        "brave.images".disabled = false;
        "duckduckgo images".disabled = true;
        "google images".disabled = true;
        "mojeek images".disabled = true;
        "presearch images".disabled = true;
        "qwant images".disabled = true;
        "startpage images".disabled = false;
        
        # without further subgrouping
        "artic".disabled = true;
        "deviantart".disabled = true;
        "flickr".disabled = true;
        "openverse".disabled = true;
        "pinterest".disabled = true;
        "public domain image archive".disabled = true;
        "unsplash".disabled = true;
        "wikicommons.images".disabled = true;


        # VIDEOS
        # web
        "bing videos".disabled = true;
        "brave videos".disabled = false;
        "duckduckgo videos".disabled = true;
        "google videos".disabled = true;
        "qwant videos".disabled = true;


        # NEWS
        # web
        "duckduckgo news".disabled = true;
        "mojeek news".disabled = true;
        "presearch news".disabled = true;
        "startpage news".disabled = false;

        # wikimedia
        "wikinews".disabled = true;

        # without further subgrouping
        "bing news".disabled = true;
        "brave.news".disabled = false;
        "google news".disabled = true;
        "qwant news".disabled = true;
        "reuters".disabled = true;
        "yahoo news".disabled = true;
        "yep news".disabled = true;
      };

      enabled_plugins = [
        "Basic Calculator"
        # "Hash plugin"
        # "Tor check plugin"
        "Open Access DOI rewrite"
        "Hostnames plugin"
        "Unit converter plugin"
        "Tracker URL remover"
      ];

      hostnames = {
        remove = [
          ".*centralbankofindia.*"
          ".*\\.facebook\\.com$"
          ".*\\.quora\\.com$"
          ".*\\.soundcloud\\.com$"
          ".*\\.stablediffusionweb\\.com$"
          ".*\\.wolframalpha\\.com$"
        ];

        high_priority = [
          ".*\\.danbooru\\.donmai\\.us$"
          ".*\\.gelbooru\\.com$"
          ".*\\.github\\.com$"
          ".*\\.pixiv\\.net$"
          ".*\\.reddit\\.com$"
          # ".*\\.wikipedia\\.org$"
        ];

        low_priority = [

        ];

        replace = {
          "(.*\\.)?x\\.com$" = "nitter.net";
          "(.*\\.)?twitter\\.com$" = "nitter.net";
        };
      };
    };
  };

  # services.tailscale.enable = true;
}
