{
  vars,
  ...
}:
{
  virtualisation.oci-containers =
    let
      minecraftServerImg = "itzg/minecraft-server:java8-multiarch";
      portDef = { host, container }: "${builtins.toString host}:${builtins.toString container}";
      volumeDef = { host, container }: "${host}:${container}";
    in
    {
      backend = "podman";
      containers = {
        ftbskies = {
          image = minecraftServerImg;
          environment = {
            EULA = "TRUE";
            TYPE = "FTBA";
            FTB_MODPACK_ID = 129;
            FTB_MODPACK_VERSION_ID = 100154;
          };

          volumes = map volumeDef [
            {
              host = "/home/drew/minecraft/ftbskies";
              container = "/data";
            }
          ];

          user = vars.user;
          autoStart = true;
          ports = map portDef [
            {
              host = 25565;
              container = 25565;
            }
          ];
        };
      };
    };
}
