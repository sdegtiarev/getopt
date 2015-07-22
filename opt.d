import local.getopt;
import std.stdio;


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

