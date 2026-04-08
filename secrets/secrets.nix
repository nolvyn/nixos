let
  weebmachine = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPHKVO6qKd5sQXRMJ687TDt+eqKLt2cOE3LxzrjHnBSu";
  moenote = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAQk3xWsx4WS0WSrkEkRBfAgN+ZjDy3eHTFHNavS3JYu";
  allHosts = [weebmachine moenote];
in
{
  "weeb-password.age".publicKeys = allHosts;
  "root-password.age".publicKeys = allHosts;
  "wifi-secrets.age".publicKeys = allHosts;
}
