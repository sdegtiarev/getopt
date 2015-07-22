import std.stdio;
import std.traits;
import std.regex;
import std.typecons : tuple, Tuple;



struct Option
{
	void delegate(string s) handle;
	string argType=null;
	string help, tag;

	private bool match(ref string input) {
		auto opt=input;
		input=replaceFirst(opt, rx(), "");
		return opt != input;
	}

	private auto rx() {
		if(shortOption)
			return regex("^"~tag);
		else if(needArg)
			return regex("^"~tag~"=");
		else
			return regex("^"~tag~"$");
	}

	@property bool shortOption() { return tag.length == 2 && tag[0] == '-'; }
	@property bool needArg() { return !(argType is null); }
};



enum matchType { matchText, matchRegex };



void getopt(T...)(ref Option[] opt, ref string[] arg, T cmd)
{
	opt=[];
	option_tree(opt, cmd);

	string prog=shift(arg);
	//option_parse(arg, opt);
	getopt_impl(arg, opt);
	unshift(prog, arg);
}


private string optionHelp(T)(T list)
{
    import std.format;
	import std.algorithm : min, max;
	typeof(Option.tag.length) len=0;
	foreach(opt; list)
		len=max(len, opt.tag.length+opt.argType.length+1);
	
	string help;
	foreach(opt; list) {
		string s=opt.tag~((!opt.shortOption && opt.needArg)? "=":" ")~opt.argType;
		help~=format("%-*s    - %s\n", len, s, opt.help);
	}
	return help;
}






private void option_tree(T...)(ref Option[] tree, T cmd)
{
	static if(cmd.length > 0) {
		auto tag=cmd[0];
		static if(is(typeof(cmd[1]) == string)) {
			auto help=cmd[1];
			auto receiver=cmd[2];
			option_tree_1(tree, tag, help, receiver, cmd[3..$]);
		} else {
			auto receiver=cmd[1];
			option_tree_1(tree, tag, "", receiver, cmd[2..$]);
		}
	}
}



private void option_tree_1(R, T...)(ref Option[] tree, string tag, string help, R receiver, T cmd)
{
    import std.conv : text, to;
	import std.array : split;


	static if(is(typeof(receiver) == delegate) || is(typeof(*receiver) == function)) {
	// functor passed as option handler

		static if(ParameterTypeTuple!receiver.length == 0) {
		// argumentless switch, functor with no parameters
			addOption(tree, Option(delegate(string){ receiver(); }, null, help), tag);

		} else static if(ParameterTypeTuple!receiver.length == 1) {
		// argument with parameter, one argument functor
			addOption(tree, Option(delegate(string s){ receiver(to!(ParameterTypeTuple!receiver[0])(s)); }, " <"~ParameterTypeTuple!receiver[0].stringof~">", help), tag);

		} else {
		// functor with more than one argument, error
			static assert(false, typeof(receiver).stringof~": invalid getopt handler signature");
		}
		option_tree(tree, cmd);


		} else static if(is(typeof(*receiver) == bool)) {
		// bool pointer passed as option handler, assuming no argumnets
		static if(cmd.length && is(typeof(cmd[0]) == bool)) {
			addOption(tree, Option(delegate(string){ *receiver=cmd[0]; }, null, help), tag);
			option_tree(tree, cmd[1..$]);
		} else {
			addOption(tree, Option(delegate(string){ *receiver=true; }, null, help), tag);
			option_tree(tree, cmd);
		}


	} else static if(is(typeof(*receiver) == string)) {
	// to distinguish string and array, just assign

		addOption(tree, Option(delegate(string val){ *receiver=val; }, "<"~typeof(*receiver).stringof~">", help), tag);
		option_tree(tree, cmd);

	} else static if(is(typeof(*receiver) == U[], U)) {
	// array pointer passed, convert argument and push into
		addOption(tree, Option(delegate(string val){ foreach(v; split(val,",")) (*receiver)~=to!U(v); }, "<"~typeof(*receiver).stringof~">", help), tag);
		option_tree(tree, cmd);

	} else static if(is(typeof(*receiver) == U[V], U, V)) {
	// map pointer passed, convert argument and push into
		import std.string : indexOf;
		import std.typecons : Tuple, tuple;
		static auto kv(string input) {
		    auto i=indexOf(input, '=');
		    auto key=input[0..i];
		    auto val=input[i+1..$];
		    return tuple!("key","val")(to!V(key), to!U(val));
		}
		addOption(tree, Option(delegate(string val){ foreach(x; split(val,",")) { auto v=kv(x); (*receiver)[v.key]=v.val; }}, "<"~typeof(*receiver).stringof~">", help), tag);
		option_tree(tree, cmd);

	} else static if(is(typeof(receiver) == U*, U)) {
	// some generic pointer passed as option handler, convert argument and assign
		addOption(tree, Option(delegate(string val){ *receiver=to!(typeof(*receiver))(val); }, "<"~typeof(*receiver).stringof~">", help), tag);
		option_tree(tree, cmd);

	} else {
	// nothing else is allowed as option handler
		static assert(false, typeof(receiver).stringof~": invalid getopt handler");
	}
}


