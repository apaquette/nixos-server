{ lib }:

let
  filterServices = predicate: services:
    lib.filterAttrs (_: service: predicate service) services;

  hasDeclaredIngress = caddyEnabled: service:
    (service.httpUpstream != null && caddyEnabled)
    || service.tcpPorts != [ ]
    || service.udpPorts != [ ];

  hasHttpIngress = service:
    service.exposure != "loopback"
    && service.hostname != null
    && service.httpUpstream != null;

  hasPublishedIngress = caddyEnabled: service:
    service.exposure != "loopback"
    && service.hostname != null
    && hasDeclaredIngress caddyEnabled service;

  hasPublicIngress = caddyEnabled: service:
    service.exposure == "public"
    && hasPublishedIngress caddyEnabled service;

  portsForExposure = exposure: protocol: services:
    if !(builtins.elem exposure [ "public" "lan" ]) then
      [ ]
    else
      let
        selected = filterServices
          (service: service.exposure == exposure)
          services;
        getPorts = service:
          if protocol == "tcp" then service.tcpPorts else service.udpPorts;
      in
      lib.unique (lib.concatMap getPorts (builtins.attrValues selected));
in
{
  httpServices = filterServices hasHttpIngress;
  publishedServices = caddyEnabled: filterServices (hasPublishedIngress caddyEnabled);
  publicServices = caddyEnabled: filterServices (hasPublicIngress caddyEnabled);
  inherit portsForExposure;
}
