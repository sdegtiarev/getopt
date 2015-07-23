module local.getopt;
import std.exception;
//import std.stdio;


struct Option
{
	void delegate(string,string) handle;
	Match mtype;
	string argType=null;
	string help, tag;

	@property bool shortOption() { return tag.length == 1 && mtype == Match.text; }
	@property bool longOption() { return tag.length > 1 || mtype == Match.regex; }
	@property bool needArg() { return !(argType is null); }
	@property bool matchEqualSign() { return longOption && needArg; }
	@property bool exactMatch() { return longOption && !needArg; }
};



enum Match { text, regex };
enum noThrow { yes };


Exception getopt(T...)(ref Option[] opt, ref string[] arg, T commandLine)
{
	opt=[];
	Exception r=null;
	static if(is(typeof(commandLine[0]) == noThrow)) {
		immutable bool catchExceptions=true;
		option_tree(opt, commandLine[1..$]);
	} else {
		immutable bool catchExceptions=false;
		option_tree(opt, commandLine);
	}

	string prog=shift(arg);
	static if(catchExceptions)
		r=collectException(option_parse(arg, opt));
	else
		option_parse(arg, opt);
	unshift(prog, arg);
	return r;
}


string optionHelp(T)(T list)
{
    import std.format;
	import std.algorithm : min, max;
	typeof(Option.tag.length) len=0;
	foreach(opt; list)
		len=max(len, key(opt).length+opt.argType.length+1);
	
	string help;
	foreach(opt; list) {
		string s=key(opt)~(opt.shortOption? " ":"")~opt.argType;
		if(opt.help == "") opt.help="not documented";
		help~=format("%-*s    - %s\n", len, s, opt.help);
	}
	return help;
}




///////////////////////////////////////////////////////////////////////////////////////

private void option_tree(T...)(ref Option[] tree, T commandLine)
{
	static if(commandLine.length > 0) {
		static if(is(typeof(commandLine[0]) == Match))
			option_tree_match(tree, commandLine[0], commandLine[1..$]);
		else
			option_tree_match(tree, Match.text, commandLine);
	}
}


private void option_tree_match(T...)(ref Option[] tree, Match match, T commandLine)
{
	// we enforce (CT) the next parameter is option tag
	string tag=commandLine[0];
	// the next one may be help string or receiver if help omitted
	static if(is(typeof(commandLine[1]) == string)) {
		auto help=commandLine[1];
		auto receiver=commandLine[2];
		option_build(tree, match, tag, help, receiver, commandLine[3..$]);
	} else {
		auto receiver=commandLine[1];
		option_build(tree, match, tag, "", receiver, commandLine[2..$]);
	}
}



private void option_build(R, T...)(ref Option[] tree, Match match, string tag, string help, R receiver, T commandLine)
{
    import std.conv : to;
	import std.array : split;
	import std.traits;


	static if(is(typeof(receiver) == delegate) || is(typeof(*receiver) == function)) {
	// functor passed as option handler

		static if(ParameterTypeTuple!receiver.length == 0) {
		// argumentless switch, functor with no parameters
			typeof(Option.handle) handle=delegate(string key, string val){ receiver(); };
			add_option(tree, Option(handle, match, null, help), tag);

		} else static if(ParameterTypeTuple!receiver.length == 1) {
		// argument with parameter, one argument functor
			typeof(Option.handle) handle=delegate(string key, string val){ receiver(to!(ParameterTypeTuple!receiver[0])(val)); };
			auto arg=" <"~ParameterTypeTuple!receiver[0].stringof~">";
			add_option(tree, Option(handle, match, arg, help), tag);

		} else static if(ParameterTypeTuple!receiver.length == 2) {
		// argument with parameter, two argument functor, key and val
			typeof(Option.handle) handle=delegate(string key, string val){ receiver(to!(ParameterTypeTuple!receiver[0])(key),to!(ParameterTypeTuple!receiver[1])(val)); };
			auto arg=" <"~ParameterTypeTuple!receiver[0].stringof~","~ParameterTypeTuple!receiver[1].stringof~">";
			add_option(tree, Option(handle, match, arg, help), tag);

		} else {
		// functor with more than one argument, error
			static assert(false, typeof(receiver).stringof~": invalid getopt handler signature");
		}
		option_tree(tree, commandLine);


		} else static if(is(typeof(*receiver) == bool)) {
		// bool pointer passed as option handler, assuming no argumnets
		static if(commandLine.length && is(typeof(commandLine[0]) == bool)) {
			typeof(Option.handle) handle=delegate(string key, string val){ *receiver=commandLine[0]; };
			add_option(tree, Option(handle, match, null, help), tag);
			option_tree(tree, commandLine[1..$]);
		} else {
			typeof(Option.handle) handle=delegate(string key, string val){ *receiver=true; };
			add_option(tree, Option(handle, match, null, help), tag);
			option_tree(tree, commandLine);
		}


	} else static if(is(typeof(*receiver) == string)) {
	// to distinguish string and array, just assign

		typeof(Option.handle) handle=delegate(string key, string val){ *receiver=val; };
		auto arg="<"~typeof(*receiver).stringof~">";
		add_option(tree, Option(handle, match, arg, help), tag);
		option_tree(tree, commandLine);

	} else static if(is(typeof(*receiver) == U[], U)) {
	// array pointer passed, convert argument and push into
		auto handle=delegate(string key, string val){ foreach(v; split(val,",")) (*receiver)~=to!U(v); };
		auto arg="<"~typeof(*receiver).stringof~">";
		add_option(tree, Option(handle, match, arg, help), tag);
		option_tree(tree, commandLine);

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
		typeof(Option.handle) handle=delegate(string key, string val){ foreach(x; split(val,",")) { auto v=kv(x); (*receiver)[v.key]=v.val; }};
		auto arg="<"~typeof(*receiver).stringof~">";
		add_option(tree, Option(handle, match, arg, help), tag);
		option_tree(tree, commandLine);

	} else static if(is(typeof(receiver) == U*, U)) {
	// some generic pointer passed as option handler, convert argument and assign
		auto handle=delegate(string key, string val){ *receiver=to!(typeof(*receiver))(val); };
		auto arg="<"~typeof(*receiver).stringof~">";
		add_option(tree, Option(handle, match, arg, help), tag);
		option_tree(tree, commandLine);

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
		opt.tag=v;
		opt.help=ref_help;
		ref_help="same as "~ref_tag;
		tree~=opt;
	}
}





