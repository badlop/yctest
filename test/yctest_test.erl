%%%-------------------------------------------------------------------
%%% Created : 26 Sep 2018 by Evgeny Khramtsov <ekhramtsov@process-one.net>
%%%
%%% Copyright (C) 2002-2021 ProcessOne, SARL. All Rights Reserved.
%%%
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%     http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%%
%%%-------------------------------------------------------------------
-module(yctest_test).
-include_lib("eunit/include/eunit.hrl").

-define(checkError(Pattern, Expression),
	(fun() ->
		 Ret = Expression,
		 ?assertMatch({error, Pattern, _}, Ret),
		 test_format_error(Ret)
	 end)()).

%%%===================================================================
%%% Tests
%%%===================================================================
start_test() ->
    ?assertEqual(ok, yctest:start()).

validate_test() ->
    ?assertEqual({ok, 1}, yctest:validate(yctest:any(), 1)).

error_validate_test() ->
    ?checkError(
       {bad_int, _},
       yctest:validate(yctest:int(), foo)).

empty_yaml_test() ->
    File = file(""),
    ?assertEqual({ok, []}, yctest:parse(File, #{})).

bad_yaml_test() ->
    ?checkError(
       {bad_yaml, enoent, _},
       yctest:parse("non-existent.yml", #{})).

define_macro_test() ->
    File = file(["define_macro:",
		 "  A: 1",
		 "  B: 2",
		 "  C: 3",
		 "a: A",
		 "b: B",
		 "c: C"]),
    ?assertEqual(
       {ok, [{a, 1}, {b, 2}, {c, 3}]},
       yctest:parse(File, #{'_' => yctest:any()}, [replace_macros])).

include_config_file_test() ->
    IncludedFile = included_file(["a: 1",
				  "b: 2"]),
    File = file(["include_config_file: " ++ IncludedFile,
		 "c: 3"]),
    ?assertEqual(
       {ok, [{a, 1}, {b, 2}, {c, 3}]},
       yctest:parse(File, #{'_' => yctest:any()}, [include_files])).

include_allow_only_test() ->
    IncludedFile = included_file(["a: 1",
				  "b: 2",
				  "c: 3"]),
    File = file(["include_config_file:",
		 " " ++ IncludedFile  ++ ":",
		 "  allow_only:",
		 "   - a",
		 "   - c"]),
    ?assertEqual(
       {ok, [{a, 1}, {c, 3}]},
       yctest:parse(File, #{'_' => yctest:any()}, [include_files])).

include_disallow_test() ->
    IncludedFile = included_file(["a: 1",
				  "b: 2",
				  "c: 3"]),
    File = file(["include_config_file:",
		 " " ++ IncludedFile  ++ ":",
		 "  disallow:",
		 "   - a",
		 "   - c"]),
    ?assertEqual(
       {ok, [{b, 2}]},
       yctest:parse(File, #{'_' => yctest:any()}, [include_files])).

duplicated_macro_test() ->
    File = file(["define_macro:",
		 " MACRO: 1",
		 "define_macro:",
		 " MACRO: 2",
		 "a: MACRO"]),
    ?checkError(
       {duplicated_macro, <<"MACRO">>},
       yctest:parse(File, #{'_' => yctest:any()}, [replace_macros])).

included_macro_test() ->
    IncludedFile = included_file(["define_macro:",
				  " MACRO: 1",
				  "b: MACRO"]),
    File = file(["a: MACRO",
		 "include_config_file: " ++ IncludedFile]),
    ?assertEqual(
       {ok, [{a, 1}, {b, 1}]},
       yctest:parse(File, #{'_' => yctest:any()}, [replace_macros, include_files])).

nested_macro_test() ->
    File = file(["define_macro:",
		 " FOO: BAR",
		 " BAR: BAZ",
		 " BAZ: baz",
		 "foo: FOO",
		 "bar: FOO",
		 "baz: FOO"]),
    ?assertEqual(
       {ok, [{foo, <<"baz">>}, {bar, <<"baz">>}, {baz, <<"baz">>}]},
       yctest:parse(File, #{'_' => yctest:any()}, [replace_macros])).

include_circular_test() ->
    File = file(""),
    IncludedFile = included_file(["include_config_file: " ++ File]),
    File = file(["include_config_file: " ++ IncludedFile]),
    ?checkError(
       {bad_yaml, circular_include, _},
       yctest:parse(File, #{}, [include_files])).

macro_circular_test() ->
    File = file(["define_macro:",
		 " FOO: BAR",
		 " BAR: BAZ",
		 " BAZ: FOO"]),
    ?checkError(
       {circular_macro, <<"FOO">>},
       yctest:parse(File, #{}, [replace_macros])).

any_test() ->
    File = file(["a: 1"]),
    ?assertEqual(
       {ok, [{a, 1}]},
       yctest:parse(File, #{a => yctest:any()})).

enum_atom_test() ->
    File = file(["a: foo"]),
    ?assertEqual(
       {ok, [{a, foo}]},
       yctest:parse(File, #{a => yctest:enum([foo, bar])})).

enum_binary_test() ->
    File = file(["a: foo"]),
    ?assertEqual(
       {ok, [{a, <<"foo">>}]},
       yctest:parse(File, #{a => yctest:enum([<<"foo">>, <<"bar">>])})).

bad_enum_test() ->
    File = file(["a: baz"]),
    ?checkError(
       {bad_enum, [foo, bar], baz},
       yctest:parse(File, #{a => yctest:enum([foo, bar])})).

bool_test() ->
    File = file(["a: true",
		 "b: false",
		 "c: on",
		 "d: off",
		 "e: yes",
		 "f: no",
		 "g: y",
		 "h: n"]),
    ?assertEqual(
       {ok, [{a, true}, {b, false}, {c, true}, {d, false},
	     {e, true}, {f, false}, {g, true}, {h, false}]},
       yctest:parse(File, #{a => yctest:bool(),
			   b => yctest:bool(),
			   c => yctest:bool(),
			   d => yctest:bool(),
			   e => yctest:bool(),
			   f => yctest:bool(),
			   g => yctest:bool(),
			   h => yctest:bool()})).

bad_bool_test() ->
    File = file(["a: bad"]),
    ?checkError(
       {bad_bool, bad},
       yctest:parse(File, #{a => yctest:bool()})).

int_test() ->
    File = file(["a: 5",
		 "b: 0",
		 "c: -7"]),
    ?assertEqual(
       {ok, [{a, 5}, {b, 0}, {c, -7}]},
       yctest:parse(File, #{a => yctest:int(),
			   b => yctest:int(),
			   c => yctest:int()})).

bad_int_test() ->
    File = file(["a: bad"]),
    ?checkError(
       {bad_int, _},
       yctest:parse(File, #{a => yctest:int()})).

int_range_test() ->
    File = file(["a: 5",
		 "b: 0",
		 "c: -10"]),
    ?assertEqual(
       {ok, [{a, 5}, {b, 0}, {c, -10}]},
       yctest:parse(File, #{a => yctest:int(4, 5),
			   b => yctest:int(-1, 5),
			   c => yctest:int(-10, 0)})).

bad_int_range_test() ->
    File = file(["a: 5"]),
    ?checkError(
       {bad_int, 10, 20, 5},
       yctest:parse(File, #{a => yctest:int(10, 20)})).

pos_int_test() ->
    File = file(["a: 1"]),
    ?assertEqual(
       {ok, [{a, 1}]},
       yctest:parse(File, #{a => yctest:pos_int()})).

bad_pos_int_test() ->
    File = file(["a: 0"]),
    ?checkError(
       {bad_pos_int, 0},
       yctest:parse(File, #{a => yctest:pos_int()})).

pos_int_infinity_test() ->
    File = file(["a: 1",
		 "b: infinity",
		 "c: infinite",
		 "d: unlimited"]),
    ?assertEqual(
       {ok, [{a, 1}, {b, infinite}, {c, unlimited}, {d, infinity}]},
       yctest:parse(File, #{a => yctest:pos_int(infinity),
			   b => yctest:pos_int(infinite),
			   c => yctest:pos_int(unlimited),
			   d => yctest:pos_int(infinity)})).

bad_pos_int_infinity_test() ->
    File = file(["a: 0"]),
    ?checkError(
       {bad_pos_int, infinity, 0},
       yctest:parse(File, #{a => yctest:pos_int(infinity)})),
    ?checkError(
       {bad_int, foo},
       yctest:validate(yctest:pos_int(infinity), foo)),
    ?checkError(
       {bad_int, _},
       yctest:validate(
	 yctest:pos_int(infinity),
	 list_to_binary(lists:duplicate(256, $z)))).

non_neg_int_test() ->
    File = file(["a: 0"]),
    ?assertEqual(
       {ok, [{a, 0}]},
       yctest:parse(File, #{a => yctest:non_neg_int()})).

bad_non_neg_int_test() ->
    File = file(["a: -1"]),
    ?checkError(
       {bad_non_neg_int, -1},
       yctest:parse(File, #{a => yctest:non_neg_int()})).

non_neg_int_infinity_test() ->
    File = file(["a: 0",
		 "b: infinity",
		 "c: infinite",
		 "d: unlimited"]),
    ?assertEqual(
       {ok, [{a, 0}, {b, infinite}, {c, unlimited}, {d, infinity}]},
       yctest:parse(File, #{a => yctest:non_neg_int(infinity),
			   b => yctest:non_neg_int(infinite),
			   c => yctest:non_neg_int(unlimited),
			   d => yctest:non_neg_int(infinity)})).

bad_non_neg_int_infinity_test() ->
    File = file(["a: -1"]),
    ?checkError(
       {bad_non_neg_int, infinity, -1},
       yctest:parse(File, #{a => yctest:non_neg_int(infinity)})).

number_test() ->
    File = file(["a: 0.5"]),
    ?assertEqual(
       {ok, [{a, 0.5}]},
       yctest:parse(File, #{a => yctest:number(0.5)})).

bad_number_test() ->
    File = file(["a: bad"]),
    ?checkError(
       {bad_number, _},
       yctest:parse(File, #{a => yctest:number(1.0)})),
    File = file(["a: 0.4"]),
    ?checkError(
       {bad_number, 0.5, 0.4},
       yctest:parse(File, #{a => yctest:number(0.5)})).

binary_test() ->
    File = file(["a: foo",
		 "b: \"bar\"",
		 "c: 'baz'"]),
    ?assertEqual(
       {ok, [{a, <<"foo">>}, {b, <<"bar">>}, {c, <<"baz">>}]},
       yctest:parse(File, #{a => yctest:binary(),
			   b => yctest:binary(),
			   c => yctest:binary()})),
    ?assertEqual(<<"foo">>, (yctest:binary())(foo)).

bad_binary_test() ->
    File = file(["a: 1"]),
    ?checkError(
       {bad_binary, 1},
       yctest:parse(File, #{a => yctest:binary()})).

binary_re_test() ->
    File = file(["a: foo",
		 "b: BAR",
		 "c: \"123\""]),
    ?assertEqual(
       {ok, [{a, <<"foo">>}, {b, <<"BAR">>}, {c, <<"123">>}]},
       yctest:parse(File, #{a => yctest:binary("^[a-z]+$"),
			   b => yctest:binary("^[A-Z]+$"),
			   c => yctest:binary("^[0-9]+$")})).

bad_binary_re_test() ->
    File = file(["a: fooBAR"]),
    ?checkError(
       {nomatch, "^[a-z]+$", <<"fooBAR">>},
       yctest:parse(File, #{a => yctest:binary("^[a-z]+$")})).

base64_test() ->
    File = file(["a: Zm9v"]),
    ?assertEqual(
       {ok, [{a, <<"foo">>}]},
       yctest:parse(File, #{a => yctest:base64()})).

bad_base64_test() ->
    File = file(["a: foo"]),
    ?checkError(
       {bad_base64, <<"foo">>},
       yctest:parse(File, #{a => yctest:base64()})).

atom_test() ->
    File = file(["a: atom"]),
    ?assertEqual(
       {ok, [{a, atom}]},
       yctest:parse(File, #{a => yctest:atom()})).

bad_atom_test() ->
    File = file(["a: []"]),
    ?checkError(
       {bad_atom, []},
       yctest:parse(File, #{a => yctest:atom()})).

bad_atom_length_test() ->
    Bad = list_to_binary(lists:duplicate(256, $z)),
    ?checkError(
       {bad_length, 255},
       yctest:validate(yctest:atom(), Bad)).

string_test() ->
    File = file(["a: foo"]),
    ?assertEqual(
       {ok, [{a, "foo"}]},
       yctest:parse(File, #{a => yctest:string()})).

bad_string_test() ->
    File = file(["a: []"]),
    ?checkError(
       {bad_binary, []},
       yctest:parse(File, #{a => yctest:string()})).

string_re_test() ->
    File = file(["a: foo",
		 "b: BAR",
		 "c: \"123\""]),
    ?assertEqual(
       {ok, [{a, "foo"}, {b, "BAR"}, {c, "123"}]},
       yctest:parse(File, #{a => yctest:string("^[a-z]+$"),
			   b => yctest:string("^[A-Z]+$"),
			   c => yctest:string("^[0-9]+$")})).

bad_string_re_test() ->
    File = file(["a: fooBAR"]),
    ?checkError(
       {nomatch, "^[a-z]+$", "fooBAR"},
       yctest:parse(File, #{a => yctest:string("^[a-z]+$")})).

binary_sep_test() ->
    File = file(["a: b/c//d//"]),
    ?assertEqual(
       {ok, [{a, [<<"b">>, <<"c">>, <<"d">>]}]},
       yctest:parse(File, #{a => yctest:binary_sep("/")})).

path_test() ->
    File = file(["a: foo"]),
    ?assertMatch(
       {ok, [{a, _}]},
       yctest:parse(File, #{a => yctest:path()})).

empty_path_test() ->
    File = file(["a: ''"]),
    ?checkError(
       empty_binary,
       yctest:parse(File, #{a => yctest:path()})).

file_read_test() ->
    File = file(""),
    File = file(["a: " ++ File]),
    ?assertMatch(
       {ok, [{a, _}]},
       yctest:parse(File, #{a => yctest:file()})).

bad_file_read_test() ->
    File = file(["a: non_existent"]),
    ?checkError(
       {read_file, enoent, _},
       yctest:parse(File, #{a => yctest:file()})).

file_write_test() ->
    File = file(""),
    File = file(["a: " ++ File]),
    ?assertMatch(
       {ok, [{a, _}]},
       yctest:parse(File, #{a => yctest:file(write)})).

bad_file_write_test() ->
    File = file(["a: " ++ test_dir()]),
    ?checkError(
       {create_file, eisdir, _},
       yctest:parse(File, #{a => yctest:file(write)})),
    File = file(["a: " ++ filename:join(File, "foo")]),
    ?checkError(
       {create_dir, eexist, _},
       yctest:parse(File, #{a => yctest:file(write)})).

directory_read_test() ->
    File = file(["a: " ++ test_dir()]),
    ?assertMatch(
       {ok, [{a, _}]},
       yctest:parse(File, #{a => yctest:directory()})).

bad_directory_read_test() ->
    File = file(["a: non_existent"]),
    ?checkError(
       {read_dir, enoent, _},
       yctest:parse(File, #{a => yctest:directory()})).

directory_write_test() ->
    File = file(["a: " ++ test_dir()]),
    ?assertMatch(
       {ok, [{a, _}]},
       yctest:parse(File, #{a => yctest:directory(write)})).

bad_directory_write_test() ->
    File = file(""),
    File = file(["a: " ++ File]),
    ?checkError(
       {create_dir, eexist, _},
       yctest:parse(File, #{a => yctest:directory(write)})).

url_test() ->
    File = file(["a: http://domain.tld",
		 "b: https://domain.tld"]),
    ?assertEqual(
       {ok, [{a, <<"http://domain.tld">>}, {b, <<"https://domain.tld">>}]},
       yctest:parse(File, #{a => yctest:url(), b => yctest:url()})).

url_any_test() ->
    File = file(["a: wss://domain.tld:8443"]),
    ?assertEqual(
       {ok, [{a, <<"wss://domain.tld:8443">>}]},
       yctest:parse(File, #{a => yctest:url([])})).

bad_url_scheme_test() ->
    File = file(["a: http://domain.tld"]),
    ?checkError(
       {bad_url, {unsupported_scheme, http}, <<"http://domain.tld">>},
       yctest:parse(File, #{a => yctest:url([https])})).

bad_url_host_test() ->
    File = file(["a: http:///path"]),
    ?checkError(
       {bad_url, empty_host, <<"http:///path">>},
       yctest:parse(File, #{a => yctest:url()})).

bad_url_test() ->
    File = file(["a: bad"]),
    ?checkError(
       {bad_url, _, <<"bad">>},
       yctest:parse(File, #{a => yctest:url()})).

octal_test() ->
    File = file(["a: \"644\""]),
    ?assertEqual(
       {ok, [{a, 420}]},
       yctest:parse(File, #{a => yctest:octal()})).

bad_octal_test() ->
    File = file(["a: \"9\""]),
    ?checkError(
       {bad_octal, <<"9">>},
       yctest:parse(File, #{a => yctest:octal()})).

ipv4_test() ->
    File = file(["a: 127.0.0.1"]),
    ?assertEqual(
       {ok, [{a, {127,0,0,1}}]},
       yctest:parse(File, #{a => yctest:ipv4()})).

bad_ipv4_test() ->
    File = file(["a: '::1'"]),
    ?checkError(
       {bad_ipv4, "::1"},
       yctest:parse(File, #{a => yctest:ipv4()})).

ipv6_test() ->
    File = file(["a: '::1'"]),
    ?assertEqual(
       {ok, [{a, {0,0,0,0,0,0,0,1}}]},
       yctest:parse(File, #{a => yctest:ipv6()})).

bad_ipv6_test() ->
    File = file(["a: 127.0.0.1"]),
    ?checkError(
       {bad_ipv6, "127.0.0.1"},
       yctest:parse(File, #{a => yctest:ipv6()})).

ip_test() ->
    File = file(["a: 127.0.0.1",
		 "b: '::1'"]),
    ?assertEqual(
       {ok, [{a, {127,0,0,1}}, {b, {0,0,0,0,0,0,0,1}}]},
       yctest:parse(File, #{a => yctest:ip(), b => yctest:ip()})).

bad_ip_test() ->
    File = file(["a: bad"]),
    ?checkError(
       {bad_ip, "bad"},
       yctest:parse(File, #{a => yctest:ip()})).

ip_mask_test() ->
    File = file(["a: 127.0.0.1",
		 "b: 127.0.0.1/0",
		 "c: 127.0.0.1/32",
		 "d: '::1'",
		 "e: '::1/0'",
		 "f: '::1/128'"]),
    ?assertEqual(
       {ok, [{a, {{127,0,0,1}, 32}},
	     {b, {{127,0,0,1}, 0}},
	     {c, {{127,0,0,1}, 32}},
	     {d, {{0,0,0,0,0,0,0,1}, 128}},
	     {e, {{0,0,0,0,0,0,0,1}, 0}},
	     {f, {{0,0,0,0,0,0,0,1}, 128}}]},
       yctest:parse(File, #{a => yctest:ip_mask(),
			   b => yctest:ip_mask(),
			   c => yctest:ip_mask(),
			   d => yctest:ip_mask(),
			   e => yctest:ip_mask(),
			   f => yctest:ip_mask()})).

bad_ip_mask_test() ->
    File = file(["a: 127.0.0.1/128"]),
    ?checkError(
       {bad_ip_mask, "127.0.0.1/128"},
       yctest:parse(File, #{a => yctest:ip_mask()})).

port_test() ->
    File = file(["a: 1",
		 "b: 65535"]),
    ?assertEqual(
       {ok, [{a, 1}, {b, 65535}]},
       yctest:parse(File, #{a => yctest:port(), b => yctest:port()})).

timeout_test() ->
    File = file(["millisecond: 1",
		 "second: 1",
		 "minute: 1",
		 "hour: 1",
		 "day: 1"]),
    ?assertEqual(
       {ok, [{millisecond, 1},
	     {second, 1000},
	     {minute, 60000},
	     {hour, 3600000},
	     {day, 86400000}]},
       yctest:parse(File, #{millisecond => yctest:timeout(millisecond),
			   second => yctest:timeout(second),
			   minute => yctest:timeout(minute),
			   hour => yctest:timeout(hour),
			   day => yctest:timeout(day)})).

timeout_atom_test() ->
    File = file(["a: '5'"]),
    ?assertEqual(
       {ok, [{a, 5}]},
       yctest:parse(File, #{a => yctest:timeout(millisecond)},
		   [plain_as_atom])).

timeout_format_test() ->
    File = file(["ms: 1 ms",
		 "msec: 1 msec",
		 "msecs: 1 msecs",
		 "millisec: 1 millisec",
		 "millisecs: 1 millisecs",
		 "millisecond: 1 millisecond",
		 "s: 1 s",
		 "sec: 1 sec",
		 "secs: 1 secs",
		 "second: 1 second",
		 "seconds: 1 seconds",
		 "m: 1 m",
		 "min: 1 min",
		 "mins: 1 mins",
		 "minute: 1 minute",
		 "minutes: 1 minutes",
		 "h: 1 h",
		 "hour: 1 hour",
		 "hours: 1 hours",
		 "d: 1 d",
		 "day: 1 day",
		 "days: 1 days"]),
    ?assertEqual(
       {ok, [{ms,1},
	     {msec,1},
	     {msecs,1},
	     {millisec,1},
	     {millisecs,1},
	     {millisecond,1},
	     {s,1000},
	     {sec,1000},
	     {secs,1000},
	     {second,1000},
	     {seconds,1000},
	     {m,60000},
	     {min,60000},
	     {mins,60000},
	     {minute,60000},
	     {minutes,60000},
	     {h,3600000},
	     {hour,3600000},
	     {hours,3600000},
	     {d,86400000},
	     {day,86400000},
	     {days,86400000}]},
       yctest:parse(File, #{'_' => yctest:timeout(millisecond)})).

timeout_infinity_test() ->
    File = file(["a: infinity",
		 "b: infinite",
		 "c: unlimited"]),
    ?assertEqual(
       {ok, [{a, infinite}, {b, unlimited}, {c, infinity}]},
       yctest:parse(File, #{a => yctest:timeout(day, infinite),
			   b => yctest:timeout(day, unlimited),
			   c => yctest:timeout(day, infinity)})).

bad_timeout_test() ->
    File = file(["a: []"]),
    ?checkError(
       {bad_timeout, []},
       yctest:parse(File, #{a => yctest:timeout(second)})),
    ?checkError(
       {bad_timeout, infinity, []},
       yctest:parse(File, #{a => yctest:timeout(second, infinity)})).

bad_timeout_zero_test() ->
    File = file(["a: 0"]),
    ?checkError(
       {bad_pos_int, 0},
       yctest:parse(File, #{a => yctest:timeout(second)})),
    ?checkError(
       {bad_pos_int, infinity, 0},
       yctest:parse(File, #{a => yctest:timeout(second, infinity)})).

bad_timeout_infinity_test() ->
    File = file(["a: foo"]),
    ?checkError(
       {bad_int, <<"foo">>},
       yctest:parse(File, #{a => yctest:timeout(second)})),
    ?checkError(
       {bad_enum, _, foo},
       yctest:parse(File, #{a => yctest:timeout(second, infinity)})).

bad_timeout_unit_test() ->
    File = file(["a: 1foo"]),
    ?checkError(
       {bad_timeout_unit, "foo"},
       yctest:parse(File, #{a => yctest:timeout(second)})).

bad_timeout_min_test() ->
    File = file(["a: 1ms"]),
    ?checkError(
       {bad_timeout_min, second},
       yctest:parse(File, #{a => yctest:timeout(second)})).

bad_timeout_negative_test() ->
    File = file(["a: -1s"]),
    ?checkError(
       {bad_pos_int, -1},
       yctest:parse(File, #{a => yctest:timeout(second)})),
    ?checkError(
       {bad_pos_int, infinity, -1},
       yctest:parse(File, #{a => yctest:timeout(second, infinity)})).

re_test() ->
    File = file(["a: ^[0-9]+$"]),
    ?assertMatch(
       {ok, [{a, _}]},
       yctest:parse(File, #{a => yctest:re()})).

bad_re_test() ->
    File = file(["a: '['"]),
    ?checkError(
       {bad_regexp, {_, _}, _},
       yctest:parse(File, #{a => yctest:re()})).

glob_test() ->
    File = file(["a: '*'"]),
    ?assertMatch(
       {ok, [{a, _}]},
       yctest:parse(File, #{a => yctest:glob()})).

bad_glob_test() ->
    File = file(["a: '['"]),
    ?checkError(
       {bad_glob, {_, _}, _},
       yctest:parse(File, #{a => yctest:glob()})).

beam_test() ->
    Exports = [[{foo, 1}, {parse, 2}], {parse, 3}, []],
    File = file(["a: yctest"]),
    ?assertMatch(
       {ok, [{a, yctest}]},
       yctest:parse(File, #{a => yctest:beam(Exports)})).

bad_beam_test() ->
    File = file(["a: foo"]),
    ?checkError(
       {bad_module, foo},
       yctest:parse(File, #{a => yctest:beam()})),
    File = file(["a: yctest"]),
    ?checkError(
       {bad_export, {foo, 1}, yctest},
       yctest:parse(File, #{a => yctest:beam([[{foo, 1}, {bar, 2}]])})),
    ?checkError(
       {bad_export, {foo, 1}, yctest},
       yctest:parse(File, #{a => yctest:beam([{foo, 1}])})).

non_empty_test() ->
    File = file(["a: [1,2,3]",
		 "b: 1",
		 "c: foo",
		 "d: {e: f}"]),
    ?assertMatch(
       {ok, [{a, [1,2,3]}, {b, 1}, {c, foo}, {d, [_]}]},
       yctest:parse(File, #{a => yctest:non_empty(yctest:list(yctest:int())),
			   b => yctest:non_empty(yctest:int()),
			   c => yctest:non_empty(yctest:atom()),
			   d => yctest:non_empty(yctest:map(yctest:any(), yctest:any()))})).

empty_atom_test() ->
    File = file(["a: ''"]),
    ?checkError(
       empty_atom,
       yctest:parse(File, #{a => yctest:non_empty(yctest:atom())})).

empty_binary_test() ->
    File = file(["a: ''"]),
    ?checkError(
       empty_binary,
       yctest:parse(File, #{a => yctest:non_empty(yctest:binary())})).

empty_list_test() ->
    File = file(["a: []"]),
    ?checkError(
       empty_list,
       yctest:parse(File, #{a => yctest:non_empty(yctest:list(yctest:any()))})).

empty_map_test() ->
    File = file(["a: {}"]),
    ?checkError(
       empty_list,
       yctest:parse(File, #{a => yctest:non_empty(
				  yctest:map(yctest:any(), yctest:any()))})).

list_test() ->
    File = file(["a: [1,2,3]"]),
    ?assertMatch(
       {ok, [{a, [1,2,3]}]},
       yctest:parse(File, #{a => yctest:list(yctest:any())})).

bad_list_test() ->
    File = file(["a: 1"]),
    ?checkError(
       {bad_list, 1},
       yctest:parse(File, #{a => yctest:list(yctest:any())})).

sorted_list_test() ->
    File = file(["a: [3,2,1]"]),
    ?assertMatch(
       {ok, [{a, [1,2,3]}]},
       yctest:parse(File, #{a => yctest:list(yctest:any(), [sorted])})).

bad_sorted_list_test() ->
    File = file(["a: 1"]),
    ?checkError(
       {bad_list, 1},
       yctest:parse(File, #{a => yctest:list(yctest:any(), [sorted])})).

unique_list_test() ->
    File = file(["a: [1,2,3]"]),
    ?assertMatch(
       {ok, [{a, [1,2,3]}]},
       yctest:parse(File, #{a => yctest:list(yctest:any(), [unique])})).

bad_unique_list_test() ->
    File = file(["a: [1,2,1,3]"]),
    ?checkError(
       {duplicated_value, 1},
       yctest:parse(File, #{a => yctest:list(yctest:any(), [unique])})),
    File = file(["a: [foo, bar, foo]"]),
    ?checkError(
       {duplicated_value, foo},
       yctest:parse(File, #{a => yctest:list(yctest:atom(), [unique])})),
    File = file(["a: [[1], [2], [1]]"]),
    ?checkError(
       {duplicated_value, [1]},
       yctest:parse(File, #{a => yctest:list(yctest:any(), [unique])})).

list_or_single_test() ->
    File = file(["a: 1",
		 "b: [1,2,3]"]),
    ?assertMatch(
       {ok, [{a, [1]}, {b, [1,2,3]}]},
       yctest:parse(File, #{a => yctest:list_or_single(yctest:any()),
			   b => yctest:list_or_single(yctest:any())})).

sorted_list_or_single_test() ->
    File = file(["a: 1",
		 "b: [3,2,1]"]),
    ?assertMatch(
       {ok, [{a, [1]}, {b, [1,2,3]}]},
       yctest:parse(File, #{a => yctest:list_or_single(yctest:any(), [sorted]),
			   b => yctest:list_or_single(yctest:any(), [sorted])})).

unique_list_or_single_test() ->
    File = file(["a: 1",
		 "b: [1,2,3]"]),
    ?assertMatch(
       {ok, [{a, [1]}, {b, [1,2,3]}]},
       yctest:parse(File, #{a => yctest:list_or_single(yctest:any(), [unique]),
			   b => yctest:list_or_single(yctest:any(), [unique])})).

bad_unique_list_or_single_test() ->
    File = file(["a: 1",
		 "b: [1,2,1,3]"]),
    ?checkError(
       {duplicated_value, 1},
       yctest:parse(File, #{a => yctest:list_or_single(yctest:any(), [unique]),
			   b => yctest:list_or_single(yctest:any(), [unique])})).

map_test() ->
    File = file(["a: {c: 2, b: 1}"]),
    ?assertEqual(
       {ok, [{a, [{c, 2}, {b, 1}]}]},
       yctest:parse(File, #{a => yctest:map(yctest:atom(), yctest:any())})),
    ?assertEqual(
       {ok, [{a, [{c, 2}, {b, 1}]}]},
       yctest:parse(File, #{a => yctest:map(yctest:atom(), yctest:any(),
					  [unique])})),
    ?assertEqual(
       {ok, [{a, [{b, 1}, {c, 2}]}]},
       yctest:parse(File, #{a => yctest:map(yctest:atom(), yctest:any(),
					  [{return, orddict}])})),
    ?assertEqual(
       {ok, [{a, #{b => 1, c => 2}}]},
       yctest:parse(File, #{a => yctest:map(yctest:atom(), yctest:any(),
					  [{return, map}])})),
    Ret = yctest:parse(File, #{a => yctest:map(yctest:atom(), yctest:any(),
					     [{return, dict}])}),
    ?assertMatch({ok, [{a, _}]}, Ret),
    ?assertEqual(
       [{b, 1}, {c, 2}],
       lists:keysort(1, dict:to_list(element(2, hd(element(2, Ret)))))).

bad_map_test() ->
    V = yctest:map(yctest:atom(), yctest:any()),
    File = file(["a: 1"]),
    ?checkError(
       {bad_map, 1},
       yctest:parse(File, #{a => V})),
    File = file(["a: [1,2,3]"]),
    ?checkError(
       {bad_map, [1,2,3]},
       yctest:parse(File, #{a => V})).

bad_unique_map_test() ->
    File = file(["a: {c: 2, b: 1, c: 3}"]),
    ?checkError(
       {duplicated_key, c},
       yctest:parse(File, #{a => yctest:map(yctest:atom(), yctest:any(),
					  [unique])})).

either_test() ->
    V = yctest:either(yctest:bool(), yctest:int()),
    File = file(["a: true",
		 "b: 5"]),
    ?assertEqual(
       {ok, [{a, true}, {b, 5}]},
       yctest:parse(File, #{a => V, b => V})).

either_atom_test() ->
    V = yctest:either(atom, yctest:int()),
    File = file(["a: atom",
		 "b: 1"]),
    ?assertEqual(
       {ok, [{a, atom}, {b, 1}]},
       yctest:parse(File, #{a => V, b => V})).

and_then_test() ->
    V = yctest:and_then(
	  yctest:list(yctest:int()),
	  fun lists:sum/1),
    File = file(["a: [1,2,3]"]),
    ?assertEqual(
       {ok, [{a, 6}]},
       yctest:parse(File, #{a => V})).

options_test() ->
    File = file(["a: {b: 1, c: true}"]),
    ?assertEqual(
       {ok, [{a, [{b, 1}, {c, true}]}]},
       yctest:parse(File, #{a => yctest:options(
				  #{b => yctest:int(),
				    c => yctest:bool(),
				    d => yctest:atom()})})).

options_return_map_test() ->
    File = file(["a: 1",
		 "b: 2"]),
    ?assertEqual(
       {ok, #{a => 1, b => 2}},
       yctest:parse(File, #{a => yctest:any(),
			   b => yctest:any()},
		   [{return, map}])).

options_return_dict_test() ->
    File = file(["a: 1",
		 "b: 2"]),
    Ret = yctest:parse(File, #{a => yctest:any(),
			      b => yctest:any()},
		      [{return, dict}]),
    ?assertMatch({ok, _}, Ret),
    ?assertEqual(
       [{a, 1}, {b, 2}],
       lists:keysort(1, dict:to_list(element(2, Ret)))).

options_return_orddict_test() ->
    File = file(["b: 1",
		 "a: 2"]),
    ?assertEqual(
       {ok, [{a, 2}, {b, 1}]},
       yctest:parse(File, #{a => yctest:any(),
			   b => yctest:any()},
		   [{return, orddict}])).

options_default_validator_test() ->
    File = file(["a: {b: 1, c: true}"]),
    ?assertEqual(
       {ok, [{a, [{b, 1}, {c, true}]}]},
       yctest:parse(File, #{a => yctest:options(
				  #{b => yctest:int(),
				    '_' => yctest:bool()})})).

bad_options_test() ->
    File = file(["a: 1"]),
    ?checkError(
       {bad_map, 1},
       yctest:parse(File, #{a => yctest:options(#{})})),
    File = file(["a: [1,2,3]"]),
    ?checkError(
       {bad_map, [1,2,3]},
       yctest:parse(File, #{a => yctest:options(#{})})).

bad_binary_map_option_test() ->
    File = file(["a: {b: foo}"]),
    ?checkError(
       {bad_bool, foo},
       yctest:parse(File, #{a => yctest:map(yctest:binary(), yctest:bool())})).

bad_integer_map_option_test() ->
    File = file(["a: {1: foo}"]),
    ?checkError(
       {bad_bool, foo},
       yctest:parse(File, #{a => yctest:map(yctest:int(), yctest:bool())})).

unknown_option_test() ->
    File = file(["a: 1"]),
    ?checkError(
       {unknown_option, [define_macro], a},
       yctest:parse(File, #{}, [replace_macros])).

missing_option_test() ->
    File = file(["a: 1"]),
    ?checkError(
       {missing_option, b},
       yctest:parse(File, #{a => yctest:int(),
			   b => yctest:any()},
		   [{required, [b]}])).

disallowed_option_test() ->
    File = file(["a: 1",
		 "b: 2"]),
    ?checkError(
       {disallowed_option, b},
       yctest:parse(File, #{a => yctest:int()},
		   [{disallowed, [b]}])),
    ?checkError(
       {disallowed_option, b},
       yctest:parse(File, #{a => yctest:int(), b => yctest:int()},
		   [{disallowed, [b]}])),
    ?checkError(
       {disallowed_option, b},
       yctest:parse(File, #{a => yctest:int(), b => yctest:int()},
		   [{required, [b]}, {disallowed, [b]}])).

unknown_option_with_disallowed_test() ->
    File = file(["a: 1",
		 "c: 2"]),
    ?checkError(
       {unknown_option, [a], c},
       yctest:parse(File, #{a => yctest:int(), b => yctest:int()},
		   [{disallowed, [b]}])).

duplicated_option_test() ->
    File = file(["a: 1",
		 "b: 2",
		 "a: 3"]),
    ?checkError(
       {duplicated_option, a},
       yctest:parse(File, #{a => yctest:int(), b => yctest:int()},
		   [unique])),
    ?assertEqual(
       {ok, [{a, 1}, {b, 2}, {a, 3}]},
       yctest:parse(File, #{a => yctest:int(), b => yctest:int()}, [])).

duplicated_unknown_option_test() ->
    File = file(["a: 1",
		 "b: 2",
		 "b: 3"]),
    ?checkError(
       {duplicated_option, b},
       yctest:parse(File, #{a => yctest:int(),
			   '_' => yctest:any()},
		   [unique])).

bad_cwd_test() ->
    test_format_error({error, {bad_cwd, eaccess}, []}).

unknown_reason_test() ->
    test_format_error({error, foo, []}).

unicode_test() ->
    UTF8CharList = [209,134],
    UTF8CharBin = list_to_binary(UTF8CharList),
    UTF8CharAtom = list_to_atom(UTF8CharList),
    File = file(["a: " ++ UTF8CharList,
		 "b: " ++ UTF8CharList]),
    ?assertEqual(
       {ok, [{a, UTF8CharAtom}, {b, UTF8CharBin}]},
       yctest:parse(File, #{a => yctest:atom(),
			   b => yctest:binary()},
		   [plain_as_atom])),
    ?assertEqual(
       {ok, [{a, UTF8CharAtom}, {b, UTF8CharBin}]},
       yctest:parse(File, #{a => yctest:atom(),
			   b => yctest:binary()})).

stop_test() ->
    ?assertEqual(ok, yctest:stop()).

%%%===================================================================
%%% Internal functions
%%%===================================================================
test_dir() ->
    {ok, Cwd} = file:get_cwd(),
    CwdClean = case lists:reverse(filename:split(Cwd)) of
                   [".eunit" | Tail] -> Tail; % when using rebar2
                   Tail -> Tail % when using rebar3
    end,
    filename:join(lists:reverse(["test" | CwdClean])).

file(Data) ->
    file("test.yml", Data).

included_file(Data) ->
    file("included.yml", Data).

file(FileName, Data) ->
    Path = filename:join(test_dir(), FileName),
    ok = file:write_file(Path, string:join(Data, io_lib:nl())),
    Path.

test_format_error({error, Why, Ctx}) ->
    ?assertMatch([_|_], yctest:format_error(Why, Ctx)).
