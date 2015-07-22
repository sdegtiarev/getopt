
DC= dmd
CC= dmd


%: %.d
	$(DC) $(DFLAGS) $<
	@rm -f getopt.o
	
all: getopt

clean:
	@rm -f *.o getopt
