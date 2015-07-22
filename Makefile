
	
all: opt

opt: opt.d getopt.d
	dmd opt.d getopt.d
	@rm -f *.o

clean:
	@rm -f opt *.o core
