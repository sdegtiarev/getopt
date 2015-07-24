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
		auto r=getopt(opt, arg
			, noThrow.yes
			, "x", "integer option", &x
			, "c", "character array", &ch
			, "d", "argumentless functor", delegate { writeln("delegate() is called");}
			, "s", "function with one argument", delegate(string data) { writeln("delegate(",data,") is called");}
			, Match.regex, "f", "argumentless functor", &f
			, "g", "function with one argument", &g
			, "force", "boolean flag", &sink
			, "r", &flag
			, "o|output", "file name", &file
			, "w|what", "one of 'one','two','three'", &what
			, "V|vector", "integer array", &v
			, "M|map", "associative array", &m
			, "A", &sink
			, "q", "be quiet", &verb, false
			, "v", "verbose (opposite of quiet)", &verb, true
			, Match.regex, "l.*", delegate(string key,int val){ writeln("called L('",key,"',",val,")");}
			, Match.regex, ".", delegate(char key,string val){ writeln("switch ", key, "(",val,")");}
			, Match.regex, "[0-9]+", delegate(int key,string val){ writeln("translate ", key, " => ",val);}
			, Match.regex, "A[A-Z]+",  delegate(string key,string val){ writeln("login: ",key,", password: ", val);}
			, Match.regex, "B(.*)",  delegate(string key,string val){ writeln("login: ",key,", password: ", val);}
			, "h|help|?", "this help", &help
		);
		if(r) {
			writeln("getopt: ",r.msg, "\n--------------------------------------------------------");
			writeln(optionHelp(opt));
			return;
		}
	} catch(Exception x) {
		writeln("error: ",x.msg, "\n--------------------------------------------------------");
		writeln(optionHelp(opt));
		return;
	}

	if(help)
		writeln("Options:\n",optionHelp(sort!("a.tag < b.tag")(opt)));
	

	if(flag) writeln("-------- result --------"
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


void f() { writeln("f() is called"); }

void g(string msg) { writeln("g(", msg, ") is called"); }

