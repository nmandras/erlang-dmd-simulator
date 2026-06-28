%%% @doc Logging setup helper. Each runnable app installs its own `logger' file
%%% handler that captures only events tagged with its domain, so the agent and
%%% the management server write to separate, timestamped log files.
-module(dmd_log).

-export([setup/3]).

%% Install a file handler `Name' writing events whose metadata domain is under
%% `Domain' to `File'. Each line is `<rfc3339-time> <level> <message>'.
-spec setup(atom(), file:name_all(), [atom()]) -> ok.
setup(Name, File, Domain) ->
    ok = filelib:ensure_dir(File),
    Config = #{
        config => #{file => File},
        filter_default => stop,
        filters => [{domain,
                     {fun logger_filters:domain/2, {log, sub, Domain}}}],
        formatter => {logger_formatter,
                      #{single_line => true,
                        time_designator => $\s,
                        template => [time, " ", level, " ", msg, "\n"]}}
    },
    case logger:add_handler(Name, logger_std_h, Config) of
        ok -> ok;
        {error, {already_exist, _}} -> ok
    end.
