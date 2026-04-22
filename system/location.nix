{
  location.provider = "geoclue2";

  services.geoclue2 = {
    enable = true;
    appConfig."gdbus" = {
      isAllowed = true;
      isSystem = false;
    };
  };
}
