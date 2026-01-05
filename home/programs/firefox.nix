{
  lib,
  vars,
  ...
}:

{
  home.file.".mozilla/firefox/default/search.json.mozlz4".force = lib.mkForce true;
  programs.firefox = {
    enable = true;

    # https://nix-community.github.io/home-manager/options.html#opt-programs.firefox.profiles
    profiles = {
      default = {
        # choose a profile name; directory is /home/<user>/.mozilla/firefox/profile_0
        name = vars.user; # name as listed in about:profiles
        id = 0; # 0 is the default profile; see also option "isDefault"
        isDefault = true; # can be omitted; true if profile ID is 0
        settings = {
          # specify profile-specific preferences here; check about:config for options
          # widget.use-xdg-desktop-portal.file-picker = 1;
          browser.newtabpage.activity-stream = {
            feeds.section.highlights = false;
            showSponsoredTopSites = false;
          };
          browser.aboutConfig.showWarning = false;
          # restores previous session on startup
          browser.startup.page = 3;
          extensions.pocket.enabled = false;
          sidebar = {
            revamp = true;
            verticalTabs = true;
          };
        };
        search = {
          engines = {
            "unduck" = {
              urls = [ { template = "https://unduck.link?q={searchTerms}"; } ];
              icon = "https://unduck.link/favicon.ico";
              updateInterval = 24 * 60 * 60 * 1000; # every day
            };
            bing.metaData.hidden = true;
          };
          default = "unduck";
          privateDefault = "ddg";
        };
        extensions.force = true; # needed to enable catppuccin theming
      };
    };
  };
}
