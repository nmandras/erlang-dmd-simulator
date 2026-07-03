-module(dmd_conn_limit_tests).
-include_lib("eunit/include/eunit.hrl").

limit_test_() ->
    {setup,
     fun setup/0,
     fun cleanup/1,
     fun(_) ->
         [
          ?_test(try_acquire_release()),
          ?_test(blocks_at_max())
         ]
     end}.

setup() ->
    application:load(dmd_agent),
    application:set_env(dmd_agent, max_connect_inflight, 2),
    catch gen_server:stop(dmd_conn_limit_agent),
    {ok, _} = dmd_conn_limit:start_link(dmd_agent),
    ok.

cleanup(_Setup) ->
    catch gen_server:stop(dmd_conn_limit_agent),
    ok.

try_acquire_release() ->
    ?assertEqual(ok, dmd_conn_limit:try_acquire(dmd_agent)),
    ?assertEqual(ok, dmd_conn_limit:try_acquire(dmd_agent)),
    ?assertEqual(throttled, dmd_conn_limit:try_acquire(dmd_agent)),
    dmd_conn_limit:release(dmd_agent),
    ?assertEqual(ok, dmd_conn_limit:try_acquire(dmd_agent)),
    dmd_conn_limit:release(dmd_agent),
    dmd_conn_limit:release(dmd_agent).

blocks_at_max() ->
    ?assertEqual(ok, dmd_conn_limit:try_acquire(dmd_agent)),
    ?assertEqual(ok, dmd_conn_limit:try_acquire(dmd_agent)),
    Parent = self(),
    spawn(fun() ->
        ?assertEqual(ok, dmd_conn_limit:acquire(dmd_agent, 5000)),
        Parent ! waiter_done,
        dmd_conn_limit:release(dmd_agent)
    end),
    timer:sleep(50),
    dmd_conn_limit:release(dmd_agent),
    receive waiter_done -> ok after 5000 -> ?assert(false) end,
    dmd_conn_limit:release(dmd_agent),
    dmd_conn_limit:release(dmd_agent),
    ok.
