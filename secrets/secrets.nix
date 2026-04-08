let
  weebmachine = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPHKVO6qKd5sQXRMJ687TDt+eqKLt2cOE3LxzrjHnBSu";
  moenote = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAQk3xWsx4WS0WSrkEkRBfAgN+ZjDy3eHTFHNavS3JYu";
in
{
  "weeb-password.age".publicKeys = [ weebmachine moenote ];
  "root-password.age".publicKeys = [ weebmachine moenote ];
}
