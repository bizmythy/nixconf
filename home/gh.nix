{
  pkgs,
  ...
}:
{
  programs.gh = {
    enable = true;
    extensions = with pkgs; [
      gh-s
      gh-i
      gh-f
      gh-copilot
      gh-markdown-preview
    ];
    settings = {
      git_protocol = "ssh";
      aliases = {
        cs = "copilot suggest";
        ce = "copilot explain";
      };
    };
  };

  programs.gh-dash = {
    enable = true;
    settings = {
      pager.diff = "delta";
      repoPaths = {
        "diracq/*" = "~/dirac/*";
      };
      prSections =
        let
          needReview = "is:open draft:false review:required";
        in
        [
          {
            title = "need my approval";
            filters = needReview + " -review:approved-by:@me -author:@me";
          }
          {
            title = "mine";
            filters = "is:open author:@me";
            layout.author.hidden = true;
          }
          {
            title = "review requested";
            filters = "is:open review-requested:@me";
          }
          {
            title = "all ready";
            filters = "is:open draft:false";
          }
          {
            title = "all";
            filters = "is:open";
          }
          {
            title = "need review";
            filters = needReview;
          }
        ];
      # keybindings.prs =
      #   let
      #     url = "https://github.com/{{.RepoName}}/pull/{{.PrNumber}}";
      #     command = "chromium-browser --ozone-platform-hint=auto --force-dark-mode --enable-features=WebUIDarkMode --app=${url} &> /dev/null &";
      #   in
      #   [
      #     {
      #       key = "o";
      #       inherit command;
      #     }
      #   ];
    };
  };
}
