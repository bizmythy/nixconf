{
  config,
  pkgs,
  ...
}:

let
  lockFalse = {
    Value = false;
    Status = "locked";
  };
  lockTrue = {
    Value = true;
    Status = "locked";
  };
in
{
  programs = {
    firefox = {
      enable = true;
      languagePacks = [
        "en-US"
      ];

      # ---- POLICIES ----
      # Check about:policies#documentation for options.
      policies = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };
        DisablePocket = true;
        DisableFirefoxAccounts = false;
        DisableAccounts = false;
        DisableFirefoxScreenshots = false;
        OverrideFirstRunPage = "";
        OverridePostUpdatePage = "";
        DontCheckDefaultBrowser = false;
        DisplayBookmarksToolbar = "newtab"; # one of ["always", "never", "newtab"]
        DisplayMenuBar = "default-off"; # alternatives: "always", "never" or "default-on"
        SearchBar = "unified"; # alternative: "separate"

        # ---- PREFERENCES ----
        # Check about:config for options.
        Preferences = {
          # "browser.contentblocking.category" = {
          #   Value = "strict";
          #   Status = "locked";
          # };
          "extensions.pocket.enabled" = lockFalse;
          # "extensions.screenshots.disabled" = lockTrue;
          # "browser.topsites.contile.enabled" = lockFalse;
          # "browser.formfill.enable" = lockFalse;
          # "browser.search.suggest.enabled" = lockFalse;
          # "browser.search.suggest.enabled.private" = lockFalse;
          # "browser.urlbar.suggest.searches" = lockFalse;
          # "browser.urlbar.showSearchSuggestionsFirst" = lockFalse;
          "browser.newtabpage.activity-stream.feeds.section.topstories" = lockFalse;
          "browser.newtabpage.activity-stream.feeds.snippets" = lockFalse;
          "browser.newtabpage.activity-stream.section.highlights.includePocket" = lockFalse;
          # "browser.newtabpage.activity-stream.section.highlights.includeBookmarks" = lockFalse;
          # "browser.newtabpage.activity-stream.section.highlights.includeDownloads" = lockFalse;
          # "browser.newtabpage.activity-stream.section.highlights.includeVisited" = lockFalse;
          "browser.newtabpage.activity-stream.showSponsored" = lockFalse;
          "browser.newtabpage.activity-stream.system.showSponsored" = lockFalse;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = lockFalse;

          "sidebar.revamp" = lockTrue;
          "sidebar.verticalTabs" = lockTrue;
        };
      };
    };
  };
}
