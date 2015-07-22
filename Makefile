
	
all: opt

opt: opt.d getopt.d
	dmd opt.d getopt.d
	@rm -f *.o

release:
	dmd -release opt.d getopt.d
	@rm -f *.o

debug:
	dmd -debug opt.d getopt.d
	@rm -f *.o

clean:
	@rm -f opt *.o core
