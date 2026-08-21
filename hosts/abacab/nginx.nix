# Nginx on abacab — vhosts from the Ubuntu site files in ../../nginx-conf/.
# TLS: one ACME cert per hostname (isolated renewals).
# Proxy/alias paths are unchanged from those configs.
{
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "acme@hammerpot.dev";
  };

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    virtualHosts."24fire.hammerpot.dev" = {
      forceSSL = true;
      enableACME = true;
    };

    virtualHosts."24fire.nailington.net" = {
      forceSSL = true;
      enableACME = true;
    };

    virtualHosts."jellyfin.nailington.net" = {
      forceSSL = true;
      enableACME = true;
      # extraConfig = ''
      #   client_max_body_size 20M;
      #   add_header X-Content-Type-Options "nosniff";
      #   add_header Permissions-Policy "accelerometer=(), ambient-light-sensor=(), battery=(), bluetooth=(), camera=(), clipboard-read=(), display-capture=(), document-domain=(), encrypted-media=(), gamepad=(), geolocation=(), gyroscope=(), hid=(), idle-detection=(), interest-cohort=(), keyboard-map=(), local-fonts=(), magnetometer=(), microphone=(), payment=(), publickey-credentials-get=(), serial=(), sync-xhr=(), usb=(), xr-spatial-tracking=()" always;
      #   add_header Content-Security-Policy "default-src https: data: blob: ; img-src 'self' https://* ; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' https://www.gstatic.com https://www.youtube.com blob:; worker-src 'self' blob:; connect-src 'self'; object-src 'none'; font-src 'self'";
      # '';
      # locations."/" = {
      #   proxyPass = "http://127.0.0.1:8096";
      #   extraConfig = ''
      #     proxy_set_header X-Forwarded-Protocol $scheme;
      #     proxy_set_header X-Forwarded-Host $http_host;
      #     proxy_buffering off;
      #   '';
      # };
      # locations."/socket" = {
      #   proxyPass = "http://127.0.0.1:8096";
      #   proxyWebsockets = true;
      #   extraConfig = ''
      #     proxy_set_header X-Forwarded-Protocol $scheme;
      #     proxy_set_header X-Forwarded-Host $http_host;
      #   '';
      # };
    };

    virtualHosts."ftc.hammerpot.dev" = {
      forceSSL = true;
      enableACME = true;
      extraConfig = ''
        client_max_body_size 300M;
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.53:8102";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header X-Forwarded-Host $server_name;
          proxy_cache_bypass $http_upgrade;
        '';
      };
      # locations."/voxy" = {
      #   extraConfig = ''
      #     alias /home/root/ftc3/webserve/ts;
      #     add_header Content-disposition "attachment";
      #   '';
      # };
    };

    virtualHosts."git.hammerpot.dev" = {
      forceSSL = true;
      enableACME = true;
      # extraConfig = ''
      #   client_max_body_size 300M;
      #   add_header X-Frame-Options DENY;
      #   add_header X-Content-Type-Options nosniff;
      #   add_header X-XSS-Protection "1; mode=block";
      #   add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
      # '';
      # locations."/" = {
      #   proxyPass = "http://127.0.0.1:3000";
      #   proxyWebsockets = true;
      #   extraConfig = ''
      #     proxy_set_header X-Forwarded-Host $server_name;
      #     proxy_cache_bypass $http_upgrade;
      #   '';
      # };
    };
  };
}
