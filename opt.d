import local.getopt;
import std.stdio;


void main(string arg[])
{
	import std.algorithm.sorting;
	
		int x;
		int[] v;
		int[string] m;
		string file;
		bool verb=true, flag, help;
		enum Choise { one, two, three };
		Choise what;
		char[] ch;

	Option[] opt;
	try {
		auto r=getopt(opt, arg
			, noThrow.yes
			, "-x", "integer option", &x
			, "-V|--vector", "integer array", &v
			, "-M|--map", "associative array, string=int", &m
			, "-q|--quiet", "be quiet", &verb, false
			, "-v|--verbose", "verbose (opposite of quiet)", &verb, true
			, "-d", "argumentless functor", delegate { writeln("delegate() is called");}
			, "-e", "argumentless functor", &e
			, "-f", "one argument function f(string)", delegate(string data) { writeln("delegate(",data,") is called");}
			, "-g", "one argument function g(string)", &g
			, "-r|--report", "print result", &flag
			, "-o|--output", "file name", &file
			, "-w|--what", "one of 'one','two','three'", &what
			, Match.regex, "--k.+", delegate(string key,int val){ writeln("matched k('",key,"',",val,")");}
			, Match.regex, "--.", delegate(char key,string val){ writeln("switch ", key, "(",val,")");}
			, Match.regex, "--[0-9]+", delegate(int key,string val){ writeln("translate ", key, " => ",val);}
			, Match.regex, "--l(.*)",  delegate(string key,string val){ writeln("login: ",key,", password: ", val);}
			, Match.regex, "--LOGIN@([A-Z]+)",  delegate(string key,string val){ writeln("login: ",key,", password: ", val);}
			, "-h|--help|-?", "this help", &help
		);
		if(r) {
			writeln("getopt: ",r.msg);
			//writeln("getopt: ",r.msg, "\n--------------------------------------------------------");
			//writeln(optionHelp(opt));
			return;
		}
	} catch(Exception x) {
		writeln("error: ",x.msg);
		//writeln("error: ",x.msg, "\n--------------------------------------------------------");
		//writeln(optionHelp(opt));
		return;
	}

	if(help)
		writeln("Options:\n",optionHelp(sort!("a.group < b.group || a.group == b.group && a.tag < b.tag")(opt)));
	

	if(flag) writeln("-------- result --------"
		, "\n  x=", x
		, "\n  vector=", v
		, "\n  map=", m
		, "\n  file=", file
		, "\n  choise=", what
		, "\n  quiet=", !verb
		, "\nremaining args: ", arg
	);
}


void e() { writeln("e() is called"); }

void g(string msg) { writeln("g(", msg, ") is called"); }