private void option_parse(ref string[] arg, Option[] commandLine)
{
	while(arg.length && arg[0][0] == '-') {
		auto opt=shift(arg);
		if(opt == "--")
				return;

		match_option(opt, arg, commandLine);
	}
}



private void match_option(string arg, ref string[] commandLine, Option[] optList)
{
	import std.exception : enforce;

	foreach(opt; optList) {
		auto kv=match(opt,arg);
		if(!kv.match)
				continue;

		if(opt.shortOption) {
			if(opt.needArg) {
			// find either bundled or unbundled argument
				if(kv.val == "") {
					enforce(commandLine.length,key(opt)~" requires an argument");
					kv.val=shift(commandLine);
				}
			} else {
			// unbundle option and keep the rest for further processing
				if(kv.val != "") { unshift("-"~kv.val, commandLine); kv.val=""; }
			}
		} else if(opt.longOption && opt.needArg) {
			enforce(kv.val != "", key(opt)~" requires an argument");
		}

		opt.handle(kv.arg, kv.val);
		return;
	}

	enforce(false, "invalid option '"~arg~"'");
}



private auto match(Option opt, string input) {
	import std.string : indexOf;
	import std.regex : regex,matchFirst;
	import std.typecons : Tuple, tuple;

	if(opt.mtype == Match.text) {
		auto pattern=key(opt);
//writeln("comp  ",input," with ",pattern,": ", indexOf(input, pattern) == 0);
		if(indexOf(input, pattern))
			return tuple!("match","arg","val")(false, opt.tag, "");
		auto val=input[pattern.length..$];
		bool matching=opt.exactMatch? (val == "") : true;
		return tuple!("match","arg","val")(matching, opt.tag, val);

	} else {
		auto c=matchFirst(input, local.getopt.regex(opt));
//writeln("match ",input," with ",local.getopt.regex(opt),": ", !c.empty,"    ", c);
		string key, val;
		if(c.length > 2) { key=c[c.length-2]; val=c[c.length-1]; }
		else if(c.length > 1) { key=c[c.length-1]; }
		if(c) return tuple!("match","arg","val")(!c.empty, key, val);
		else  return tuple!("match","arg","val")(!c.empty, opt.tag, "");
	}
}


private auto key(Option opt)
{
	auto prefix="-", postfix="";
	if(opt.longOption) {
		prefix="--";
		if(opt.needArg) postfix="=";
	}
	return prefix~opt.tag~postfix;
}

private auto regex(Option opt)
{
	auto prefix="^-(", postfix=")(.*)";
	if(opt.longOption) {
		prefix="^--(";
		if(opt.needArg) postfix=")=(.*)";
		else			postfix=")$";
	}
	return prefix~opt.tag~postfix;
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



