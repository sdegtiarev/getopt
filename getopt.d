module local.getopt;



struct Option
{
	void delegate(string s) handle;
	Match mtype;
	string argType=null;
	string help, tag;

	private bool match(ref string input) {
		import std.string : indexOf;
		import std.regex : regex,replaceFirst;

		if(mtype == Match.text) {
			if(indexOf(input, tag))
				return false;
			input=input[tag.length..$];
			return matchExact? (input == "") : true;

		} else {
			auto opt=input;
			input=replaceFirst(opt, regex("^"~tag), "");
			return opt != input;
		}
	}

	@property bool shortOption() { return tag.length == 2; }
	@property bool longOption() { return tag.length > 2; }
	@property bool needArg() { return !(argType is null); }
	@property bool matchEqualSign() { return longOption && needArg; }
	@property bool matchExact() { return longOption && !needArg; }
};



enum Match { text, regex };



void getopt(T...)(ref Option[] opt, ref string[] arg, T cmd)
{
	opt=[];
	option_tree(opt, cmd);

	string prog=shift(arg);
	option_parse(arg, opt);
	unshift(prog, arg);
}


string optionHelp(T)(T list)
{
    import std.format;
	import std.algorithm : min, max;
	typeof(Option.tag.length) len=0;
	foreach(opt; list)
		len=max(len, opt.tag.length+opt.argType.length+1);
	
	string help;
	foreach(opt; list) {
		//string s=opt.tag~((!opt.shortOption && opt.needArg)? "=":" ")~opt.argType;
		string s=opt.tag~(opt.shortOption? " ":"")~opt.argType;
		if(opt.help == "") opt.help="not documented";
		help~=format("%-*s    - %s\n", len, s, opt.help);
	}
	return help;
}






private void option_tree(T...)(ref Option[] tree, T cmd)
{
	static if(cmd.length > 0) {
		static if(is(typeof(cmd[0]) == Match))
			option_tree_match(tree, cmd[0], cmd[1..$]);
		else
			option_tree_match(tree, Match.text, cmd);
	}
}


private void option_tree_match(T...)(ref Option[] tree, Match match, T cmd)
{
	static if(cmd.length > 0) {
		auto tag=cmd[0];
		static if(is(typeof(cmd[1]) == string)) {
			auto help=cmd[1];
			auto receiver=cmd[2];
			option_build(tree, match, tag, help, receiver, cmd[3..$]);
		} else {
			auto receiver=cmd[1];
			option_build(tree, match, tag, "", receiver, cmd[2..$]);
		}
	}
}



