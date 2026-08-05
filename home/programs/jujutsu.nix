{
  pkgs,
  vars,
  ...
}:
let
  vcs = import ../vcs-settings.nix { inherit vars; };
  inherit (vcs.identities) personal dirac;
  jjIdentity = identity: {
    inherit (identity) name email;
  };
in
{
  programs.jujutsu = {
    enable = true;
    settings = {
      user = jjIdentity personal;

      ui = {
        editor = vars.defaults.termEditor;
        show-cryptographic-signatures = true;
      };

      # Colocation keeps repositories available to Git-based tools and IDEs.
      git = {
        colocate = true;
        # Avoid a 1Password prompt after every history rewrite.
        sign-on-push = true;
      };

      signing = {
        backend = "ssh";
        behavior = "drop";
        key = personal.sshPublicKey;
        backends.ssh.program = vcs.onePassword.sshSigner;
      };

      "--scope" = [
        {
          "--when".repositories = [ dirac.repositoryRoot ];
          user = jjIdentity dirac;
          signing.key = dirac.sshPublicKey;
        }
      ];
    };
  };

  # Use delta for jj's pager and Git-format diffs.
  programs.delta.enableJujutsuIntegration = true;

  # jjui is the closest feature-rich Jujutsu equivalent to Lazygit.
  home.packages = [ pkgs.jjui ];
}
