# YAML configuration processor TEST TEST

This is a temporary fork of yconf for testing github action hex publishing

[![CI](https://github.com/badlop/yctest/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/badlop/yctest/actions/workflows/ci.yml)
[![CI](https://github.com/badlop/yctest/actions/workflows/hexpm-release.yml/badge.svg?branch=main)](https://github.com/badlop/yctest/actions/workflows/hexpm-release.yml)
[![Hex version](https://img.shields.io/hexpm/v/yctest.svg "Hex version")](https://hex.pm/packages/yctest)

You can find usage example in ejabberd. See `econf.erl` and `ejabberd_options.erl` for most parts that are using it.

Validation is performed based on rules that you pass to `yconf:parser/2`, there is no way to load those rules from
some special syntax file. Generally you will do something like this:

```
yconf:parse("/home/me/conf.yml", #{
  host => yconf:string(),
  opts => yconf:options(#{
    addr => yconf:ip(),
    count => yconf:non_neg_int()
  }
)}).
```

That when feed with:

```
host: "test.com"
opts:
  addr: "127.0.0.1"
  count: 100
```

should produce:

```
{ok,[{host,"test.com"},{opts,[{addr,{127,0,0,1}},{count,100}]}]}
```
