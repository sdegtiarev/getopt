
	
all: opt

opt: opt.d getopt.d
	dmd opt.d getopt.d
	@rm -f *.o

# unconditional rebuild
release:
	dmd -release opt.d getopt.d
	@rm -f *.o

# unconditional rebuild
debug:
	dmd -debug opt.d getopt.d
	@rm -f *.o

# unconditional rebuild
details:
	dmd opt.d getopt.d
	@rm -f *.o


clean:
	@rm -f opt *.o core
