{ vars }:
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

  onePassword = {
    agentSocket = "${vars.home}/.1password/agent.sock";
    sshSigner = "/run/current-system/sw/bin/op-ssh-sign";
  };
}