private void addOption(T...)(ref Option[] tree, Option opt, string tag)
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





private void getopt_impl(ref string[] arg, Option[] cmd)
{
	while(arg.length && arg[0][0] == '-') {
		auto opt=shift(arg);
		if(opt == "--")
				return;

		processOption(opt, arg, cmd);
	}
}



private void processOption(string opt, ref string[] arg, Option[] cmd)
{

	foreach(tag; cmd) {
		auto val=opt;
		if(!tag.match(val))
				continue;

		if(tag.shortOption) {
			if(tag.needArg) {
				if(val == "") {
					if(arg.length == 0)
						throw new Exception("getopt: "~tag.tag~" requires an argument");
					val=shift(arg);
				}
			} else {
				if(val != "") { unshift("-"~val, arg); val=""; }
			}
		}
		tag.handle(val);
		return;
	}
	throw new Exception("getopt: invalid option '"~opt~"'");
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



void main(string arg[])
{
	import std.algorithm.sorting;
	
		int x;
		string file;
		bool verb=true, sink, flag, help;
		enum Choise { one, two, three };
		Choise what;
		int[] v;
		int[string] m;
		char[] ch;

	Option[] opt;
	try {
		getopt(opt, arg
		, "-x", "integer option", &x
		, "-c", "character array", &ch
		, "-d", "argumentless functor", delegate { writeln("delegate() is called");}
		, "-s", "function with one argument", delegate(string data) { writeln("delegate(",data,") is called");}
		, "-f", "argumentless functor", &f
		, "-g", "function with one argument", &g
		, "--force", "boolean flag", &sink
		, "-r", &flag
		, "-o|--output", "file name", &file
		, "-w|--what", "one of 'one','two','three'", &what
		, "-V|--vector", "integer array", &v
		, "-M|--map", "associative array", &m
		, "-h|--help", "this help", &help
		, "-A", &sink
		////, "-.*", &help
		////, "-?", &help
		, "-q", "be quiet", &verb, false
		, "-v", "verbose (opposite of quiet)", &verb, true
	); } catch(Exception x) {
		writeln("error: ",x.msg);
		writeln("--------------------------------------------------------\n", optionHelp(opt));
		return;
	}

	//writeln(typeof(sort!("a.tag < b.tag")(opt)).stringof);
	//writeln(optionHelp(opt[0]));

	if(help)
		writeln("--------------------------------------------------------\n", optionHelp(sort!("a.tag < b.tag")(opt)));
	

	if(flag) writeln("result:"
		, "\n  x=", x
		, "\n  file=", file
		, "\n  choise=", what
		, "\n  array=", v
		, "\n  map=", m
		, "\n  ch=", ch
		, "\n  quiet=", !verb
		, "\nremaining args: ", arg
	);
}

bool ocmp(Option a, Option b) { return a.tag < b.tag; }

void f()
{
	writeln("f() is called");
}

void g(string msg)
{
	writeln("g(", msg, ") is called");
}

