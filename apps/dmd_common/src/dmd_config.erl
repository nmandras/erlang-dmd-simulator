%%% @doc Per-application environment access. Both runnable apps (`dmd_agent'
%%% and `dmd_mgmt') keep their own env namespace; callers pass which app they
%%% belong to so the shared TLS/addressing helpers work for either.
-module(dmd_config).

-export([get/3,
         mgmt_host/1, mgmt_port/1,
         tls_enabled/1, tls_listen_opts/1, tls_connect_opts/1,
         listen_tls/1, connect_tls/1]).

-spec get(atom(), atom(), term()) -> term().
get(App, Key, Default) -> application:get_env(App, Key, Default).

mgmt_host(App) -> get(App, mgmt_host, {127,0,0,1}).
mgmt_port(App) -> get(App, mgmt_port, 5000).

tls_enabled(App) -> get(App, tls, false) =:= true.
tls_listen_opts(App) -> proplists:get_value(listen, get(App, tls_opts, []), []).
tls_connect_opts(App) -> proplists:get_value(connect, get(App, tls_opts, []), []).

%% TLS argument forms consumed by dmd_transport: `false' or `{tls, SslOpts}'.
-spec listen_tls(atom()) -> false | {tls, [ssl:tls_option()]}.
listen_tls(App) ->
    case tls_enabled(App) of
        true -> {tls, tls_listen_opts(App)};
        false -> false
    end.

-spec connect_tls(atom()) -> false | {tls, [ssl:tls_option()]}.
connect_tls(App) ->
    case tls_enabled(App) of
        true -> {tls, tls_connect_opts(App)};
        false -> false
    end.
