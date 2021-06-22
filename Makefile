REBAR ?= rebar3

all: src

src:
	$(REBAR) get-deps
	$(REBAR) compile

clean:
	$(REBAR) clean

distclean: clean
	rm -f config.status
	rm -f config.log
	rm -rf autom4te.cache
	rm -rf _build
	rm -rf deps
	rm -rf ebin
	rm -f rebar.lock
	rm -f test/*.beam
	rm -rf priv
	rm -f vars.config
	rm -f erl_crash.dump
	rm -f compile_commands.json
	rm -rf dialyzer

test: all
	$(REBAR) eunit

xref: all
	$(REBAR) xref

dialyzer:
	$(REBAR) dialyzer

check-syntax:
	gcc -o nul -S ${CHK_SOURCES}

.PHONY: clean src test all dialyzer