private void option_build(R, T...)(ref Option[] tree, Match match, string tag, string help, R receiver, T cmd)
{
    import std.conv : text, to;
	import std.array : split;
	import std.traits;


	static if(is(typeof(receiver) == delegate) || is(typeof(*receiver) == function)) {
	// functor passed as option handler

		static if(ParameterTypeTuple!receiver.length == 0) {
		// argumentless switch, functor with no parameters
			typeof(Option.handle) handle=delegate(string){ receiver(); };
			add_option(tree, Option(handle, match, null, help), tag);

		} else static if(ParameterTypeTuple!receiver.length == 1) {
		// argument with parameter, one argument functor
			typeof(Option.handle) handle=delegate(string s){ receiver(to!(ParameterTypeTuple!receiver[0])(s)); };
			auto arg=" <"~ParameterTypeTuple!receiver[0].stringof~">";
			add_option(tree, Option(handle, match, arg, help), tag);

		} else {
		// functor with more than one argument, error
			static assert(false, typeof(receiver).stringof~": invalid getopt handler signature");
		}
		option_tree(tree, cmd);


		} else static if(is(typeof(*receiver) == bool)) {
		// bool pointer passed as option handler, assuming no argumnets
		static if(cmd.length && is(typeof(cmd[0]) == bool)) {
			typeof(Option.handle) handle=delegate(string){ *receiver=cmd[0]; };
			add_option(tree, Option(handle, match, null, help), tag);
			option_tree(tree, cmd[1..$]);
		} else {
			typeof(Option.handle) handle=delegate(string){ *receiver=true; };
			add_option(tree, Option(handle, match, null, help), tag);
			option_tree(tree, cmd);
		}


	} else static if(is(typeof(*receiver) == string)) {
	// to distinguish string and array, just assign

		typeof(Option.handle) handle=delegate(string val){ *receiver=val; };
		auto arg="<"~typeof(*receiver).stringof~">";
		add_option(tree, Option(handle, match, arg, help), tag);
		option_tree(tree, cmd);

	} else static if(is(typeof(*receiver) == U[], U)) {
	// array pointer passed, convert argument and push into
		auto handle=delegate(string val){ foreach(v; split(val,",")) (*receiver)~=to!U(v); };
		auto arg="<"~typeof(*receiver).stringof~">";
		add_option(tree, Option(handle, match, arg, help), tag);
		option_tree(tree, cmd);

	} else static if(is(typeof(*receiver) == U[V], U, V)) {
	// map pointer passed, convert argument and push into
		import std.string : indexOf;
		import std.typecons : Tuple, tuple;
		static auto kv(string input) {
		    auto i=indexOf(input, '=');
		    assert(i > 0, "invalid value for map '"~input~"'");
		    auto key=input[0..i];
		    auto val=input[i+1..$];
		    return tuple!("key","val")(to!V(key), to!U(val));
		}
		typeof(Option.handle) handle=delegate(string val){ foreach(x; split(val,",")) { auto v=kv(x); (*receiver)[v.key]=v.val; }};
		auto arg="<"~typeof(*receiver).stringof~">";
		add_option(tree, Option(handle, match, arg, help), tag);
		option_tree(tree, cmd);

	} else static if(is(typeof(receiver) == U*, U)) {
	// some generic pointer passed as option handler, convert argument and assign
		auto handle=delegate(string val){ *receiver=to!(typeof(*receiver))(val); };
		auto arg="<"~typeof(*receiver).stringof~">";
		add_option(tree, Option(handle, match, arg, help), tag);
		option_tree(tree, cmd);

	} else {
	// nothing else is allowed as option handler
		static assert(false, typeof(receiver).stringof~": invalid getopt handler");
	}
}


private void add_option(T...)(ref Option[] tree, Option opt, string tag)
{
	import std.array : split;
	auto ref_tag=split(tag, "|")[0], ref_help=opt.help;
	foreach(v; split(tag, "|")) {
		assert((v.length == 2 && v[0] == '-') || (v.length > 2 && v[0] == '-' && v[1] == '-'), "neither short nor long option '"~v~"'");
		//enforce((v.length == 2 && v[0] == '-') || (v.length > 2 && v[0] == '-' && v[1] == '-'), "getopt: neither short nor long option '"~v~"'");
		opt.tag=v;
		if(opt.matchEqualSign) opt.tag~="=";
		opt.help=ref_help;
		ref_help="same as "~ref_tag;
		tree~=opt;
	}
}





private void option_parse(ref string[] arg, Option[] cmd)
{
	while(arg.length && arg[0][0] == '-') {
		auto opt=shift(arg);
		if(opt == "--")
				return;

		match_option(opt, arg, cmd);
	}
}



private void match_option(string opt, ref string[] arg, Option[] cmd)
{
	import std.exception : enforce;

	string val="EMPTY";
	foreach(tag; cmd) {
		val=opt;
		if(!tag.match(val))
				continue;

		if(tag.shortOption) {
			if(tag.needArg) {
			// find either bundled or unbundled argument
				if(val == "") {
					enforce(arg.length,"getopt: "~tag.tag~" requires an argument");
					val=shift(arg);
				}
			} else {
			// unbundle option and keep the rest for further processing
				if(val != "") { unshift("-"~val, arg); val=""; }
			}
		}
		tag.handle(val);
		return;
	}

	enforce(false, "getopt: invalid option '"~opt~"'");
}



private string shift(ref string[] arg, int line=__LINE__)
{
	string r=arg[0];
	arg=arg[1..$];
	return r;
}

private void unshift(string top, ref string[] arg)
{
	arg=top~arg;
}



