{
  inputs,
  lib,
  pkgs,
  vars,
  ...
}:

let
  # choose a profile name; directory is /home/<user>/.mozilla/firefox/profile_0
  name = vars.user; # name as listed in about:profiles
  isDefault = true; # set as default profile
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
in
{
  home.file.".mozilla/firefox/default/search.json.mozlz4".force = lib.mkForce true;
  programs.firefox = {
    enable = true;

    # https://nix-community.github.io/home-manager/options.html#opt-programs.firefox.profiles
    profiles.default = {
      inherit name isDefault search;
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
      extensions.force = true; # needed to enable catppuccin theming
    };
  };

  # zen browser settings
  catppuccin.floorp.profiles.default.enable = false;
  programs.floorp = {
    # jank workaround where we replace the floorp package with zen browser
    # which allows me to configure the settings
    package = inputs.zen-browser.packages.${pkgs.system}.zen-browser;
    profiles.default = {
      inherit name isDefault search;
      settings = {
        browser.aboutConfig.showWarning = false;
      };
    };
  };
}
