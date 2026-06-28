%%% @doc Centralised access to the `dmd' application environment.
-module(dmd_config).

-export([get/1, get/2,
         mgmt_host/0, mgmt_port/0,
         device_port/0, device_ip/1, device_ip_first_octet/0,
         call_interval_ms/0, reboot_duration_ms/0,
         tls_enabled/0, tls_listen_opts/0, tls_connect_opts/0]).

-spec get(atom()) -> term().
get(Key) -> get(Key, undefined).

-spec get(atom(), term()) -> term().
get(Key, Default) -> application:get_env(dmd, Key, Default).

mgmt_host() -> get(mgmt_host, {127,0,0,1}).
mgmt_port() -> get(mgmt_port, 5000).

device_port() -> get(device_port, 6000).
device_ip_first_octet() -> get(device_ip_first_octet, 2).

%% Each device gets a distinct loopback IP: 127.0.0.N. On Linux the whole
%% 127.0.0.0/8 block already routes to loopback, so no aliasing is needed.
device_ip(N) when is_integer(N), N >= 1, N =< 254 -> {127,0,0,N}.

call_interval_ms() -> get(call_interval_ms, 10000).
reboot_duration_ms() -> get(reboot_duration_ms, 5000).

tls_enabled() -> get(tls, false) =:= true.

%% ssl options used when opening a listening socket (server side).
tls_listen_opts() -> proplists:get_value(listen, get(tls_opts, []), []).

%% ssl options used when dialing out (client side).
tls_connect_opts() -> proplists:get_value(connect, get(tls_opts, []), []).
