{
  pkgs,
  ...
}:

{
  # enable kwallet for org.freedesktop.Secrets
  security = {
    pam.services.kwallet = {
      name = "kwallet";
      enableKwallet = true;
      kwallet = {
        enable = true;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    kdePackages.kwalletmanager
  ];
}
