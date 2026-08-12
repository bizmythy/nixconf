{ pkgs, vars }:
{
  identities = {
    personal = {
      name = "bizmythy";
      email = "andrew.p.council@gmail.com";
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOjbUnES0AUVvsqNzMdCix3Qp+XRpKiS7tm6PR6u7WTY";
    };

    dirac = {
      name = "drew-dirac";
      email = "drew@diracinc.com";
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIrRXpZt/U8OkMsWoft9+2JiITBsUyGVxuhZJhl+Xpm";
      repositoryRoot = "${vars.home}/dirac";
    };
  };

  onePassword =
    if pkgs.stdenv.isDarwin then
      {
        agentSocket = "${vars.home}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
        sshSigner = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      }
    else
      {
        agentSocket = "${vars.home}/.1password/agent.sock";
        sshSigner = "/run/current-system/sw/bin/op-ssh-sign";
      };
}
